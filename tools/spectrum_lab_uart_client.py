#!/usr/bin/env python3
"""CLI client for the Spectrum Lab UART frame backend."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys

from spectrum_lab_hardware_backend import (
    Gains,
    HardwareBackendError,
    decode_status_bits,
    run_frame,
)
from uart_frame_protocol import FRAME_SAMPLES
from uart_transport import MockFpgaTransport, SerialTransport, TransportError


SELECTED_INDICES = [0, 1, 2, 16, 64, 128, 255]


def build_impulse_frame(amplitude: int = 64) -> list[int]:
    frame = [0 for _ in range(FRAME_SAMPLES)]
    frame[0] = int(amplitude)
    return frame


def build_sine_like_frame(amplitude: int = 1024) -> list[int]:
    # Lightweight deterministic waveform without importing math-heavy GUI code.
    pattern = [0, 1, 2, 1, 0, -1, -2, -1]
    return [int(amplitude * pattern[index % len(pattern)] / 2) for index in range(256)]


def write_csv(path: Path, samples: list[int]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "sample"])
        for index, sample in enumerate(samples):
            writer.writerow([index, sample])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send one 256-sample frame through the UART FPGA backend."
    )
    target = parser.add_mutually_exclusive_group()
    target.add_argument(
        "--mock",
        action="store_true",
        help="Use the dependency-free mock FPGA transport.",
    )
    target.add_argument(
        "--port",
        help="Serial port for real hardware, for example COM5 or /dev/ttyUSB0.",
    )
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate.")
    parser.add_argument("--timeout", type=float, default=5.0, help="Timeout in seconds.")
    parser.add_argument(
        "--frame",
        choices=["impulse", "sine"],
        default="impulse",
        help="Built-in test frame.",
    )
    parser.add_argument("--csv", type=Path, help="Optional CSV output path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    samples = build_impulse_frame() if args.frame == "impulse" else build_sine_like_frame()
    gains = Gains(16384, 16384, 16384)

    print("=== SPECTRUM LAB UART CLIENT ===")
    print(f"FRAME={args.frame}")
    print("PACKET_FLOW=PING SET_GAINS WRITE_FRAME_CHUNKx8 RUN_FRAME GET_STATUS READ_RESULT_CHUNKx8")

    if args.mock or not args.port:
        if not args.mock:
            print("No --port provided; using --mock transport.")
        transport = MockFpgaTransport()
        transport_name = "mock"
    else:
        try:
            transport = SerialTransport(args.port, baudrate=args.baud, timeout_s=args.timeout)
        except TransportError as exc:
            print(f"Serial setup error: {exc}")
            print("STATUS=FAIL")
            return 1
        transport_name = args.port

    print(f"TRANSPORT={transport_name}")
    try:
        result = run_frame(samples, gains, transport, timeout_s=args.timeout)
    except HardwareBackendError as exc:
        print(f"Backend error: {exc}")
        print("STATUS=FAIL")
        return 1
    finally:
        transport.close()

    flags = decode_status_bits(result.status)
    print("")
    print("STATUS BYTE:")
    for name, value in flags.items():
        print(f"  {name.upper()}={1 if value else 0}")

    print("")
    print("SELECTED OUTPUT SAMPLES:")
    for index in SELECTED_INDICES:
        print(f"  out[{index}]={result.samples[index]}")

    if args.csv:
        write_csv(args.csv, result.samples)
        print(f"CSV={args.csv}")

    passed = (
        flags["done"]
        and not flags["error"]
        and not flags["timeout"]
        and len(result.samples) == FRAME_SAMPLES
    )
    print("")
    print("STATUS=PASS" if passed else "STATUS=FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
