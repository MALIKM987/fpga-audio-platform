# Project milestone summary — FPGA Audio Platform FFT/IFFT Accelerator

## 1. Cel aktualnej wersji

Aktualna wersja projektu jest etapem FPGA-only akceleratora FFT/IFFT dla bloków
audio w formacie I2S-like. Celem tego etapu jest sprawdzenie architektury,
sterowania i przepływu danych bez zależności od fizycznego ADC, DAC, I2S ani
top-levelu pod płytkę.

Projekt jest obecnie weryfikowalny przez:

- symulacje testbenchy Verilog,
- raporty konsolowe PASS/FAIL,
- pliki CSV z wektorami testowymi,
- Pythonowy model referencyjny,
- GitHub Actions uruchamiające runner testów.

To nie jest jeszcze gotowy tor audio na Tang Nano 20K. Jest to uporządkowana
infrastruktura pod przyszłą integrację prawdziwego FFT/IFFT.

## 2. Aktualna gałąź projektu

Aktualna gałąź robocza dla tego kierunku:

```text
fpga-only-fft-console
```

## 3. Główna architektura

Główny przepływ danych modelowanego pipeline:

```text
sample input
    -> sample_block_buffer
    -> fft_accel_wrapper
    -> spectral_processor
    -> ifft_accel_wrapper
    -> output sample
```

Warstwa sterowania:

```text
fft_control_regs
    -> fft_accelerator_core
    -> fft_ifft_pipeline
```

`fft_accelerator_core` łączy prosty bank rejestrów z pipeline DSP. Testbench
może zapisać gainy, ustawić start w `CONTROL_REG`, podać ramkę próbek, a potem
odczytać status zakończenia.

## 4. Moduły RTL i ich rola

- `sample_block_buffer.v` - zbiera ramkę próbek, obecnie `FFT_SIZE = 256`, i
  wypuszcza ją w kolejności indeksów do dalszego przetwarzania.
- `spectral_gain_select.v` - wybiera pasmo `BASS`, `MID` albo `TREBLE` na
  podstawie efektywnego indeksu binu.
- `spectral_processor.v` - mnoży część rzeczywistą i urojoną próbki/binów przez
  gain Q2.14 wybrany dla danego pasma.
- `fft_accel_wrapper.v` - obecnie model passthrough interfejsu przyszłej FFT.
- `ifft_accel_wrapper.v` - obecnie model passthrough interfejsu przyszłej IFFT.
- `fft_ifft_pipeline.v` - integruje bufor ramki, wrapper FFT, spectral processor
  i wrapper IFFT w jeden model przepływu danych.
- `fft_control_regs.v` - prosty bank rejestrów `CONTROL`, `STATUS`, gainów i
  rejestrów diagnostycznych.
- `fft_accelerator_core.v` - moduł nadrzędny łączący bank rejestrów z
  `fft_ifft_pipeline`.

## 5. Sterowanie rejestrami

Aktualny interfejs rejestrowy jest prosty i niezależny od konkretnej magistrali.
Nie jest jeszcze AXI-Lite, ale odpowiada metodologii `control/status` znanej z
laboratoriów akceleratorów sprzętowych.

Mapa rejestrów:

- `CONTROL_REG` - start, reset/clear status i bity sterujące.
- `STATUS_REG` - busy, done, overflow, error.
- `BASS_GAIN_REG` - gain pasma niskiego w Q2.14.
- `MID_GAIN_REG` - gain pasma środkowego w Q2.14.
- `TREBLE_GAIN_REG` - gain pasma wysokiego w Q2.14.
- `TEST_SELECT_REG` - wybór trybu testowego/diagnostycznego.
- `DEBUG_REG` - rejestr pomocniczy do obserwacji stanu.

Typowy scenariusz:

1. Testbench albo przyszły kontroler zapisuje gainy.
2. Testbench ustawia bit startu w `CONTROL_REG`.
3. `fft_accelerator_core` uruchamia przetwarzanie ramki.
4. Po zakończeniu `STATUS_REG` pokazuje `done=1`, a `busy=0`.

## 6. Model referencyjny FFT/IFFT

Pythonowy model referencyjny znajduje się w:

```text
tools/fft_reference_model.py
```

Model wykonuje:

```text
DFT -> spectral gain -> IDFT
```

Właściwości modelu:

