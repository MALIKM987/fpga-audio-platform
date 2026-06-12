#!/usr/bin/env python3
"""Bit-exact fixed-point model of the standalone radix-2 FFT core.

This model mirrors the current RTL behavior of rtl/dsp/fft_radix2_core.v.
It is intentionally not an ideal floating-point FFT reference.  It models the
Q2.14 twiddle ROM, the combinational complex multiplier, bit-reversed loading,
radix-2 butterfly address generation, and 16-bit wraparound/truncation.
"""

from __future__ import annotations


FFT_SIZE = 256
DATA_WIDTH = 16
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


def twiddle_q14(addr: int, inverse: bool = False) -> tuple[int, int]:
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

    return wrap_int16(real), wrap_int16(imag)


def complex_mult_q14(
    a_real: int,
    a_imag: int,
    b_real: int,
    b_imag: int,
) -> tuple[int, int]:
    """Match rtl/dsp/complex_mult.v with Q2.14 shift and 16-bit truncation."""

    ar = wrap_int16(a_real)
    ai = wrap_int16(a_imag)
    br = wrap_int16(b_real)
    bi = wrap_int16(b_imag)

    real_full = (ar * br) - (ai * bi)
    imag_full = (ar * bi) + (ai * br)

    real_scaled = real_full >> FRAC_BITS
    imag_scaled = imag_full >> FRAC_BITS

    return wrap_int16(real_scaled), wrap_int16(imag_scaled)


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
) -> tuple[list[int], list[int]]:
    """Run the same frame-level computation as the current RTL core."""

    if imag_samples is None:
        imag_samples = [0] * FFT_SIZE
    _validate_frame(real_samples, imag_samples)

    real_mem = [0] * FFT_SIZE
    imag_mem = [0] * FFT_SIZE

    for index in range(FFT_SIZE):
        write_addr = bit_reverse(index)
        real_mem[write_addr] = wrap_int16(real_samples[index])
        imag_mem[write_addr] = wrap_int16(imag_samples[index])

    for stage in range(NUM_STAGES):
        for butterfly_index in range(BUTTERFLIES_PER_STAGE):
            addr_a, addr_b, twiddle_index = butterfly_addresses(stage, butterfly_index)

            a_real = real_mem[addr_a]
            a_imag = imag_mem[addr_a]
            b_real = real_mem[addr_b]
            b_imag = imag_mem[addr_b]

            tw_real, tw_imag = twiddle_q14(twiddle_index, inverse=inverse)
            b_tw_real, b_tw_imag = complex_mult_q14(
                b_real,
                b_imag,
                tw_real,
                tw_imag,
            )

            out_a_real = wrap_int16(a_real + b_tw_real)
            out_a_imag = wrap_int16(a_imag + b_tw_imag)
            out_b_real = wrap_int16(a_real - b_tw_real)
            out_b_imag = wrap_int16(a_imag - b_tw_imag)

            real_mem[addr_a] = out_a_real
            imag_mem[addr_a] = out_a_imag
            real_mem[addr_b] = out_b_real
            imag_mem[addr_b] = out_b_imag

    return list(real_mem), list(imag_mem)
