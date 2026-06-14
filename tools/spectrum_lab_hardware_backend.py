#!/usr/bin/env python3
"""PC-side backend for the UART frame FPGA flow.

This module keeps the PC application on the documented UART frame protocol:
the PC uploads gains and one 256-sample frame, requests processing, polls
status, and reads result chunks. It does not control FFT/IFFT registers
directly; the mini CPU owns that work on the FPGA side.
"""

from __future__ import annotations

from dataclasses import dataclass
import time

from spectrum_lab_model import SignalComponent, SpectrumModification
from uart_frame_protocol import (
    CMD_ERROR,
    CMD_PONG,
    CMD_RESULT_CHUNK,
    CMD_STATUS,
    FRAME_SAMPLES,
    ProtocolError,
    UartFramePacket,
    build_read_result_requests,
    build_write_frame_chunks,
    decode_packet,
    decode_result_chunk,
    make_get_status,
    make_ping,
    make_run_frame,
    make_set_gains,
)
from uart_transport import (
    STATUS_CPU_BUSY,
    STATUS_DONE,
    STATUS_ERROR,
    STATUS_INPUT_LOADED,
    STATUS_TIMEOUT,
    TransportError,
    UartTransport,
)


DEFAULT_TIMEOUT_S = 2.0
DEFAULT_POLL_INTERVAL_S = 0.01
Q2_14_SCALE = 16_384
HARDWARE_GAIN_MIN_Q2_14 = -32_768
HARDWARE_GAIN_MAX_Q2_14 = 32_767
HARDWARE_GAIN_MIN_FLOAT = HARDWARE_GAIN_MIN_Q2_14 / float(Q2_14_SCALE)
HARDWARE_GAIN_MAX_FLOAT = HARDWARE_GAIN_MAX_Q2_14 / float(Q2_14_SCALE)

RTL_BASS_MAX_BIN = 1
RTL_MID_MAX_BIN = 21


class HardwareBackendError(RuntimeError):
    """Raised when the PC-side FPGA backend sees an invalid transaction."""


@dataclass(frozen=True)
class Gains:
    """Q2.14 gains used by the current UART frame protocol."""

    bass_gain: int = 16384
    mid_gain: int = 16384
    treble_gain: int = 16384


@dataclass(frozen=True)
class HardwareFrameResult:
    """Result returned by ``run_frame``."""

    status: int
    samples: list[int]
    status_history: list[int]


def q2_14_to_float(value: int) -> float:
    """Convert a signed 16-bit Q2.14 gain value to float."""

    signed_value = int(value)
    if signed_value > 0x7FFF:
        signed_value -= 0x10000
    return signed_value / float(Q2_14_SCALE)


def float_gain_to_q2_14(gain: float) -> int:
    """Encode a GUI gain as the signed 16-bit Q2.14 value used by FPGA."""

    raw_value = int(round(float(gain) * float(Q2_14_SCALE)))
    return max(HARDWARE_GAIN_MIN_Q2_14, min(HARDWARE_GAIN_MAX_Q2_14, raw_value))


def gain_was_clipped(gain: float) -> bool:
    """Return True when a GUI gain cannot be represented by signed Q2.14."""

    raw_value = int(round(float(gain) * float(Q2_14_SCALE)))
    return raw_value < HARDWARE_GAIN_MIN_Q2_14 or raw_value > HARDWARE_GAIN_MAX_Q2_14


def hardware_band_for_frequency(
    frequency_hz: float,
    sample_rate_hz: float = 48_000.0,
    frame_size: int = FRAME_SAMPLES,
) -> str:
    """Map a GUI center frequency to the current RTL BASS/MID/TREBLE bands."""

    if sample_rate_hz <= 0.0 or frame_size <= 0:
        raise ValueError("sample_rate_hz and frame_size must be positive")

    bin_hz = sample_rate_hz / float(frame_size)
    effective_bin = int(round(max(0.0, float(frequency_hz)) / bin_hz))

    if effective_bin <= RTL_BASS_MAX_BIN:
        return "bass"
    if effective_bin <= RTL_MID_MAX_BIN:
        return "mid"
    return "treble"


def hardware_gains_from_modifications(
    modifications: list[SpectrumModification] | tuple[SpectrumModification, ...],
    sample_rate_hz: float = 48_000.0,
    frame_size: int = FRAME_SAMPLES,
) -> Gains:
    """Collapse GUI modifications to the current three hardware band gains."""

    bass = Q2_14_SCALE
    mid = Q2_14_SCALE
    treble = Q2_14_SCALE

    for modification in modifications:
        gain = float_gain_to_q2_14(modification.gain)
        band = hardware_band_for_frequency(
            modification.center_frequency_hz,
            sample_rate_hz=sample_rate_hz,
            frame_size=frame_size,
        )
        if band == "bass":
            bass = gain
        elif band == "mid":
            mid = gain
        else:
            treble = gain

    return Gains(bass, mid, treble)


