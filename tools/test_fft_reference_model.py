#!/usr/bin/env python3
"""Console tests for the pure Python FFT/IFFT reference model."""

from __future__ import annotations

import sys

from fft_reference_model import (
    BAND_BASS,
    BAND_MID,
    BAND_TREBLE,
    DEFAULT_BASS_GAIN,
    DEFAULT_MID_GAIN,
    DEFAULT_TREBLE_GAIN,
    FFT_SIZE,
    dft,
    generate_test_frame,
    idft,
    process_frame_reference,
    q2_14_to_float,
    saturate_int16,
    select_band,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def close(a: complex | float, b: complex | float, tolerance: float = 1.0e-6) -> bool:
    return abs(a - b) <= tolerance


def max_abs_error(values_a: list[float | int], values_b: list[float | int]) -> float:
    return max(abs(float(a) - float(b)) for a, b in zip(values_a, values_b))


def test_q2_14() -> bool:
    cases = {
        8192: 0.5,
        12288: 0.75,
        16384: 1.0,
        24576: 1.5,
    }
    return all(close(q2_14_to_float(raw), expected) for raw, expected in cases.items())


def test_bin_mapping() -> bool:
    cases = {
        1: BAND_BASS,
        10: BAND_MID,
        40: BAND_TREBLE,
        255: BAND_BASS,
        246: BAND_MID,
        216: BAND_TREBLE,
    }
    return all(select_band(bin_index) == band for bin_index, band in cases.items())


def test_dft_idft_impulse() -> bool:
    frame = [0.0] * FFT_SIZE
    frame[0] = 1234.0
    spectrum = dft(frame)
    reconstructed = idft(spectrum)

    spectrum_ok = all(close(value, 1234.0 + 0j, 1.0e-6) for value in spectrum)
    frame_ok = all(close(reconstructed[i].real, frame[i], 1.0e-6) for i in range(FFT_SIZE))
    imag_ok = all(close(sample.imag, 0.0, 1.0e-6) for sample in reconstructed)
    return spectrum_ok and frame_ok and imag_ok


def test_dft_idft_constant() -> bool:
    frame = [77.0] * FFT_SIZE
    spectrum = dft(frame)
    reconstructed = idft(spectrum)

    dc_ok = close(spectrum[0], 77.0 * FFT_SIZE + 0j, 1.0e-6)
    other_bins_ok = all(abs(value) <= 1.0e-6 for value in spectrum[1:])
    frame_ok = all(close(reconstructed[i].real, frame[i], 1.0e-6) for i in range(FFT_SIZE))
    imag_ok = all(close(sample.imag, 0.0, 1.0e-6) for sample in reconstructed)
    return dc_ok and other_bins_ok and frame_ok and imag_ok


def test_processed_frame(kind: str, scale: float) -> bool:
    frame = generate_test_frame(kind)
    processed = process_frame_reference(
        frame,
        bass_gain=DEFAULT_BASS_GAIN,
        mid_gain=DEFAULT_MID_GAIN,
        treble_gain=DEFAULT_TREBLE_GAIN,
    )
    expected = [saturate_int16(value * scale) for value in frame]
    return max_abs_error(processed, expected) <= 1.0


def test_saturation() -> bool:
    direct_cases_ok = (
        saturate_int16(40_000.0) == 32767
        and saturate_int16(-40_000.0) == -32768
        and saturate_int16(12.4) == 12
        and saturate_int16(12.6) == 13
    )

    loud_frame = [30_000.0] * FFT_SIZE
    processed = process_frame_reference(
        loud_frame,
        bass_gain=DEFAULT_BASS_GAIN,
        mid_gain=DEFAULT_BASS_GAIN,
        treble_gain=DEFAULT_BASS_GAIN,
    )
    process_ok = all(sample == 32767 for sample in processed)
    return direct_cases_ok and process_ok


def test_mixed_frame_runs() -> bool:
    processed = process_frame_reference(generate_test_frame("mixed"))
    return len(processed) == FFT_SIZE and all(-32768 <= sample <= 32767 for sample in processed)


def main() -> int:
    print("=== FFT REFERENCE MODEL TEST ===")
    report("q2_14", test_q2_14())
    report("bin_mapping", test_bin_mapping())
    report("dft_idft_impulse", test_dft_idft_impulse())
    report("dft_idft_constant", test_dft_idft_constant())
    report("process_low_band", test_processed_frame("single_bin_low", 1.5))
    report("process_mid_band", test_processed_frame("single_bin_mid", 1.0))
    report("process_high_band", test_processed_frame("single_bin_high", 0.75))
    report("saturation", test_saturation())
    report("process_mixed", test_mixed_frame_runs())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
