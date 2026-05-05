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

## Co jest jeszcze niegotowe

- Prawdziwy rdzen FFT.
- Prawdziwy rdzen IFFT.
- `sample_buffer`.
- `spectral_processor` mnozacy biny zespolone przez gain.
- Overlap-add.
- Wejscie audio ADC/I2S.
- Dokladny zegar audio.
- Fizyczne piny przyciskow.

## Problem I2S i zegara 48 kHz

Obecny `i2s_tx` uzywa prostego dzielnika calkowitoliczbowego z zegara 27 MHz. Dla 48 kHz i 16 bitow stereo docelowy BCLK wynosi:

```text
48000 * 16 * 2 = 1.536 MHz
```

Prosty dzielnik calkowitoliczbowy moze dac niedokladna czestotliwosc BCLK/LRCK. TODO:

- sprawdzic wymagania MAX98357A,
- przygotowac PLL albo dzielnik ulamkowy,
- zweryfikowac rzeczywiste `I2S_BCLK`, `I2S_LRCK` i `I2S_DIN` na analizatorze logicznym.

## Nastepny logiczny krok

- Uruchomic `tang_audio_control_top` na sprzecie.
- Sprawdzic `I2S_BCLK`, `I2S_LRCK` i `I2S_DIN` na analizatorze logicznym.
- Sprawdzic, czy przyciski zmieniaja `volume_L/R`.
- Sprawdzic LED aktywnego kanalu L/R.
- Dopiero potem zaczac `sample_buffer` i testowy FFT 64/128 punktow.
- Nastepnie przejsc do `FFT_N = 512`.
