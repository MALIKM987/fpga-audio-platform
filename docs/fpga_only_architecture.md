# FPGA-Only FFT/IFFT Architecture

## Goal

The current project goal is an FPGA-only FFT/IFFT accelerator for I2S-like
audio blocks on Tang Nano 20K. The design should be verifiable from simulation
and console reports before it is connected to real external audio hardware.

This stage focuses on deterministic block processing, fixed-point arithmetic,
clear test reports, and a clean interface between audio-style sample frames and
the future FFT/IFFT accelerator.

## Why Physical ADC/DAC Is Deferred

The earlier hardware direction used:

```text
PCM1808 ADC -> FPGA -> PCM5102A DAC
```

That path depends on physical wiring, clocking, real I2S RX/TX timing, analog
measurement, and board-level debug. Those are useful later, but they make it
harder to prove whether the DSP logic itself is correct.

For now, the project defers PCM1808, PCM5102A, physical I2S, and continuous
audio streaming. The FPGA logic should first pass repeatable tests using
internally generated or testbench-modeled sample blocks.

## Logical Pipeline

The target processing path is:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

The input and output models are not meant to be physical I2S drivers in this
stage. They represent audio frames in an I2S-like order so the later hardware
integration can reuse the same data layout.

## Current State

The FFT/IFFT pipeline RTL is not implemented yet.

The active logic today is a standalone diagnostic self-test:

```text
test_signal_gen
-> auto_param_controller
-> modulation_core
-> debug_analyzer
-> uart_debug_formatter
-> uart_tx
```

Relevant files:

- `rtl/top/tang_audio_selftest_top.v`
- `rtl/top/tang_audio_selftest_board_top.v`
- `rtl/debug/test_signal_gen.v`
- `rtl/debug/auto_param_controller.v`
- `rtl/debug/debug_analyzer.v`
- `rtl/debug/uart_debug_formatter.v`
- `rtl/dsp/modulation_core.v`
- `rtl/dsp/gain_lut_q2_14.v`
- `rtl/dsp/volume_lut_q2_14.v`
- `rtl/uart/uart_tx.v`

This self-test is useful as the current diagnostic baseline. It generates an
internal test signal, changes VOL/BASS/MID/TREBLE parameters automatically,
runs a simple DSP modulation block, collects min/max/clipping information, and
formats a UART diagnostic stream.

## Planned RTL Modules

The following modules are planned for the FPGA-only FFT/IFFT architecture:

- `rtl/dsp/sample_block_buffer.v`
- `rtl/dsp/spectral_gain_select.v`
- `rtl/dsp/spectral_processor.v`
- `rtl/dsp/fft_accel_wrapper.v`
- `rtl/dsp/ifft_accel_wrapper.v`
- `rtl/dsp/fft_ifft_pipeline.v`

These modules should be introduced step by step. Each new Verilog module should
have a dedicated testbench or be covered by a higher-level pipeline testbench.

## First Version Parameters

Initial target parameters:

- `FFT_SIZE = 256`
- `SAMPLE_WIDTH = 16` signed
- stereo L/R sample blocks
- fixed-point arithmetic
- gain values in Q2.14

The accelerator may be shared between left and right channels in the first
version if that keeps the architecture simpler.

## Parameter Registers

The planned processing configuration is stereo-aware:

```text
volume_L
bass_gain_L
mid_gain_L
treble_gain_L

volume_R
bass_gain_R
mid_gain_R
treble_gain_R
```

The first implementation can model these as simple registers driven by a
testbench or self-test controller. A later system can expose them through UART,
buttons, or a memory-mapped interface.

## Spectral Processor

The `spectral_processor` will modify FFT bins according to the configured
frequency bands.

Expected first behavior:

- bass gain affects low-frequency bins,
- mid gain affects middle-frequency bins,
- treble gain affects high-frequency bins,
- volume can be applied globally or after IFFT,
- clipping/overflow should be detected and reported.

This is not a real-time audio effect yet. It is a block-processing test path
intended to prove FFT -> modify bins -> IFFT behavior.

## Self-Test Mode

The self-test should eventually generate deterministic sample blocks such as:

- bypass input,
- 100 Hz sine-like signal,
- 1 kHz sine-like signal,
- 8 kHz sine-like signal,
- impulse,
- mixed signal,
- stereo signals with different L/R gains.

The current self-test is not the final FFT/IFFT self-test, but it is the active
diagnostic foundation for clock/reset/status/UART behavior.

## Reporting

Results should be visible first in testbench console output. A later board
self-test can reuse the same summary fields over UART on Tang Nano 20K.

Expected report contents include:

- test name,
- FFT size,
- channel,
- gain settings,
- FFT done,
- IFFT done,
- dominant bin/frequency,
- input and output magnitudes,
- clipping flag,
- PASS/FAIL status.

## Future FFT Core Integration

The FFT/IFFT wrapper may later connect to Gowin FFT IP or another verified FFT
core. The wrapper should hide core-specific handshakes from the rest of the
pipeline so the surrounding testbench, spectral processor, and report logic can
remain stable while the FFT implementation changes.
