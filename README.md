# FPGA Audio Platform — Tang Nano 20K

Projekt jest rozwijany jako stereofoniczna platforma audio na FPGA Tang Nano 20K. Docelowy tor pomiarowy wykorzystuje ADC PCM1808 do akwizycji sygnalu analogowego L/R, przetwarzanie w FPGA oraz DAC PCM5102A do wyjscia analogowego L/R mierzonego oscyloskopem.

## Aktualna koncepcja hardware

```text
generator funkcyjny
    -> analog L/R
PCM1808 ADC stereo
    -> I2S stereo
Tang Nano 20K / FPGA
    -> I2S stereo
PCM5102A DAC stereo
    -> analog L/R
oscyloskop
```

Na tym etapie nie uzywamy wzmacniacza mocy ani glosnikow. PCM5102A jest traktowany jako wyjscie liniowe L/R do pomiarow oscyloskopem. Wczesniejsze testy z prostym wyjsciem I2S/MAX98357A nalezy traktowac jako pomocniczy etap demonstracyjny, a nie docelowy tor pomiarowy.

## Elementy sprzetowe

- Tang Nano 20K.
- PCM1808 ADC stereo I2S.
- PCM5102A DAC stereo I2S.
- Generator funkcyjny.
- Oscyloskop.
- Zasilacz 5 V.
- Przewody polaczeniowe.
- Przyciski.
- LED-y z rezystorami.
- Opcjonalnie analizator logiczny.

## Cel projektu

- Zbudowac stereofoniczny tor pomiarowy ADC -> FPGA -> DAC.
- Uruchomic tryb BYPASS dla weryfikacji toru PCM1808 -> FPGA -> PCM5102A.
- Dodac sterowanie parametrami audio z przyciskow.
- Rozwijac bloki DAFX/korektora dla kanalow L/R.
- Docelowo przygotowac sprzetowa akceleracje FFT/IFFT do przetwarzania widmowego.

## Aktualny status projektu

Zaimplementowane:

- Generatory testowe `tone_gen` i `test_mix_gen`.
- Prosty korektor DAFX w dziedzinie czasu: `eq3band_simple` i `eq3band_stereo`.
- `volume_control`.
- Obsluga przyciskow i rejestrow parametrow L/R.
- Topy demonstracyjne dla lokalnych zrodel sygnalu z FPGA.
- `fft_ifft_accel_stub.v` jako stub/interfejs przyszlego akceleratora FFT/IFFT.

Niezaimplementowane jeszcze:

- Stabilny tor wejsciowy PCM1808 -> `i2s_rx_stereo`.
- Pelny BYPASS ADC -> FPGA -> DAC.
- Pelne przypisanie pinow dla PCM1808/PCM5102A.
- Prawdziwy FFT/IFFT.
- `sample_buffer`.
- `spectral_processor`.
- Overlap-add.

## Tryby pracy

- `SELFTEST` - diagnostyka bez sprzetu zewnetrznego, z wewnetrznym generatorem probek, automatyczna zmiana parametrow, modulacja i raport przez UART TX.
- `TEST_TONE` / `TEST_MIX` - sygnal generowany lokalnie w FPGA, bez ADC.
- `BYPASS` - probki z PCM1808 przechodza bez zmian do PCM5102A. To jest najblizszy priorytet sprzetowy.
- `EQ_DAFX` - probki przechodza przez korektor bass/mid/treble.
- `FFT_DSP` - planowany tryb przyszly z FFT/IFFT.

## Docelowe bloki logiczne

- `i2s_rx_stereo` - odbior I2S stereo z PCM1808.
- `audio_pipeline` - BYPASS, potem volume/EQ/FFT DSP.
- `i2s_tx_stereo` - nadawanie I2S stereo do PCM5102A.
- `button_controller` - obsluga przyciskow.
- `parameter_registers` - rejestry volume/EQ/trybow.
- `led_controller` - sygnalizacja trybu, aktywnego kanalu i clippingu.

## Priorytet najblizszego uruchomienia

Najpierw BYPASS bez FFT:

