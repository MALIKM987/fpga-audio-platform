# `rtl/control/`

Rejestry sterujące i wrappery MMIO.

Najważniejsze pliki:

- `fft_mmio_regs.v` - rejestry `CONTROL`, `STATUS`, `MODE`, gainy i pamięci
  próbek.
- `fft_accelerator_mmio.v` - wrapper łączący rejestry z `fft_ifft_pipeline`.
- `fft_control_regs.v` i `fft_accelerator_core.v` - wcześniejszy wariant
  rejestrowego sterowania używany w testach/demonstracji.
- `audio_param_regs.v`, `button_control_top.v` - starsze moduły sterowania audio.

Aktualny flow CPU używa `fft_accelerator_mmio.v`.
