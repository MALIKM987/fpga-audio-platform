#!/usr/bin/env python3
"""Transport abstractions for the UART frame protocol.

The core project tests use ``MockFpgaTransport`` and do not require pyserial.
``SerialTransport`` imports pyserial lazily only when real hardware is selected.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
import time

from uart_frame_protocol import (
    CMD_ERROR,
    CMD_GET_STATUS,
    CMD_PING,
    CMD_PONG,
    CMD_READ_RESULT_CHUNK,
    CMD_RUN_FRAME,
    CMD_SET_GAINS,
    CMD_STATUS,
    CMD_WRITE_FRAME_CHUNK,
    EOF,
    FRAME_SAMPLES,
    MAX_CHUNK_SAMPLES,
    SOF,
    ProtocolError,
    UartFramePacket,
    decode_packet,
    encode_packet,
    make_result_chunk_response,
    unpack_i16_list,
    validate_chunk,
)


STATUS_INPUT_LOADED = 0x01
STATUS_CPU_BUSY = 0x02
STATUS_DONE = 0x04
STATUS_ERROR = 0x08
STATUS_TIMEOUT = 0x10


class TransportError(RuntimeError):
    """Raised when a UART transport cannot complete a transaction."""


class UartTransport:
    """Minimal request/response transport interface used by the PC backend."""

    def transact(self, packet: bytes, timeout_s: float = 1.0) -> bytes:
        raise NotImplementedError

    def close(self) -> None:
        """Close any owned resources."""


class FakeTransport(UartTransport):
    """Small test transport backed by a request handler callable."""

    def __init__(self, handler: Callable[[bytes], bytes]) -> None:
        self.handler = handler
        self.tx_packets: list[bytes] = []
        self.rx_packets: list[bytes] = []

    def transact(self, packet: bytes, timeout_s: float = 1.0) -> bytes:
        del timeout_s
        request = bytes(packet)
        self.tx_packets.append(request)
        response = bytes(self.handler(request))
        self.rx_packets.append(response)
        return response


@dataclass
class MockFpgaTransport(UartTransport):
    """Deterministic FPGA-side UART frame mock.

    The mock emulates the CPU-owned mailbox flow at packet level. It currently
    returns loopback samples after RUN_FRAME; it does not model the real FFT/IFFT
    math and is intentionally not a replacement for RTL simulation.
    """

    processing_polls: int = 1
    input_frame: list[int] = field(
        default_factory=lambda: [0 for _ in range(FRAME_SAMPLES)]
    )
    result_frame: list[int] = field(
        default_factory=lambda: [0 for _ in range(FRAME_SAMPLES)]
    )
    gains: tuple[int, int, int] = (16384, 16384, 16384)
    status: int = 0
    tx_packets: list[bytes] = field(default_factory=list)
    rx_packets: list[bytes] = field(default_factory=list)
    requests: list[UartFramePacket] = field(default_factory=list)
    busy_polls_remaining: int = 0

    def transact(self, packet: bytes, timeout_s: float = 1.0) -> bytes:
        del timeout_s
        request = bytes(packet)
        self.tx_packets.append(request)

        try:
            decoded = decode_packet(request)
            self.requests.append(decoded)
            response = self._handle(decoded)
        except ProtocolError:
            response = encode_packet(CMD_ERROR, 0, bytes([CMD_ERROR]))

        self.rx_packets.append(response)
        return response

    def _status_response(self, seq: int) -> bytes:
        return encode_packet(CMD_STATUS, seq, bytes([self.status & 0xFF]))

    def _error_response(self, seq: int, cmd: int) -> bytes:
        self.status |= STATUS_ERROR
        return encode_packet(CMD_ERROR, seq, bytes([cmd & 0xFF]))

    def _handle(self, packet: UartFramePacket) -> bytes:
        if packet.cmd == CMD_PING and packet.payload == b"":
            return encode_packet(CMD_PONG, packet.seq)

        if packet.cmd == CMD_SET_GAINS:
            if len(packet.payload) != 6:
                return self._error_response(packet.seq, packet.cmd)
            values = unpack_i16_list(packet.payload, 3)
            self.gains = (values[0], values[1], values[2])
            return self._status_response(packet.seq)

        if packet.cmd == CMD_WRITE_FRAME_CHUNK:
            if len(packet.payload) < 3:
                return self._error_response(packet.seq, packet.cmd)
            offset = packet.payload[0] | (packet.payload[1] << 8)
            count = packet.payload[2]
            try:
                validate_chunk(offset, count, MAX_CHUNK_SAMPLES)
                samples = unpack_i16_list(packet.payload[3:], count)
            except ProtocolError:
                return self._error_response(packet.seq, packet.cmd)

            self.input_frame[offset : offset + count] = samples
            self.status = STATUS_INPUT_LOADED
            return self._status_response(packet.seq)

        if packet.cmd == CMD_RUN_FRAME and packet.payload == b"":
            if (self.status & STATUS_INPUT_LOADED) == 0:
                return self._error_response(packet.seq, packet.cmd)
            if (self.status & STATUS_CPU_BUSY) != 0:
                return self._error_response(packet.seq, packet.cmd)

            self.result_frame = list(self.input_frame)
            self.busy_polls_remaining = max(0, int(self.processing_polls))
            if self.busy_polls_remaining:
                self.status = STATUS_INPUT_LOADED | STATUS_CPU_BUSY
            else:
                self.status = STATUS_INPUT_LOADED | STATUS_DONE
            return self._status_response(packet.seq)

        if packet.cmd == CMD_GET_STATUS and packet.payload == b"":
            if self.busy_polls_remaining > 0:
                self.busy_polls_remaining -= 1
                if self.busy_polls_remaining == 0:
                    self.status = STATUS_INPUT_LOADED | STATUS_DONE
            return self._status_response(packet.seq)

        if packet.cmd == CMD_READ_RESULT_CHUNK:
            if len(packet.payload) != 3:
                return self._error_response(packet.seq, packet.cmd)
            offset = packet.payload[0] | (packet.payload[1] << 8)
            count = packet.payload[2]
            try:
                validate_chunk(offset, count, MAX_CHUNK_SAMPLES)
            except ProtocolError:
                return self._error_response(packet.seq, packet.cmd)

            if (self.status & STATUS_DONE) == 0:
                return self._error_response(packet.seq, packet.cmd)

            samples = self.result_frame[offset : offset + count]
            return make_result_chunk_response(
                self.status,
                offset,
                samples,
                seq=packet.seq,
            )

        return self._error_response(packet.seq, packet.cmd)


MockTransport = MockFpgaTransport


class SerialTransport(UartTransport):
    """pyserial-backed packet transport for real UART hardware."""

    def __init__(
        self,
        port: str,
        baudrate: int = 115200,
        timeout_s: float = 1.0,
    ) -> None:
        try:
            import serial
        except ImportError as exc:  # pragma: no cover - optional dependency.
            raise TransportError(
                "pyserial is required for SerialTransport. "
                "Install it with: python -m pip install pyserial"
            ) from exc

        self._serial_module = serial
        try:
            self._serial = serial.Serial(
                port=port,
                baudrate=baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=timeout_s,
            )
        except serial.SerialException as exc:  # pragma: no cover - hardware path.
            raise TransportError(f"could not open serial port {port}: {exc}") from exc

    def close(self) -> None:
        self._serial.close()

    def __enter__(self) -> "SerialTransport":
        return self

    def __exit__(self, _exc_type, _exc, _traceback) -> None:
        self.close()

    def _read_exact(self, count: int, timeout_s: float) -> bytes:
        deadline = time.monotonic() + timeout_s
        out = bytearray()
        while len(out) < count:
            if time.monotonic() > deadline:
                raise TransportError("serial read timed out")
            chunk = self._serial.read(count - len(out))
            if chunk:
                out.extend(chunk)
        return bytes(out)

    def _read_packet(self, timeout_s: float) -> bytes:
        deadline = time.monotonic() + timeout_s
        while True:
            if time.monotonic() > deadline:
                raise TransportError("timed out waiting for packet SOF")
            start = self._serial.read(1)
            if start == bytes([SOF]):
                break

        header = self._read_exact(4, timeout_s)
        length = header[2] | (header[3] << 8)
        payload_checksum_eof = self._read_exact(length + 2, timeout_s)
        packet = bytes([SOF]) + header + payload_checksum_eof
        if packet[-1] != EOF:
            raise TransportError("received packet has invalid EOF")
        decode_packet(packet)
        return packet

    def transact(self, packet: bytes, timeout_s: float = 1.0) -> bytes:
        timeout = float(timeout_s)
        old_timeout = self._serial.timeout
        self._serial.timeout = timeout
        try:
            self._serial.write(bytes(packet))
            self._serial.flush()
            return self._read_packet(timeout)
        except self._serial_module.SerialException as exc:  # pragma: no cover.
            raise TransportError(f"serial transaction failed: {exc}") from exc
        finally:
            self._serial.timeout = old_timeout
