# Status po nastepnym etapie

## Co zostalo zrobione przez Codexa

- Dodano `sync_2ff`.
- Dodano `debounce`.
- Dodano `button_onepulse`.
- Dodano `audio_param_regs`.
- Dodano `button_control_top`.
- Dodano `gain_lut_q2_14`.
- Dodano `spectral_gain_select`.
- Dodano dokumentacje przyciskow i panelu sterowania.

## Co zostalo poprawione w tym etapie

- README zostalo napisane od zera i opisuje aktualny stan bez sugerowania, ze FFT/IFFT juz dziala.
- `.gitignore` zostal uzupelniony o artefakty Vivado/XSim, Gowin i pliki lokalne.
- Testbenche dostaly proste sanity-checki i komunikaty PASS/FAIL.
- Zsynchronizowano duplikaty `rtl/` i `gowin_impl/tang_audio_hw/src/` dla `tone_gen`, `i2s_tx` i `tang_audio_top`.
- Dodano `volume_lut_q2_14` i `volume_control`.
- Dodano top demonstracyjny `tang_audio_control_top`.
- Dodano stub interfejsu przyszlego FFT/IFFT.
- Dodano dokumentacje interfejsu przyszlego akceleratora.

## Co jest gotowe

- Generator tonu `tone_gen`.
- Podstawowe wyjscie I2S przez `i2s_tx`.
- Sterowanie przyciskami z synchronizacja, debounce i impulsem jednocyklowym.
- Rejestry parametrow stereo L/R.
- Regulacja glosnosci przez `volume_control`.
- Wybor aktywnego kanalu L/R i LED aktywnego kanalu.
- Wybor gainu dla binow FFT przez `spectral_gain_select`.
- Demonstrator `tang_audio_control_top`: `button_control_top -> volume_L/R -> volume_control -> i2s_tx`.

## Etap: pierwszy korektor DAFX

Dodano pierwszy realny blok korektora dzialajacy w dziedzinie czasu:

- `rtl/audio/test_mix_gen.v` generuje testowy miks low/mid/high.
- `rtl/dsp/eq3band_simple.v` dzieli sygnal na przyblizone pasma bass/mid/treble.
- `rtl/dsp/eq3band_stereo.v` instancjuje korektor osobno dla kanalow L/R.
- `rtl/top/tang_audio_eq_top.v` laczy `test_mix_gen -> eq3band_stereo -> volume_control -> i2s_tx`.

Co dziala logicznie w RTL:

- `bass_gain_L/R`, `mid_gain_L/R` i `treble_gain_L/R` realnie wplywaja na probki audio.
- `volume_L/R` nadal dziala po korektorze.
- `led_clip` sygnalizuje saturacje korektora.
- FFT/IFFT nadal nie jest uzywane w torze audio.

Co wymaga testu:

- odsluch i pomiar I2S na sprzecie,
- reakcja przyciskow po fizycznym przypisaniu pinow,
- rzeczywiste progi clippingu dla wybranego poziomu sygnalu,
- dokladnosc BCLK/LRCK.

## Co jest jeszcze niegotowe

- Prawdziwy rdzen FFT.
- Prawdziwy rdzen IFFT.
- `sample_buffer`.
- `spectral_processor` mnozacy biny zespolone przez gain.
- Overlap-add.
- Wejscie audio PCM1808/I2S.
- Wyjscie audio PCM5102A/I2S w docelowym torze pomiarowym.
- Dokladny zegar audio.
- Fizyczne piny przyciskow.

## Aktualizacja koncepcji hardware

Projekt przechodzi z testow lokalnego generatora na docelowy stereofoniczny tor pomiarowy:

```text
generator funkcyjny
    -> PCM1808 ADC stereo
    -> Tang Nano 20K / FPGA
    -> PCM5102A DAC stereo
    -> oscyloskop
```

Glowny hardware docelowy to PCM1808 jako ADC stereo i PCM5102A jako DAC stereo. Wyjscie DAC jest traktowane jako wyjscie liniowe L/R do pomiaru oscyloskopem, bez wzmacniacza mocy i bez glosnikow.

Pierwszym celem sprzetowym jest tryb BYPASS:

```text
PCM1808 -> i2s_rx_stereo -> audio_pipeline_bypass -> i2s_tx_stereo -> PCM5102A
```

Obecne topy z `tone_gen`, `test_mix_gen` i `tang_audio_eq_top` pozostaja jako tryby testowe/demonstracyjne. Sa przydatne do debugowania DSP bez ADC. Blok EQ/DAFX zostaje jako blok DSP do pozniejszego wlaczenia w `audio_pipeline`.

FFT/IFFT nadal jest przyszlym etapem. `rtl/dsp/fft_ifft_accel_stub.v` pozostaje tylko stubem/interfejsem, a nie dzialajacym rdzeniem FFT/IFFT.

