#!/usr/bin/env python3
"""Analyze Spectrum Lab CSV exports from real FPGA UART runs."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path


INTERESTING_COLUMNS = [
    "input_int16",
    "local_output_int16",
    "mock_output_int16",
    "serial_output_int16",
    "mock_minus_local_int16",
    "serial_minus_local_int16",
]


def parse_int(value: str) -> int:
    return int(value.strip())


def column_values(rows: list[dict[str, str]], column: str) -> list[int]:
    return [parse_int(row[column]) for row in rows if row.get(column, "") != ""]


def rms(values: list[int]) -> float:
    if not values:
        return 0.0
    return math.sqrt(sum(value * value for value in values) / len(values))


def mean_abs(values: list[int]) -> float:
    if not values:
        return 0.0
    return sum(abs(value) for value in values) / len(values)


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


def print_column_stats(rows: list[dict[str, str]], column: str) -> None:
    values = column_values(rows, column)
    if not values:
        return
    print(
        f"  {column}: "
        f"min={min(values)} max={max(values)} "
        f"mean_abs={mean_abs(values):.3f} rms={rms(values):.3f}"
    )


def analyze_file(path: Path) -> bool:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)

    if not rows:
        print(f"{path}: FAIL empty CSV")
        return False

    columns = list(rows[0].keys())
    print(f"=== {path} ===")
    print(f"rows={len(rows)}")
    print(f"columns={', '.join(columns)}")

    for column in INTERESTING_COLUMNS:
        if column in columns:
            print_column_stats(rows, column)

    if {"local_output_int16", "serial_output_int16"}.issubset(columns):
        local = column_values(rows, "local_output_int16")
        serial = column_values(rows, "serial_output_int16")
        errors = [serial_value - local_value
                  for local_value, serial_value in zip(local, serial)]
        print("  serial_vs_local:")
        print(f"    max_abs_error={max(abs(value) for value in errors)}")
        print(f"    mean_abs_error={mean_abs(errors):.3f}")
        print(f"    rms_error={rms(errors):.3f}")
        print(f"    correlation={correlation(local, serial):.6f}")

        ranked = sorted(
            enumerate(errors),
            key=lambda item: abs(item[1]),
            reverse=True,
        )[:8]
        print("  largest_errors:")
        for index, error in ranked:
            print(
                "    "
                f"index={rows[index].get('index', index)} "
                f"local={local[index]} "
                f"serial={serial[index]} "
                f"error={error}"
            )

    print("")
    return True


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Analyze Spectrum Lab hardware CSV exports.",
    )
    parser.add_argument("csv_files", nargs="+", help="CSV file paths")
    args = parser.parse_args(argv)

    ok = True
    for name in args.csv_files:
        path = Path(name)
        if not path.exists():
            print(f"{path}: FAIL file not found")
            ok = False
            continue
        ok = analyze_file(path) and ok

    print("STATUS=PASS" if ok else "STATUS=FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
