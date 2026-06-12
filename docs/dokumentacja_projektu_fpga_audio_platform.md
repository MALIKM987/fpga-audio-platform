# Dokumentacja projektu FPGA Audio Platform

## 1. Informacje podstawowe

| Pole | Wartość |
| --- | --- |
| Nazwa projektu | FPGA Audio Platform |
| Platforma | Tang Nano 20K / Gowin FPGA |
| Główny kierunek | Akcelerator FFT/IFFT w RTL dla ramek audio |
| Aktualny status | Wersja przygotowana do lokalnych testów sprzętowych |
| Dokument | Markdown gotowy do późniejszego eksportu do DOCX/PDF |

Ten dokument opisuje aktualny stan projektu `fpga-audio-platform` po
przygotowaniu własnego toru FFT/IFFT w RTL. Projekt jest gotowy do lokalnej
próby syntezy w Gowin EDA i do pierwszych testów na płytce Tang Nano, ale w tym
PR nie wykonano jeszcze realnego testu sprzętowego.

## 2. Cel projektu

Celem projektu jest zbudowanie platformy audio na FPGA, w której dane audio są
przetwarzane blokowo przez tor FFT/IFFT. Akcelerator ma przyjmować ramkę próbek,
wykonać transformację do dziedziny częstotliwości, zmodyfikować wybrane pasma
i wrócić do dziedziny czasu.

Własny rdzeń FFT/IFFT został wybrany jako główny wariant edukacyjny, ponieważ
pozwala pokazać:

- algorytm radix-2,
- arytmetykę stałoprzecinkową Q2.14,
- bit-reversal,
- twiddle ROM,
- mnożenie zespolone,
- sterowanie FSMD,
- porównanie RTL z modelem bit-exact w Pythonie.

Gowin FFT IP pozostaje możliwym wariantem porównawczym albo przyszłą
optymalizacją. Nie jest jednak podstawą obecnej wersji.

## 3. Wymagania i założenia

Najważniejsze założenia techniczne:

- `FFT_SIZE = 256`,
- dane signed 16-bit,
- współczynniki gain w formacie Q2.14,
- wartość `16384` oznacza `1.0`,
- przetwarzanie ramkowe, a nie ciągły streaming audio,
- sterowanie przez sygnały `start`, `busy`, `done`, `valid`,
- testowalność w symulacji i w GitHub Actions,
- przygotowanie do późniejszego uruchomienia w Gowin EDA na Tang Nano.

Obecny projekt nie deklaruje jeszcze wyników syntezy, wykorzystania zasobów ani
timingu. Te dane muszą zostać zebrane lokalnie z raportów Gowin.

## 4. Architektura systemu

Aktualny tor logiczny:

```text
sample input
    -> sample_block_buffer
    -> fft_accel_wrapper
    -> spectral_processor
    -> ifft_accel_wrapper
    -> sample output
```

Wrapper FFT i wrapper IFFT korzystają z tego samego rdzenia:

```text
fft_accel_wrapper  -> fft_radix2_core(inverse=0)
ifft_accel_wrapper -> fft_radix2_core(inverse=1)
```

Kod produkcyjny RTL znajduje się w `rtl/`. Testbenche są w `tb/`, a narzędzia
Python do generowania wektorów i porównywania wyników są w `tools/`.

## 5. Rdzeń `fft_radix2_core.v`

`rtl/dsp/fft_radix2_core.v` jest sekwencyjnym rdzeniem radix-2 dla `N = 256`.
Rdzeń pracuje jako FSMD:

```text
IDLE
 -> LOAD
 -> BUTTERFLY_READ
 -> TWIDDLE_READ
 -> COMPLEX_MULT
 -> BUTTERFLY_WRITEBACK_A
 -> BUTTERFLY_WRITEBACK_B
 -> BUTTERFLY_ADVANCE
 -> OUTPUT
 -> DONE
```

Najważniejsze elementy:

- wejście jest zapisywane do pamięci z użyciem bit-reversal,
- transformacja ma 8 etapów,
- każdy etap ma 128 operacji butterfly,
- twiddle factors pochodzą z `fft_twiddle_rom.v`,
- mnożenie zespolone wykonuje `complex_mult.v`,
- wyniki są zapisywane in-place do pamięci `real_mem` i `imag_mem`,
- `inverse=0` oznacza FFT,
- `inverse=1` oznacza IFFT.

## 6. Format Q2.14

Projekt używa arytmetyki stałoprzecinkowej Q2.14 dla współczynników i części
operacji DSP. Interpretacja:

| Wartość całkowita | Znaczenie |
| --- | --- |
| `16384` | `1.0` |
| `8192` | `0.5` |
| `24576` | `1.5` |
| `-16384` | `-1.0` |

Mnożenie zespolone wykonuje operacje:

