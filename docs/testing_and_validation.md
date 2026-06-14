# Testowanie i walidacja

Projekt ma testy Python, testy Verilog i walidację sprzętową na Tang Nano 20K.

## Główny runner

```powershell
python tools/run_all_tests.py
```

Runner uruchamia:

- modele referencyjne Python,
- generowanie wektorów testowych,
- testy Verilog przez Icarus Verilog, jeśli `iverilog` i `vvp` są w PATH,
- porównania wyników RTL z modelem Python.

## Testy PC

```powershell
python tools/test_spectrum_lab_model.py
python tools/test_spectrum_lab_hardware_backend.py
python tools/test_fpga_fixed_point_reference_calibration.py
python tools/spectrum_lab_uart_client.py --mock
```

## Testy Verilog

Testbenche znajdują się w `tb/`. Obejmują:

- UART RX/TX,
- parser i formatter pakietów,
- frame mailbox,
- mini CPU,
- MMIO akceleratora,
- FFT/IFFT pipeline,
- topy Tang Nano,
- regresje CPU-owned UART frame flow.

## GitHub Actions

Workflow GitHub Actions uruchamia testy dla branchy i pull requestów do
`fpga-only-fft-console`. Dzięki temu dokumentacja i kod są sprawdzane w
jednolitym środowisku Linux.

## Walidacja sprzętowa

Potwierdzono fizyczny flow:

```text
PC -> UART -> Tang Nano -> mini CPU -> FFT/IFFT accelerator -> UART -> PC
```

Testy CSV i porównania fixed-point potwierdziły, że realny FPGA zgadza się z
modelem fixed-point przy aktualnych limitach Q2.14 i mapowaniu pasm.

## Raport bug/fix

| Kod / obszar | Objaw | Przyczyna | Naprawa | Status |
| --- | --- | --- | --- | --- |
| IFFT output | wynik wyglądał jak int8/high-byte loss | błędne skalowanie i zawężanie | poprawione skalowanie IFFT | zamknięte |
| Dynamic range | stary zakres około `±127` | zbyt wąskie ścieżki pośrednie | szersza ścieżka fixed-point i saturacja | zamknięte |
| Gain > 2 | rozbieżność local float vs FPGA | Q2.14 nie reprezentuje gainu > 1.99994 | dokumentacja, ostrzeżenia GUI, model fixed-point | oczekiwane |
| Same band | dwie modyfikacje dają jeden gain | hardware ma BASS/MID/TREBLE | zasada "last one wins" i ostrzeżenie GUI | oczekiwane |
| GUI readability | trudne porównanie wykresów | mało opisów i status jednoliniowy | etykiety, presety, panel Q2.14, status wieloliniowy | zamknięte |

## Co potwierdzono

- Komunikację UART i framing.
- Dwa kolejne frame transactions bez resetu.
- Mini CPU jako właściciela akceleratora.
- START/DONE przez MMIO.
- Wybrane próbki wyniku dla impulsu i ramek testowych.
- Saturację gainu Q2.14.
- Zgodność realnego FPGA z modelem fixed-point dla przebadanych przypadków.
