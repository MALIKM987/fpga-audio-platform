#!/usr/bin/env python3
"""Helpers for the extended UART frame protocol.

The legacy RUN_IMPULSE_TEST command remains the three-byte packet
``A5 01 5A``. The helpers in this file implement the newer length-based packet
format intended for full 256-sample frame transfer.
"""

from __future__ import annotations

from dataclasses import dataclass


SOF = 0xA5
EOF = 0x5A

CMD_RUN_IMPULSE_TEST = 0x01
CMD_PING = 0x10
CMD_SET_GAINS = 0x11
CMD_WRITE_FRAME_CHUNK = 0x12
CMD_RUN_FRAME = 0x13
CMD_READ_RESULT_CHUNK = 0x14
CMD_GET_STATUS = 0x15
CMD_ERROR = 0x7F

CMD_PONG = 0x90
CMD_RESULT_CHUNK = 0x94
CMD_STATUS = 0x95

LEGACY_RUN_IMPULSE_TEST_PACKET = bytes([SOF, CMD_RUN_IMPULSE_TEST, EOF])

FRAME_SAMPLES = 256
MAX_CHUNK_SAMPLES = 32
INT16_MIN = -32768
INT16_MAX = 32767


class ProtocolError(ValueError):
    """Raised when a packet or payload violates the protocol."""


@dataclass(frozen=True)
class UartFramePacket:
    """Decoded length-based UART protocol packet."""

    cmd: int
    seq: int
    payload: bytes


def _byte(value: int, name: str) -> int:
    integer = int(value)
    if integer < 0 or integer > 0xFF:
        raise ProtocolError(f"{name} must fit in one byte")
    return integer


def _u16(value: int, name: str) -> int:
    integer = int(value)
    if integer < 0 or integer > 0xFFFF:
        raise ProtocolError(f"{name} must fit in uint16")
    return integer


def _i16(value: int, name: str) -> int:
    integer = int(value)
    if integer < INT16_MIN or integer > INT16_MAX:
        raise ProtocolError(f"{name} must fit in signed int16")
    return integer


def checksum(cmd: int, seq: int, payload: bytes) -> int:
    """Return the 8-bit modulo-sum checksum."""

    cmd_b = _byte(cmd, "cmd")
    seq_b = _byte(seq, "seq")
    payload_bytes = bytes(payload)
    length = len(payload_bytes)
    if length > 0xFFFF:
        raise ProtocolError("payload is too long")

    len_l = length & 0xFF
    len_h = (length >> 8) & 0xFF
    return (cmd_b + seq_b + len_l + len_h + sum(payload_bytes)) & 0xFF


def encode_packet(cmd: int, seq: int = 0, payload: bytes = b"") -> bytes:
    """Encode one length-based UART frame packet."""

    cmd_b = _byte(cmd, "cmd")
    seq_b = _byte(seq, "seq")
    payload_bytes = bytes(payload)
    length = len(payload_bytes)
    if length > 0xFFFF:
        raise ProtocolError("payload is too long")

    len_l = length & 0xFF
    len_h = (length >> 8) & 0xFF
    chk = checksum(cmd_b, seq_b, payload_bytes)
    return bytes([SOF, cmd_b, seq_b, len_l, len_h]) + payload_bytes + bytes(
        [chk, EOF]
    )


def decode_packet(packet: bytes) -> UartFramePacket:
    """Decode and validate one complete length-based UART packet."""

    data = bytes(packet)
    if len(data) < 7:
        raise ProtocolError("packet is too short for framed UART protocol")
    if data[0] != SOF:
        raise ProtocolError("invalid SOF")
    if data[-1] != EOF:
        raise ProtocolError("invalid EOF")

    cmd = data[1]
    seq = data[2]
    length = data[3] | (data[4] << 8)
    expected_len = 1 + 1 + 1 + 2 + length + 1 + 1
    if len(data) != expected_len:
        raise ProtocolError("packet length does not match LEN field")

    payload = data[5 : 5 + length]
    received = data[5 + length]
    expected = checksum(cmd, seq, payload)
    if received != expected:
        raise ProtocolError("bad checksum")

    return UartFramePacket(cmd=cmd, seq=seq, payload=payload)


def pack_i16(value: int) -> bytes:
    """Pack one signed int16 value as little-endian bytes."""

    return _i16(value, "value").to_bytes(2, "little", signed=True)


def unpack_i16(data: bytes) -> int:
    """Unpack one signed int16 little-endian value."""

    if len(data) != 2:
        raise ProtocolError("signed int16 field must have exactly two bytes")
    return int.from_bytes(data, "little", signed=True)


def pack_i16_list(values: list[int] | tuple[int, ...]) -> bytes:
    """Pack signed int16 samples as little-endian bytes."""

    out = bytearray()
    for index, value in enumerate(values):
        out.extend(pack_i16(_i16(value, f"samples[{index}]")))
    return bytes(out)


def unpack_i16_list(data: bytes, count: int) -> list[int]:
    """Unpack ``count`` signed int16 little-endian values."""

    count_i = int(count)
    if count_i < 0:
        raise ProtocolError("count must be non-negative")
    if len(data) != count_i * 2:
        raise ProtocolError("payload length does not match sample count")
    return [unpack_i16(data[index : index + 2]) for index in range(0, len(data), 2)]