```text
real = ar * br - ai * bi
imag = ar * bi + ai * br
```

Po mnożeniu wynik jest przesuwany o 14 bitów, aby wrócić do skali Q2.14.
Obecna wersja stosuje wrap/truncation przy zapisie do signed 16-bit. Saturacja
nie jest jeszcze dodana.

## 7. Normalizacja IFFT

Matematyczna IFFT wymaga dzielenia przez `N`. Dla obecnego rozmiaru:

```text
N = 256
1 / N = 1 / 256
```

W RTL normalizacja została dodana w stanie `OUTPUT` rdzenia
`fft_radix2_core.v`. Dla trybu `inverse=1` wynik jest dzielony przez 256 przez
arytmetyczne przesunięcie w prawo:

```verilog
real_out <= raw_real >>> 8;
imag_out <= raw_imag >>> 8;
```

Forward FFT nie jest normalizowana. Po dodaniu normalizacji tor
`FFT -> IFFT` odtwarza małoamplitudowe sygnały z błędem wynikającym z
kwantyzacji i obcięć fixed-point. Testy dopuszczają małą tolerancję LSB dla
takich przypadków.

## 8. Wrappery FFT/IFFT

`fft_accel_wrapper.v` i `ifft_accel_wrapper.v` zachowują stabilny interfejs
używany przez pipeline. Wcześniejsze modele passthrough zostały zastąpione
cienkimi wrapperami:

- `fft_accel_wrapper.v` instancjonuje `fft_radix2_core.v` z `inverse=0`,
- `ifft_accel_wrapper.v` instancjonuje `fft_radix2_core.v` z `inverse=1`.

Dzięki temu pozostałe moduły nie muszą znać szczegółów rdzenia. Wrappery są
punktem integracji dla przyszłych optymalizacji lub ewentualnego porównania
z Gowin FFT IP.

## 9. Pipeline przetwarzania

`rtl/dsp/fft_ifft_pipeline.v` łączy:

```text
sample_block_buffer
    -> fft_accel_wrapper
    -> spectral_processor
    -> ifft_accel_wrapper
```

`sample_block_buffer` zbiera ramkę 256 próbek. `spectral_processor` wybiera
pasmo na podstawie indeksu binu i mnoży część rzeczywistą oraz urojoną przez
gain Q2.14:

- bass: `effective_bin <= 1`,
- mid: `2 <= effective_bin <= 21`,
- treble: `22 <= effective_bin <= 127`.

Obecny pipeline jest funkcjonalnym modelem blokowego przetwarzania FFT/IFFT.
Nie jest jeszcze pełnym systemem audio z fizycznym I2S, buforowaniem
strumieniowym, okienkowaniem ani overlap-add.

## 10. Model bit-exact w Pythonie

`tools/fft_radix2_fixed_model.py` odwzorowuje zachowanie RTL:

- bit-reversal,
- twiddle ROM Q2.14,
- `complex_mult`,
- adresację butterfly,
- wrap/truncation do signed 16-bit,
- normalizację IFFT przez przesunięcie o 8 bitów.

Model jest używany do generowania oczekiwanych wyników dla testbenchy Verilog.
To nie jest idealny model floating-point. Jest to model bit-exact aktualnego
RTL, dlatego jest właściwym kryterium PASS/FAIL dla obecnej wersji.

## 11. Wektory testowe

Generator `tools/generate_fft_radix2_core_vectors.py` tworzy pliki:

- `tb/generated/fft_radix2_core_zero_frame.mem`,
- `tb/generated/fft_radix2_core_impulse0.mem`,
- `tb/generated/fft_radix2_core_impulse1.mem`,
- `tb/generated/fft_radix2_core_two_sample.mem`,
- `tb/generated/ifft_radix2_core_zero_frame.mem`,
- `tb/generated/ifft_radix2_core_impulse0.mem`,
- `tb/generated/ifft_radix2_core_impulse1.mem`,
- `tb/generated/ifft_radix2_core_two_sample.mem`.

Każda linia ma format:

```text
input_real input_imag expected_real expected_imag
```

Generator `tools/generate_fft_test_vectors.py` tworzy dodatkowe CSV dla testów
pipeline. Oczekiwane wyniki odpowiadają aktualnemu torowi:

```text
FFT core -> spectral gain -> normalized IFFT core
```

## 12. Testy Verilog

Najważniejsze testbenche:

| Testbench | Zakres |
| --- | --- |
| `tb/fft_radix2_core_tb.v` | porównanie rdzenia z wektorami bit-exact |
| `tb/fft_accel_wrapper_tb.v` | wrapper FFT z `inverse=0` |
| `tb/ifft_accel_wrapper_tb.v` | wrapper IFFT z `inverse=1` i normalizacją |
| `tb/fft_ifft_pipeline_tb.v` | integracja pipeline |
| `tb/fft_accelerator_core_tb.v` | demonstracja sterowania rejestrowego |

