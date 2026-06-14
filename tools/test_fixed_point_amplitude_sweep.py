#!/usr/bin/env python3
"""Amplitude sweep for the fixed-point FFT/IFFT pipeline model.

This test protects the hardware-visible failure found during Tang Nano UART
tests: small frames worked, but near input amplitude 0.008 the 16-bit forward
FFT path could wrap internally and produce int8-like output jumps.
"""

from __future__ import annotations

import math
import sys

from fft_reference_model import FFT_SIZE, process_frame_reference
from fft_radix2_fixed_model import fft_ifft_pipeline_fixed_model


SAMPLE_RATE_HZ = 48_000
TONE_HZ = 1_000
INT16_SCALE = 32_767

UNITY_GAIN_Q2_14 = 16_384
HALF_GAIN_Q2_14 = 8_192

# The physical failure was reproduced with a 1 kHz band cut. In the current
# three-band RTL selector that tone is in MID, so this sweep applies MID=0.5.
BASS_GAIN = UNITY_GAIN_Q2_14
MID_GAIN = HALF_GAIN_Q2_14
TREBLE_GAIN = UNITY_GAIN_Q2_14

AMPLITUDES = [
    0.001,
    0.002,
    0.004,
    0.006,
    0.007,
    0.008,
    0.010,
]

MAX_ALLOWED_ABS_ERROR = 2
MAX_ALLOWED_RMS_ERROR = 1.0
MIN_ALLOWED_CORRELATION = 0.998


def quantized_sine_frame(amplitude: float) -> list[int]:
    return [
        int(round(
            amplitude
            * INT16_SCALE
            * math.sin(2.0 * math.pi * TONE_HZ * index / SAMPLE_RATE_HZ)
        ))
        for index in range(FFT_SIZE)
    ]


def error_metrics(expected: list[int], actual: list[int]) -> tuple[int, float, float]:
    errors = [actual_value - expected_value
              for expected_value, actual_value in zip(expected, actual)]
    max_abs = max(abs(error) for error in errors)
    mean_abs = sum(abs(error) for error in errors) / len(errors)
    rms = math.sqrt(sum(error * error for error in errors) / len(errors))
    return max_abs, mean_abs, rms


def correlation(left: list[int], right: list[int]) -> float:
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


def main() -> int:
    errors = 0

    print("=== FIXED-POINT AMPLITUDE SWEEP TEST ===")
    print(f"FFT_SIZE={FFT_SIZE}")
    print(f"TONE_HZ={TONE_HZ}")
    print("GAINS=bass:1.00 mid:0.50 treble:1.00")
    print("MODEL=24-bit internal FFT bins with saturated int16 output")
    print("")

    for amplitude in AMPLITUDES:
        samples = quantized_sine_frame(amplitude)
        reference = process_frame_reference(
            samples,
            bass_gain=BASS_GAIN,
            mid_gain=MID_GAIN,
            treble_gain=TREBLE_GAIN,
        )
        fixed = fft_ifft_pipeline_fixed_model(
            samples,
            bass_gain=BASS_GAIN,
            mid_gain=MID_GAIN,
            treble_gain=TREBLE_GAIN,
        )

        max_abs, mean_abs, rms = error_metrics(reference, fixed)
        corr = correlation(reference, fixed)
        input_peak = max(abs(value) for value in samples)
        output_peak = max(abs(value) for value in fixed)
        passed = (
            max_abs <= MAX_ALLOWED_ABS_ERROR
            and rms <= MAX_ALLOWED_RMS_ERROR
            and corr >= MIN_ALLOWED_CORRELATION
        )

        # Regression guard for the observed failing region: this amplitude must
        # no longer collapse into roughly signed 8-bit range.
        if amplitude == 0.008 and output_peak < 170:
            passed = False

        print(
            "TEST "
            f"amp={amplitude:.3f} "
            f"input_peak={input_peak} "
            f"output_peak={output_peak} "
            f"max_abs_error={max_abs} "
            f"mean_abs_error={mean_abs:.3f} "
            f"rms_error={rms:.3f} "
            f"corr={corr:.6f} "
            f"{'PASS' if passed else 'FAIL'}"
        )

        if not passed:
            errors += 1

    if errors == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={errors}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
