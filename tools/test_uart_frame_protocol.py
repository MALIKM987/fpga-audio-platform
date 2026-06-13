#!/usr/bin/env python3
"""Console tests for the extended UART frame protocol helpers."""

from __future__ import annotations

import sys

from uart_frame_protocol import (
    CMD_PING,
    CMD_RESULT_CHUNK,
    CMD_SET_GAINS,
    CMD_WRITE_FRAME_CHUNK,
    LEGACY_RUN_IMPULSE_TEST_PACKET,
    MAX_CHUNK_SAMPLES,
    ProtocolError,
    build_read_result_requests,
    build_write_frame_chunks,
    checksum,
    decode_packet,
    decode_result_chunk,
    encode_packet,
    make_ping,
    make_read_result_chunk,
    make_result_chunk_response,
    make_set_gains,
    make_write_frame_chunk,
    pack_i16_list,
    unpack_i16_list,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def expect_protocol_error(func) -> bool:
    try:
        func()
    except ProtocolError:
        return True
    return False


def test_ping_encode_decode() -> bool:
    packet = make_ping(seq=7)
    decoded = decode_packet(packet)
    return decoded.cmd == CMD_PING and decoded.seq == 7 and decoded.payload == b""


def test_checksum_value() -> bool:
    return checksum(CMD_PING, 0x22, b"") == ((CMD_PING + 0x22) & 0xFF)


def test_bad_checksum_rejected() -> bool:
    packet = bytearray(make_ping(seq=3))
    packet[-2] ^= 0x55
    return expect_protocol_error(lambda: decode_packet(bytes(packet)))


def test_payload_can_contain_framing_bytes() -> bool:
    payload = bytes([0xA5, 0x5A, 0x00, 0xFF, 0xA5, 0x5A])
    packet = encode_packet(CMD_WRITE_FRAME_CHUNK, seq=9, payload=payload)
    decoded = decode_packet(packet)
    return decoded.cmd == CMD_WRITE_FRAME_CHUNK and decoded.payload == payload


def test_set_gains_payload() -> bool:
    packet = make_set_gains(16384, 12288, -8192, seq=4)
    decoded = decode_packet(packet)
    expected = pack_i16_list([16384, 12288, -8192])
    values = unpack_i16_list(decoded.payload, 3)
    return (
        decoded.cmd == CMD_SET_GAINS
        and decoded.seq == 4
        and decoded.payload == expected
        and values == [16384, 12288, -8192]
    )


def test_write_frame_chunk_payload() -> bool:
    samples = [-32768, -1, 0, 32767]
    packet = make_write_frame_chunk(16, samples, seq=5)
    decoded = decode_packet(packet)
    offset = decoded.payload[0] | (decoded.payload[1] << 8)
    count = decoded.payload[2]
    decoded_samples = unpack_i16_list(decoded.payload[3:], count)
    return (
        decoded.cmd == CMD_WRITE_FRAME_CHUNK
        and offset == 16
        and count == len(samples)
        and decoded_samples == samples
    )


def test_invalid_offset_count_rejected() -> bool:
    checks = [
        lambda: make_write_frame_chunk(250, list(range(10))),
        lambda: make_write_frame_chunk(0, list(range(MAX_CHUNK_SAMPLES + 1))),
        lambda: make_write_frame_chunk(0, []),
        lambda: make_write_frame_chunk(0, [40000]),
        lambda: make_read_result_chunk(255, 2),
        lambda: make_read_result_chunk(0, 0),
        lambda: make_read_result_chunk(0, MAX_CHUNK_SAMPLES + 1),
    ]
    return all(expect_protocol_error(check) for check in checks)


def test_result_chunk_decode() -> bool:
    response = make_result_chunk_response(0x03, 64, [64, 0, -2], seq=11)
    decoded = decode_packet(response)
    result = decode_result_chunk(decoded)
    return (
        decoded.cmd == CMD_RESULT_CHUNK
        and result["seq"] == 11
        and result["status"] == 0x03
        and result["offset"] == 64
        and result["count"] == 3
        and result["samples"] == [64, 0, -2]
    )


def test_legacy_packet_is_separate() -> bool:
    return (
        LEGACY_RUN_IMPULSE_TEST_PACKET == bytes([0xA5, 0x01, 0x5A])
        and expect_protocol_error(lambda: decode_packet(LEGACY_RUN_IMPULSE_TEST_PACKET))
    )


def test_frame_chunk_builder() -> bool:
    frame = [index - 128 for index in range(256)]
    packets = build_write_frame_chunks(frame, seq_start=20)
    requests = build_read_result_requests(seq_start=40)
    first = decode_packet(packets[0])
    last = decode_packet(packets[-1])
    first_offset = first.payload[0] | (first.payload[1] << 8)
    last_offset = last.payload[0] | (last.payload[1] << 8)
    first_count = first.payload[2]
    last_count = last.payload[2]
    return (
        len(packets) == 8
        and len(requests) == 8
        and first.seq == 20
        and last.seq == 27
        and first_offset == 0
        and last_offset == 224
        and first_count == 32
        and last_count == 32
    )


def main() -> int:
    print("=== UART FRAME PROTOCOL TEST ===")
    report("encode_decode_ping", test_ping_encode_decode())
    report("checksum_value", test_checksum_value())
    report("bad_checksum_rejected", test_bad_checksum_rejected())
    report("payload_can_contain_a5_5a", test_payload_can_contain_framing_bytes())
    report("set_gains_q2_14_payload", test_set_gains_payload())
    report("write_frame_chunk_signed_samples", test_write_frame_chunk_payload())
    report("invalid_offset_count_rejected", test_invalid_offset_count_rejected())
    report("read_result_chunk_response", test_result_chunk_decode())
    report("legacy_run_packet_separate", test_legacy_packet_is_separate())
    report("frame_chunk_builder", test_frame_chunk_builder())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
