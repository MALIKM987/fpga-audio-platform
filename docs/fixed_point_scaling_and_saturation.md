# Skalowanie fixed-point i saturacja

Ten dokument opisuje poprawkę zakresu dynamicznego w torze:

```text
sample_block_buffer
    -> fft_accel_wrapper
    -> spectral_processor
    -> ifft_accel_wrapper
```

Zmiana powstała po fizycznym teście Tang Nano 20K przez UART, w którym małe
amplitudy działały poprawnie, ale sygnał w okolicy amplitudy `0.008` zaczynał
wykazywać skoki i zniekształcenia.

## Dane wejściowe z testu sprzętowego

Do analizy użyto eksportów CSV:

- `testok.csv`
- `testgraniczny.csv`
- `testfail.csv`

Zaobserwowane objawy:

- `testok.csv`: wejście około `-33..33` LSB, błąd maksymalny względem lokalnego
  modelu około `8` LSB.
- `testgraniczny.csv`: wejście około `-229..229` LSB, pojawia się duży błąd na
  końcu ramki, gdzie wynik FPGA przechodzi w przeciwny znak.
- `testfail.csv`: wejście około `-262..262` LSB, wynik FPGA wygląda jak
  ograniczony do okolic `-128..127`, mimo że oczekiwany wynik powinien
  przekraczać ten zakres.

To nie wyglądało na problem UART ani formatowania `READ_RESULT_CHUNK`, ponieważ
wcześniejszy test impulsu potwierdził odczyt pełnych próbek signed 16-bit.

## Przyczyna

Dla rzeczywistego tonu sinusoidalnego o amplitudzie `A` główne biny FFT mają
w przybliżeniu wartość:

```text
FFT_peak ~= (N / 2) * A
```

Dla `N = 256` daje to:

```text
FFT_peak ~= 128 * A
```

Przy wejściu około `256` LSB wynik binu dochodzi do:

```text
128 * 256 = 32768
```

To jest dokładnie okolica granicy signed 16-bit. Dlatego granica błędu wypadała
między testem około `229` LSB i `262` LSB. Główna przyczyna była więc w zbyt
wąskim 16-bitowym zakresie wewnętrznym forward FFT oraz zawijaniu wyniku po
operacjach motylkowych i mnożeniach.

Gain Q2.14 pozostał spójny:

- `1.00 = 16384`
- `0.50 = 8192`
- `0.75 = 12288`
- `1.50 = 24576`

Problem nie był w kodowaniu gainu, tylko w zakresie dynamicznym toru FFT.

## Zmiany w RTL

Zmieniono zachowanie zawężania wyników tak, żeby krytyczne miejsca saturująco
ograniczały wynik zamiast zawijać go modulo szerokość słowa:

- `complex_mult.v` saturuje wynik po przesunięciu Q2.14.
- `spectral_processor.v` saturuje wynik mnożenia przez gain Q2.14.
- `fft_radix2_core.v` saturuje zapis wyników motylka do pamięci rdzenia.
- `fft_ifft_pipeline.v` używa szerszej wewnętrznej ścieżki:

```verilog
INTERNAL_WIDTH = 24
```

Wejście i wyjście zewnętrzne pozostają signed 16-bit. Szerszy zakres dotyczy
tylko środka toru:

```text
int16 samples
    -> sign-extend to 24-bit FFT bins
    -> FFT
    -> spectral gain
    -> IFFT
    -> saturate back to int16
```

Nie zmieniono protokołu UART, mailboxa, mini CPU, topów ani formatu odpowiedzi
`READ_RESULT_CHUNK`.

## Model Python

Model bit-exact w `tools/fft_radix2_fixed_model.py` został rozszerzony tak, aby
odzwierciedlał:

- szerszy wewnętrzny zakres pipeline,
- saturację po mnożeniu zespolonym,
- saturację po gainie widmowym,
- saturację przy zapisie wyników motylka,
- końcową saturację do signed 16-bit.

Dodano test:

```text
tools/test_fixed_point_amplitude_sweep.py
```

Test uruchamia sweep amplitudy dla tonu 1 kHz i gainu MID `0.50`, w tym
przypadek `0.008`, który wcześniej był obszarem awarii sprzętowej.

Oczekiwany efekt po poprawce:

- brak zapadania wyniku do zakresu około signed 8-bit,
- błąd względem matematycznego modelu FFT/IFFT pozostaje mały dla testowanych
  amplitud,
- wynik dla amplitudy `0.008` może bezpiecznie przekraczać `127` LSB.

## Analizator CSV

Dodano narzędzie diagnostyczne:

```powershell
python tools/analyze_hardware_csv.py testok.csv testgraniczny.csv testfail.csv
```

Skrypt wypisuje:

- zakres wejścia,
- zakres lokalnego wyniku,
- zakres wyniku serial FPGA,
- `max_abs_error`,
- `mean_abs_error`,
- `rms_error`,
- korelację,
- indeksy największych błędów.

To narzędzie nie jest obowiązkowym testem CI, bo analizuje lokalne eksporty z
pomiarów sprzętowych.

## Synchronizacja Gowin

Ponieważ projekt Gowin może używać kopii RTL w `gowin_impl/tang_audio_hw/src/`,
zsynchronizowano kopie plików:

- `complex_mult.v`
- `fft_ifft_pipeline.v`
- `fft_radix2_core.v`
- `spectral_processor.v`

Canonical source nadal pozostaje w katalogu `rtl/`.

## Ograniczenia

Ta poprawka nie oznacza, że cały tor jest już w pełni zweryfikowany
sprzętowo. Nadal trzeba wykonać ponowny test fizyczny na Tang Nano 20K dla:

- amplitudy `0.001`,
- amplitudy `0.007`,
- amplitudy `0.008`,
- większych amplitud, gdzie spodziewana jest saturacja końcowa int16.

Nie dodano:

- nowego UART protocol,
- zmian w aplikacji PC,
- zmian w mini CPU,
- zmian w topologii CPU-owned,
- fizycznego I2S,
- Gowin FFT IP.

## Uruchamianie testów

Podstawowa walidacja:

```powershell
python tools/run_all_tests.py
python tools/test_fft_radix2_fixed_model.py
python tools/test_fixed_point_amplitude_sweep.py
python tools/test_spectrum_lab_model.py
python tools/test_spectrum_lab_hardware_backend.py
python tools/spectrum_lab_uart_client.py --mock
```

Jeżeli lokalnie `iverilog` i `vvp` nie są dostępne w `PATH`, runner może
oznaczyć symulacje Verilog jako `STATUS=SKIPPED`. GitHub Actions powinien
uruchomić pełną walidację Verilog.
