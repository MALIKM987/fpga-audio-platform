# Plan Weryfikacji

## Cel

Celem weryfikacji jest udowodnienie działania pipeline FPGA-only FFT/IFFT przed
powrotem do fizycznego ADC/DAC. Testy mają być deterministyczne, powtarzalne z
poziomu konsoli i czytelne na tyle, żeby status PASS/FAIL był zrozumiały bez
oscyloskopu.

Planowany pipeline testowany:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

Pierwsze parametry docelowe:

- `FFT_SIZE = 256`,
- `SAMPLE_WIDTH = 16`,
- signed fixed-point samples,
- testy stereo L/R,
- wartości gain w Q2.14.

## Wymagane Testy

### bypass

Cel:

- uruchomić FFT -> IFFT bez modyfikacji widma,
- potwierdzić, że wyjście jest prawie takie samo jak wejście.

Kryteria PASS:

- `FFT_DONE = 1`,
- `IFFT_DONE = 1`,
- próbki wyjściowe zgadzają się z wejściowymi w dopuszczalnej tolerancji
  fixed-point,
- brak nieoczekiwanego clippingu.

### sine_100Hz

Cel:

- sprawdzić detekcję i modyfikację pasma bass,
- potwierdzić, że niska częstotliwość trafia do oczekiwanego zakresu niskich
  binów FFT.

Kryteria PASS:

- dominujący bin jest w zakresie bass,
- bass gain zmienia oczekiwane biny,
- biny mid/treble pozostają prawie bez zmian,
- clipping jest zgodny z oczekiwaniem.

### sine_1kHz

Cel:

- sprawdzić detekcję i modyfikację pasma mid.

Kryteria PASS:

- dominujący bin jest w zakresie mid,
- mid gain zmienia oczekiwane biny,
- biny bass/treble pozostają prawie bez zmian,
- magnituda wyjściowa zmienia się zgodnie z ustawionym gainem.

### sine_8kHz

Cel:

- sprawdzić detekcję i modyfikację pasma treble.

Kryteria PASS:

- dominujący bin jest w zakresie treble,
- treble gain zmienia oczekiwane biny,
- biny bass/mid pozostają prawie bez zmian,
- clipping jest raportowany, jeśli ustawiony gain przekracza zakres wyjścia.

### impulse

Cel:

- przetestować pełną ścieżkę FFT/IFFT na impulsie wejściowym,
- sprawdzić rozłożenie po binach i rekonstrukcję.

Kryteria PASS:

- FFT i IFFT kończą pracę,
- zrekonstruowany impuls mieści się w tolerancji,
- raport nie zawiera wartości unknown ani invalid.

### mixed_signal

Cel:

- sprawdzić kilka składowych częstotliwościowych jednocześnie,
- potwierdzić, że gainy bass/mid/treble wpływają na właściwe części widma.

Kryteria PASS:

- oczekiwane składowe są widoczne w raporcie,
- zmodyfikowane magnitudy odpowiadają wybranym ustawieniom gain,
- niezwiązane biny pozostają w tolerancji.

### stereo_diff_gains

Cel:

- sprawdzić niezależne parametry kanałów lewego i prawego.

Kryteria PASS:

- kanał L używa rejestrów gain kanału L,
- kanał R używa rejestrów gain kanału R,
- raportowane magnitudy różnią się zgodnie z ustawieniami L/R,
- dane kanałów nie są zamienione miejscami.

## Format Raportu Konsolowego

Przykładowy raport:

```text
=== FFT/IFFT PIPELINE TEST ===
FFT_SIZE=256
SAMPLE_WIDTH=16
TEST=sine_100Hz
CHANNEL=L
BASS_GAIN=+6dB
MID_GAIN=0dB
TREBLE_GAIN=0dB

FFT_DONE=1
IFFT_DONE=1
DOMINANT_BIN_IN=1
DOMINANT_FREQ_HZ=187.5
MAG_IN=8120
MAG_AFTER_MOD=12180
CLIP=0
STATUS=PASS
```

Każdy testbench powinien wypisywać tyle informacji, żeby dało się zrozumieć
przyczynę błędu. Test zakończony niepowodzeniem powinien używać `STATUS=FAIL`
i wskazywać pole, które się nie zgadza: dominujący bin, magnitudę, clipping
albo tolerancję rekonstrukcji wyjścia.

## Ogólne Zasady PASS/FAIL

Testy powinny kończyć się błędem, gdy:

- `FFT_DONE` nie zostanie ustawione,
- `IFFT_DONE` nie zostanie ustawione,
- wyjście zawiera wartości unknown,
- dominujący bin jest poza oczekiwanym zakresem,
- gain nie wpływa na oczekiwane pasmo,
- pojawia się nieoczekiwany clipping,
- mapowanie kanałów stereo jest błędne.

Testy mogą dopuszczać małą tolerancję dla skalowania fixed-point, zaokrągleń i
normalizacji FFT/IFFT. Tolerancja musi być wypisana albo opisana przez
testbench.

## Aktualny Status Weryfikacji

Finalne testy FFT/IFFT nie mogą jeszcze działać, ponieważ moduły pipeline
FFT/IFFT nie są zaimplementowane. Istniejące testbenche self-testu pozostają
przydatne dla obecnej warstwy diagnostycznej:

- `tb/test_signal_gen_tb.v`
- `tb/modulation_core_tb.v`
- `tb/debug_analyzer_tb.v`
- `tb/uart_tx_tb.v`
- `tb/tang_audio_selftest_top_tb.v`

Te testy sprawdzają fragmenty obecnego toru diagnostycznego, a nie przyszły
akcelerator FFT/IFFT.
