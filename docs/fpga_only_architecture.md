# Architektura FPGA-Only FFT/IFFT

## Cel

Aktualnym celem projektu jest akcelerator FFT/IFFT działający wyłącznie w FPGA
dla bloków danych audio w formacie I2S-like na Tang Nano 20K. Projekt ma być
sprawdzalny w symulacji i przez raporty konsolowe zanim zostanie ponownie
połączony z rzeczywistym sprzętem audio.

Ten etap skupia się na deterministycznym przetwarzaniu blokowym, arytmetyce
fixed-point, czytelnych raportach testowych i czystym interfejsie między
ramkami próbek audio a przyszłym akceleratorem FFT/IFFT.

## Dlaczego Odkładamy Fizyczny ADC/DAC

Poprzedni kierunek sprzętowy zakładał:

```text
PCM1808 ADC -> FPGA -> PCM5102A DAC
```

Ten tor zależy od okablowania, taktowania, rzeczywistego I2S RX/TX, pomiarów
analogowych i debugowania płytki. To będzie potrzebne później, ale utrudnia
jednoznaczne sprawdzenie, czy sama logika DSP działa poprawnie.

Na tym etapie odkładamy PCM1808, PCM5102A, fizyczne I2S i ciągły streaming
audio. Najpierw logika FPGA ma przejść powtarzalne testy na blokach próbek
generowanych wewnętrznie albo modelowanych w testbenchu.

## Pipeline Logiczny

Docelowa ścieżka przetwarzania:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

Modele wejścia i wyjścia nie są w tym etapie fizycznymi driverami I2S. Mają
reprezentować ramki audio w kolejności podobnej do I2S, żeby późniejsza
integracja sprzętowa mogła użyć tego samego układu danych.

## Aktualny Stan

Pipeline FFT/IFFT nie jest jeszcze zaimplementowany w RTL.

Obecnie aktywna logika to samodzielny self-test diagnostyczny:

```text
test_signal_gen
-> auto_param_controller
-> modulation_core
-> debug_analyzer
-> uart_debug_formatter
-> uart_tx
```

Powiązane pliki:

- `rtl/top/tang_audio_selftest_top.v`
- `rtl/top/tang_audio_selftest_board_top.v`
- `rtl/debug/test_signal_gen.v`
- `rtl/debug/auto_param_controller.v`
- `rtl/debug/debug_analyzer.v`
- `rtl/debug/uart_debug_formatter.v`
- `rtl/dsp/modulation_core.v`
- `rtl/dsp/gain_lut_q2_14.v`
- `rtl/dsp/volume_lut_q2_14.v`
- `rtl/uart/uart_tx.v`

Ten self-test jest aktualną bazą diagnostyczną. Generuje wewnętrzny sygnał
testowy, automatycznie zmienia parametry VOL/BASS/MID/TREBLE, uruchamia prosty
blok DSP `modulation_core`, zbiera min/max/clipping i formatuje strumień
diagnostyczny UART.

## Planowane Moduły RTL

Planowane moduły dla architektury FPGA-only FFT/IFFT:

- `rtl/dsp/sample_block_buffer.v`
- `rtl/dsp/spectral_gain_select.v`
- `rtl/dsp/spectral_processor.v`
- `rtl/dsp/fft_accel_wrapper.v`
- `rtl/dsp/ifft_accel_wrapper.v`
- `rtl/dsp/fft_ifft_pipeline.v`

Moduły powinny być dodawane etapami. Każdy nowy moduł Verilog powinien mieć
własny testbench albo być pokryty testbenchem wyższego poziomu.

## Parametry Pierwszej Wersji

Początkowe parametry:

- `FFT_SIZE = 256`,
- `SAMPLE_WIDTH = 16` signed,
- bloki próbek stereo L/R,
- arytmetyka fixed-point,
- wartości gain w Q2.14.

W pierwszej wersji akcelerator może być współdzielony między kanałem lewym i
prawym, jeśli uprości to architekturę.

## Rejestry Parametrów

Planowana konfiguracja przetwarzania jest stereofoniczna:

```text
volume_L
bass_gain_L
mid_gain_L
treble_gain_L

volume_R
bass_gain_R
mid_gain_R
treble_gain_R
```

Pierwsza implementacja może modelować te wartości jako proste rejestry
sterowane z testbencha albo kontrolera self-testu. Późniejszy system może
wystawić je przez UART, przyciski albo interfejs memory-mapped.

## Spectral Processor

`spectral_processor` będzie modyfikować biny FFT zgodnie z ustawionymi pasmami
częstotliwości.

Oczekiwane pierwsze zachowanie:

- bass gain wpływa na niskie biny,
- mid gain wpływa na środkowe biny,
- treble gain wpływa na wysokie biny,
- volume może być zastosowane globalnie albo po IFFT,
- clipping/overflow powinien być wykrywany i raportowany.

To jeszcze nie jest efekt audio czasu rzeczywistego. To testowa ścieżka
blokowa do udowodnienia zachowania FFT -> modyfikacja binów -> IFFT.

## Tryb Self-Test

Docelowy self-test powinien generować deterministyczne bloki próbek, np.:

- bypass input,
- sygnał sinusoidalny 100 Hz,
- sygnał sinusoidalny 1 kHz,
- sygnał sinusoidalny 8 kHz,
- impuls,
- sygnał mieszany,
- sygnały stereo z różnymi gainami L/R.

Obecny self-test nie jest jeszcze finalnym self-testem FFT/IFFT, ale jest
aktywną bazą diagnostyczną dla zegara, resetu, statusu i UART.

## Raportowanie

Wyniki powinny być widoczne najpierw w konsoli testbencha. Późniejszy self-test
na płytce może użyć tych samych pól raportu przez UART na Tang Nano 20K.

Oczekiwane pola raportu:

- nazwa testu,
- rozmiar FFT,
- kanał,
- ustawienia gain,
- FFT done,
- IFFT done,
- dominujący bin/częstotliwość,
- magnituda wejścia i wyjścia,
- flaga clippingu,
- status PASS/FAIL.

## Przyszła Integracja Rdzenia FFT

Wrapper FFT/IFFT może później połączyć się z Gowin FFT IP albo innym
zweryfikowanym rdzeniem FFT. Wrapper powinien ukrywać handshake specyficzny dla
danego rdzenia, żeby testbench, `spectral_processor` i logika raportowania
pozostały stabilne nawet przy zmianie implementacji FFT.
