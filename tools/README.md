# `tools/`

Narzędzia PC, modele referencyjne i testy Python.

Najważniejsze pliki:

- `spectrum_lab_app.py` - GUI Tkinter.
- `spectrum_lab_model.py` - lokalny model float.
- `spectrum_lab_hardware_backend.py` - facade dla mock/serial FPGA backend.
- `spectrum_lab_presets.py` - presety GUI.
- `spectrum_lab_uart_client.py` - konsolowy klient pełnych ramek UART.
- `uart_frame_protocol.py` - helpery protokołu ramek.
- `uart_transport.py` - transport mock i serial.
- `fft_reference_model.py`, `fft_radix2_fixed_model.py` - modele
  referencyjne.
- `compare_float_fixed_fpga.py`, `analyze_hardware_csv.py` - analiza CSV.
- `run_all_tests.py` - główny runner testów.

`pyserial` jest potrzebny tylko do realnego portu serial. Testy mock i modele
nie wymagają pyserial.
