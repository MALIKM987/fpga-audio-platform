#!/usr/bin/env python3
"""Bit-exact fixed-point model of the standalone radix-2 FFT core.

This model mirrors the current RTL behavior of rtl/dsp/fft_radix2_core.v.
It is intentionally not an ideal floating-point FFT reference.  It models the
Q2.14 twiddle ROM, the combinational complex multiplier, bit-reversed loading,
radix-2 butterfly address generation, saturating butterfly writeback, and
inverse per-stage 1-bit scaling. The project pipeline uses a wider internal FFT
width and narrows back to int16 only at the final output.
"""

from __future__ import annotations


FFT_SIZE = 256
DATA_WIDTH = 16
PIPELINE_INTERNAL_WIDTH = 24
INDEX_WIDTH = 8
FRAC_BITS = 14
Q2_14_ONE = 1 << FRAC_BITS
NUM_STAGES = 8
BUTTERFLIES_PER_STAGE = FFT_SIZE // 2

COS_Q14 = (
    16384,
    16379,
    16364,
    16340,
    16305,
    16261,
    16207,
    16143,
    16069,
    15986,
    15893,
    15791,
    15679,
    15557,
    15426,
    15286,
    15137,
    14978,
    14811,
    14635,
    14449,
    14256,
    14053,
    13842,
    13623,
    13395,
    13160,
    12916,
    12665,
    12406,
    12140,
    11866,
    11585,
    11297,
    11003,
    10702,
    10394,
    10080,
    9760,
    9434,
    9102,
    8765,
    8423,
    8076,
    7723,
    7366,
    7005,
    6639,
    6270,
    5897,
    5520,
    5139,
    4756,
    4370,
    3981,
    3590,
    3196,
    2801,
    2404,
    2006,
    1606,
    1205,
    804,
    402,
    0,
)


def mask_to_width(value: int, width: int) -> int:
    """Return the low `width` bits, like assigning to a Verilog vector."""

    return value & ((1 << width) - 1)


def to_signed(value: int, width: int) -> int:
    """Interpret `value` as a signed two's-complement integer."""

    masked = mask_to_width(value, width)
    sign_bit = 1 << (width - 1)
    if masked & sign_bit:
        return masked - (1 << width)
    return masked


def wrap_int16(value: int) -> int:
    """Wrap/truncate to signed 16-bit, matching DATA_WIDTH assignment."""

    return to_signed(value, DATA_WIDTH)


def wrap_to_width(value: int, width: int) -> int:
    """Wrap/truncate to signed `width` bits."""

    return to_signed(value, width)


def saturate_to_width(value: int, width: int) -> int:
    """Saturate an integer to signed `width` bits."""

    min_value = -(1 << (width - 1))
    max_value = (1 << (width - 1)) - 1
    if value > max_value:
        return max_value
    if value < min_value:
        return min_value
    return int(value)


def narrow_to_width(value: int, width: int, saturate: bool = True) -> int:
    """Narrow `value` either by saturation or two's-complement wrap."""

    if saturate:
        return saturate_to_width(value, width)
    return wrap_to_width(value, width)


def bit_reverse(index: int, width: int = INDEX_WIDTH) -> int:
    """Reverse FFT index bits, matching rtl/dsp/fft_bit_reverse.v."""

    result = 0
    for bit_index in range(width):
        result = (result << 1) | ((index >> bit_index) & 1)
    return result


def cos_q14(index: int) -> int:
    """Return the exact Q2.14 cosine table entry used by fft_twiddle_rom.v."""

    if 0 <= index < len(COS_Q14):
        return COS_Q14[index]
    return 0


def twiddle_q14(
    addr: int,
    inverse: bool = False,
    data_width: int = DATA_WIDTH,
) -> tuple[int, int]:
    """Return twiddle factor for FFT/IFFT mode using the RTL ROM table."""

    rom_addr = mask_to_width(addr, 7)
    if rom_addr <= 64:
        real = cos_q14(rom_addr)
        imag = -cos_q14(64 - rom_addr)
    else:
        mirror_addr = 128 - rom_addr
        real = -cos_q14(mirror_addr)
        imag = -cos_q14(64 - mirror_addr)

    if inverse:
        imag = -imag

    return wrap_to_width(real, data_width), wrap_to_width(imag, data_width)


def complex_mult_q14(
    a_real: int,
    a_imag: int,
    b_real: int,
    b_imag: int,
    data_width: int = DATA_WIDTH,
    saturate: bool = True,
) -> tuple[int, int]:
    """Match rtl/dsp/complex_mult.v with Q2.14 shift and saturation."""

    ar = wrap_to_width(a_real, data_width)
    ai = wrap_to_width(a_imag, data_width)
    br = wrap_to_width(b_real, data_width)
    bi = wrap_to_width(b_imag, data_width)

    real_full = (ar * br) - (ai * bi)
    imag_full = (ar * bi) + (ai * br)

    real_scaled = real_full >> FRAC_BITS
    imag_scaled = imag_full >> FRAC_BITS

    return (
        narrow_to_width(real_scaled, data_width, saturate=saturate),
        narrow_to_width(imag_scaled, data_width, saturate=saturate),
    )


def apply_q2_14_gain(
    value: int,
    gain: int,
    data_width: int = DATA_WIDTH,
    saturate: bool = True,
) -> int:
    """Match rtl/dsp/spectral_processor.v gain multiply and narrowing."""

    value = wrap_to_width(value, data_width)
    gain = wrap_to_width(gain, DATA_WIDTH)
    scaled = (value * gain) >> FRAC_BITS
    return narrow_to_width(scaled, data_width, saturate=saturate)


