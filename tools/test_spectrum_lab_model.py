#!/usr/bin/env python3
"""Console tests for the Spectrum Lab simulation model."""

from __future__ import annotations

import sys

from spectrum_lab_model import (
    DEFAULT_FRAME_SIZE,
    DEFAULT_SAMPLE_RATE_HZ,
    INT16_MAX,
    INT16_MIN,
    SignalComponent,
    SpectrumModification,
    apply_spectrum_modifications,
    dft,
    fft_magnitude,
    generate_signal,
    idft,
    samples_to_int16,
    simulate_spectrum_lab,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def close(actual: float, expected: float, tolerance: float = 1.0e-6) -> bool:
    return abs(actual - expected) <= tolerance


def test_signal_generation_length() -> bool:
    components = [
        SignalComponent(frequency_hz=1_000.0, amplitude=0.5),
        SignalComponent(frequency_hz=2_700.0, amplitude=0.25, phase_rad=0.4),
    ]
    frame = generate_signal(components)
    return len(frame) == DEFAULT_FRAME_SIZE


def test_int16_conversion_clips_safely() -> bool:
    converted = samples_to_int16([0.0, 0.5, 2.0, -2.0])
    return (
        converted.samples[0] == 0
        and converted.samples[1] in (16383, 16384)
        and converted.samples[2] == INT16_MAX
        and converted.samples[3] == INT16_MIN
        and converted.clipped
    )


def test_fft_magnitude_length() -> bool:
    frame = generate_signal([SignalComponent(1_000.0, 0.5)])
    magnitude = fft_magnitude(dft(frame))
    return len(magnitude) == DEFAULT_FRAME_SIZE


def test_gain_band_changes_expected_spectrum() -> bool:
    bin_index = 10
    bin_frequency = DEFAULT_SAMPLE_RATE_HZ * bin_index / DEFAULT_FRAME_SIZE
    frame = generate_signal([SignalComponent(bin_frequency, 1.0)])
    spectrum = dft(frame)
    modified, mask = apply_spectrum_modifications(
        spectrum,
        [
            SpectrumModification(
                center_frequency_hz=bin_frequency,
                bandwidth_hz=100.0,
                gain=2.0,
            )
        ],
    )

    input_mag = abs(spectrum[bin_index])
    output_mag = abs(modified[bin_index])
    mirrored_bin = DEFAULT_FRAME_SIZE - bin_index
    mirror_ok = close(mask[mirrored_bin], 2.0)
    far_bin_ok = close(mask[40], 1.0)
    gain_ok = close(output_mag, input_mag * 2.0, tolerance=1.0e-5)
    return gain_ok and mirror_ok and far_bin_ok


def test_idft_output_size() -> bool:
    frame = generate_signal([SignalComponent(1_000.0, 0.5)])
    reconstructed = idft(dft(frame))
    return len(reconstructed) == DEFAULT_FRAME_SIZE


def test_full_simulation_runs() -> bool:
    result = simulate_spectrum_lab(
        components=[
            SignalComponent(1_000.0, 0.6),
            SignalComponent(2_700.0, 0.3),
        ],
        modifications=[
            SpectrumModification(1_000.0, 300.0, 1.5),
            SpectrumModification(2_700.0, 500.0, 0.5),
        ],
    )
    return (
        len(result.input_signal) == DEFAULT_FRAME_SIZE
        and len(result.output_signal) == DEFAULT_FRAME_SIZE
        and len(result.input_int16.samples) == DEFAULT_FRAME_SIZE
        and len(result.output_int16.samples) == DEFAULT_FRAME_SIZE
        and len(result.gain_mask) == DEFAULT_FRAME_SIZE
    )


def main() -> int:
    print("=== SPECTRUM LAB MODEL TEST ===")
    report("signal_generation_length", test_signal_generation_length())
    report("int16_conversion_clips_safely", test_int16_conversion_clips_safely())
    report("fft_magnitude_length", test_fft_magnitude_length())
    report("gain_band_changes_expected_spectrum", test_gain_band_changes_expected_spectrum())
    report("idft_output_size", test_idft_output_size())
    report("full_simulation_runs", test_full_simulation_runs())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
