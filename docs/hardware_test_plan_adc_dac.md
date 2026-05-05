# Plan testow hardware ADC/DAC

## Test 0 - kontrola bezpieczenstwa

- Sprawdzic zasilania modulow.
- Sprawdzic wspolna mase GND.
- Sprawdzic poziomy logiczne I2S.
- Nie podlaczac 5 V do pinow FPGA.
- Zaczac od malej amplitudy generatora.

## Test 1 - zegary

- Sprawdzic BCLK oscyloskopem albo analizatorem logicznym.
- Sprawdzic LRCK oscyloskopem albo analizatorem logicznym.
- Ustalic, kto jest masterem zegarow.
- Sprawdzic, czy PCM1808 wymaga MCLK/SCKI z FPGA albo z generatora zewnetrznego.

## Test 2 - BYPASS

- Podac sinus 1 kHz na wejscie PCM1808.
- Uruchomic BYPASS.
- Sprawdzic, czy sinus pojawia sie na wyjsciu PCM5102A.

## Test 3 - kanal lewy

- Podac sygnal tylko na L.
- Sprawdzic wyjscie L.
- Sprawdzic, czy R jest cichy.

## Test 4 - kanal prawy

- Podac sygnal tylko na R.
- Sprawdzic wyjscie R.
- Sprawdzic, czy L jest cichy.

## Test 5 - volume

- Sprawdzic zmiane amplitudy przez `VOL_UP` i `VOL_DOWN`.

## Test 6 - EQ

- Dopiero po stabilnym BYPASS sprawdzic `BASS`, `MID` i `TREBLE`.

## Test 7 - FFT

- Dopiero po stabilnym BYPASS i EQ przejsc do testow FFT/IFFT.
