# Utrzymanie i deployment

## Workflow GitHub

Główna gałąź robocza projektu:

```text
fpga-only-fft-console
```

Zmiany należy robić w osobnych branchach i zgłaszać przez pull request. Nie
należy commitować bezpośrednio do `fpga-only-fft-console`.

Typowy flow:

```text
git fetch origin
git switch -c codex/nazwa-zmiany origin/fpga-only-fft-console
... praca ...
python tools/run_all_tests.py
git diff --check
git add konkretne-pliki
git commit -m "Krótki opis"
git push -u origin codex/nazwa-zmiany
```

## Testy przed PR

Minimum:

```powershell
python tools/run_all_tests.py
python tools/spectrum_lab_uart_client.py --mock
git diff --check
```

Dla zmian PC-side warto dodać:

```powershell
python tools/test_spectrum_lab_model.py
python tools/test_spectrum_lab_hardware_backend.py
```

## Budowanie bitstreamu

1. Otwórz projekt Gowin w `gowin_impl/tang_audio_hw/`.
2. Ustaw właściwy top.
3. Sprawdź constraints.
4. Uruchom `Synthesize`.
5. Uruchom `Place & Route`.
6. Uruchom `Generate Bitstream`.
7. Wgraj przez `SRAM Program`.

## Synchronizacja `rtl/` i `gowin_impl/`

`rtl/` jest głównym źródłem prawdy. `gowin_impl/` może zawierać kopie plików RTL
używane przez projekt Gowin. Jeśli zmiana RTL ma być budowana w Gowin, trzeba
świadomie zsynchronizować odpowiednie kopie i opisać to w PR.

Nie należy automatycznie nadpisywać działającego setupu hardware bez testu.

## Dodawanie nowych funkcji

Zalecana kolejność:

1. model Python lub mały moduł RTL,
2. test jednostkowy,
3. integracja,
4. test systemowy,
5. dokumentacja,
6. dopiero potem hardware bring-up.

Przykłady przyszłych kierunków:

- fizyczne I2S audio input/output,
- lepsze mapowanie pasm,
- szerszy format gainu,
- szybszy interfejs niż UART,
- ewentualny adapter do Gowin FFT IP.

## Reprodukcja testów sprzętowych

1. Zbuduj bitstream dla `tang_cpu_owned_frame_uart_top`.
2. Wgraj do Tang Nano przez SRAM Program.
3. Sprawdź port COM.
4. Uruchom:

```powershell
python tools/spectrum_lab_uart_client.py --port COM6
```

5. Uruchom GUI i wybierz `Serial FPGA backend`.
6. Wyeksportuj CSV dla ważnych przypadków testowych.
7. Porównaj z modelem fixed-point.
