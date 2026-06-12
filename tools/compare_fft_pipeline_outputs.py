#!/usr/bin/env python3
"""Compare RTL pipeline CSV output against the current staged RTL model."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RTL_OUTPUT = REPO_ROOT / "sim" / "fft_accelerator_core_output.csv"
DEFAULT_VECTOR_DIR = REPO_ROOT / "sim" / "vectors"


def read_samples(path: Path) -> list[int]:
    samples: list[int] = []

    with path.open("r", newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            samples.append(int(row["sample"]))

    return samples


def compare_samples(actual: list[int], expected: list[int], tolerance: int) -> tuple[int, int, list[str]]:
    compared = min(len(actual), len(expected))
    max_abs_error = 0
    mismatches: list[str] = []

    for index in range(compared):
        error = abs(actual[index] - expected[index])
        max_abs_error = max(max_abs_error, error)
        if error > tolerance and len(mismatches) < 8:
            mismatches.append(
                f"index={index} actual={actual[index]} expected={expected[index]} error={error}"
            )

    if len(actual) != len(expected):
        mismatches.append(f"length actual={len(actual)} expected={len(expected)}")

    return compared, max_abs_error, mismatches


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frame", default="mixed", help="input frame name")
    parser.add_argument("--tolerance", type=int, default=1, help="allowed absolute error in LSB")
    parser.add_argument("--rtl-output", default=str(DEFAULT_RTL_OUTPUT), help="RTL output CSV path")
    parser.add_argument("--vector-dir", default=str(DEFAULT_VECTOR_DIR), help="test vector directory")
    args = parser.parse_args()

    rtl_output = Path(args.rtl_output)
    vector_dir = Path(args.vector_dir)
    expected_path = vector_dir / f"{args.frame}_expected_rtl_fft_ifft_normalized.csv"

    print("=== FFT PIPELINE OUTPUT COMPARISON ===")
    print("MODE=RTL_FFT_CORE_PLUS_NORMALIZED_IFFT_MODEL")
    print(f"INPUT_FRAME={args.frame}")

    if not rtl_output.exists():
        print("STATUS=SKIPPED")
        print("reason=RTL output CSV not found")
        return 0

    if not expected_path.exists():
        print("STATUS=FAIL")
        print(f"reason=expected CSV not found: {expected_path}")
        return 1

    actual = read_samples(rtl_output)
    expected = read_samples(expected_path)
    compared, max_abs_error, mismatches = compare_samples(actual, expected, args.tolerance)

    print(f"compared_samples={compared}")
    print(f"max_abs_error={max_abs_error}")
    print(f"tolerance={args.tolerance}")

    if not mismatches:
        print("STATUS=PASS")
        return 0

    for mismatch in mismatches:
        print(f"mismatch {mismatch}")
    print("STATUS=FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