def hardware_operating_warnings(
    modifications: list[SpectrumModification] | tuple[SpectrumModification, ...],
    sample_rate_hz: float = 48_000.0,
    frame_size: int = FRAME_SAMPLES,
) -> list[str]:
    """Return concise warnings for GUI settings that differ from FPGA limits."""

    warnings: list[str] = []
    nyquist = sample_rate_hz / 2.0
    seen_bands: dict[str, int] = {}

    for modification in modifications:
        if modification.center_frequency_hz > nyquist:
            warnings.append(
                f"frequency {modification.center_frequency_hz:g} Hz is above "
                f"Nyquist {nyquist:g} Hz for Fs={sample_rate_hz:g} Hz"
            )
        if modification.gain > HARDWARE_GAIN_MAX_FLOAT:
            warnings.append(
                f"gain {modification.gain:g} is above signed Q2.14 positive "
                f"limit +{HARDWARE_GAIN_MAX_FLOAT:.5f}; FPGA clips it to "
                "about gain=2.0"
            )
        elif modification.gain < HARDWARE_GAIN_MIN_FLOAT:
            warnings.append(
                f"gain {modification.gain:g} is below signed Q2.14 negative "
                f"limit {HARDWARE_GAIN_MIN_FLOAT:.1f}; FPGA clips it to "
                "gain=-2.0"
            )

        band = hardware_band_for_frequency(
            modification.center_frequency_hz,
            sample_rate_hz=sample_rate_hz,
            frame_size=frame_size,
        )
        seen_bands[band] = seen_bands.get(band, 0) + 1

    for band, count in sorted(seen_bands.items()):
        if count > 1:
            warnings.append(
                f"same hardware band collision: {count} modifications map to "
                f"hardware {band.upper()} band; "
                "only the last gain is sent to FPGA"
            )

    return warnings


def signal_component_warnings(
    components: list[SignalComponent] | tuple[SignalComponent, ...],
    sample_rate_hz: float = 48_000.0,
) -> list[str]:
    """Return warnings for generated input components outside sample-rate limits."""

    warnings: list[str] = []
    nyquist = sample_rate_hz / 2.0

    for component in components:
        if abs(component.frequency_hz) > nyquist:
            warnings.append(
                f"input component frequency {component.frequency_hz:g} Hz is above "
                f"Nyquist {nyquist:g} Hz for Fs={sample_rate_hz:g} Hz"
            )

    return warnings


def decode_status_bits(status: int) -> dict[str, bool]:
    """Decode the frame STATUS byte into named flags."""

    value = int(status) & 0xFF
    return {
        "input_loaded": bool(value & STATUS_INPUT_LOADED),
        "cpu_busy": bool(value & STATUS_CPU_BUSY),
        "done": bool(value & STATUS_DONE),
        "error": bool(value & STATUS_ERROR),
        "timeout": bool(value & STATUS_TIMEOUT),
    }


def _normalize_gains(gains: Gains | tuple[int, int, int] | dict[str, int]) -> Gains:
    if isinstance(gains, Gains):
        return gains
    if isinstance(gains, dict):
        return Gains(
            bass_gain=int(gains.get("bass_gain", 16384)),
            mid_gain=int(gains.get("mid_gain", 16384)),
            treble_gain=int(gains.get("treble_gain", 16384)),
        )
    bass_gain, mid_gain, treble_gain = gains
    return Gains(int(bass_gain), int(mid_gain), int(treble_gain))


def _decode_response(response: bytes, expected_cmd: int | None = None) -> UartFramePacket:
    try:
        decoded = decode_packet(response)
    except ProtocolError as exc:
        raise HardwareBackendError(f"invalid UART response: {exc}") from exc

    if decoded.cmd == CMD_ERROR:
        detail = decoded.payload[0] if decoded.payload else 0
        raise HardwareBackendError(f"FPGA returned ERROR for command 0x{detail:02X}")

    if expected_cmd is not None and decoded.cmd != expected_cmd:
        raise HardwareBackendError(
            f"unexpected response command 0x{decoded.cmd:02X}, "
            f"expected 0x{expected_cmd:02X}"
        )

    return decoded


def _status_from_response(response: bytes) -> int:
    decoded = _decode_response(response, CMD_STATUS)
    if len(decoded.payload) != 1:
        raise HardwareBackendError("STATUS response must contain one status byte")
    return decoded.payload[0]


def _transact(
    transport: UartTransport,
    packet: bytes,
    timeout_s: float,
    expected_cmd: int | None = None,
) -> UartFramePacket:
    try:
        response = transport.transact(packet, timeout_s=timeout_s)
    except TransportError as exc:
        raise HardwareBackendError(str(exc)) from exc
    return _decode_response(response, expected_cmd)


