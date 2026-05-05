# Etap DAFX: prosty korektor 3-pasmowy

## Cel etapu

Ten etap dodaje pierwszy realny blok DAFX w torze audio: prosty korektor bass/mid/treble dzialajacy w dziedzinie czasu. Nie jest to jeszcze przetwarzanie widmowe FFT/IFFT. Celem jest uruchomienie slyszalnej zmiany barwy dzwieku sterowanej przyciskami i rejestrami parametrow L/R.

## Architektura

```text
test_mix_gen
   ->
eq3band_stereo
   ->
volume_control L/R
   ->
i2s_tx
   ->
MAX98357A
```

Na tym etapie zrodlo `test_mix_gen` jest mono i jest kopiowane na kanal L oraz R. Parametry korektora i glosnosci sa jednak oddzielne dla kanalu lewego i prawego.

## Dzialanie eq3band_simple

`eq3band_simple` dzieli sygnal na trzy przyblizone pasma:

- bass: wolny filtr dolnoprzepustowy IIR,
- treble: roznica `sample_in - szybki filtr dolnoprzepustowy IIR`,
- mid: pozostala czesc sygnalu, czyli `sample_in - bass - treble`.

Kazde pasmo jest mnozone przez gain Q2.14 pobrany z istniejacego `gain_lut_q2_14`. Po zsumowaniu pasm wynik jest saturacyjny do signed 16-bit:

- minimum: `-32768`,
- maksimum: `+32767`.

Wyjscie `clip` jest aktywne, gdy wystapi saturacja.

## Sterowanie

- `BASS_UP` / `BASS_DOWN` zmieniaja `bass_gain` aktywnego kanalu.
- `MID_UP` / `MID_DOWN` zmieniaja `mid_gain` aktywnego kanalu.
- `TREBLE_UP` / `TREBLE_DOWN` zmieniaja `treble_gain` aktywnego kanalu.
- `VOL_UP` / `VOL_DOWN` zmieniaja `volume` aktywnego kanalu.
- `CHANNEL_SELECT` wybiera kanal L/R.

Zakresy pozostaja zgodne z bankiem rejestrow:

- `volume_L/R`: `0...15`, domyslnie `8`,
- `bass_gain_L/R`: `-6...+6`, domyslnie `0`,
- `mid_gain_L/R`: `-6...+6`, domyslnie `0`,
- `treble_gain_L/R`: `-6...+6`, domyslnie `0`.

## Ograniczenia

- To prosty korektor w dziedzinie czasu, a nie profesjonalny filtr parametryczny.
- Czestotliwosci podzialu pasm sa przyblizone i wynikaja z prostych przesuniec bitowych w filtrach IIR.
- Dokladniejsza wersja moze zostac pozniej zrobiona przez biquady albo przez przetwarzanie widmowe FFT/IFFT.
- `fft_ifft_accel_stub.v` nadal jest tylko interfejsem/stubem. FFT/IFFT nie jest jeszcze zaimplementowane.

## Test sprzetowy

1. Ustawic `tang_audio_eq_top` jako top projektu.
2. Dodac do projektu Gowin wymagane pliki RTL opisane w `docs/hardware_bringup_tang_audio_eq.md`.
3. Przypisac realne piny przyciskow i LED po ustaleniu polaczen.
4. Sprawdzic `I2S_BCLK` na analizatorze logicznym.
5. Sprawdzic `I2S_LRCK` na analizatorze logicznym.
6. Sprawdzic `I2S_DIN` na analizatorze logicznym.
7. Sprawdzic `led_heartbeat`.
8. Sprawdzic `led_left_active` i `led_right_active`.
9. Sprawdzic `led_clip`.
10. Po przypisaniu pinow przyciskow sprawdzic zmiane glosnosci i barwy.
