# `rtl/dsp/`

Bloki DSP i fixed-point.

Najważniejsze pliki aktualnego toru:

- `sample_block_buffer.v` - zbieranie ramek próbek.
- `fft_radix2_core.v` - sekwencyjny rdzeń FFT/IFFT radix-2.
- `fft_accel_wrapper.v` - wrapper FFT.
- `ifft_accel_wrapper.v` - wrapper IFFT.
- `fft_ifft_pipeline.v` - integracja FFT -> spectral gain -> IFFT.
- `spectral_gain_select.v` - wybór pasma `BASS/MID/TREBLE`.
- `spectral_processor.v` - mnożenie binów przez gain Q2.14.
- `complex_mult.v`, `fft_twiddle_rom.v`, `fft_bit_reverse.v`,
  `fft_butterfly_addr_gen.v` - bloki pomocnicze FFT.

Starsze pliki `eq3band_*`, `volume_*` i `modulation_core.v` pozostają jako
osobne moduły demonstracyjne.
