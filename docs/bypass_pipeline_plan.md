# Plan top-level dla toru BYPASS

## Plan blokowy

```text
PCM1808
   ->
i2s_rx_stereo
   ->
audio_pipeline
   ->
i2s_tx_stereo
   ->
PCM5102A
```

## i2s_rx_stereo

- Odbiera I2S z ADC PCM1808.
- Rozdziela kanal lewy i prawy.
- Wystawia `left_sample`, `right_sample` i `sample_valid`.
- Wymaga potwierdzenia dokladnego timingu I2S uzytego modulu PCM1808 przed testem hardware.

## audio_pipeline

Tryb poczatkowy BYPASS:

```text
left_out  = left_in
right_out = right_in
```

Pozniejsze etapy:

- volume,
- EQ,
- FFT/DSP.

## i2s_tx_stereo

- Wysyla probki L/R do DAC PCM5102A.
- Uzywa jednej linii DATA.
- LRCK wybiera kanal.
- TX powinien pracowac w tej samej domenie zegara audio co RX albo przez dobrze opisane przejscie miedzy domenami.

## bypass_enable

- Rejestr konfiguracyjny wlaczajacy tryb BYPASS.
- Na start moze byc stale `1`.
- Pozniej moze byc sterowany przyciskiem `btn_bypass_mode`.

## led_bypass

- Swieci, gdy aktywny jest tryb BYPASS.
- Pomaga weryfikowac, ze tor pomiarowy pracuje bez dodatkowego DSP.

## Uwaga

Nie implementowac jeszcze pelnego FFT/IFFT. Najpierw nalezy uzyskac stabilny BYPASS ADC -> FPGA -> DAC.