Testy wypisują czytelny raport i kończą się linią:

```text
STATUS=PASS
```

albo:

```text
STATUS=FAIL errors=<count>
```

GitHub Actions uruchamia `python tools/run_all_tests.py` dla pull requestów do
brancha `fpga-only-fft-console`.

## 13. Narzędzia testowe

Podstawowy runner:

```powershell
python tools/run_all_tests.py
```

Runner wykonuje:

- testy modelu referencyjnego,
- testy modelu bit-exact radix-2,
- generowanie wektorów,
- testbenche Verilog przez `iverilog` i `vvp`,
- porównanie CSV wyjścia pipeline, jeśli plik wyjściowy istnieje.

Jeżeli lokalnie brakuje `iverilog` albo `vvp`, runner wypisuje
`STATUS=SKIPPED` dla symulacji Verilog. Nie oznacza to błędu RTL; pełne
symulacje Verilog wykonuje GitHub Actions.

## 14. Integracja z Tang Nano / Gowin

Kod RTL jest gotowy do pierwszej lokalnej próby syntezy, ale obecny PR nie
zawiera potwierdzonego bitstreamu ani raportu zasobów. Użytkownik musi lokalnie
sprawdzić projekt w Gowin EDA.

Istotne pliki RTL dla toru FFT/IFFT:

- `rtl/dsp/sample_block_buffer.v`,
- `rtl/dsp/fft_bit_reverse.v`,
- `rtl/dsp/fft_butterfly_addr_gen.v`,
- `rtl/dsp/fft_twiddle_rom.v`,
- `rtl/dsp/complex_mult.v`,
- `rtl/dsp/fft_radix2_core.v`,
- `rtl/dsp/fft_accel_wrapper.v`,
- `rtl/dsp/spectral_gain_select.v`,
- `rtl/dsp/spectral_processor.v`,
- `rtl/dsp/ifft_accel_wrapper.v`,
- `rtl/dsp/fft_ifft_pipeline.v`,
- `rtl/control/fft_control_regs.v`,
- `rtl/control/fft_accelerator_core.v`.

Testbenchy z `tb/` nie należy dodawać jako plików syntezowalnych.

## 15. Procedura testów sprzętowych

Szczegółowa lista kontrolna jest w:

```text
docs/tang_nano_hardware_test_checklist.md
```

Skrót procedury:

1. Uruchomić lokalnie `python tools/run_all_tests.py`.
2. Otworzyć projekt w Gowin EDA.
3. Dodać wymagane pliki RTL do wariantu testowego.
4. Uruchomić Synthesis.
5. Uruchomić Place & Route.
6. Wygenerować bitstream.
7. Zaprogramować Tang Nano.
8. Zebrać raporty zasobów, timingów i ostrzeżeń.
9. Wkleić raporty z powrotem do Codex/ChatGPT do analizy.

## 16. Ograniczenia obecnej wersji

Znane ograniczenia:

- brak saturacji w butterfly i spectral gain,
- możliwy wraparound przy większych amplitudach,
- sekwencyjna architektura, a nie szybki pipeline równoległy,
- konieczność sprawdzenia inferencji pamięci RAM/BRAM w Gowin,
- konieczność sprawdzenia użycia DSP dla `complex_mult.v`,
- brak potwierdzonego Fmax,
- brak potwierdzonego użycia zasobów,
- brak realnego testu na Tang Nano w tym PR,
- brak fizycznego I2S dla nowego pipeline,
- brak UART bridge do sterowania rejestrowego.

## 17. Możliwe dalsze prace

Najważniejsze kolejne kroki:

- dodać saturację albo kontrolowane skalowanie stage-by-stage,
- zoptymalizować pamięci i mnożniki pod Gowin,
- porównać własny rdzeń z Gowin FFT IP,
- dodać UART/self-test dla nowego pipeline,
- przygotować top-level Tang Nano dla testu akceleratora,
- zebrać realne raporty zasobów i timingów,
- przygotować wersję dokumentacji DOCX/PDF.

## 18. Podsumowanie

Projekt ma już własny sekwencyjny rdzeń FFT/IFFT radix-2 dla `N = 256`,
wrappery FFT/IFFT podłączone do tego rdzenia, normalizację IFFT oraz testy
bit-exact. Aktualny stan jest gotowy do lokalnego etapu narzędziowego:
syntezy, Place & Route i pierwszego testu na Tang Nano.

Najbliższy krok użytkownika to uruchomienie Gowin EDA lokalnie, zebranie
raportów zasobów/timingu oraz potwierdzenie, czy projekt zamyka timing na
docelowej płytce.
