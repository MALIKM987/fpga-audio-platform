# Demonstracja akceleratora sterowanego rejestrami

## Cel

Ten dokument opisuje demonstrację konsolową modułu `fft_accelerator_core`.
Celem nie jest jeszcze prawdziwa FFT/IFFT, tylko pokazanie metody sterowania
akceleratorem przez prosty bank rejestrów:

```text
write CONTROL_REG -> start -> processing -> read STATUS_REG
```

To jest etap laboratoryjny, który potwierdza, że część sterująca potrafi
zapisać parametry, uruchomić model pipeline i odczytać wynik statusu.

## Mapa rejestrów

Adresy są podawane jako offsety w prostym interfejsie rejestrowym testbencha:

```text
0x0 CONTROL_REG
0x1 STATUS_REG
0x2 BASS_GAIN_REG
0x3 MID_GAIN_REG
0x4 TREBLE_GAIN_REG
0x5 TEST_SELECT_REG
0x6 DEBUG_REG
```

Najważniejsze pola:

- `CONTROL_REG[0]` - `start`
- `CONTROL_REG[2]` - `spectral_enable`
- `CONTROL_REG[3]` - `clear_status`
- `STATUS_REG[0]` - `busy`
- `STATUS_REG[1]` - `done`
- `STATUS_REG[2]` - `overflow`
- `STATUS_REG[3]` - `error`

Gainy są zapisywane w formacie Q2.14:

- `24576` = 1.50
- `16384` = 1.00
- `12288` = 0.75

## Przebieg demonstracji

Test `fft_accelerator_core_tb` wykonuje następującą sekwencję:

1. Resetuje moduł i sprawdza domyślny stan `busy`, `done`, `overflow`.
2. Odczytuje domyślne wartości gainów.
3. Zapisuje `BASS_GAIN_REG`, `MID_GAIN_REG` i `TREBLE_GAIN_REG`.
4. Zapisuje `CONTROL_REG` z bitem `start`.
5. Podaje 256 próbek wejściowych do modelu pipeline.
6. Czeka na zakończenie przetwarzania.
7. Odczytuje `STATUS_REG` i sprawdza `done=1`, `overflow=0`, `error=0`.
8. Czyści status przez `CONTROL_REG[3]`.

Raport z symulacji pokazuje te kroki w formie czytelnej dla konsoli, np.:

```text
=== REGISTER CONTROLLED FFT ACCELERATOR DEMO ===
MODE=MODEL_PASSTHROUGH
NOTE=FFT and IFFT wrappers are currently passthrough models.

REGISTER MAP:
0x0 CONTROL_REG
0x1 STATUS_REG
...

CONFIGURATION:
WRITE BASS_GAIN_REG=24576    // 1.50 Q2.14
WRITE MID_GAIN_REG=16384     // 1.00 Q2.14
WRITE TREBLE_GAIN_REG=12288  // 0.75 Q2.14
WRITE CONTROL_REG start=1 spectral_enable=1 bypass=0

PROCESS:
collect_samples=256 PASS
pipeline_done=1 PASS
overflow=0 PASS

STATUS_REG:
busy=0
done=1
overflow=0
error=0

SUMMARY:
STATUS=PASS
```

## Podobieństwo do laboratoriów CORDIC/AXI

Podejście jest podobne do typowej struktury laboratoryjnej z rejestrami
`slv_reg`, `control` i `status`: procesor albo testbench zapisuje rejestry
konfiguracyjne, ustawia bit startu, czeka na zakończenie i odczytuje status.

W tej wersji nie ma jeszcze konkretnej magistrali, np. AXI-Lite. Bank rejestrów
jest celowo prosty, aby najpierw sprawdzić semantykę sterowania akceleratorem.
Później można go podłączyć do mostka UART, soft CPU albo magistrali AXI-like.

## Ograniczenia obecnej wersji

- `fft_accel_wrapper` jest modelem passthrough, a nie prawdziwą FFT.
- `ifft_accel_wrapper` jest modelem passthrough, a nie prawdziwą IFFT.
- Nie ma jeszcze AXI-Lite.
- Nie ma jeszcze UART do sterowania rejestrami.
- Nie ma jeszcze fizycznego I2S.
- Nie ma jeszcze Gowin FFT IP.

## Uruchamianie

Pełny zestaw testów uruchamia się jedną komendą:

```powershell
python tools/run_all_tests.py
```

Reprezentatywny test dla tej demonstracji to:

```text
fft_accelerator_core_tb
```
