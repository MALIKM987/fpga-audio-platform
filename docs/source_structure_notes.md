# Struktura zrodel RTL

## Canonical source

Katalog `rtl/` jest glownym zrodlem prawdy dla kodu RTL projektu. Nowe moduly nalezy dodawac do:

- `rtl/audio/` dla blokow toru audio, takich jak `tone_gen` i `i2s_tx`,
- `rtl/common/` dla malych blokow wspolnych, takich jak synchronizatory i debounce,
- `rtl/control/` dla logiki sterowania przyciskami i rejestrow parametrow,
- `rtl/debug/` dla self-testu, analizatorow i formatowania diagnostyki,
- `rtl/dsp/` dla blokow przetwarzania sygnalu,
- `rtl/top/` dla top-leveli demonstracyjnych i sprzetowych,
- `rtl/uart/` dla prostych interfejsow UART do diagnostyki.

## Pliki Gowin

Katalog `gowin_impl/tang_audio_hw/` jest katalogiem projektu narzedziowego Gowin. Pliki w `gowin_impl/tang_audio_hw/src/` sa kopia pomocnicza albo plikami constraints uzywanymi przez projekt Gowin. Nie powinny byc traktowane jako glowny punkt edycji logiki RTL.

W tym repozytorium wykryto zdublowane moduly:

- `rtl/audio/tone_gen.v` oraz `gowin_impl/tang_audio_hw/src/tone_gen.v`,
- `rtl/audio/i2s_tx.v` oraz `gowin_impl/tang_audio_hw/src/i2s_tx.v`,
- `rtl/top/tang_audio_top.v` oraz `gowin_impl/tang_audio_hw/src/tang_audio_top.v`.

Audyt obejmuje tez constraints:

- `constraints.sdc` w katalogu glownym oraz `gowin_impl/tang_audio_hw/src/constraints.sdc`,
- `gowin_impl/tang_audio_hw/src/tang_audio_hw.cst`.

Pliki `.sdc` sa kopia tego samego ograniczenia zegara 27 MHz. Plik `.cst` jest fizycznym opisem pinow dla aktualnego topu Gowin i nie powinien byc uzupelniany losowymi pinami przyciskow.

Wersje w `rtl/` sa traktowane jako canonical source. Kopie w `gowin_impl/tang_audio_hw/src/` powinny byc synchronizowane z `rtl/`, jesli projekt Gowin nadal odwoluje sie do katalogu `src/`.

## Jak uniknac rozjazdu wersji

Najczystsze rozwiazanie to skonfigurowac projekt Gowin tak, aby bezposrednio uzywal plikow z `rtl/`. Alternatywnie mozna utrzymac kopie w `gowin_impl/tang_audio_hw/src/`, ale wtedy po kazdej zmianie RTL trzeba zsynchronizowac odpowiednie pliki przed budowa bitstreamu.

Nie nalezy edytowac rownolegle obu kopii tego samego modulu. Zmiane najpierw wykonuje sie w `rtl/`, a dopiero potem przenosi do `gowin_impl/tang_audio_hw/src/`, jesli projekt narzedziowy tego wymaga.

Nowy demonstrator `tang_audio_control_top` znajduje sie w `rtl/top/tang_audio_control_top.v`. Do uruchomienia go w Gowin trzeba dodac ten plik i jego zaleznosci RTL do projektu oraz uzupelnic constraints dla nowych przyciskow i LED.

Aktualnie kopie `tone_gen.v`, `i2s_tx.v` i `tang_audio_top.v` w `gowin_impl/tang_audio_hw/src/` zostaly zsynchronizowane z wersjami w `rtl/`.

Top `tang_audio_eq_top` jest nowszym demonstratorem DAFX i powinien byc dodawany do Gowin razem z plikami wymienionymi w `docs/hardware_bringup_tang_audio_eq.md`.

## Topy testowe i docelowy top pomiarowy

W repozytorium istnieja topy testowe dla lokalnego generatora i EQ:

- `rtl/top/tang_audio_top.v` - prosty tor testowy,
- `rtl/top/tang_audio_control_top.v` - test przyciskow i glosnosci,
- `rtl/top/tang_audio_eq_top.v` - test DAFX/EQ z lokalnym `test_mix_gen`,
- `rtl/top/tang_audio_selftest_top.v` - diagnostyka bez sprzetu zewnetrznego, z raportem UART.

Nie usuwac tych topow. Sa przydatne do debugowania bez ADC/DAC.

Docelowo dla toru pomiarowego potrzebny bedzie osobny top BYPASS ADC/DAC:

```text
PCM1808 -> i2s_rx_stereo -> audio_pipeline -> i2s_tx_stereo -> PCM5102A
```

Ten top nie powinien zgadywac pinow. Najpierw trzeba uzupelnic `docs/hardware_connections_todo.md` i plik `.cst` na podstawie faktycznego okablowania.
