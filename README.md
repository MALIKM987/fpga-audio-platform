# FPGA Audio Platform

Aktualny priorytet projektu to akcelerator FFT/IFFT działający wyłącznie w
FPGA, przetwarzający bloki próbek audio w formacie I2S-like i weryfikowalny z
poziomu symulacji oraz raportów konsolowych. Dopiero po sprawdzeniu logiki DSP
projekt wróci do fizycznego toru audio.

Projekt zaczynał jako uruchomienie fizycznego toru:

```text
PCM1808 ADC -> FPGA -> PCM5102A DAC
```

Ten tor pozostaje jako przyszła warstwa sprzętowa. Obecnie skupiamy się na
modelowaniu ramek audio wewnątrz FPGA/testbencha, przetwarzaniu ich w logice
FPGA i raportowaniu wyników bez konieczności użycia ADC, DAC, oscyloskopu ani
ciągłego streamingu audio.

## Aktualny Zakres

Aktualny zakres projektu:

- logika DSP i sterująca działająca wyłącznie w FPGA,
- planowany pipeline FFT/IFFT sprawdzalny w konsoli,
- self-test diagnostyczny dla Tang Nano 20K,
- przetwarzanie fixed-point dla signed 16-bit próbek audio,
- architektura stereo L/R, z możliwością współdzielenia akceleratora.

Pierwsza docelowa architektura:

```text
test generator / I2S-like input model
-> sample_block_buffer
-> FFT accelerator wrapper
-> spectral_processor
-> IFFT accelerator wrapper
-> I2S-like output model
-> console report / UART report
```

Fizyczne wejście PCM1808 i fizyczne wyjście PCM5102A nie są częścią obecnego
celu implementacyjnego.

## Aktualny Self-Test

Obecnie aktywny RTL to diagnostyczny self-test:

```text
test_signal_gen
-> auto_param_controller
-> modulation_core
-> debug_analyzer
-> uart_debug_formatter
-> uart_tx
```

Ważne pliki:

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

Dla pierwszego minimalnego testu sprzętowego w Gowin użyj:

```text
Top module: tang_audio_selftest_board_top
Constraints: gowin_impl/tang_audio_hw/src/tang_audio_hw.cst
```

Ten wrapper wystawia tylko `clk` i `led`. UART pozostaje wewnętrzny dla
pierwszego testu płytkowego, chyba że dostępne jest potwierdzone połączenie
UART 3.3 V.

## Planowana Architektura FFT/IFFT

Pierwsza wersja FFT/IFFT ma używać:

- `FFT_SIZE = 256`,
- signed 16-bit próbek,
- bloków stereo L/R,
- arytmetyki fixed-point,
- wartości gain w Q2.14,
- trybów testowych takich jak bypass, sinusy, impuls, sygnał mieszany i różne
  gainy dla kanałów L/R.

Planowane moduły RTL:

- `rtl/dsp/sample_block_buffer.v`
- `rtl/dsp/spectral_gain_select.v`
- `rtl/dsp/spectral_processor.v`
- `rtl/dsp/fft_accel_wrapper.v`
- `rtl/dsp/ifft_accel_wrapper.v`
- `rtl/dsp/fft_ifft_pipeline.v`

Te moduły nie są jeszcze zaimplementowane. Należy dodawać je małymi krokami,
każdy z osobnym testbenchem albo pokryciem w testbenchu wyższego poziomu.

## Hardware TODO / Przyszłe Prace

Fizyczny tor audio jest celowo odłożony:

- PCM1808 ADC jako przyszła fizyczna warstwa wejściowa,
- PCM5102A DAC jako przyszła fizyczna warstwa wyjściowa,
- prawdziwe constrainty pinów I2S i testy oscyloskopem,
- ciągły streaming audio,
- windowing i overlap-add,
- późniejsza integracja z hardware po zweryfikowaniu pipeline FPGA-only.

Istniejące pliki I2S i bring-up sprzętowego zostają jako materiał
legacy/referencyjny dla późniejszego etapu. Nie należy traktować ich jako
aktywnej architektury dla prac FFT/IFFT.

## Dokumentacja

Zacznij tutaj:

- `docs/fpga_only_architecture.md`
- `docs/verification_plan.md`
- `docs/hardware_todo.md`
- `docs/selftest_uart_diagnostics.md`
- `docs/gowin_hardware_test_steps.md`