- działa bez `numpy` i `scipy`,
- używa czystego Pythona 3,
- stosuje gainy Q2.14,
- zaokrągla i saturuje wynik do signed 16-bit,
- służy jako golden model dla przyszłego Gowin FFT IP albo własnego RTL FFT/IFFT.

Ten model nie oznacza jeszcze, że RTL wykonuje prawdziwą FFT/IFFT. To punkt
odniesienia matematycznego na następny etap.

## 7. Wektory testowe i porównanie RTL

Wektory testowe generuje:

```text
tools/generate_fft_test_vectors.py
```

Porównanie wyjścia pipeline wykonuje:

```text
tools/compare_fft_pipeline_outputs.py
```

Projekt rozróżnia dwa modele odniesienia:

- `rtl_passthrough_model` - model aktualnego zachowania RTL.
- `math_reference_model` - pełny matematyczny model `DFT -> spectral gain -> IDFT`.

Obecny RTL jest porównywany z `rtl_passthrough_model`, ponieważ
`fft_accel_wrapper.v` i `ifft_accel_wrapper.v` są nadal modelami passthrough.
To jest oczekiwane i poprawne na tym etapie. `math_reference_model` będzie
użyty później do sprawdzania prawdziwego FFT/IFFT, np. po integracji Gowin FFT
IP.

## 8. Testy i GitHub Actions

Główny runner testów:

```text
tools/run_all_tests.py
```

Uruchomienie:

```powershell
python tools/run_all_tests.py
```

Runner wykonuje kolejno:

1. testy Python modelu referencyjnego,
2. generowanie wektorów CSV,
3. testy Verilog, jeśli dostępne są `iverilog` i `vvp`,
4. porównanie CSV wyjścia RTL z `rtl_passthrough_model`, jeśli powstał plik
   wyjściowy z symulacji.

`STATUS=PASS` oznacza, że dostępne testy przeszły. Lokalnie, jeśli nie ma
`iverilog` albo `vvp`, część Verilog i porównanie RTL mogą zgłosić
`STATUS=SKIPPED`. Nie oznacza to błędu projektu; GitHub Actions uruchamiają
testy w środowisku z narzędziami Verilog.

## 9. Co jest już zaimplementowane

Zaimplementowane elementy obecnego etapu:

- bank rejestrów `fft_control_regs`,
- moduł nadrzędny `fft_accelerator_core`,
- model integracyjny `fft_ifft_pipeline`,
- `sample_block_buffer`,
- `spectral_gain_select`,
- `spectral_processor`,
- wrappery FFT/IFFT jako passthrough modele interfejsu,
- testbenche Verilog,
- Pythonowy golden model FFT/IFFT,
- generator wektorów testowych CSV,
- porównanie wyjścia RTL z `rtl_passthrough_model`,
- GitHub Actions,
- dokumentacja architektury, sterowania rejestrami i wektorów testowych.

## 10. Co jest jeszcze modelem

Na tym etapie trzeba wyraźnie rozdzielić infrastrukturę od właściwego algorytmu:

- `fft_accel_wrapper.v` jest passthrough.
- `ifft_accel_wrapper.v` jest passthrough.
- `fft_ifft_pipeline.v` sprawdza przepływ danych, indeksy, `valid/done`,
  sterowanie i gainy, ale nie wykonuje jeszcze prawdziwej FFT/IFFT w RTL.

To jest świadomy etap pośredni. Dzięki niemu można osobno zweryfikować
sterowanie i testy przed podłączeniem realnego bloku FFT/IFFT.

## 11. TODO / kolejne etapy

Logiczne następne kroki:

1. Przygotować plan integracji Gowin FFT IP.
2. Zastąpić passthrough wrappery prawdziwym FFT/IFFT.
3. Porównać wyniki Gowin IP albo RTL FFT/IFFT z `math_reference_model`.
4. Dodać UART bridge albo inny prosty interfejs sterowania rejestrami.
5. Wrócić do fizycznego I2S.
6. Przygotować top-level Tang Nano dla nowego pipeline.
7. Wygenerować bitstream i przygotować demonstrację sprzętową.

## 12. Wniosek

Projekt ma już przygotowaną architekturę akceleratora, warstwę sterowania,
pipeline danych, testbenche, modele referencyjne, wektory testowe i automatyczną
walidację. Najbliższy logiczny krok to integracja prawdziwego bloku FFT/IFFT i
porównanie jego wyników z Pythonowym `math_reference_model`.
