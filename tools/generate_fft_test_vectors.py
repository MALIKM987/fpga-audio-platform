#!/usr/bin/env python3
"""Generate FFT pipeline CSV vectors for RTL and math-reference checks."""

from __future__ import annotations

import csv
from pathlib import Path

from fft_reference_model import (
    BAND_BASS,
    BAND_MID,
    DEFAULT_BASS_GAIN,
    DEFAULT_MID_GAIN,
    DEFAULT_TREBLE_GAIN,
    FFT_SIZE,
    generate_test_frame,
    process_frame_reference,
    saturate_int16,
    select_band,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
VECTOR_DIR = REPO_ROOT / "sim" / "vectors"

FRAME_KINDS = [
    "impulse",
    "constant",
    "single_bin_low",
    "single_bin_mid",
    "single_bin_high",
    "mixed",
]


def write_csv(path: Path, samples: list[int]) -> None:
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["index", "sample"])
        for index, sample in enumerate(samples):
            writer.writerow([index, sample])


def apply_current_rtl_q2_14(sample: int, gain: int) -> int:
    # Mirrors current spectral_processor.v behavior: product >>> 14.
    return saturate_int16((int(sample) * int(gain)) >> 14)


def rtl_passthrough_model(samples: list[int], size: int = FFT_SIZE) -> list[int]:
    """Model current RTL: passthrough FFT/IFFT wrappers plus spectral gain."""

    expected: list[int] = []

    for index, sample in enumerate(samples[:size]):
        band = select_band(index, size)
        if band == BAND_BASS:
            gain = DEFAULT_BASS_GAIN
        elif band == BAND_MID:
            gain = DEFAULT_MID_GAIN
        else:
            gain = DEFAULT_TREBLE_GAIN
        expected.append(apply_current_rtl_q2_14(sample, gain))

    return expected


def generate_vectors() -> int:
    print("=== FFT TEST VECTOR GENERATOR ===")
    print(f"FFT_SIZE={FFT_SIZE}")
    print("RTL_MODEL=PASSTHROUGH_WRAPPERS_PLUS_SPECTRAL_GAIN")
    print("MATH_MODEL=DFT_SPECTRAL_GAIN_IDFT")
    print("")

    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    for kind in FRAME_KINDS:
        input_samples = [
            saturate_int16(sample)
            for sample in generate_test_frame(kind, FFT_SIZE)
        ]
        expected_rtl = rtl_passthrough_model(input_samples, FFT_SIZE)
        expected_math = process_frame_reference(
            input_samples,
            bass_gain=DEFAULT_BASS_GAIN,
            mid_gain=DEFAULT_MID_GAIN,
            treble_gain=DEFAULT_TREBLE_GAIN,
            size=FFT_SIZE,
        )

        write_csv(VECTOR_DIR / f"{kind}.csv", input_samples)
        write_csv(VECTOR_DIR / f"{kind}_expected_rtl_passthrough.csv", expected_rtl)
        write_csv(VECTOR_DIR / f"{kind}_expected_math_reference.csv", expected_math)
        print(f"FRAME {kind} PASS")

    print("")
    print("STATUS=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(generate_vectors())
