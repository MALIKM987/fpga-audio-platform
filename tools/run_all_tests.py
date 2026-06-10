#!/usr/bin/env python3
"""Run the small Verilog testbench suite with Icarus Verilog."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = REPO_ROOT / "sim"

TESTS = [
    {
        "name": "fft_control_regs",
        "sources": [
            "rtl/control/fft_control_regs.v",
            "tb/fft_control_regs_tb.v",
        ],
    },
    {
        "name": "fft_accelerator_core",
        "sources": [
            "rtl/control/fft_control_regs.v",
            "rtl/dsp/sample_block_buffer.v",
            "rtl/dsp/spectral_gain_select.v",
            "rtl/dsp/spectral_processor.v",
            "rtl/dsp/fft_accel_wrapper.v",
            "rtl/dsp/ifft_accel_wrapper.v",
            "rtl/dsp/fft_ifft_pipeline.v",
            "rtl/control/fft_accelerator_core.v",
            "tb/fft_accelerator_core_tb.v",
        ],
    },
    {
        "name": "spectral_processor",
        "sources": [
            "rtl/dsp/spectral_gain_select.v",
            "rtl/dsp/spectral_processor.v",
            "tb/spectral_processor_tb.v",
        ],
    },
    {
        "name": "sample_block_buffer",
        "sources": [
            "rtl/dsp/sample_block_buffer.v",
            "tb/sample_block_buffer_tb.v",
        ],
    },
    {
        "name": "fft_accel_wrapper",
        "sources": [
            "rtl/dsp/fft_accel_wrapper.v",
            "tb/fft_accel_wrapper_tb.v",
        ],
    },
    {
        "name": "ifft_accel_wrapper",
        "sources": [
            "rtl/dsp/ifft_accel_wrapper.v",
            "tb/ifft_accel_wrapper_tb.v",
        ],
    },
    {
        "name": "fft_ifft_pipeline",
        "sources": [
            "rtl/dsp/sample_block_buffer.v",
            "rtl/dsp/spectral_gain_select.v",
            "rtl/dsp/spectral_processor.v",
            "rtl/dsp/fft_accel_wrapper.v",
            "rtl/dsp/ifft_accel_wrapper.v",
            "rtl/dsp/fft_ifft_pipeline.v",
            "tb/fft_ifft_pipeline_tb.v",
        ],
    },
]


def print_tool_status(tool_name: str, tool_path: str | None) -> None:
    status = "FOUND" if tool_path else "NOT FOUND"
    print(f"{tool_name}: {status}")


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def run_test(test: dict[str, object]) -> bool:
    name = str(test["name"])
    sources = [str(source) for source in test["sources"]]
    output_file = SIM_DIR / f"{name}.vvp"

    compile_cmd = ["iverilog", "-g2012", "-o", str(output_file), *sources]
    compile_result = run_command(compile_cmd)
    if compile_result.returncode != 0:
        print(f"TEST {name} FAIL")
        print("  compile failed:")
        print(compile_result.stdout.rstrip())
        return False

    sim_result = run_command(["vvp", str(output_file)])
    sim_stdout = sim_result.stdout.rstrip()
    pass_marker = "STATUS=PASS" in sim_result.stdout
    fail_marker = "STATUS=FAIL" in sim_result.stdout

    if sim_stdout:
        print(sim_stdout)

    if sim_result.returncode == 0 and pass_marker and not fail_marker:
        print(f"TEST {name} PASS")
        return True

    print(f"TEST {name} FAIL")
    if sim_result.returncode != 0:
        print(f"  simulation exit code: {sim_result.returncode}")
    if not pass_marker:
        print("  missing STATUS=PASS marker")
    if fail_marker:
        print("  STATUS=FAIL marker found")
    return False


def main() -> int:
    iverilog_path = shutil.which("iverilog")
    vvp_path = shutil.which("vvp")

    print("=== VERILOG TEST RUNNER ===")
    print("TOOLS:")
    print_tool_status("iverilog", iverilog_path)
    print_tool_status("vvp", vvp_path)
    print("")

    SIM_DIR.mkdir(exist_ok=True)

    if not iverilog_path or not vvp_path:
        print("Cannot run Verilog simulations.")
        print("Install Icarus Verilog and make sure iverilog/vvp are available in PATH.")
        print("STATUS=SKIPPED")
        return 0

    passed = 0
    failed = 0

    for test in TESTS:
        if run_test(test):
            passed += 1
        else:
            failed += 1
        print("")

    print("SUMMARY:")
    print(f"passed: {passed}")
    print(f"failed: {failed}")
    print("STATUS=PASS" if failed == 0 else "STATUS=FAIL")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
