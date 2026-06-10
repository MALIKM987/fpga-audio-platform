#!/usr/bin/env python3
"""Run Python reference tests and the Verilog testbench suite."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = REPO_ROOT / "sim"

PYTHON_TESTS = [
    {
        "name": "fft_reference_model",
        "command": [sys.executable, "tools/test_fft_reference_model.py"],
    },
]

VERILOG_TESTS = [
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


def run_python_test(test: dict[str, object]) -> bool:
    name = str(test["name"])
    command = [str(part) for part in test["command"]]
    result = run_command(command)
    output = result.stdout.rstrip()
    pass_marker = "STATUS=PASS" in result.stdout
    fail_marker = "STATUS=FAIL" in result.stdout

    if output:
        print(output)

    if result.returncode == 0 and pass_marker and not fail_marker:
        print(f"TEST {name} PASS")
        return True

    print(f"TEST {name} FAIL")
    if result.returncode != 0:
        print(f"  exit code: {result.returncode}")
    if not pass_marker:
        print("  missing STATUS=PASS marker")
    if fail_marker:
        print("  STATUS=FAIL marker found")
    return False


def run_verilog_test(test: dict[str, object]) -> bool:
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

    print("=== PROJECT TEST RUNNER ===")
    print("")
    print("PYTHON REFERENCE TESTS:")

    python_passed = 0
    python_failed = 0

    for test in PYTHON_TESTS:
        if run_python_test(test):
            python_passed += 1
        else:
            python_failed += 1
        print("")

    print("VERILOG TESTS:")
    print("TOOLS:")
    print_tool_status("iverilog", iverilog_path)
    print_tool_status("vvp", vvp_path)
    print("")

    SIM_DIR.mkdir(exist_ok=True)

    verilog_passed = 0
    verilog_failed = 0
    verilog_skipped = False

    if not iverilog_path or not vvp_path:
        print("Cannot run Verilog simulations.")
        print("Install Icarus Verilog and make sure iverilog/vvp are available in PATH.")
        print("STATUS=SKIPPED")
        verilog_skipped = True
    else:
        for test in VERILOG_TESTS:
            if run_verilog_test(test):
                verilog_passed += 1
            else:
                verilog_failed += 1
            print("")

    final_pass = python_failed == 0 and verilog_failed == 0

    print("")
    print("FINAL STATUS:")
    print(f"python_passed: {python_passed}")
    print(f"python_failed: {python_failed}")
    print(f"verilog_passed: {verilog_passed}")
    print(f"verilog_failed: {verilog_failed}")
    print(f"verilog_skipped: {1 if verilog_skipped else 0}")
    print("STATUS=PASS" if final_pass else "STATUS=FAIL")

    return 0 if final_pass else 1


if __name__ == "__main__":
    sys.exit(main())
