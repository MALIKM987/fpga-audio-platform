#!/usr/bin/env python3
"""Simulation model for the PC-side Spectrum Lab application.

The model is intentionally dependency-free. It uses direct DFT/IDFT equations
because the frame size is small and the code should be easy to compare with the
RTL-oriented reference models in this repository.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Iterable


DEFAULT_SAMPLE_RATE_HZ = 48_000.0
DEFAULT_FRAME_SIZE = 256
INT16_MIN = -32768
INT16_MAX = 32767


@dataclass(frozen=True)
class SignalComponent:
    """One sinusoidal component of a generated time-domain frame."""

    frequency_hz: float
    amplitude: float
    phase_rad: float = 0.0


@dataclass(frozen=True)
class SpectrumModification:
    """Simple frequency-domain gain band."""

    center_frequency_hz: float
    bandwidth_hz: float
    gain: float


@dataclass(frozen=True)
class Int16Frame:
    """Signed int16 frame plus clipping metadata."""

    samples: list[int]
    clipped: bool
    max_abs_before_clip: float


@dataclass(frozen=True)
class SpectrumLabResult:
    """Full simulation result for GUI, CLI, and future UART tooling."""

    input_signal: list[float]
    input_int16: Int16Frame
    input_spectrum: list[complex]
    input_magnitude: list[float]
    gain_mask: list[float]
    output_spectrum: list[complex]
    output_signal: list[float]
    output_int16: Int16Frame
    output_magnitude: list[float]


def generate_signal(
    components: Iterable[SignalComponent],
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE_HZ,
    frame_size: int = DEFAULT_FRAME_SIZE,
) -> list[float]:
    """Generate a frame from arbitrary sinusoidal components."""

    if sample_rate_hz <= 0:
        raise ValueError("sample_rate_hz must be positive")
    if frame_size <= 0:
        raise ValueError("frame_size must be positive")

    component_list = list(components)
    frame: list[float] = []

    for n in range(frame_size):
        t = n / sample_rate_hz
        value = 0.0
        for component in component_list:
            angle = 2.0 * math.pi * component.frequency_hz * t
            value += component.amplitude * math.sin(angle + component.phase_rad)
        frame.append(value)

    return frame


def samples_to_int16(
    samples: Iterable[float],
    scale: float = float(INT16_MAX),
    normalize: bool = False,
) -> Int16Frame:
    """Scale, round, and clip floating-point samples to signed int16."""

    values = [float(sample) for sample in samples]
    if not values:
        return Int16Frame(samples=[], clipped=False, max_abs_before_clip=0.0)

    max_abs = max(abs(value) for value in values)
    effective_scale = float(scale)
    if normalize and max_abs > 0.0:
        effective_scale = float(INT16_MAX) / max_abs

    converted: list[int] = []
    clipped = False

    for value in values:
        scaled = int(round(value * effective_scale))
        if scaled > INT16_MAX:
            scaled = INT16_MAX
            clipped = True
        elif scaled < INT16_MIN:
            scaled = INT16_MIN
            clipped = True
        converted.append(scaled)

    return Int16Frame(
        samples=converted,
        clipped=clipped,
        max_abs_before_clip=max_abs * effective_scale,
    )


def _frame_with_size(values: Iterable[complex | float | int], size: int) -> list[complex]:
    frame = [complex(value) for value in values]
    if len(frame) < size:
        frame.extend([0j] * (size - len(frame)))
    return frame[:size]


def dft(samples: Iterable[complex | float | int], size: int | None = None) -> list[complex]:
    """Return the direct DFT of a real or complex frame."""

    input_values = list(samples)
    dft_size = int(size) if size is not None else len(input_values)
    if dft_size <= 0:
        raise ValueError("DFT size must be positive")

    frame = _frame_with_size(input_values, dft_size)
    spectrum: list[complex] = []

    for k in range(dft_size):
        acc = 0j
        for n, sample in enumerate(frame):
            angle = -2.0 * math.pi * k * n / dft_size
            acc += sample * complex(math.cos(angle), math.sin(angle))
        spectrum.append(acc)

    return spectrum


def idft(
    spectrum: Iterable[complex | float | int],
    size: int | None = None,
) -> list[complex]:
    """Return the direct inverse DFT of a spectrum."""

    input_values = list(spectrum)
    idft_size = int(size) if size is not None else len(input_values)
    if idft_size <= 0:
        raise ValueError("IDFT size must be positive")

    bins = _frame_with_size(input_values, idft_size)
    samples: list[complex] = []

    for n in range(idft_size):
        acc = 0j
        for k, value in enumerate(bins):
            angle = 2.0 * math.pi * k * n / idft_size
            acc += value * complex(math.cos(angle), math.sin(angle))
        samples.append(acc / idft_size)

    return samples


def fft_magnitude(spectrum: Iterable[complex | float | int]) -> list[float]:
    """Return absolute magnitude for each spectrum bin."""

    return [abs(complex(value)) for value in spectrum]


def bin_frequency_hz(
    bin_index: int,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE_HZ,
    frame_size: int = DEFAULT_FRAME_SIZE,
) -> float:
    """Return mirrored positive frequency represented by a DFT bin."""

    index = int(bin_index) % frame_size
    effective_index = min(index, frame_size - index)
    return effective_index * sample_rate_hz / frame_size


def build_gain_mask(
    modifications: Iterable[SpectrumModification],
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE_HZ,
    frame_size: int = DEFAULT_FRAME_SIZE,
) -> list[float]:
    """Convert center-frequency gain bands to a per-bin gain mask."""

    mask = [1.0] * frame_size

    for modification in modifications:
        center = max(0.0, float(modification.center_frequency_hz))
        half_width = max(0.0, float(modification.bandwidth_hz) / 2.0)
        gain = float(modification.gain)

        for index in range(frame_size):
            frequency = bin_frequency_hz(index, sample_rate_hz, frame_size)
            if abs(frequency - center) <= half_width:
                mask[index] *= gain

    return mask


def apply_spectrum_modifications(
    spectrum: Iterable[complex | float | int],
    modifications: Iterable[SpectrumModification],
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE_HZ,
) -> tuple[list[complex], list[float]]:
    """Apply gain bands to a spectrum and return the modified bins and mask."""

    bins = [complex(value) for value in spectrum]
    mask = build_gain_mask(modifications, sample_rate_hz, len(bins))
    return [value * mask[index] for index, value in enumerate(bins)], mask


def simulate_spectrum_lab(
    components: Iterable[SignalComponent],
    modifications: Iterable[SpectrumModification],
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE_HZ,
    frame_size: int = DEFAULT_FRAME_SIZE,
    int16_scale: float = float(INT16_MAX),
    normalize_int16: bool = False,
) -> SpectrumLabResult:
    """Run signal generation, DFT, spectral gains, IDFT, and int16 conversion."""

    input_signal = generate_signal(components, sample_rate_hz, frame_size)
    input_int16 = samples_to_int16(input_signal, int16_scale, normalize_int16)
    input_spectrum = dft(input_signal, frame_size)
    input_magnitude = fft_magnitude(input_spectrum)
    output_spectrum, gain_mask = apply_spectrum_modifications(
        input_spectrum,
        modifications,
        sample_rate_hz,
    )
    output_complex = idft(output_spectrum, frame_size)
    output_signal = [sample.real for sample in output_complex]
    output_int16 = samples_to_int16(output_signal, int16_scale, normalize_int16)
    output_magnitude = fft_magnitude(output_spectrum)

    return SpectrumLabResult(
        input_signal=input_signal,
        input_int16=input_int16,
        input_spectrum=input_spectrum,
        input_magnitude=input_magnitude,
        gain_mask=gain_mask,
        output_spectrum=output_spectrum,
        output_signal=output_signal,
        output_int16=output_int16,
        output_magnitude=output_magnitude,
    )
