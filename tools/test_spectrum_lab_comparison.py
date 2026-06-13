#!/usr/bin/env python3
"""Console tests for Spectrum Lab FPGA/local comparison helpers."""

from __future__ import annotations

import math
import sys

from spectrum_lab_comparison import (
    build_frame_comparison,
    compute_error_metrics,
    format_error_metrics,
)
from spectrum_lab_hardware_backend import Gains, run_frame
from spectrum_lab_model import SignalComponent, SpectrumModification, simulate_spectrum_lab
from uart_transport import MockFpgaTransport


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def close(actual: float, expected: float, tolerance: float = 1.0e-9) -> bool:
    return abs(actual - expected) <= tolerance


def test_zero_error_metrics() -> bool:
    metrics = compute_error_metrics([0, 10, -10, 64], [0, 10, -10, 64])
    return (
        metrics.max_abs_error == 0.0
        and metrics.mean_abs_error == 0.0
        and metrics.rms_error == 0.0
    )


def test_nonzero_error_metrics() -> bool:
    metrics = compute_error_metrics([0, 10, -10], [0, 7, -4])
    expected_rms = math.sqrt((0.0 + 9.0 + 36.0) / 3.0)
    return (
        close(metrics.max_abs_error, 6.0)
        and close(metrics.mean_abs_error, 3.0)
        and close(metrics.rms_error, expected_rms)
        and "max_abs=6.000" in format_error_metrics(metrics)
    )


def test_length_mismatch_rejected() -> bool:
    try:
        compute_error_metrics([1, 2], [1])
    except ValueError:
        return True
    return False


def test_mock_backend_comparison_path() -> bool:
    local_result = simulate_spectrum_lab(
        components=[
            SignalComponent(1000.0, 0.50),
            SignalComponent(2700.0, 0.20),
        ],
        modifications=[
            SpectrumModification(1000.0, 300.0, 1.5),
            SpectrumModification(2700.0, 500.0, 0.5),
        ],
    )
    transport = MockFpgaTransport()
    hardware_result = run_frame(
        local_result.input_int16.samples,
        Gains(24576, 8192, 16384),
        transport,
        timeout_s=1.0,
    )
    comparison = build_frame_comparison(
        local_result,
        hardware_result.samples,
        "Mock FPGA backend",
        "loopback",
    )

    return (
        hardware_result.samples == local_result.input_int16.samples
        and comparison.backend_name == "Mock FPGA backend"
        and len(comparison.difference_samples) == len(local_result.output_int16.samples)
        and comparison.metrics.max_abs_error > 0.0
        and comparison.note == "loopback"
    )


def main() -> int:
    print("=== SPECTRUM LAB COMPARISON TEST ===")
    report("zero_error_metrics", test_zero_error_metrics())
    report("nonzero_error_metrics", test_nonzero_error_metrics())
    report("length_mismatch_rejected", test_length_mismatch_rejected())
    report("mock_backend_comparison_path", test_mock_backend_comparison_path())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
