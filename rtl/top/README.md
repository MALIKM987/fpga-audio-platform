# `rtl/top/`

Top-level moduły FPGA.

Najważniejszy aktualny top:

```text
tang_cpu_owned_frame_uart_top.v
```

Łączy UART RX/TX, protokół ramek, mailbox, mini CPU i akcelerator FFT/IFFT.

Inne topy pozostają w repo jako demonstratory lub testy wcześniejszych warstw:

- `tang_uart_cpu_fft_console_top.v` - legacy binarna konsola `A5 01 5A`.
- `tang_fft_ifft_selftest_top.v` - hardware self-test FFT/IFFT.
- topy `tang_audio_*` - starsze warianty audio/test-tone/EQ.

Nie należy usuwać starszych topów bez osobnej decyzji, bo są przydatne do
regresji i porównania.
