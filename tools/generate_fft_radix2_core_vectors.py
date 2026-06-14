#!/usr/bin/env python3
"""Generate deterministic vectors for fft_radix2_core_tb.v."""

from __future__ import annotations

from pathlib import Path

from fft_radix2_fixed_model import (
    FFT_SIZE,
    Q2_14_ONE,
    fft_radix2_core_fixed_model,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = REPO_ROOT / "tb" / "generated"

TEST_CASES = {
    "zero_frame": {
        "real": [0] * FFT_SIZE,
        "imag": [0] * FFT_SIZE,
    },
    "impulse0": {
        "real": [Q2_14_ONE] + [0] * (FFT_SIZE - 1),
        "imag": [0] * FFT_SIZE,
    },
    "impulse1": {
        "real": [0, Q2_14_ONE] + [0] * (FFT_SIZE - 2),
        "imag": [0] * FFT_SIZE,
    },
    "two_sample": {
        "real": [8192, 8192] + [0] * (FFT_SIZE - 2),
        "imag": [0] * FFT_SIZE,
    },
}


def format_vector_lines(
    real_in: list[int],
    imag_in: list[int],
    expected_real: list[int],
    expected_imag: list[int],
) -> str:
    lines = []
    for index in range(FFT_SIZE):
        lines.append(
            f"{real_in[index]} {imag_in[index]} "
            f"{expected_real[index]} {expected_imag[index]}"
        )
    return "\n".join(lines) + "\n"


def write_if_changed(path: Path, content: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return False
    path.write_text(content, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("=== FFT RADIX-2 CORE VECTOR GENERATOR ===")
    print(f"FFT_SIZE={FFT_SIZE}")
    print("FORMAT=decimal real_in imag_in expected_real expected_imag")
    print("IFFT_NORMALIZATION=PER_STAGE_ARITH_SHIFT_RIGHT_1")
    print("")

    changed_count = 0
    for name, frame in TEST_CASES.items():
        real_in = list(frame["real"])
        imag_in = list(frame["imag"])
        expected_real, expected_imag = fft_radix2_core_fixed_model(real_in, imag_in)
        vector_text = format_vector_lines(real_in, imag_in, expected_real, expected_imag)
        output_path = OUTPUT_DIR / f"fft_radix2_core_{name}.mem"
        changed = write_if_changed(output_path, vector_text)
        changed_count += 1 if changed else 0
        status = "UPDATED" if changed else "UNCHANGED"
        print(f"VECTOR {name} {status} {output_path.relative_to(REPO_ROOT)}")

        inverse_expected_real, inverse_expected_imag = fft_radix2_core_fixed_model(
            real_in,
            imag_in,
            inverse=True,
        )
        inverse_vector_text = format_vector_lines(
            real_in,
            imag_in,
            inverse_expected_real,
            inverse_expected_imag,
        )
        inverse_output_path = OUTPUT_DIR / f"ifft_radix2_core_{name}.mem"
        inverse_changed = write_if_changed(inverse_output_path, inverse_vector_text)
        changed_count += 1 if inverse_changed else 0
        inverse_status = "UPDATED" if inverse_changed else "UNCHANGED"
        print(
            f"VECTOR ifft_{name} {inverse_status} "
            f"{inverse_output_path.relative_to(REPO_ROOT)}"
        )

    print("")
    print(f"generated_vectors: {len(TEST_CASES) * 2}")
    print(f"changed_vectors: {changed_count}")
    print("STATUS=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
