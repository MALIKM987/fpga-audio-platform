# `rtl/cpu/`

Własny mini CPU soft-core.

Najważniejsze pliki:

- `mini_cpu_core.v` - rdzeń CPU z fetch/decode/execute.
- `mini_cpu_defs.vh` - opkody i identyfikatory programów.
- `mini_cpu_program_rom.v` - programy ROM, w tym service loop dla UART frame.
- `mini_cpu_uart_frame_system.v` - integracja CPU z mailboxem UART i
  `fft_accelerator_mmio`.
- `mini_cpu_fft_system.v` - wcześniejszy system impulsowy CPU -> FFT.
- `mini_cpu_system.v` - prosty system testowy CPU/MMIO.

CPU jest właścicielem sterowania akceleratorem FFT/IFFT. UART backend zapisuje
mailbox, ale nie steruje bezpośrednio DSP.
