#!/usr/bin/env python3
"""Console tests for the bit-exact radix-2 FFT fixed-point model."""

from __future__ import annotations

import sys

from fft_radix2_fixed_model import (
    FFT_SIZE,
    Q2_14_ONE,
    bit_reverse,
    butterfly_addresses,
    complex_mult_q14,
    fft_radix2_core_fixed_model,
    twiddle_q14,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def int16_range(values: list[int]) -> bool:
    return all(-32768 <= value <= 32767 for value in values)


def no_invalid_values(values: list[int]) -> bool:
    return all(isinstance(value, int) for value in values)


def check_bins(
    name: str,
    real_out: list[int],
    imag_out: list[int],
    expected: dict[int, tuple[int, int]],
) -> bool:
    ok = True
    for index, (expected_real, expected_imag) in expected.items():
        if real_out[index] != expected_real or imag_out[index] != expected_imag:
            ok = False
            print(
                f"  {name} bin={index} real={real_out[index]} "
                f"expected={expected_real}"
            )
            print(
                f"  {name} bin={index} imag={imag_out[index]} "
                f"expected={expected_imag}"
            )
    return ok


def test_helpers() -> bool:
    bit_reverse_ok = (
        bit_reverse(0) == 0
        and bit_reverse(1) == 128
        and bit_reverse(15) == 240
        and bit_reverse(170) == 85
        and bit_reverse(255) == 255
    )

    twiddle_ok = (
        twiddle_q14(0, inverse=False) == (16384, 0)
        and twiddle_q14(32, inverse=False) == (11585, -11585)
        and twiddle_q14(64, inverse=False) == (0, -16384)
        and twiddle_q14(96, inverse=False) == (-11585, -11585)
        and twiddle_q14(32, inverse=True) == (11585, 11585)
        and twiddle_q14(64, inverse=True) == (0, 16384)
    )

    complex_ok = (
        complex_mult_q14(8192, 4096, 16384, 0) == (8192, 4096)
        and complex_mult_q14(8192, 0, 0, 16384) == (0, 8192)
        and complex_mult_q14(8192, 8192, 8192, -8192) == (8192, 0)
    )

    addr_ok = (
        butterfly_addresses(0, 0) == (0, 1, 0)
        and butterfly_addresses(1, 1) == (1, 3, 64)
        and butterfly_addresses(2, 4) == (8, 12, 0)
        and butterfly_addresses(7, 127) == (127, 255, 127)
    )

    return bit_reverse_ok and twiddle_ok and complex_ok and addr_ok


def test_zero_frame() -> bool:
    real_out, imag_out = fft_radix2_core_fixed_model([0] * FFT_SIZE)
    return all(value == 0 for value in real_out) and all(value == 0 for value in imag_out)


def test_impulse0() -> bool:
    real_samples = [0] * FFT_SIZE
    real_samples[0] = Q2_14_ONE
    real_out, imag_out = fft_radix2_core_fixed_model(real_samples)
    return all(value == Q2_14_ONE for value in real_out) and all(
        value == 0 for value in imag_out
    )


def test_impulse1_basic_properties() -> bool:
    real_samples = [0] * FFT_SIZE
    real_samples[1] = Q2_14_ONE
    real_out, imag_out = fft_radix2_core_fixed_model(real_samples)

    selected_bins_ok = check_bins(
        "impulse1",
        real_out,
        imag_out,
        {
            0: (16384, 0),
            1: (16379, -402),
            2: (16364, -804),
            32: (11585, -11585),
            64: (0, -16384),
            96: (-11585, -11585),
            128: (-16384, 0),
            192: (0, 16384),
            255: (16379, 402),
        },
    )

    return (
        selected_bins_ok
        and no_invalid_values(real_out)
        and no_invalid_values(imag_out)
        and int16_range(real_out)
        and int16_range(imag_out)
    )


def test_simple_two_sample() -> bool:
    real_samples = [0] * FFT_SIZE
    real_samples[0] = 8192
    real_samples[1] = 8192

    real_out_a, imag_out_a = fft_radix2_core_fixed_model(real_samples)
    real_out_b, imag_out_b = fft_radix2_core_fixed_model(real_samples)

    deterministic_ok = real_out_a == real_out_b and imag_out_a == imag_out_b
    selected_bins_ok = check_bins(
        "simple_two_sample",
        real_out_a,
        imag_out_a,
        {
            0: (16384, 0),
            1: (16381, -201),
            32: (13984, -5793),
            64: (8192, -8192),
            128: (0, 0),
            192: (8192, 8192),
            255: (16382, 201),
        },
    )

    return (
        deterministic_ok
        and selected_bins_ok
        and no_invalid_values(real_out_a)
        and no_invalid_values(imag_out_a)
        and int16_range(real_out_a)
        and int16_range(imag_out_a)
    )


def main() -> int:
    print("=== FFT RADIX-2 BIT-EXACT FIXED MODEL TEST ===")
    print(f"FFT_SIZE={FFT_SIZE}")
    print("FORMAT=Q2.14")
    print("MODE=RTL_WRAPAROUND_TRUNCATION")
    print("")

    report("helpers", test_helpers())
    report("zero_frame", test_zero_frame())
    report("impulse0", test_impulse0())
    report("impulse1_basic_properties", test_impulse1_basic_properties())
    report("simple_two_sample", test_simple_two_sample())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
