# FPGA Audio Platform

Current priority: an FPGA-only FFT/IFFT accelerator for I2S-like audio blocks
on Tang Nano 20K, verified from simulation and console reports before returning
to external audio hardware.

The repository started as a physical audio bring-up project for:

```text
PCM1808 ADC -> FPGA -> PCM5102A DAC
```

That hardware path is now future work. The active direction is to model audio
frames internally, process them in FPGA logic, and report results in a way that
can be checked without ADC, DAC, oscilloscope, or real-time streaming.

## Current Scope

The current project scope is:

- FPGA-only DSP and control logic.
- Console-verifiable FFT/IFFT pipeline planning.
- Self-test diagnostics on Tang Nano 20K.
- Fixed-point processing for signed 16-bit audio-style samples.
- Stereo L/R architecture planning, with shared accelerator use allowed.

The first target architecture is:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

No physical PCM1808 input path or PCM5102A output path is part of the current
implementation target.

## Current Active Self-Test

The active RTL that can be used today is the diagnostic self-test:

```text
test_signal_gen
-> auto_param_controller
-> modulation_core
-> debug_analyzer
-> uart_debug_formatter
-> uart_tx
```

Important files:

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

For the first minimal Gowin hardware self-test, use:

```text
Top module: tang_audio_selftest_board_top
Constraints: gowin_impl/tang_audio_hw/src/tang_audio_hw.cst
```

This wrapper exposes only `clk` and `led`. UART is kept internal for the first
board-level check unless a confirmed 3.3 V UART connection is available.

## Planned FFT/IFFT Architecture

The planned first FFT/IFFT version uses:

- `FFT_SIZE = 256`
- signed 16-bit samples
- stereo L/R blocks
- fixed-point arithmetic
- Q2.14 gain values
- test modes such as bypass, sine tones, impulse, mixed signal, and different
  L/R gains

Planned RTL modules include:

- `rtl/dsp/sample_block_buffer.v`
- `rtl/dsp/spectral_gain_select.v`
- `rtl/dsp/spectral_processor.v`
- `rtl/dsp/fft_accel_wrapper.v`
- `rtl/dsp/ifft_accel_wrapper.v`
- `rtl/dsp/fft_ifft_pipeline.v`

These modules are not implemented yet. They should be added in small steps,
each with a testbench or coverage from a higher-level testbench.

## Hardware TODO / Future Work

The physical audio path is intentionally deferred:

- PCM1808 ADC as the future physical input layer.
- PCM5102A DAC as the future physical output layer.
- Real I2S pin constraints and oscilloscope checks.
- Continuous audio streaming.
- Windowing and overlap-add.
- Later integration with external hardware after the FPGA-only pipeline is
  verified.

Existing I2S and hardware bring-up files are retained as legacy/reference
material for that later stage. Do not treat them as the active architecture for
the FFT/IFFT work.

## Documentation

Start here:

- `docs/fpga_only_architecture.md`
- `docs/verification_plan.md`
- `docs/hardware_todo.md`
- `docs/selftest_uart_diagnostics.md`
- `docs/gowin_hardware_test_steps.md`