def butterfly_addresses(stage: int, butterfly_index: int) -> tuple[int, int, int]:
    """Match rtl/dsp/fft_butterfly_addr_gen.v for FFT_SIZE=256."""

    half_size = 1 << stage
    group_size = 1 << (stage + 1)
    group = butterfly_index // half_size
    index_in_group = butterfly_index % half_size
    twiddle_step = FFT_SIZE // group_size

    addr_a = (group * group_size) + index_in_group
    addr_b = addr_a + half_size
    twiddle_index = index_in_group * twiddle_step

    return addr_a, addr_b, twiddle_index


def _validate_frame(real_samples: list[int], imag_samples: list[int]) -> None:
    if len(real_samples) != FFT_SIZE:
        raise ValueError(f"real_samples must contain exactly {FFT_SIZE} samples")
    if len(imag_samples) != FFT_SIZE:
        raise ValueError(f"imag_samples must contain exactly {FFT_SIZE} samples")


def fft_radix2_core_fixed_model(
    real_samples: list[int],
    imag_samples: list[int] | None = None,
    inverse: bool = False,
    normalize_inverse: bool = True,
    data_width: int = DATA_WIDTH,
    saturate: bool = True,
) -> tuple[list[int], list[int]]:
    """Run the same frame-level computation as the current RTL core."""

    if imag_samples is None:
        imag_samples = [0] * FFT_SIZE
    _validate_frame(real_samples, imag_samples)

    real_mem = [0] * FFT_SIZE
    imag_mem = [0] * FFT_SIZE

    for index in range(FFT_SIZE):
        write_addr = bit_reverse(index)
        real_mem[write_addr] = wrap_to_width(real_samples[index], data_width)
        imag_mem[write_addr] = wrap_to_width(imag_samples[index], data_width)

    for stage in range(NUM_STAGES):
        for butterfly_index in range(BUTTERFLIES_PER_STAGE):
            addr_a, addr_b, twiddle_index = butterfly_addresses(stage, butterfly_index)

            a_real = real_mem[addr_a]
            a_imag = imag_mem[addr_a]
            b_real = real_mem[addr_b]
            b_imag = imag_mem[addr_b]

            tw_real, tw_imag = twiddle_q14(
                twiddle_index,
                inverse=inverse,
                data_width=data_width,
            )
            b_tw_real, b_tw_imag = complex_mult_q14(
                b_real,
                b_imag,
                tw_real,
                tw_imag,
                data_width=data_width,
                saturate=saturate,
            )

            out_a_real_full = a_real + b_tw_real
            out_a_imag_full = a_imag + b_tw_imag
            out_b_real_full = a_real - b_tw_real
            out_b_imag_full = a_imag - b_tw_imag

            if inverse and normalize_inverse:
                out_a_real_full >>= 1
                out_a_imag_full >>= 1
                out_b_real_full >>= 1
                out_b_imag_full >>= 1

            out_a_real = narrow_to_width(
                out_a_real_full,
                data_width,
                saturate=saturate,
            )
            out_a_imag = narrow_to_width(
                out_a_imag_full,
                data_width,
                saturate=saturate,
            )
            out_b_real = narrow_to_width(
                out_b_real_full,
                data_width,
                saturate=saturate,
            )
            out_b_imag = narrow_to_width(
                out_b_imag_full,
                data_width,
                saturate=saturate,
            )

            real_mem[addr_a] = out_a_real
            imag_mem[addr_a] = out_a_imag
            real_mem[addr_b] = out_b_real
            imag_mem[addr_b] = out_b_imag

    return list(real_mem), list(imag_mem)


def fft_ifft_pipeline_fixed_model(
    samples: list[int],
    bass_gain: int,
    mid_gain: int,
    treble_gain: int,
    internal_width: int = PIPELINE_INTERNAL_WIDTH,
    output_width: int = DATA_WIDTH,
    saturate: bool = True,
) -> list[int]:
    """Model the RTL pipeline with wider internal FFT bins and int16 output."""

    if len(samples) != FFT_SIZE:
        raise ValueError(f"samples must contain exactly {FFT_SIZE} samples")

    zero_imag = [0] * FFT_SIZE
    input_real = [wrap_to_width(sample, output_width) for sample in samples]
    fft_real, fft_imag = fft_radix2_core_fixed_model(
        input_real,
        zero_imag,
        inverse=False,
        data_width=internal_width,
        saturate=saturate,
    )

    spectral_real: list[int] = []
    spectral_imag: list[int] = []
    for index, (real_value, imag_value) in enumerate(zip(fft_real, fft_imag)):
        effective_bin = index if index <= FFT_SIZE // 2 else FFT_SIZE - index
        if effective_bin <= 1:
            gain = bass_gain
        elif effective_bin <= 21:
            gain = mid_gain
        else:
            gain = treble_gain

        spectral_real.append(
            apply_q2_14_gain(
                real_value,
                gain,
                data_width=internal_width,
                saturate=saturate,
            )
        )
        spectral_imag.append(
            apply_q2_14_gain(
                imag_value,
                gain,
                data_width=internal_width,
                saturate=saturate,
            )
        )

    ifft_real, _ifft_imag = fft_radix2_core_fixed_model(
        spectral_real,
        spectral_imag,
        inverse=True,
        normalize_inverse=True,
        data_width=internal_width,
        saturate=saturate,
    )

    return [
        saturate_to_width(value, output_width)
        for value in ifft_real
    ]
