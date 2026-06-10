# Model referencyjny FFT/IFFT

## Cel

`tools/fft_reference_model.py` jest czystym Pythonowym modelem referencyjnym dla
toru:

```text
DFT -> spectral gain -> IDFT
```

Model ma służyć jako golden model do późniejszego porównania wyników z Gowin FFT
IP albo własną implementacją RTL FFT/IFFT. Nie zastępuje obecnych modułów RTL i
nie oznacza jeszcze, że `fft_accel_wrapper.v` lub `ifft_accel_wrapper.v`
wykonują prawdziwą FFT/IFFT.

## Zakres

Model implementuje bez zewnętrznych bibliotek:

- bezpośrednią DFT,
- bezpośrednią IDFT,
- mapowanie binów na pasma `BASS`, `MID`, `TREBLE`,
- gainy w formacie Q2.14,
- pełne przetwarzanie ramki przez DFT, gain widmowy i IDFT,
- zaokrąglenie oraz saturację do signed 16-bit.

Bezpośrednia DFT/IDFT ma złożoność O(N²). To jest celowe: model ma być prosty i
czytelny matematycznie, a nie szybki.

## Mapowanie pasm

Dla `FFT_SIZE = 256` efektywny bin jest liczony tak samo jak w RTL:

```text
effective_bin = min(bin_index, FFT_SIZE - bin_index)
```

Podział pasm:

- `BASS`: `effective_bin <= 1`
- `MID`: `effective_bin` od `2` do `21`
- `TREBLE`: `effective_bin >= 22`

Dzięki temu biny lustrzane, np. `255`, `246` i `216`, trafiają odpowiednio do
tych samych pasm co `1`, `10` i `40`.

## Q2.14

Gainy są zgodne z formatem Q2.14 używanym w RTL:

```text
8192  -> 0.50
12288 -> 0.75
16384 -> 1.00
24576 -> 1.50
```

Domyślne ustawienia modelu:

- `BASS = 24576`, czyli `1.50`
- `MID = 16384`, czyli `1.00`
- `TREBLE = 12288`, czyli `0.75`

## Testy

Test `tools/test_fft_reference_model.py` sprawdza:

- DFT/IDFT dla impulsu,
- DFT/IDFT dla sygnału stałego,
- mapowanie pasm i binów lustrzanych,
- konwersję Q2.14,
- saturację signed 16-bit,
- przetwarzanie ramek `single_bin_low`, `single_bin_mid`, `single_bin_high`
  oraz `mixed`.

Uruchomienie pełnego zestawu:

```powershell
python tools/run_all_tests.py
```

Jeżeli lokalnie nie ma `iverilog` albo `vvp`, runner nadal uruchomi testy
Pythonowe i oznaczy część Verilog jako `STATUS=SKIPPED`.

## Następny etap

Następnym krokiem będzie porównanie wyników przyszłego Gowin FFT IP albo RTL
FFT/IFFT z tym modelem referencyjnym. Dopiero wtedy wrappery passthrough powinny
zostać zastąpione rzeczywistą implementacją obliczeń.
