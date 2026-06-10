# Verification Plan

## Goal

The verification goal is to prove the FPGA-only FFT/IFFT pipeline before
returning to physical ADC/DAC hardware. Tests should be deterministic,
repeatable from the console, and clear enough to show PASS/FAIL status without
an oscilloscope.

The planned pipeline under test is:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

The first target parameters are:

- `FFT_SIZE = 256`
- `SAMPLE_WIDTH = 16`
- signed fixed-point samples
- stereo L/R tests
- Q2.14 gain values

## Required Tests

### bypass

Purpose:

- Run FFT -> IFFT without spectral modification.
- Confirm that the output is almost equal to the input.

PASS criteria:

- `FFT_DONE = 1`
- `IFFT_DONE = 1`
- output samples match input samples within the accepted fixed-point tolerance,
- no unexpected clipping.

### sine_100Hz

Purpose:

- Verify bass-band detection and modification.
- Confirm that a low-frequency tone maps to the expected low FFT bin range.

PASS criteria:

- dominant bin is in the bass range,
- bass gain changes the expected bins,
- mid/treble bins remain mostly unchanged,
- clipping matches expectation.

### sine_1kHz

Purpose:

- Verify mid-band detection and modification.

PASS criteria:

- dominant bin is in the mid range,
- mid gain changes the expected bins,
- bass/treble bins remain mostly unchanged,
- output magnitude changes consistently with the configured gain.

### sine_8kHz

Purpose:

- Verify treble-band detection and modification.

PASS criteria:

- dominant bin is in the treble range,
- treble gain changes the expected bins,
- bass/mid bins remain mostly unchanged,
- clipping is reported if the configured gain exceeds output range.

### impulse

Purpose:

- Exercise the full FFT/IFFT path with an impulse input.
- Check bin spreading and reconstruction behavior.

PASS criteria:

- FFT and IFFT complete,
- reconstructed impulse is within tolerance,
- report shows no unknown or invalid values.

### mixed_signal

Purpose:

- Verify several frequency components at the same time.
- Confirm that bass/mid/treble gains affect the correct parts of the spectrum.

PASS criteria:

- expected components are visible in the report,
- modified magnitudes match the selected gain settings,
- unrelated bins remain within tolerance.

### stereo_diff_gains

Purpose:

- Verify independent left and right channel parameters.

PASS criteria:

- channel L uses L gain registers,
- channel R uses R gain registers,
- reported magnitudes differ according to the configured L/R gains,
- channel data is not swapped.

## Console Report Format

Example report:

```text
=== FFT/IFFT PIPELINE TEST ===
FFT_SIZE=256
SAMPLE_WIDTH=16
TEST=sine_100Hz
CHANNEL=L
BASS_GAIN=+6dB
MID_GAIN=0dB
TREBLE_GAIN=0dB

FFT_DONE=1
IFFT_DONE=1
DOMINANT_BIN_IN=1
DOMINANT_FREQ_HZ=187.5
MAG_IN=8120
MAG_AFTER_MOD=12180
CLIP=0
STATUS=PASS
```

Each testbench should print enough information to explain a failure. A failing
test should use `STATUS=FAIL` and identify the mismatched field, such as
dominant bin, magnitude, clipping, or output reconstruction tolerance.

## General PASS/FAIL Rules

Tests should fail when:

- `FFT_DONE` is not asserted,
- `IFFT_DONE` is not asserted,
- output contains unknown values,
- dominant bin is outside the expected range,
- gain does not affect the expected band,
- unexpected clipping occurs,
- stereo channel mapping is incorrect.

Tests may allow a small tolerance for fixed-point scaling, rounding, and FFT/IFFT
normalization. That tolerance must be printed or documented by the testbench.

## Current Verification Status

The final FFT/IFFT tests cannot run yet because the FFT/IFFT pipeline modules
are not implemented. Existing self-test testbenches remain useful for the
current diagnostic layer:

- `tb/test_signal_gen_tb.v`
- `tb/modulation_core_tb.v`
- `tb/debug_analyzer_tb.v`
- `tb/uart_tx_tb.v`
- `tb/tang_audio_selftest_top_tb.v`

Those tests verify pieces of the current diagnostic path, not the future
FFT/IFFT accelerator.