## Problem I2S i zegara 48 kHz

Obecny `i2s_tx` uzywa prostego dzielnika calkowitoliczbowego z zegara 27 MHz. Dla 48 kHz i 16 bitow stereo docelowy BCLK wynosi:

```text
48000 * 16 * 2 = 1.536 MHz
```

Prosty dzielnik calkowitoliczbowy moze dac niedokladna czestotliwosc BCLK/LRCK. TODO:

- sprawdzic wymagania PCM5102A dla docelowego toru DAC,
- przygotowac PLL albo dzielnik ulamkowy,
- zweryfikowac rzeczywiste `I2S_BCLK`, `I2S_LRCK` i `I2S_DIN` na analizatorze logicznym.

## Weryfikacja etapu DAFX/EQ

Sprawdzono `tang_audio_eq_top` na galezi `Version-with-accelerator` bez porownywania z `main`.

Wyniki przegladu RTL:

- `tang_audio_eq_top` ma kompletne polaczenia miedzy `test_mix_gen`, `button_control_top`, `eq3band_stereo`, dwoma instancjami `volume_control` i `i2s_tx`.
- `test_mix_gen` generuje `sample_valid = 1` po resecie przy kazdym cyklu `clk`.
- `eq3band_simple` ma dwucyklowa latencje valid: `sample_valid -> sample_out_valid`.
- `eq3band_stereo` laczy validy kanalow L/R przez `left_valid & right_valid`.
- `volume_control` ma jednocyklowa latencje valid.
- Po rozbiegu pipeline `eq_valid` i `volume_left_valid/right_valid` sa aktywne stale, bo zrodlo testowe dostarcza probke w kazdym cyklu zegara.

Wazne ograniczenie:

- Obecny `i2s_tx` nie ma wejscia `sample_valid`, `sample_ready` ani `sample_tick`.
- Przez to tor DSP pracuje z czestotliwoscia `clk`, a `i2s_tx` tylko okresowo pobiera aktualna wartosc `sample_left/right`.
- Sama serializacja slowa I2S jest stabilna, bo `i2s_tx` kopiuje probke do rejestru przesuwnego `shreg` na poczatku slowa i przesuwa juz kopie, a nie zmieniajace sie wejscie.
- Brakuje jednak jawnego handshake/sample tick, ktory mowilby generatorowi i filtrom, kiedy ma powstac nastepna probka audio.

Minimalna poprawka na kolejny etap, bez przebudowy calego projektu:

- dodac w `i2s_tx` wyjscie `sample_tick` albo `sample_request` aktywne raz na nowa probke/ramke audio,
- uzyc tego ticku jako `sample_valid`/clock-enable dla `test_mix_gen`, `eq3band_stereo` i `volume_control`,
- opcjonalnie zarejestrowac `volume_left_sample/right_sample` w topie tylko wtedy, gdy `volume_left_valid & volume_right_valid` sa aktywne,
- zachowac dotychczasowy interfejs kompatybilny wstecz dla istniejacych topow.

Testy nie zostaly uruchomione, poniewaz narzedzia symulacyjne (`iverilog`, `verilator`, `xvlog`, `vlog`) nie sa dostepne w PATH.

Pliki wymagane dla topu `tang_audio_eq_top` w projekcie Gowin:

- `rtl/audio/test_mix_gen.v`
- `rtl/audio/i2s_tx.v`
- `rtl/common/sync_2ff.v`
- `rtl/common/debounce.v`
- `rtl/common/button_onepulse.v`
- `rtl/control/audio_param_regs.v`
- `rtl/control/button_control_top.v`
- `rtl/dsp/gain_lut_q2_14.v`
- `rtl/dsp/eq3band_simple.v`
- `rtl/dsp/eq3band_stereo.v`
- `rtl/dsp/volume_lut_q2_14.v`
- `rtl/dsp/volume_control.v`
- `rtl/top/tang_audio_eq_top.v`

Nie przypisano pinow przyciskow. Piny `btn_*`, `led_left_active`, `led_right_active` i `led_clip` nadal trzeba uzupelnic recznie w `.cst` po ustaleniu polaczen.

## Nastepny logiczny krok

- Potwierdzic dokumentacje i tryb zegarow uzytych modulow PCM1808 oraz PCM5102A.
- Przygotowac `i2s_rx_stereo` dla PCM1808.
- Przygotowac `audio_pipeline_bypass`.
- Przygotowac top BYPASS dla PCM1808 -> FPGA -> PCM5102A.
- Sprawdzic BCLK/LRCK/DATA na analizatorze logicznym.
- Dopiero po stabilnym BYPASS wlaczyc EQ/DAFX.
- Dopiero pozniej zaczac `sample_buffer` i testowy FFT 64/128 punktow.
