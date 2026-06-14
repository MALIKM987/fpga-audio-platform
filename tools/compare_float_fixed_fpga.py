#!/usr/bin/env python3
"""Compare exported GUI float output, fixed-point reference, and FPGA CSV data."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from dataclasses import dataclass
from pathlib import Path

from fft_radix2_fixed_model import fft_ifft_pipeline_fixed_model
from spectrum_lab_hardware_backend import (
    Gains,
    hardware_gains_from_modifications,
    q2_14_to_float,
)
from spectrum_lab_model import SpectrumModification


@dataclass(frozen=True)
class Metrics:
    max_abs_error: int
    mean_abs_error: float
    rms_error: float
    correlation: float
    best_fit_scale: float


def parse_modification(text: str) -> SpectrumModification:
    parts = [part.strip() for part in text.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(
            "modification must have format center_hz,bandwidth_hz,gain"
        )
    return SpectrumModification(float(parts[0]), float(parts[1]), float(parts[2]))


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def int_column(rows: list[dict[str, str]], column: str) -> list[int]:
    return [int(row[column]) for row in rows]


def correlation(left: list[int], right: list[int]) -> float:
    if len(left) != len(right) or not left:
        return 0.0
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    left_centered = [value - left_mean for value in left]
    right_centered = [value - right_mean for value in right]
    numerator = sum(a * b for a, b in zip(left_centered, right_centered))
    left_energy = math.sqrt(sum(value * value for value in left_centered))
    right_energy = math.sqrt(sum(value * value for value in right_centered))
    if left_energy == 0.0 or right_energy == 0.0:
        return 1.0 if left == right else 0.0
    return numerator / (left_energy * right_energy)


def best_fit_scale(reference: list[int], measured: list[int]) -> float:
    numerator = sum(m * r for m, r in zip(measured, reference))
    denominator = sum(r * r for r in reference)
    if denominator == 0:
        return 0.0
    return numerator / denominator


def metrics(reference: list[int], measured: list[int]) -> Metrics:
    if len(reference) != len(measured):
        raise ValueError("frames must have the same length")
    errors = [measured_value - reference_value
              for reference_value, measured_value in zip(reference, measured)]
    return Metrics(
        max_abs_error=max(abs(error) for error in errors),
        mean_abs_error=sum(abs(error) for error in errors) / len(errors),
        rms_error=math.sqrt(sum(error * error for error in errors) / len(errors)),
        correlation=correlation(reference, measured),
        best_fit_scale=best_fit_scale(reference, measured),
    )


def print_metrics(label: str, values: Metrics) -> None:
    print(f"  {label}:")
    print(f"    max_abs_error={values.max_abs_error}")
    print(f"    mean_abs_error={values.mean_abs_error:.3f}")
    print(f"    rms_error={values.rms_error:.3f}")
    print(f"    correlation={values.correlation:.6f}")
    print(f"    best_fit_scale={values.best_fit_scale:.6f}")


def print_largest_errors(
    label: str,
    reference: list[int],
    measured: list[int],
    rows: list[dict[str, str]],
    limit: int,
) -> None:
    ranked = sorted(
        enumerate(measured_value - reference_value
                  for reference_value, measured_value in zip(reference, measured)),
        key=lambda item: abs(item[1]),
        reverse=True,
    )[:limit]
    print(f"  {label}_largest_errors:")
    for index, error in ranked:
        print(
            "    "
            f"index={rows[index].get('index', index)} "
            f"reference={reference[index]} "
            f"measured={measured[index]} "
            f"error={error}"
        )


def build_fixed_reference(input_samples: list[int], gains: Gains) -> list[int]:
    return fft_ifft_pipeline_fixed_model(
        input_samples,
        bass_gain=gains.bass_gain,
        mid_gain=gains.mid_gain,
        treble_gain=gains.treble_gain,
    )


def analyze_file(path: Path, gains: Gains, top_errors: int) -> bool:
    rows = read_csv_rows(path)
    if not rows:
        print(f"{path}: FAIL empty CSV")
        return False

    required = {"input_int16", "local_output_int16", "serial_output_int16"}
    missing = required.difference(rows[0].keys())
    if missing:
        print(f"{path}: FAIL missing columns: {', '.join(sorted(missing))}")
        return False

    input_samples = int_column(rows, "input_int16")
    local_float = int_column(rows, "local_output_int16")
    serial_fpga = int_column(rows, "serial_output_int16")
    local_fixed = build_fixed_reference(input_samples, gains)

    print(f"=== {path} ===")
    print(f"rows={len(rows)}")
    print(
        "gains_q2_14="
        f"bass:{gains.bass_gain} mid:{gains.mid_gain} treble:{gains.treble_gain}"
    )
    print(
        "gains_float="
        f"bass:{q2_14_to_float(gains.bass_gain):.6f} "
        f"mid:{q2_14_to_float(gains.mid_gain):.6f} "
        f"treble:{q2_14_to_float(gains.treble_gain):.6f}"
    )
    print(f"input_range={min(input_samples)}..{max(input_samples)}")
    print(f"local_float_range={min(local_float)}..{max(local_float)}")
    print(f"local_fixed_range={min(local_fixed)}..{max(local_fixed)}")
    print(f"serial_fpga_range={min(serial_fpga)}..{max(serial_fpga)}")

    float_vs_fpga = metrics(local_float, serial_fpga)
    fixed_vs_fpga = metrics(local_fixed, serial_fpga)
    float_vs_fixed = metrics(local_float, local_fixed)
    print_metrics("local_float_vs_fpga", float_vs_fpga)
    print_metrics("local_fixed_vs_fpga", fixed_vs_fpga)
    print_metrics("local_float_vs_fixed", float_vs_fixed)
    print_largest_errors("fixed_vs_fpga", local_fixed, serial_fpga, rows, top_errors)
    print("")
    return True


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Compare local float, local fixed, and FPGA serial CSV output.",
    )
    parser.add_argument("csv_files", nargs="+")
    parser.add_argument("--bass", type=float, default=1.0)
    parser.add_argument("--mid", type=float, default=1.0)
    parser.add_argument("--treble", type=float, default=1.0)
    parser.add_argument(
        "--mod",
        action="append",
        type=parse_modification,
        default=[],
        help="GUI modification as center_hz,bandwidth_hz,gain",
    )
    parser.add_argument("--top-errors", type=int, default=8)
    args = parser.parse_args(argv)

    if args.mod:
        gains = hardware_gains_from_modifications(args.mod)
    else:
        gains = hardware_gains_from_modifications(
            [
                SpectrumModification(0.0, 0.0, args.bass),
                SpectrumModification(1000.0, 0.0, args.mid),
                SpectrumModification(6200.0, 0.0, args.treble),
            ]
        )

    ok = True
    for name in args.csv_files:
        ok = analyze_file(Path(name), gains, args.top_errors) and ok

    print("STATUS=PASS" if ok else "STATUS=FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
