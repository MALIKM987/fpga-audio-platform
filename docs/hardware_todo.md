# Hardware TODO / Przyszłe Prace Sprzętowe

## Cel Dokumentu

Aktualny kierunek projektu to FPGA-only FFT/IFFT z testami sprawdzalnymi w
konsoli. Fizyczny tor audio jest odłożony do czasu, aż pipeline DSP będzie
stabilny w symulacji i self-teście.

Ten dokument zapisuje prace sprzętowe, do których trzeba wrócić później,
zamiast usuwać starsze pliki bring-up.

## Przyszła Warstwa Wejściowa: PCM1808 ADC

PCM1808 ADC pozostaje przyszłą fizyczną warstwą wejściową.

Przyszłe prace:

- potwierdzić bezpieczne poziomy napięć dla pinów FPGA,
- potwierdzić taktowanie i tryb master/slave,
- zaimplementować albo zweryfikować stabilny blok I2S RX,
- zapisywać próbki stereo L/R do buforów ramek/bloków,
- testować z dobrze znanym sygnałem analogowym,
- zweryfikować DATA, BCLK, LRCK i MCLK oscyloskopem albo analizatorem
  logicznym.

Pierwszy test sprzętowy wejścia powinien być prostym trybem BYPASS, a nie FFT.

## Przyszła Warstwa Wyjściowa: PCM5102A DAC

PCM5102A DAC pozostaje przyszłą fizyczną warstwą wyjściową.

Przyszłe prace:

- potwierdzić format i timing I2S,
- potwierdzić częstotliwości BCLK/LRCK,
- wysłać znane próbki testowe przed użyciem wyjścia FFT/IFFT,
- zweryfikować analogowe wyjścia L/R oscyloskopem,
- utrzymać napięcia na pinach FPGA w bezpiecznym zakresie.

## Prawdziwe Piny I2S

Istniejące notatki pinów i pliki constraints zostają jako materiał
referencyjny. Nie należy traktować ich jako aktywnych dla etapu FPGA-only
FFT/IFFT.

Przyszłe prace nad fizycznym I2S powinny potwierdzić:

- pin zegara,
- PCM5102A DIN/LRCK/BCLK,
- PCM1808 DATA/BCLK/LRCK/MCLK,
- opcjonalne wejścia przycisków,
- opcjonalny pin UART TX,
- ewentualne LED-y używane do diagnostyki.

Nie należy zgadywać pinów przy tworzeniu topu sprzętowego. Każdy top musi
pasować do aktywnego pliku constraints.

## Ograniczenia Aktualnej Wersji FPGA-Only

Aktualny kierunek FPGA-only celowo nie zawiera:

- fizycznego przechwytywania próbek z PCM1808,
- fizycznego odtwarzania przez PCM5102A,
- ciągłego streamingu audio czasu rzeczywistego,
- analogowego wyjścia zweryfikowanego oscyloskopem,
- windowing,
- overlap-add,
- finalnej integracji z IP FFT/IFFT.

Celem jest najpierw zweryfikowanie blokowej architektury FFT/IFFT.

## Przyszły Streaming Audio

Po zweryfikowaniu ścieżki blokowej FFT/IFFT projekt może dodać ciągły streaming
audio. Będzie to wymagało:

- buforowania próbek wejściowych,
- buforowania próbek wyjściowych,
- harmonogramu ramek,
- policzenia latencji,
- wykrywania underrun/overrun,
- przeglądu domen zegarowych i handshake, jeśli będą używane zewnętrzne zegary
  audio.

## Windowing i Overlap-Add

Windowing i overlap-add są przyszłymi funkcjami DSP. Należy dodać je dopiero po
uruchomieniu podstawowej ścieżki blokowej:

```text
input block -> FFT -> spectral modification -> IFFT -> output block
```

Planowane dodatki:

- wybór funkcji okna,
- nakładanie bloków,
- rekonstrukcja overlap-add,
- normalizacja gain,
- dodatkowe testy błędu rekonstrukcji.

## Testy Oscyloskopem

Testy oscyloskopem należą do późniejszego etapu sprzętowego.

Sugerowana kolejność:

1. raporty symulacji FPGA-only,
2. diagnostyka LED/UART self-testu na Tang Nano,
3. wyjście PCM5102A ze znanym sygnałem generowanym w FPGA,
4. przechwytywanie wejścia PCM1808,
5. BYPASS PCM1808 -> FPGA -> PCM5102A,
6. wstawienie pipeline FFT/IFFT do zweryfikowanego toru sprzętowego.

## Istniejące Pliki Sprzętowe Do Zachowania Jako Referencja

Te pliki mogą być przydatne, gdy projekt wróci do warstwy sprzętowej:

- `rtl/audio/i2s_tx.v`
- `rtl/audio/tone_gen.v`
- `rtl/top/tang_audio_top.v`
- `rtl/top/tang_audio_pcm5102a_test_top.v`
- `rtl/top/tang_audio_pcm5102a_scope_test_top.v`
- `rtl/top/tang_audio_buttons_volume_test_top.v`

Powiązane pliki constraints Gowin również mogą się przydać:

- `gowin_impl/tang_audio_hw/pcm5102a_test.cst`
- `gowin_impl/tang_audio_hw/buttons_volume_test.cst`
- `gowin_impl/tang_audio_hw/full_button_eq_future.cst`

Do czasu powrotu do integracji ADC/DAC należy traktować je jako materiał
legacy/referencyjny.
