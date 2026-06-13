#!/usr/bin/env python3
"""Comparison helpers for PC local simulation and FPGA backend results."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Iterable

from spectrum_lab_model import INT16_MAX, SpectrumLabResult


@dataclass(frozen=True)
class ErrorMetrics:
    """Simple absolute-error metrics in signed-int16 sample units."""

    max_abs_error: float
    mean_abs_error: float
    rms_error: float


@dataclass(frozen=True)
class FrameComparison:
    """Comparison between local simulation output and one backend output."""

    backend_name: str
    backend_samples: list[int]
    backend_signal: list[float]
    difference_samples: list[int]
    difference_signal: list[float]
    metrics: ErrorMetrics
    note: str


def compute_error_metrics(
    reference_samples: Iterable[int],
    backend_samples: Iterable[int],
) -> ErrorMetrics:
    """Compute max/mean/RMS absolute error between two int16 sample frames."""

    reference = [int(sample) for sample in reference_samples]
    backend = [int(sample) for sample in backend_samples]

    if len(reference) != len(backend):
        raise ValueError("frames must have the same length")
    if not reference:
        return ErrorMetrics(0.0, 0.0, 0.0)

    abs_errors = [abs(fpga - local) for local, fpga in zip(reference, backend)]
    squared_errors = [error * error for error in abs_errors]

    return ErrorMetrics(
        max_abs_error=float(max(abs_errors)),
        mean_abs_error=float(sum(abs_errors)) / float(len(abs_errors)),
        rms_error=math.sqrt(float(sum(squared_errors)) / float(len(squared_errors))),
    )


def int16_to_unit_signal(samples: Iterable[int]) -> list[float]:
    """Normalize signed-int16 samples to approximately -1.0..+1.0."""

    return [int(sample) / float(INT16_MAX) for sample in samples]


def build_frame_comparison(
    local_result: SpectrumLabResult,
    backend_samples: Iterable[int],
    backend_name: str,
    note: str = "",
) -> FrameComparison:
    """Build plot-ready comparison data for a backend frame."""

    local_samples = list(local_result.output_int16.samples)
    backend = [int(sample) for sample in backend_samples]

    if len(local_samples) != len(backend):
        raise ValueError("backend frame length must match local output frame length")

    difference = [fpga - local for local, fpga in zip(local_samples, backend)]
    return FrameComparison(
        backend_name=backend_name,
        backend_samples=backend,
        backend_signal=int16_to_unit_signal(backend),
        difference_samples=difference,
        difference_signal=int16_to_unit_signal(difference),
        metrics=compute_error_metrics(local_samples, backend),
        note=note,
    )


def format_error_metrics(metrics: ErrorMetrics) -> str:
    """Return compact text for GUI status and console logs."""

    return (
        f"max_abs={metrics.max_abs_error:.3f}, "
        f"mean_abs={metrics.mean_abs_error:.3f}, "
        f"rms={metrics.rms_error:.3f}"
    )