def build_transfer_sequence(
    samples_i16: list[int] | tuple[int, ...],
    bass_gain: int,
    mid_gain: int,
    treble_gain: int,
) -> list[bytes]:
    """Build the upload/start packet sequence for one 256-sample frame."""

    frame = list(samples_i16)
    if len(frame) != FRAME_SAMPLES:
        raise HardwareBackendError("samples_i16 must contain exactly 256 samples")

    packets = [
        make_ping(seq=0),
        make_set_gains(bass_gain, mid_gain, treble_gain, seq=1),
    ]
    packets.extend(build_write_frame_chunks(frame, seq_start=2))
    packets.append(make_run_frame(seq=10))
    return packets


def ping(transport: UartTransport, timeout_s: float = DEFAULT_TIMEOUT_S) -> None:
    """Send PING and require PONG."""

    _transact(transport, make_ping(seq=0), timeout_s, expected_cmd=CMD_PONG)


def set_gains(
    transport: UartTransport,
    bass_gain: int,
    mid_gain: int,
    treble_gain: int,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    seq: int = 1,
) -> int:
    """Write Q2.14 gains and return the STATUS byte."""

    response = transport.transact(
        make_set_gains(bass_gain, mid_gain, treble_gain, seq=seq),
        timeout_s=timeout_s,
    )
    return _status_from_response(response)


def write_frame(
    transport: UartTransport,
    samples_i16: list[int] | tuple[int, ...],
    timeout_s: float = DEFAULT_TIMEOUT_S,
    seq_start: int = 2,
) -> list[int]:
    """Write all 256 frame samples as eight 32-sample chunks."""

    statuses: list[int] = []
    for packet in build_write_frame_chunks(samples_i16, seq_start=seq_start):
        statuses.append(_status_from_response(transport.transact(packet, timeout_s)))
    return statuses


def run_processing(
    transport: UartTransport,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    seq: int = 10,
) -> int:
    """Send RUN_FRAME and return the immediate STATUS response."""

    response = transport.transact(make_run_frame(seq=seq), timeout_s=timeout_s)
    return _status_from_response(response)


def poll_status(
    transport: UartTransport,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    poll_interval_s: float = DEFAULT_POLL_INTERVAL_S,
    seq_start: int = 32,
) -> tuple[int, list[int]]:
    """Poll GET_STATUS until DONE or an error/timeout status appears."""

    deadline = time.monotonic() + float(timeout_s)
    seq = seq_start & 0xFF
    history: list[int] = []

    while True:
        response = transport.transact(make_get_status(seq=seq), timeout_s=timeout_s)
        status = _status_from_response(response)
        history.append(status)

        if status & (STATUS_DONE | STATUS_ERROR | STATUS_TIMEOUT):
            return status, history

        if time.monotonic() >= deadline:
            raise HardwareBackendError("timed out waiting for STATUS_DONE")

        seq = (seq + 1) & 0xFF
        if poll_interval_s > 0.0:
            time.sleep(poll_interval_s)


def read_result_frame(
    transport: UartTransport,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    seq_start: int = 64,
) -> tuple[int, list[int]]:
    """Read and reconstruct the complete 256-sample result frame."""

    result = [0 for _ in range(FRAME_SAMPLES)]
    final_status = 0

    for packet in build_read_result_requests(seq_start=seq_start):
        decoded = _transact(transport, packet, timeout_s, expected_cmd=CMD_RESULT_CHUNK)
        chunk = decode_result_chunk(decoded)
        offset = int(chunk["offset"])
        count = int(chunk["count"])
        samples = list(chunk["samples"])
        if count != len(samples):
            raise HardwareBackendError("RESULT_CHUNK count does not match samples")
        result[offset : offset + count] = samples
        final_status = int(chunk["status"])

    return final_status, result


def run_frame(
    samples_i16: list[int] | tuple[int, ...],
    gains: Gains | tuple[int, int, int] | dict[str, int],
    transport: UartTransport,
    timeout_s: float = DEFAULT_TIMEOUT_S,
) -> HardwareFrameResult:
    """Upload one frame, run FPGA processing, and read back 256 samples."""

    gain_values = _normalize_gains(gains)
    frame = list(samples_i16)
    if len(frame) != FRAME_SAMPLES:
        raise HardwareBackendError("samples_i16 must contain exactly 256 samples")

    ping(transport, timeout_s=timeout_s)
    set_gains(
        transport,
        gain_values.bass_gain,
        gain_values.mid_gain,
        gain_values.treble_gain,
        timeout_s=timeout_s,
        seq=1,
    )
    write_frame(transport, frame, timeout_s=timeout_s, seq_start=2)
    run_processing(transport, timeout_s=timeout_s, seq=10)
    status, history = poll_status(transport, timeout_s=timeout_s, seq_start=32)

    if status & (STATUS_ERROR | STATUS_TIMEOUT):
        flags = decode_status_bits(status)
        raise HardwareBackendError(f"processing failed with status {flags}")
    if (status & STATUS_DONE) == 0:
        raise HardwareBackendError("processing finished without STATUS_DONE")

    final_status, result = read_result_frame(
        transport,
        timeout_s=timeout_s,
        seq_start=64,
    )
    return HardwareFrameResult(
        status=final_status,
        samples=result,
        status_history=history,
    )