def validate_chunk(
    offset: int,
    count: int,
    max_count: int = MAX_CHUNK_SAMPLES,
) -> tuple[int, int]:
    """Validate a frame chunk address and return normalized integers."""

    offset_i = int(offset)
    count_i = int(count)
    max_count_i = int(max_count)

    if offset_i < 0 or offset_i >= FRAME_SAMPLES:
        raise ProtocolError("offset is outside the 256-sample frame")
    if count_i <= 0:
        raise ProtocolError("count must be positive")
    if count_i > max_count_i:
        raise ProtocolError("count exceeds maximum chunk size")
    if offset_i + count_i > FRAME_SAMPLES:
        raise ProtocolError("chunk extends beyond the 256-sample frame")

    return offset_i, count_i


def make_ping(seq: int = 0) -> bytes:
    return encode_packet(CMD_PING, seq)


def make_set_gains(
    bass_gain: int,
    mid_gain: int,
    treble_gain: int,
    seq: int = 0,
) -> bytes:
    payload = pack_i16_list([bass_gain, mid_gain, treble_gain])
    return encode_packet(CMD_SET_GAINS, seq, payload)


def make_write_frame_chunk(
    offset: int,
    samples: list[int] | tuple[int, ...],
    seq: int = 0,
    max_count: int = MAX_CHUNK_SAMPLES,
) -> bytes:
    count = len(samples)
    offset_i, count_i = validate_chunk(offset, count, max_count)
    payload = (
        _u16(offset_i, "offset").to_bytes(2, "little")
        + bytes([count_i])
        + pack_i16_list(samples)
    )
    return encode_packet(CMD_WRITE_FRAME_CHUNK, seq, payload)


def make_run_frame(seq: int = 0) -> bytes:
    return encode_packet(CMD_RUN_FRAME, seq)


def make_read_result_chunk(
    offset: int,
    count: int,
    seq: int = 0,
    max_count: int = MAX_CHUNK_SAMPLES,
) -> bytes:
    offset_i, count_i = validate_chunk(offset, count, max_count)
    payload = _u16(offset_i, "offset").to_bytes(2, "little") + bytes([count_i])
    return encode_packet(CMD_READ_RESULT_CHUNK, seq, payload)


def make_get_status(seq: int = 0) -> bytes:
    return encode_packet(CMD_GET_STATUS, seq)


def decode_result_chunk(packet: bytes | UartFramePacket) -> dict[str, object]:
    """Decode a RESULT_CHUNK response payload."""

    decoded = decode_packet(packet) if isinstance(packet, bytes) else packet
    if decoded.cmd != CMD_RESULT_CHUNK:
        raise ProtocolError("packet is not RESULT_CHUNK")
    if len(decoded.payload) < 4:
        raise ProtocolError("RESULT_CHUNK payload is too short")

    status = decoded.payload[0]
    offset = decoded.payload[1] | (decoded.payload[2] << 8)
    count = decoded.payload[3]
    validate_chunk(offset, count)

    sample_bytes = decoded.payload[4:]
    samples = unpack_i16_list(sample_bytes, count)
    return {
        "seq": decoded.seq,
        "status": status,
        "offset": offset,
        "count": count,
        "samples": samples,
    }


def make_result_chunk_response(
    status: int,
    offset: int,
    samples: list[int] | tuple[int, ...],
    seq: int = 0,
    max_count: int = MAX_CHUNK_SAMPLES,
) -> bytes:
    """Build a RESULT_CHUNK response for tests and future mocks."""

    count = len(samples)
    offset_i, count_i = validate_chunk(offset, count, max_count)
    payload = (
        bytes([_byte(status, "status")])
        + _u16(offset_i, "offset").to_bytes(2, "little")
        + bytes([count_i])
        + pack_i16_list(samples)
    )
    return encode_packet(CMD_RESULT_CHUNK, seq, payload)


def build_write_frame_chunks(
    samples: list[int] | tuple[int, ...],
    seq_start: int = 0,
    chunk_size: int = MAX_CHUNK_SAMPLES,
) -> list[bytes]:
    """Convert one 256-sample int16 frame into WRITE_FRAME_CHUNK packets."""

    frame = list(samples)
    if len(frame) != FRAME_SAMPLES:
        raise ProtocolError("frame must contain exactly 256 samples")
    if chunk_size <= 0 or chunk_size > MAX_CHUNK_SAMPLES:
        raise ProtocolError("chunk_size must be in range 1..MAX_CHUNK_SAMPLES")

    packets: list[bytes] = []
    seq = _byte(seq_start, "seq_start")
    for offset in range(0, FRAME_SAMPLES, chunk_size):
        chunk = frame[offset : offset + chunk_size]
        packets.append(make_write_frame_chunk(offset, chunk, seq=seq))
        seq = (seq + 1) & 0xFF
    return packets


def build_read_result_requests(
    seq_start: int = 0,
    chunk_size: int = MAX_CHUNK_SAMPLES,
) -> list[bytes]:
    """Build READ_RESULT_CHUNK requests for a complete 256-sample frame."""

    if chunk_size <= 0 or chunk_size > MAX_CHUNK_SAMPLES:
        raise ProtocolError("chunk_size must be in range 1..MAX_CHUNK_SAMPLES")

    packets: list[bytes] = []
    seq = _byte(seq_start, "seq_start")
    for offset in range(0, FRAME_SAMPLES, chunk_size):
        count = min(chunk_size, FRAME_SAMPLES - offset)
        packets.append(make_read_result_chunk(offset, count, seq=seq))
        seq = (seq + 1) & 0xFF
    return packets
