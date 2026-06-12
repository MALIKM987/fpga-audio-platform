# Tang Nano FFT/IFFT hardware self-test top

## Cel

`tang_fft_ifft_selftest_top` jest minimalnym top-level do pierwszego testu
sprzętowego realnego toru FFT/IFFT na Tang Nano 20K.

Ten wariant nie używa zewnętrznego ADC, DAC, UART, przycisków ani resetu.
Ma tylko dwa porty fizyczne:

```verilog
input  wire clk
output wire led
```

Celem jest wymuszenie, aby Gowin w aktywnej hierarchii syntezował:

- `sample_block_buffer`,
- `fft_accel_wrapper`,
- `fft_radix2_core`,
- `fft_twiddle_rom`,
- `fft_bit_reverse`,
- `fft_butterfly_addr_gen`,
- `complex_mult`,
- `spectral_processor`,
- `ifft_accel_wrapper`,
- `fft_ifft_pipeline`.

To nadal nie jest pełny tor audio z PCM1808/PCM5102A. To test logiczny
pipeline FFT/IFFT uruchamiany samodzielnie na FPGA.

## Porty

| Port | Kierunek | Opis |
| --- | --- | --- |
| `clk` | input | Zegar płytki, zgodny z constraintem projektu Tang Nano. |
| `led` | output | Jedyna dioda diagnostyczna self-testu. |

Aktualny wariant constraints używa tylko:

```text
clk -> pin 4
led -> pin 15
```

Jeżeli fizyczna dioda na płytce jest aktywna stanem niskim, zachowanie może
wyglądać odwrócone. RTL opisuje logikę aktywną stanem wysokim.

## Reset power-on

Top generuje reset wewnętrzny przez licznik po starcie FPGA.

Nie jest wymagany zewnętrzny pin resetu. Po nasyceniu licznika reset zostaje
zwolniony, a maszyna stanów rozpoczyna self-test.

## Ramka wejściowa

Self-test wysyła do `fft_ifft_pipeline` dokładnie 256 próbek:

- indeks `0`: `16'sd64`,
- wszystkie pozostałe indeksy: `16'sd0`.

Jest to mały impuls o niskiej amplitudzie, dobrany tak, aby uniknąć przepełnień
podczas pierwszego testu sprzętowego.

Gainy są ustawione na unity:

```verilog
bass_gain   = 16'sd16384
mid_gain    = 16'sd16384
treble_gain = 16'sd16384
```

W formacie Q2.14 wartość `16'sd16384` oznacza `1.0`.

## Sprawdzane wyjścia

Po przejściu przez:

```text
sample_block_buffer
    -> fft_accel_wrapper
    -> spectral_processor
    -> ifft_accel_wrapper
```

top sprawdza wybrane indeksy wyjściowe:

- `0`,
- `1`,
- `2`,
- `16`,
- `64`,
- `128`,
- `255`.

Dla unity gain i znormalizowanej IFFT oczekiwany wynik jest bliski ramce
wejściowej:

- indeks `0`: około `64`,
- pozostałe sprawdzane indeksy: około `0`.

Tolerancja wynosi `+/-2` LSB.

Self-test przechodzi do błędu, jeżeli:

- `overflow` zostanie ustawione,
- wystąpi timeout przed `done`,
- sprawdzany indeks ma wynik poza tolerancją,
- nie zostaną zaobserwowane wszystkie wymagane indeksy.

## Zachowanie LED

Dostępna jest tylko jedna dioda:

- reset / test w toku: szybkie miganie,
- `PASS`: świecenie ciągłe,
- `FAIL`: wolne miganie.

Jeżeli dioda na płytce jest aktywna stanem niskim, interpretacja może być
odwrócona.

## Użycie w Gowin EDA

1. Otwórz projekt Gowin dla Tang Nano.
2. Dodaj albo włącz wymagane pliki RTL:

   ```text
   rtl/dsp/fft_bit_reverse.v
   rtl/dsp/fft_butterfly_addr_gen.v
   rtl/dsp/fft_twiddle_rom.v
   rtl/dsp/complex_mult.v
   rtl/dsp/fft_radix2_core.v
   rtl/dsp/fft_accel_wrapper.v
   rtl/dsp/ifft_accel_wrapper.v
   rtl/dsp/sample_block_buffer.v
   rtl/dsp/spectral_gain_select.v
   rtl/dsp/spectral_processor.v
   rtl/dsp/fft_ifft_pipeline.v
   rtl/top/tang_fft_ifft_selftest_top.v
   ```

3. Jeżeli projekt Gowin korzysta z lokalnego katalogu `src`, dostępna jest też
   kopia:

   ```text
   gowin_impl/tang_audio_hw/src/tang_fft_ifft_selftest_top.v
   ```

   Kopia istnieje tylko dla wygody projektu Gowin. Źródłem prawdy pozostaje
   plik w `rtl/top/`.

4. Ustaw top module:

   ```text
   tang_fft_ifft_selftest_top
   ```

5. Użyj istniejących constraintów tylko dla `clk` i `led`.
6. Uruchom Synthesis.
7. Sprawdź, czy `fft_radix2_core` pojawia się w aktywnej hierarchii/netliście.
8. Uruchom Place & Route.
9. Sprawdź timing i wykorzystanie zasobów.
10. Wygeneruj bitstream.
11. Zaprogramuj Tang Nano.
12. Obserwuj LED.

Nie zmieniaj aktywnego topu na stałe bez świadomego wyboru. Ten wariant jest
osobnym testem sprzętowym FFT/IFFT.

## Co wkleić po teście sprzętowym

Po uruchomieniu w Gowin i na płytce wklej:

- ostrzeżenia z syntezy,
- informację, czy `fft_radix2_core` jest w hierarchii/netliście,
- wykorzystanie zasobów: LUT, FF, B-SRAM, DSP,
- wynik timing/slack,
- log z generowania bitstreamu,
- log z programowania Tang Nano,
- zachowanie LED po programowaniu.

Na podstawie tych danych będzie można zdecydować, czy kolejnym krokiem jest
optymalizacja zasobów, timing, dodanie UART czy integracja z fizycznym I2S.
