#!/usr/bin/env python3
"""Send the binary RUN command to the Tang UART FFT console."""

from __future__ import annotations

import argparse
import sys


COMMAND = bytes([0xA5, 0x01, 0x5A])
RESPONSE_LEN = 18
RESPONSE_START = 0xA5
RESPONSE_ID = 0x81
RESPONSE_END = 0x5A
SAMPLE_NAMES = ["out0", "out1", "out2", "out16", "out64", "out128", "out255"]


def decode_status(status: int) -> dict[str, bool]:
    return {
        "pass": bool(status & 0x01),
        "done": bool(status & 0x02),
        "overflow": bool(status & 0x04),
        "error": bool(status & 0x08),
        "timeout": bool(status & 0x10),
    }


def decode_samples(payload: bytes) -> list[int]:
    samples: list[int] = []
    for offset in range(3, 17, 2):
        samples.append(int.from_bytes(payload[offset:offset + 2], "little", signed=True))
    return samples


def format_hex(data: bytes) -> str:
    return " ".join(f"{byte:02X}" for byte in data)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run the FPGA UART FFT impulse test and decode the selected-sample "
            "response."
        )
    )
    parser.add_argument(
        "port",
        help="Serial port, for example COM6 on Windows or /dev/ttyUSB0 on Linux.",
    )
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate.")
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Read timeout in seconds.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        import serial
    except ImportError:
        print("pyserial is required for this helper script.")
        print("Install it with: python -m pip install pyserial")
        print("STATUS=FAIL")
        return 1

    print("=== UART FFT CONSOLE CLIENT ===")
    print(f"PORT={args.port}")
    print(f"BAUD={args.baud}")
    print(f"COMMAND={format_hex(COMMAND)}")
    print("RESPONSE_FORMAT=A5 81 STATUS selected_samples 5A")
    print("SELECTED_SAMPLES=out0,out1,out2,out16,out64,out128,out255")

    try:
        with serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=args.timeout,
        ) as ser:
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            ser.write(COMMAND)
            ser.flush()
            response = ser.read(RESPONSE_LEN)
    except serial.SerialException as exc:
        print(f"Serial error: {exc}")
        print("STATUS=FAIL")
        return 1

    print(f"RESPONSE={format_hex(response)}")

    if len(response) != RESPONSE_LEN:
        print(f"Expected {RESPONSE_LEN} bytes, got {len(response)} bytes.")
        print("STATUS=FAIL")
        return 1

    if response[0] != RESPONSE_START or response[1] != RESPONSE_ID:
        print("Invalid response header.")
        print("STATUS=FAIL")
        return 1

    if response[-1] != RESPONSE_END:
        print("Invalid response end byte.")
        print("STATUS=FAIL")
        return 1

    status = decode_status(response[2])
    samples = decode_samples(response)

    print("")
    print("STATUS BYTE:")
    for name, value in status.items():
        print(f"  {name.upper()}={1 if value else 0}")

    print("")
    print("SELECTED OUTPUT SAMPLES:")
    for name, value in zip(SAMPLE_NAMES, samples):
        print(f"  {name}={value}")

    passed = (
        status["pass"]
        and status["done"]
        and not status["overflow"]
        and not status["error"]
        and not status["timeout"]
        and samples[0] == 64
        and all(value == 0 for value in samples[1:])
    )

    print("")
    print("STATUS=PASS" if passed else "STATUS=FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
