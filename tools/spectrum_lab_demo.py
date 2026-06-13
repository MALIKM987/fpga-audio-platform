#!/usr/bin/env python3
"""Small CLI demo for the Spectrum Lab simulation model."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys

from spectrum_lab_model import (
    DEFAULT_FRAME_SIZE,
    DEFAULT_SAMPLE_RATE_HZ,
    SignalComponent,
    SpectrumModification,
    simulate_spectrum_lab,
)
from uart_frame_protocol import MAX_CHUNK_SAMPLES, build_write_frame_chunks


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a default Spectrum Lab simulation example."
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=None,
        help="Optional CSV path for input/output sample export.",
    )
    return parser.parse_args()


def write_csv(path: Path, input_signal: list[float], output_signal: list[float]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "input", "output"])
        for index, (input_value, output_value) in enumerate(zip(input_signal, output_signal)):
            writer.writerow([index, input_value, output_value])


def main() -> int:
    args = parse_args()
    components = [
        SignalComponent(frequency_hz=1_000.0, amplitude=0.7),
        SignalComponent(frequency_hz=2_700.0, amplitude=0.35, phase_rad=0.3),
        SignalComponent(frequency_hz=6_200.0, amplitude=0.2),
    ]
    modifications = [
        SpectrumModification(center_frequency_hz=1_000.0, bandwidth_hz=300.0, gain=1.8),
        SpectrumModification(center_frequency_hz=2_700.0, bandwidth_hz=500.0, gain=0.5),
    ]
    result = simulate_spectrum_lab(components, modifications)
    uart_chunks = build_write_frame_chunks(result.input_int16.samples)

    print("=== PC SPECTRUM LAB DEMO ===")
    print(f"sample_rate_hz={DEFAULT_SAMPLE_RATE_HZ:g}")
    print(f"frame_size={DEFAULT_FRAME_SIZE}")
    print(f"components={len(components)}")
    print(f"modifications={len(modifications)}")
    print(f"input_max_abs={max(abs(value) for value in result.input_signal):.6f}")
    print(f"output_max_abs={max(abs(value) for value in result.output_signal):.6f}")
    print(f"input_int16_clipped={int(result.input_int16.clipped)}")
    print(f"output_int16_clipped={int(result.output_int16.clipped)}")
    print(f"uart_frame_protocol_chunks={len(uart_chunks)}")
    print(f"uart_frame_protocol_chunk_samples={MAX_CHUNK_SAMPLES}")
    print("uart_frame_protocol_status=packets prepared, not sent")
    print("hardware_backend=UART hardware backend not implemented in this branch")

    if args.csv is not None:
        write_csv(args.csv, result.input_signal, result.output_signal)
        print(f"csv={args.csv}")

    print("STATUS=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
