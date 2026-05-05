# Status po nastepnym etapie

## Co zostalo zrobione

- Uporzadkowano opis struktury zrodel i wskazano `rtl/` jako canonical source.
- Poprawiono testbenche tak, aby mialy proste sprawdzenia i komunikaty PASS/FAIL.
- Dodano `volume_control` z LUT Q2.14 i saturacja signed 16-bit.
- Dodano top demonstracyjny `tang_audio_control_top`.
- Zintegrowano `button_control_top` z parametrami stereo L/R.
- Rozszerzono tor demonstracyjny o regulacje glosnosci L/R przed I2S TX.
- Dodano stub interfejsu przyszlego akceleratora FFT/IFFT.
- Dodano dokumentacje interfejsu FFT/IFFT i notatki o strukturze zrodel.

## Co dziala na tym etapie

- Generator tonu `tone_gen`.
- Nadajnik `i2s_tx`.
- Regulacja glosnosci L/R przez `volume_control`.
- Wybor aktywnego kanalu L/R przez `CHANNEL_SELECT`.
- Rejestry parametrow `bass`, `mid`, `treble` dla obu kanalow.
- LED aktywnego kanalu: `led_left_active` i `led_right_active`.
- Top demonstracyjny laczacy przyciski, volume i I2S: `tang_audio_control_top`.

## Co jeszcze nie jest zrobione

- Prawdziwy rdzen FFT.
- Prawdziwy rdzen IFFT.
- `sample_buffer` dla ramek 512 probek.
- `spectral_processor` mnozacy biny przez gain.
- Overlap-add.
- Wejscie audio I2S/ADC.
- Dokladne taktowanie audio 48 kHz przez PLL albo dzielnik ulamkowy.
- Fizyczne przypisanie pinow wszystkich przyciskow.

## Nastepne etapy rozwoju

### Etap A

- Uruchomic `tang_audio_control_top` na sprzecie.
- Sprawdzic, czy przyciski zmieniaja glosnosc.
- Sprawdzic LED kanalu L/R.

### Etap B

- Poprawic taktowanie I2S.
- Dodac PLL albo dzielnik ulamkowy dla dokladniejszego sample rate.

### Etap C

- Dodac `sample_buffer` dla ramek 512 probek.

### Etap D

- Zaimplementowac sequential radix-2 FFT accelerator.

### Etap E

- Dodac `spectral_processor`: `FFT bin -> spectral_gain_select -> mnozenie real/imag przez gain`.

### Etap F

- Dodac IFFT i overlap-add.

### Etap G

- Dodac wejscie audio z zewnetrznego ADC/kodeka I2S.
