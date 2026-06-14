# `rtl/`

Główne źródła RTL projektu. Ten katalog jest źródłem prawdy dla logiki FPGA.

## Podkatalogi

- `top/` - top-level moduły dla Tang Nano i starszych demonstratorów.
- `cpu/` - własny mini CPU soft-core i program ROM.
- `uart/` - UART RX/TX, parser/formatter ramek i mailbox.
- `control/` - rejestry MMIO i wrappery sterujące akceleratorem.
- `dsp/` - FFT/IFFT, spectral processor, fixed-point DSP.
- `audio/` - starsze moduły testowego I2S/audio.
- `debug/` - moduły self-test/debug z wcześniejszych etapów.
- `common/` - małe helpery typu synchronizacja i przyciski.

Jeżeli plik RTL jest potrzebny do budowy w Gowin, jego kopia w `gowin_impl/`
musi być zsynchronizowana świadomie.
