# Panel sterowania parametrami audio

## Cel

Ten blok przygotowuje warstwe sterowania dla projektu FPGA Audio Platform na Tang Nano 20K. Na tym etapie nie implementuje jeszcze FFT/IFFT. Zamiast tego udostepnia komplet rejestrow parametrow audio, ktore pozniej beda odczytywane przez tor DSP po FFT i przed IFFT.

Architektura przypomina podzial znany z akceleratora CORDIC: logika sterujaca zapisuje parametry do rejestrow, a blok obliczeniowy korzysta z aktualnych wartosci bez znajomosci przyciskow ani mechaniki interfejsu uzytkownika.

## Przyciski

Panel obsluguje dziewiec wejsc przyciskow:

- `VOL_UP` zwieksza glosnosc aktywnego kanalu.
- `VOL_DOWN` zmniejsza glosnosc aktywnego kanalu.
- `BASS_UP` zwieksza poziom basow aktywnego kanalu.
- `BASS_DOWN` zmniejsza poziom basow aktywnego kanalu.
- `MID_UP` zwieksza poziom srednich czestotliwosci aktywnego kanalu.
- `MID_DOWN` zmniejsza poziom srednich czestotliwosci aktywnego kanalu.
- `TREBLE_UP` zwieksza poziom wysokich czestotliwosci aktywnego kanalu.
- `TREBLE_DOWN` zmniejsza poziom wysokich czestotliwosci aktywnego kanalu.
- `CHANNEL_SELECT` przelacza aktywny kanal: `0 = LEFT`, `1 = RIGHT`.

Kazde surowe wejscie przycisku przechodzi przez dwustopniowy synchronizator, filtr debounce i detektor zbocza. Rejestry parametrow sa sterowane tylko impulsami jednocyklowymi, a nie surowymi pinami.

## Zakresy regulacji

Glosnosc jest przechowywana oddzielnie dla kanalu lewego i prawego:

- `volume_L[3:0]`
- `volume_R[3:0]`

Zakres glosnosci to `0...15`, wartosc domyslna po resecie to `8`. Logika stosuje saturacje, wiec kolejne nacisniecia nie wyjda poza zakres.

Korekcja widma jest przechowywana jako liczby signed two's complement:

- `bass_gain_L`, `bass_gain_R`
- `mid_gain_L`, `mid_gain_R`
- `treble_gain_L`, `treble_gain_R`

Kazdy gain ma typ `signed [4:0]`, zakres `-6...+6` i wartosc domyslna `0`. Rowniez tutaj obowiazuje saturacja.

## Wybor kanalu

Rejestr `active_channel` okresla, ktory kanal jest aktualnie edytowany:

- `0` oznacza kanal lewy.
- `1` oznacza kanal prawy.

Przycisk `CHANNEL_SELECT` przelacza ten bit. Wyjscia `led_left_active` i `led_right_active` sa bezposrednia sygnalizacja stanu aktywnego kanalu. Gdy aktywny jest kanal lewy, przyciski regulacji zmieniaja tylko rejestry z sufiksem `_L`. Gdy aktywny jest kanal prawy, zmieniane sa tylko rejestry z sufiksem `_R`.

## Znaczenie rejestrow

`audio_param_regs` jest centralnym bankiem rejestrow sterowania. Jego wejscia to impulsy polecen, a wyjscia to stabilne parametry dla reszty projektu. Modul `button_control_top` laczy dziewiec przyciskow z bankiem rejestrow i jest zalecanym punktem integracji z fizycznym panelem.

Modul `gain_lut_q2_14` mapuje poziom gainu `-6...+6` na mnoznik Q2.14, gdzie `1.0 = 16384`. Modul `spectral_gain_select` wybiera mnoznik dla konkretnego binu FFT przy zalozeniach `FFT_N = 512` i `SAMPLE_RATE = 48000`.

Podzial pasm w aktualnym interfejsie:

- DC, czyli bin `0`, pozostaje bez zmian: gain `1.0`.
- Bass: `abs_bin 1...3`.
- Mid: `abs_bin 4...42`.
- Treble: `abs_bin 43...255`.

Dla binow lustrzanych stosowana jest ta sama wartosc gainu, liczona przez:

```text
abs_bin = bin_index <= FFT_N/2 ? bin_index : FFT_N - bin_index
```

## Przyszle uzycie w spectral_processor

Po dodaniu FFT/IFFT planowany blok `spectral_processor` powinien pobierac probki stereo, wykonywac FFT, a nastepnie dla kazdego binu wybrac mnoznik przez `spectral_gain_select`. Wynik mnozenia widma powinien trafic do IFFT, a potem do toru I2S TX.

Dla stereo beda potrzebne dwie instancje lub jedna wspoldzielona sciezka wyboru gainu, zasilana odpowiednimi rejestrami:

- dla kanalu L: `bass_gain_L`, `mid_gain_L`, `treble_gain_L`, `volume_L`,
- dla kanalu R: `bass_gain_R`, `mid_gain_R`, `treble_gain_R`, `volume_R`.

`volume_L/R` mozna zastosowac jako dodatkowy mnoznik amplitudy po IFFT lub jako oddzielny etap skalowania probek PCM. Gainy pasmowe powinny dzialac na reprezentacji widmowej po FFT i przed IFFT.
