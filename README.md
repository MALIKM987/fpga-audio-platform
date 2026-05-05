# FPGA Audio Platform — Tang Nano 20K

Projekt dotyczy cyfrowego procesora audio na FPGA Tang Nano 20K. Docelowo ma zawierac sprzetowy akcelerator FFT/IFFT do analizy i modyfikacji widma sygnalu audio.

## Cel projektu

- Demonstracja sprzetowej akceleracji algorytmu FFT/IFFT.
- Realizacja toru audio na FPGA.
- Sterowanie parametrami audio z przyciskow.
- Przygotowanie toru stereo L/R.

## Platforma sprzetowa

- Tang Nano 20K.
- FPGA Gowin GW2AR.
- Zegar glowny 27 MHz.
- Wyjscie audio I2S do MAX98357A.
- RTL w Verilogu.
- Projekt narzedziowy w Gowin EDA.
- Testbenche symulacyjne dla wybranych modulow.

## Docelowa architektura

```text
audio input / tone_gen
       ↓
sample buffer
       ↓
FFT accelerator
       ↓
spectral processor
       ↓
IFFT accelerator
       ↓
volume control
       ↓
I2S TX
       ↓
MAX98357A
```

## Aktualny stan projektu

Gotowe albo przygotowane na obecnym etapie:

- `tone_gen` - prosty generator tonu testowego.
- `i2s_tx` - podstawowy nadajnik I2S.
- `tang_audio_top` - podstawowy top sprzetowy dla toru `tone_gen -> i2s_tx`.
- `sync_2ff` - synchronizator sygnalu asynchronicznego.
- `debounce` - filtr drgan stykow.
- `button_onepulse` - impuls jednocyklowy po stabilnym nacisnieciu przycisku.
- `audio_param_regs` - rejestry parametrow stereo L/R.
- `button_control_top` - integracja przyciskow z rejestrami parametrow.
- `gain_lut_q2_14` - LUT gainu widmowego Q2.14.
- `spectral_gain_select` - wybor gainu dla binow przyszlego FFT.
- `volume_control` - regulacja glosnosci z saturacja signed 16-bit.
- `tang_audio_control_top` - demonstracyjny top laczacy przyciski, volume i I2S.
- `test_mix_gen` - generator testowego miksu low/mid/high dla korektora.
- `eq3band_simple` - prosty korektor bass/mid/treble w dziedzinie czasu.
- `eq3band_stereo` - wrapper stereo korektora L/R.
- `tang_audio_eq_top` - demonstrator DAFX: `test_mix_gen -> EQ -> volume -> I2S`.
- Dokumentacja panelu sterowania w `docs/`.
- Testbenche dla czesci modulow w `tb/`.

Nie jest jeszcze gotowe:

- Prawdziwy rdzen FFT.
- Prawdziwy rdzen IFFT.
- `sample_buffer`.
- `spectral_processor` mnozacy biny zespolone przez gain.
- Overlap-add.
- Wejscie audio z ADC albo kodeka I2S.
- Dokladny zegar audio 48 kHz.
- Integracja przyciskow z fizycznymi pinami.

## Sterowanie

Panel sterowania przewiduje przyciski:

- `VOL_UP`
- `VOL_DOWN`
- `BASS_UP`
- `BASS_DOWN`
- `MID_UP`
- `MID_DOWN`
- `TREBLE_UP`
- `TREBLE_DOWN`
- `CHANNEL_SELECT`

Parametry audio sa oddzielne dla kanalu lewego i prawego:

- `volume_L/R`: zakres `0...15`, domyslnie `8`.
- `bass_gain_L/R`: zakres `-6...+6`, domyslnie `0`.
- `mid_gain_L/R`: zakres `-6...+6`, domyslnie `0`.
- `treble_gain_L/R`: zakres `-6...+6`, domyslnie `0`.

`CHANNEL_SELECT` wybiera aktywny kanal: `0 = LEFT`, `1 = RIGHT`. Przyciski regulacji zmieniaja tylko parametry aktywnego kanalu. LED `led_left_active` i `led_right_active` sygnalizuja wybrany kanal.

W topie `tang_audio_eq_top` parametry `bass/mid/treble` realnie zmieniaja probki audio przez prosty korektor w dziedzinie czasu. FFT/IFFT nadal nie jest gotowe; `fft_ifft_accel_stub.v` pozostaje tylko kontraktem interfejsu dla przyszlego akceleratora.

## Struktura katalogow

```text
rtl/audio    - bloki toru audio, np. tone_gen i i2s_tx
rtl/common   - bloki wspolne, np. synchronizacja i debounce
rtl/control  - sterowanie przyciskami i rejestry parametrow
rtl/dsp      - bloki DSP, EQ, gain/volume i stub FFT/IFFT
rtl/top      - top-level projektu i demonstratory
tb           - testbenche symulacyjne
docs         - dokumentacja projektu
gowin_impl   - projekt narzedziowy Gowin
```

Katalog `rtl/` jest traktowany jako glowne zrodlo RTL. Szczegoly organizacji sa opisane w `docs/source_structure_notes.md`.

## Uruchamianie testbenchy

Testbenche sa w katalogu `tb/`. Mozna je uruchamiac w Vivado/XSim, Icarus Verilog, ModelSim/Questa albo innym symulatorze obslugujacym Verilog-2001. Do symulacji nalezy dodac testbench oraz wszystkie zalezne pliki RTL z katalogow `rtl/`.

Przykladowo test `volume_control_tb` wymaga:

- `rtl/dsp/volume_lut_q2_14.v`
- `rtl/dsp/volume_control.v`
- `tb/volume_control_tb.v`

W repozytorium nie ma jeszcze jednego wspolnego skryptu uruchamiajacego wszystkie testy.

## Budowanie w Gowin

Projekt Gowin znajduje sie w:

```text
gowin_impl/tang_audio_hw/
```

Aktualny projekt narzedziowy moze uzywac kopii plikow z `gowin_impl/tang_audio_hw/src/`. Canonical source pozostaje jednak w `rtl/`, wiec przy dalszym rozwoju trzeba pilnowac synchronizacji albo przestawic projekt Gowin tak, aby bezposrednio uzywal plikow z `rtl/`.

## Ograniczenia aktualnej wersji

- `i2s_tx` uzywa prostego dzielnika calkowitoliczbowego z 27 MHz, wiec sample rate moze nie byc dokladnie 48 kHz.
- Tor audio jest jeszcze demonstracyjny.
- Obecnie dziala prosty korektor w dziedzinie czasu, nie przetwarzanie widmowe.
- FFT/IFFT jest zaplanowane, ale niezaimplementowane. Obecny `fft_ifft_accel_stub` jest tylko interfejsem/stubem.
- Piny przyciskow nie sa jeszcze przypisane w constraints.

## Nastepne kroki

- Uporzadkowac zrodla RTL/Gowin i utrzymywac `rtl/` jako canonical source.
- Uruchomic `tang_audio_eq_top` na sprzecie i sprawdzic reakcje EQ/volume.
- Utrzymac stub FFT/IFFT jako kontrakt interfejsu.
- Dodac `sample_buffer`.
- Zaimplementowac testowo mniejszy radix-2 FFT, np. 64/128 punktow.
- Rozszerzyc implementacje do `FFT_N = 512`.
- Dodac `spectral_processor`.
- Dodac IFFT i overlap-add.
- Dodac wejscie audio I2S z zewnetrznego ADC/kodeka.

## Autor

Maciej Molik
