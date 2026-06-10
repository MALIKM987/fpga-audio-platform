# Hardware TODO / Future Work

## Purpose

The current project direction is FPGA-only FFT/IFFT development with
console-verifiable tests. Physical audio hardware is deferred until the DSP
pipeline is stable in simulation and self-test.

This document records the hardware work that should be revisited later instead
of deleting the older bring-up files.

## Future Input Layer: PCM1808 ADC

The PCM1808 ADC remains a future physical input layer.

Future work:

- confirm safe electrical levels for FPGA pins,
- confirm clocking and master/slave mode,
- implement or verify a stable I2S RX block,
- capture stereo L/R samples into frame/block buffers,
- test with a known analog input signal,
- verify DATA, BCLK, LRCK, and MCLK with an oscilloscope or logic analyzer.

The first hardware input test should be a plain BYPASS path, not FFT.

## Future Output Layer: PCM5102A DAC

The PCM5102A DAC remains a future physical output layer.

Future work:

- confirm I2S format and timing,
- confirm BCLK/LRCK frequencies,
- drive known test samples before using FFT/IFFT output,
- verify analog L/R outputs on an oscilloscope,
- keep the FPGA pin voltage within safe limits.

## Real I2S Pins

Existing pin notes and constraint files are retained as reference material. They
should not be treated as active for the FPGA-only FFT/IFFT stage.

Future physical I2S work should confirm:

- clock pin,
- PCM5102A DIN/LRCK/BCLK,
- PCM1808 DATA/BCLK/LRCK/MCLK,
- optional button inputs,
- optional UART TX pin,
- any board LEDs used for diagnostics.

Do not guess pins when creating a hardware top. Each top must match its active
constraint file.

## Current FPGA-Only Limitations

The current FPGA-only direction intentionally does not provide:

- physical PCM1808 capture,
- physical PCM5102A playback,
- real-time continuous audio streaming,
- oscilloscope-verified analog output,
- windowing,
- overlap-add,
- final FFT/IFFT IP integration.

The goal is to verify the block-level FFT/IFFT architecture first.

## Future Streaming Audio

After the FFT/IFFT block path is verified, the project can add continuous audio
streaming. That will require:

- input sample buffering,
- output sample buffering,
- frame scheduling,
- latency accounting,
- underrun/overrun detection,
- clock-domain and handshake review if external audio clocks are used.

## Windowing and Overlap-Add

Windowing and overlap-add are future DSP features. They should be added only
after the basic block path works:

```text
input block -> FFT -> spectral modification -> IFFT -> output block
```

Planned additions:

- window function selection,
- block overlap,
- overlap-add reconstruction,
- gain normalization,
- additional verification tests for reconstruction error.

## Oscilloscope Tests

Oscilloscope tests belong to the later physical hardware stage.

Suggested order:

1. FPGA-only simulation reports.
2. Tang Nano self-test LED/UART diagnostics.
3. PCM5102A output with a known generated signal.
4. PCM1808 input capture.
5. PCM1808 -> FPGA -> PCM5102A BYPASS.
6. FFT/IFFT pipeline inserted into the verified hardware path.

## Existing Hardware Files To Keep For Reference

These files may be useful when the hardware layer returns:

- `rtl/audio/i2s_tx.v`
- `rtl/audio/tone_gen.v`
- `rtl/top/tang_audio_top.v`
- `rtl/top/tang_audio_pcm5102a_test_top.v`
- `rtl/top/tang_audio_pcm5102a_scope_test_top.v`
- `rtl/top/tang_audio_buttons_volume_test_top.v`

Associated Gowin constraint files may also be useful:

- `gowin_impl/tang_audio_hw/pcm5102a_test.cst`
- `gowin_impl/tang_audio_hw/buttons_volume_test.cst`
- `gowin_impl/tang_audio_hw/full_button_eq_future.cst`

These should be treated as legacy/reference material until the project returns
to physical ADC/DAC integration.
