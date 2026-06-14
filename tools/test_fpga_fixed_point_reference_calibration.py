#!/usr/bin/env python3
"""Calibration tests for GUI float gains versus FPGA fixed-point gains."""

from __future__ import annotations

import sys

from fft_radix2_fixed_model import fft_ifft_pipeline_fixed_model
from spectrum_lab_hardware_backend import (
    HARDWARE_GAIN_MAX_FLOAT,
    Q2_14_SCALE,
    float_gain_to_q2_14,
    hardware_gains_from_modifications,
    q2_14_to_float,
)
from spectrum_lab_model import SignalComponent, SpectrumModification, simulate_spectrum_lab


GAINS_TO_TEST = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0, 10.0]
ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def peak(values: list[int]) -> int:
    return max(abs(value) for value in values)


def fixed_reference_for_gain(gain: float) -> tuple[int, int, int]:
    result = simulate_spectrum_lab(
        components=[SignalComponent(1000.0, 0.001, 0.0)],
        modifications=[SpectrumModification(1000.0, 1000.0, gain)],
    )
    gains = hardware_gains_from_modifications(
        [SpectrumModification(1000.0, 1000.0, gain)]
    )
    fixed_output = fft_ifft_pipeline_fixed_model(
        result.input_int16.samples,
        bass_gain=gains.bass_gain,
        mid_gain=gains.mid_gain,
        treble_gain=gains.treble_gain,
    )
    return (
        peak(result.output_int16.samples),
        peak(fixed_output),
        gains.mid_gain,
    )


def test_q2_14_gain_encoding() -> bool:
    return (
        float_gain_to_q2_14(1.0) == Q2_14_SCALE
        and float_gain_to_q2_14(0.5) == 8192
        and float_gain_to_q2_14(2.0) == 32767
        and float_gain_to_q2_14(4.0) == 32767
        and float_gain_to_q2_14(10.0) == 32767
        and q2_14_to_float(32767) == HARDWARE_GAIN_MAX_FLOAT
    )


def test_hardware_band_mapping_last_gain_wins() -> bool:
    gains = hardware_gains_from_modifications(
        [
            SpectrumModification(1000.0, 500.0, 1.5),
            SpectrumModification(2700.0, 600.0, 0.5),
            SpectrumModification(6200.0, 800.0, 1.0),
        ]
    )
    return (
        gains.bass_gain == Q2_14_SCALE
        and gains.mid_gain == 8192
        and gains.treble_gain == Q2_14_SCALE
    )


def test_gain_sweep_saturates_above_q2_14_range() -> bool:
    print("=== FPGA FIXED-POINT GAIN SWEEP ===")
    print("INPUT=1000 Hz amplitude 0.001")
    print("MODIFICATION=1000 Hz bandwidth 1000 Hz gain sweep")
    print(f"HARDWARE_GAIN_MAX={HARDWARE_GAIN_MAX_FLOAT:.6f}")
    print("")

    gain2_fixed_peak = None
    ok = True

    for gain in GAINS_TO_TEST:
        float_peak, fixed_peak, encoded_mid_gain = fixed_reference_for_gain(gain)
        effective_gain = q2_14_to_float(encoded_mid_gain)

        if gain == 2.0:
            gain2_fixed_peak = fixed_peak

        expected_clipped = gain > HARDWARE_GAIN_MAX_FLOAT
        clipped_ok = (
            encoded_mid_gain == 32767
            if expected_clipped
            else encoded_mid_gain == float_gain_to_q2_14(gain)
        )
        saturation_ok = True
        if gain > HARDWARE_GAIN_MAX_FLOAT and gain2_fixed_peak is not None:
            saturation_ok = fixed_peak == gain2_fixed_peak

        case_ok = clipped_ok and saturation_ok
        ok = ok and case_ok

        print(
            "GAIN "
            f"requested={gain:.2f} "
            f"encoded_q2_14={encoded_mid_gain} "
            f"effective={effective_gain:.6f} "
            f"float_peak={float_peak} "
            f"fixed_peak={fixed_peak} "
            f"{'PASS' if case_ok else 'FAIL'}"
        )

    return ok


def main() -> int:
    print("=== FPGA FIXED-POINT REFERENCE CALIBRATION TEST ===")
    report("q2_14_gain_encoding", test_q2_14_gain_encoding())
    report("hardware_band_mapping_last_gain_wins", test_hardware_band_mapping_last_gain_wins())
    report("gain_sweep_saturates_above_q2_14_range", test_gain_sweep_saturates_above_q2_14_range())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