```text
PCM1808
    -> i2s_rx_stereo
    -> audio_pipeline_bypass
    -> i2s_tx_stereo
    -> PCM5102A
```

Dopiero po stabilnym BYPASS nalezy wlaczac EQ/DAFX, a pozniej przechodzic do FFT/IFFT.

## Self-test bez sprzetu zewnetrznego

Tryb `SELFTEST` jest pierwszym bezpiecznym etapem diagnostycznym uruchamianym tylko na plytce Tang Nano 20K podlaczonej do komputera przez USB. Nie wymaga generatora funkcyjnego, ADC, DAC, kodeka, przyciskow ani dodatkowego toru audio.

Tor logiczny trybu self-test:

```text
test_signal_gen
    -> auto_param_controller
    -> modulation_core
    -> debug_analyzer
    -> uart_debug_formatter
    -> uart_tx
```

`test_signal_gen` generuje signed 16-bit probki testowe wewnatrz FPGA. `auto_param_controller` cyklicznie zmienia tryby:

- `MODE=0`: normal, `VOL=8`, `BASS=0`, `MID=0`, `TREBLE=0`.
- `MODE=1`: bass boost.
- `MODE=2`: mid boost.
- `MODE=3`: treble boost.
- `MODE=4`: glosniej / clipping test.

`modulation_core` wykonuje uproszczone przetwarzanie w dziedzinie czasu. Nie uzywa FFT/IFFT. Rdzen rozdziela probke na proste komponenty bass/mid/treble, mnozy je przez gain Q2.14, naklada volume i saturuje wynik do signed 16-bit. Sygnal `clip` wskazuje przekroczenie zakresu.

`debug_analyzer` zbiera minimum i maksimum wejscia oraz wyjscia w oknie probek. `uart_debug_formatter` wysyla tekst diagnostyczny przez `uart_tx`. UART nie przesyla pelnego audio, tylko okresowe raporty tekstowe, np.:

```text
TANG AUDIO SELFTEST START
MODE=0 VOL=08 BASS=+0 MID=+0 TREBLE=+0 IN_MIN=0xC180 IN_MAX=0x3E7F OUT_MIN=0xC180 OUT_MAX=0x3E7F CLIP=0
```

Wartosci `IN_MIN`, `IN_MAX`, `OUT_MIN` i `OUT_MAX` sa wypisywane szesnastkowo jako 16-bit two's complement.

Top trybu diagnostycznego:

```text
rtl/top/tang_audio_selftest_top.v
```

Porty diagnostyczne:

- `uart_tx` - wyjscie nadajnika UART 8N1.
- `led_heartbeat` - proste potwierdzenie pracy logiki.
- `led_clip` - sygnal clippingu.
- `led_mode[2:0]` - aktualny tryb automatyczny.

Nie zakladamy, ze samo USB programatora Tang Nano 20K automatycznie udostepnia UART z FPGA jako port COM. Jezeli Windows nie pokazuje odpowiedniego portu COM albo dokumentacja plytki nie potwierdza polaczenia UART, nalezy potraktowac `uart_tx` jako osobny pin FPGA. Do fizycznego odbioru moze byc potrzebny zewnetrzny konwerter USB-UART 3.3 V oraz potwierdzone przypisanie pinu TX w constraints. Nie nalezy podlaczac 5 V do pinow FPGA.

Symulacje self-testu sa opisane w `docs/simulation_notes.md`. Przyklad dla Icarus Verilog:

```powershell
iverilog -g2001 -o sim/tang_audio_selftest_top_tb.vvp rtl/debug/test_signal_gen.v rtl/debug/auto_param_controller.v rtl/dsp/gain_lut_q2_14.v rtl/dsp/volume_lut_q2_14.v rtl/dsp/modulation_core.v rtl/debug/debug_analyzer.v rtl/debug/uart_debug_formatter.v rtl/uart/uart_tx.v rtl/top/tang_audio_selftest_top.v tb/tang_audio_selftest_top_tb.v
vvp sim/tang_audio_selftest_top_tb.vvp
```

