#!/usr/bin/env python3
"""Console tests for the PC-side Spectrum Lab UART hardware backend."""

from __future__ import annotations

import sys

from spectrum_lab_hardware_backend import (
    Gains,
    build_transfer_sequence,
    float_gain_to_q2_14,
    gain_was_clipped,
    hardware_band_for_frequency,
    hardware_gains_from_modifications,
    hardware_operating_warnings,
    poll_status,
    q2_14_to_float,
    run_frame,
    signal_component_warnings,
)
from spectrum_lab_model import SignalComponent, SpectrumModification, simulate_spectrum_lab
from uart_frame_protocol import (
    CMD_PING,
    CMD_READ_RESULT_CHUNK,
    CMD_RUN_FRAME,
    CMD_SET_GAINS,
    CMD_WRITE_FRAME_CHUNK,
    FRAME_SAMPLES,
    decode_packet,
    unpack_i16_list,
)
from uart_transport import (
    STATUS_DONE,
    STATUS_INPUT_LOADED,
    MockFpgaTransport,
    SerialTransport,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def special_frame() -> list[int]:
    frame = [index - 128 for index in range(FRAME_SAMPLES)]
    frame[0] = 0x00A5
    frame[1] = 0x005A
    frame[2] = 0x5AA5
    frame[3] = -0x5A
    return frame


def decoded_sequence(samples: list[int]) -> list:
    packets = build_transfer_sequence(samples, 24576, 16384, 12288)
    return [decode_packet(packet) for packet in packets]


def test_transfer_sequence_shape() -> bool:
    decoded = decoded_sequence([0 for _ in range(FRAME_SAMPLES)])
    commands = [packet.cmd for packet in decoded]
    return (
        len(decoded) == 11
        and commands[0] == CMD_PING
        and commands[1] == CMD_SET_GAINS
        and commands[2:10] == [CMD_WRITE_FRAME_CHUNK] * 8
        and commands[10] == CMD_RUN_FRAME
    )


def test_set_gains_packet() -> bool:
    decoded = decoded_sequence([0 for _ in range(FRAME_SAMPLES)])
    gains = unpack_i16_list(decoded[1].payload, 3)
    return gains == [24576, 16384, 12288]


def test_write_chunk_offsets() -> bool:
    decoded = decoded_sequence([0 for _ in range(FRAME_SAMPLES)])
    offsets: list[int] = []
    counts: list[int] = []
    for packet in decoded[2:10]:
        offsets.append(packet.payload[0] | (packet.payload[1] << 8))
        counts.append(packet.payload[2])
    return offsets == [0, 32, 64, 96, 128, 160, 192, 224] and counts == [32] * 8


def test_run_frame_after_chunks() -> bool:
    decoded = decoded_sequence([0 for _ in range(FRAME_SAMPLES)])
    return decoded[9].cmd == CMD_WRITE_FRAME_CHUNK and decoded[10].cmd == CMD_RUN_FRAME


def test_mock_poll_status() -> bool:
    transport = MockFpgaTransport(processing_polls=2)
    samples = [0 for _ in range(FRAME_SAMPLES)]
    for packet in build_transfer_sequence(samples, 16384, 16384, 16384):
        transport.transact(packet)
    status, history = poll_status(transport, timeout_s=1.0, poll_interval_s=0.0)
    return (
        len(history) >= 2
        and history[0] == (STATUS_INPUT_LOADED | 0x02)
        and (status & STATUS_DONE) != 0
    )


def test_run_frame_reconstructs_256_samples() -> bool:
    samples = special_frame()
    transport = MockFpgaTransport()
    result = run_frame(samples, Gains(16384, 16384, 16384), transport, timeout_s=1.0)
    read_requests = [packet for packet in transport.requests if packet.cmd == CMD_READ_RESULT_CHUNK]
    return (
        len(result.samples) == FRAME_SAMPLES
        and result.samples == samples
        and len(read_requests) == 8
    )


def test_framing_bytes_in_payload() -> bool:
    samples = special_frame()
    transport = MockFpgaTransport()
    result = run_frame(samples, (16384, 16384, 16384), transport, timeout_s=1.0)
    payload_packets = [packet for packet in transport.tx_packets if 0xA5 in packet[5:-2]]
    return result.samples[:4] == samples[:4] and len(payload_packets) >= 1


def test_pyserial_not_required_for_tests() -> bool:
    return SerialTransport is not None and MockFpgaTransport().gains == (16384, 16384, 16384)


def test_local_simulation_unaffected() -> bool:
    result = simulate_spectrum_lab(
        components=[SignalComponent(1000.0, 0.5)],
        modifications=[SpectrumModification(1000.0, 300.0, 1.5)],
    )
    return len(result.input_int16.samples) == 256 and len(result.output_int16.samples) == 256


def test_gain_q2_14_helpers() -> bool:
    return (
        float_gain_to_q2_14(0.5) == 8192
        and float_gain_to_q2_14(1.0) == 16384
        and float_gain_to_q2_14(2.0) == 32767
        and float_gain_to_q2_14(4.0) == 32767
        and gain_was_clipped(4.0)
        and not gain_was_clipped(1.5)
        and abs(q2_14_to_float(32767) - 1.99993896484375) < 1.0e-12
    )


def test_hardware_gain_mapping() -> bool:
    gains = hardware_gains_from_modifications(
        [
            SpectrumModification(1000.0, 500.0, 1.5),
            SpectrumModification(2700.0, 600.0, 0.5),
            SpectrumModification(6200.0, 800.0, 1.0),
        ]
    )
    return (
        hardware_band_for_frequency(100.0) == "bass"
        and hardware_band_for_frequency(1000.0) == "mid"
        and hardware_band_for_frequency(6200.0) == "treble"
        and gains.bass_gain == 16384
        and gains.mid_gain == 8192
        and gains.treble_gain == 16384
    )


def test_hardware_operating_warnings() -> bool:
    warnings = hardware_operating_warnings(
        [
            SpectrumModification(1000.0, 500.0, 4.0),
            SpectrumModification(2700.0, 600.0, 0.5),
            SpectrumModification(3300.0, 600.0, -3.0),
            SpectrumModification(30_000.0, 800.0, 1.0),
        ]
    )
    joined = "\n".join(warnings)
    return (
        "gain 4" in joined
        and "positive limit" in joined
        and "gain -3" in joined
        and "negative limit" in joined
        and "above Nyquist" in joined
        and "same hardware band collision" in joined
        and "hardware MID band" in joined
    )


def test_signal_component_warnings() -> bool:
    warnings = signal_component_warnings(
        [
            SignalComponent(1000.0, 0.1),
            SignalComponent(25_000.0, 0.1),
        ]
    )
    joined = "\n".join(warnings)
    return "input component frequency 25000" in joined and "Nyquist 24000" in joined


def main() -> int:
    print("=== SPECTRUM LAB HARDWARE BACKEND TEST ===")
    report("transfer_sequence_shape", test_transfer_sequence_shape())
    report("set_gains_packet", test_set_gains_packet())
    report("write_chunk_offsets", test_write_chunk_offsets())
    report("run_frame_after_chunks", test_run_frame_after_chunks())
    report("mock_get_status_polling", test_mock_poll_status())
    report("read_result_reconstructs_256_samples", test_run_frame_reconstructs_256_samples())
    report("payload_a5_5a_roundtrip", test_framing_bytes_in_payload())
    report("pyserial_not_required", test_pyserial_not_required_for_tests())
    report("local_simulation_unaffected", test_local_simulation_unaffected())
    report("gain_q2_14_helpers", test_gain_q2_14_helpers())
    report("hardware_gain_mapping", test_hardware_gain_mapping())
    report("hardware_operating_warnings", test_hardware_operating_warnings())
    report("signal_component_warnings", test_signal_component_warnings())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
