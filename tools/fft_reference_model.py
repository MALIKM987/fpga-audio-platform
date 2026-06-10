#!/usr/bin/env python3
"""Pure Python FFT/IFFT reference model for console verification.

This module intentionally uses direct DFT/IDFT equations instead of numpy,
scipy, or a fast FFT implementation. It is a small golden model for validating
the math of the planned RTL/Gowin FFT path:

    FFT -> spectral gain -> IFFT
"""

from __future__ import annotations

import math
from typing import Iterable


FFT_SIZE = 256
INT16_MIN = -32768
INT16_MAX = 32767

Q2_14_ONE = 16_384
DEFAULT_BASS_GAIN = 24_576   # 1.50
DEFAULT_MID_GAIN = 16_384    # 1.00
DEFAULT_TREBLE_GAIN = 12_288 # 0.75

BAND_BASS = "BASS"
BAND_MID = "MID"
BAND_TREBLE = "TREBLE"


def _frame_with_size(values: Iterable[complex | float | int], size: int) -> list[complex]:
    frame = [complex(value) for value in values]
    if len(frame) < size:
        frame.extend([0j] * (size - len(frame)))
    return frame[:size]


def dft(samples: Iterable[complex | float | int], size: int = FFT_SIZE) -> list[complex]:
    """Return the direct DFT of a real or complex frame."""

    frame = _frame_with_size(samples, size)
    spectrum: list[complex] = []

    for k in range(size):
        acc = 0j
        for n, sample in enumerate(frame):
            angle = -2.0 * math.pi * k * n / size
            acc += sample * complex(math.cos(angle), math.sin(angle))
        spectrum.append(acc)

    return spectrum


def idft(spectrum: Iterable[complex | float | int], size: int = FFT_SIZE) -> list[complex]:
    """Return the direct inverse DFT of a spectrum."""

    bins = _frame_with_size(spectrum, size)
    samples: list[complex] = []

    for n in range(size):
        acc = 0j
        for k, value in enumerate(bins):
            angle = 2.0 * math.pi * k * n / size
            acc += value * complex(math.cos(angle), math.sin(angle))
        samples.append(acc / size)

    return samples


def q2_14_to_float(value: int) -> float:
    """Convert a signed Q2.14 fixed-point value to float."""

    signed_value = int(value)
    if signed_value > 0x7FFF:
        signed_value -= 0x10000
    return signed_value / float(Q2_14_ONE)


def saturate_int16(value: float | int | complex) -> int:
    """Round and saturate a numeric value to signed 16-bit."""

    if isinstance(value, complex):
        value = value.real

    rounded = int(round(float(value)))
    if rounded > INT16_MAX:
        return INT16_MAX
    if rounded < INT16_MIN:
        return INT16_MIN
    return rounded


def effective_bin_index(bin_index: int, fft_size: int = FFT_SIZE) -> int:
    """Return the mirrored bin index used by the RTL spectral selector."""

    index = int(bin_index) % fft_size
    return min(index, fft_size - index)


def select_band(bin_index: int, fft_size: int = FFT_SIZE) -> str:
    """Map a bin to BASS, MID, or TREBLE using the project band split."""

    effective_bin = effective_bin_index(bin_index, fft_size)
    if effective_bin <= 1:
        return BAND_BASS
    if effective_bin <= 21:
        return BAND_MID
    return BAND_TREBLE


def gain_for_bin(
    bin_index: int,
    bass_gain: int = DEFAULT_BASS_GAIN,
    mid_gain: int = DEFAULT_MID_GAIN,
    treble_gain: int = DEFAULT_TREBLE_GAIN,
    fft_size: int = FFT_SIZE,
) -> float:
    """Return the floating-point gain selected for a spectrum bin."""

    band = select_band(bin_index, fft_size)
    if band == BAND_BASS:
        return q2_14_to_float(bass_gain)
    if band == BAND_MID:
        return q2_14_to_float(mid_gain)
    return q2_14_to_float(treble_gain)


def apply_spectral_gains(
    spectrum: Iterable[complex | float | int],
    bass_gain: int = DEFAULT_BASS_GAIN,
    mid_gain: int = DEFAULT_MID_GAIN,
    treble_gain: int = DEFAULT_TREBLE_GAIN,
    fft_size: int = FFT_SIZE,
) -> list[complex]:
    """Apply Q2.14 band gains to a complex spectrum."""

    bins = _frame_with_size(spectrum, fft_size)
    return [
        value * gain_for_bin(index, bass_gain, mid_gain, treble_gain, fft_size)
        for index, value in enumerate(bins)
    ]


def process_frame_reference(
    samples: Iterable[complex | float | int],
    bass_gain: int = DEFAULT_BASS_GAIN,
    mid_gain: int = DEFAULT_MID_GAIN,
    treble_gain: int = DEFAULT_TREBLE_GAIN,
    size: int = FFT_SIZE,
) -> list[int]:
    """Run DFT -> spectral gain -> IDFT and return saturated int16 samples."""

    spectrum = dft(samples, size)
    processed_spectrum = apply_spectral_gains(
        spectrum,
        bass_gain=bass_gain,
        mid_gain=mid_gain,
        treble_gain=treble_gain,
        fft_size=size,
    )
    processed_samples = idft(processed_spectrum, size)
    return [saturate_int16(sample.real) for sample in processed_samples]


def _cosine_frame(bin_index: int, amplitude: float, size: int) -> list[float]:
    return [
        amplitude * math.cos(2.0 * math.pi * bin_index * n / size)
        for n in range(size)
    ]


def generate_test_frame(kind: str, size: int = FFT_SIZE) -> list[float]:
    """Generate deterministic frames for reference-model tests."""

    normalized_kind = kind.lower()

    if normalized_kind == "impulse":
        frame = [0.0] * size
        frame[0] = 10_000.0
        return frame

    if normalized_kind == "constant":
        return [1_000.0] * size

    if normalized_kind == "single_bin_low":
        return _cosine_frame(1, 1_000.0, size)

    if normalized_kind == "single_bin_mid":
        return _cosine_frame(10, 1_000.0, size)

    if normalized_kind == "single_bin_high":
        return _cosine_frame(40, 1_000.0, size)

    if normalized_kind == "mixed":
        low = _cosine_frame(1, 900.0, size)
        mid = _cosine_frame(10, 600.0, size)
        high = _cosine_frame(40, 300.0, size)
        return [low[n] + mid[n] + high[n] for n in range(size)]

    raise ValueError(f"unknown test frame kind: {kind}")