Aby uruchomic na Tang Nano w Gowin EDA, nalezy dodac nowe pliki RTL do projektu, ustawic top `tang_audio_selftest_top`, przypisac potwierdzone piny `clk`, `rst`, `uart_tx` i opcjonalnych LED-ow, a nastepnie zaprogramowac plytke. Po zaprogramowaniu nalezy sprawdzic w Menedzerze urzadzen Windows, czy widoczny jest port COM. Jesli nie ma pewnego portu COM z plytki, uzyc zewnetrznego USB-UART 3.3 V podlaczonego do potwierdzonego pinu `uart_tx`.

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
- docelowo `BYPASS_MODE`

Parametry audio sa oddzielne dla kanalu lewego i prawego:

- `volume_L/R`: zakres `0...15`, domyslnie `8`.
- `bass_gain_L/R`: zakres `-6...+6`, domyslnie `0`.
- `mid_gain_L/R`: zakres `-6...+6`, domyslnie `0`.
- `treble_gain_L/R`: zakres `-6...+6`, domyslnie `0`.

W obecnym trybie demonstracyjnym EQ dziala na sygnale testowym z FPGA. Docelowo wejsciem EQ maja byc probki z `i2s_rx_stereo` odbierane z PCM1808, a wyjsciem I2S do PCM5102A.

## Struktura katalogow

```text
rtl/audio    - bloki toru audio, obecne I2S TX i przyszle I2S RX
rtl/common   - bloki wspolne, np. synchronizacja i debounce
rtl/control  - sterowanie przyciskami i rejestry parametrow
rtl/debug    - generatory i diagnostyka self-test
rtl/dsp      - bloki DSP, EQ, gain/volume i stub FFT/IFFT
rtl/top      - top-level projektu i demonstratory
rtl/uart     - proste interfejsy UART do diagnostyki
tb           - testbenche symulacyjne
docs         - dokumentacja projektu
gowin_impl   - projekt narzedziowy Gowin
```

Katalog `rtl/` jest traktowany jako glowne zrodlo RTL. Szczegoly organizacji sa opisane w `docs/source_structure_notes.md`.

## Budowanie i symulacje

Projekt Gowin znajduje sie w:

```text
gowin_impl/tang_audio_hw/
```

Aktualny projekt narzedziowy moze uzywac kopii plikow z `gowin_impl/tang_audio_hw/src/`. Canonical source pozostaje w `rtl/`.

Testbenche sa w katalogu `tb/`. Komendy przykladowe opisano w `docs/simulation_notes.md`. W repozytorium nie ma jeszcze jednego wspolnego skryptu uruchamiajacego wszystkie testy.

## Ostrzezenia sprzetowe

- Sprawdzic poziomy logiczne I2S przed podlaczeniem do Tang Nano 20K.
- Nie podawac 5 V na piny FPGA.
- Zapewnic wspolna mase GND miedzy FPGA, PCM1808, PCM5102A, generatorem i oscyloskopem.
- Zaczac od malej amplitudy generatora.
- Nie zgadywac pinow FPGA.
- Sprawdzic sposob taktowania PCM1808 i PCM5102A.

## Ograniczenia aktualnej wersji

- Tor PCM1808 -> FPGA -> PCM5102A nie jest jeszcze zaimplementowany.
- Aktualne topy EQ/testowe korzystaja z lokalnego generatora w FPGA.
- Obecny `i2s_tx` wymaga dalszej pracy nad handshake/sample tick.
- FFT/IFFT jest zaplanowane, ale niezaimplementowane. Obecny `fft_ifft_accel_stub.v` jest tylko interfejsem/stubem.

## Nastepne kroki

- Uzupelnic dokumentacje polaczen sprzetowych.
- Wybrac architekture zegarow I2S.
- Zaimplementowac `i2s_rx_stereo`.
- Zaimplementowac `audio_pipeline_bypass`.
- Dodac top BYPASS dla PCM1808 -> FPGA -> PCM5102A.
- Przetestowac generator 1 kHz -> ADC -> FPGA -> DAC -> oscyloskop.
- Po stabilnym BYPASS wlaczyc EQ.
- Dopiero pozniej rozwijac FFT/IFFT.

## Autor

Maciej Molik
