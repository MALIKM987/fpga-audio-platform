# Analiza problemu DSP

## Sygnał dyskretny i ramka

System przetwarza dyskretny sygnał audio reprezentowany jako ramka 256 próbek.
Każda próbka przesyłana do FPGA jest signed int16. Dla domyślnego
`Fs = 48000 Hz` jedna ramka opisuje krótki fragment sygnału, a rozdzielczość
widma wynosi:

```text
bin_spacing = Fs / N = 48000 / 256 = 187.5 Hz
```

Granica Nyquista to `24000 Hz`.

## DFT i IDFT

Dyskretna transformata Fouriera opisuje ramkę czasową jako zbiór zespolonych
składowych częstotliwościowych:

```math
X[k] = \sum_{n=0}^{N-1} x[n] e^{-j2\pi kn/N}
```

Odwrotna transformata wraca do dziedziny czasu:

```math
x[n] = \frac{1}{N} \sum_{k=0}^{N-1} X[k] e^{j2\pi kn/N}
```

Bezpośrednia DFT wymaga około `N^2` operacji zespolonych. Dla `N = 256` daje to
65536 kombinacji próbek i binów. FFT radix-2 wykorzystuje strukturę motylkową
i zmniejsza złożoność do rzędu `N log2(N)`, czyli dla 256 punktów do znacznie
mniejszej liczby etapów sprzętowych.

## FFT i IFFT w projekcie

FFT zamienia ramkę czasową na biny częstotliwościowe. Po modyfikacji widma IFFT
zamienia dane z powrotem na próbki czasowe. W projekcie tor logiczny jest
następujący:

```text
input frame
    -> FFT
    -> spectral processor
    -> IFFT
    -> output frame
```

Aktualna implementacja sprzętowa jest ramkowa. Nie ma jeszcze fizycznego
ciągłego wejścia I2S ani strumieniowej obróbki próbka-po-próbce.

## Rozdzielczość binów i leakage

Dla `N = 256` i `Fs = 48000 Hz`:

```text
bin_spacing = 187.5 Hz
1000 Hz / 187.5 Hz = 5.333...
```

Sygnał 1000 Hz nie trafia dokładnie w pojedynczy bin FFT. Najbliższe biny to
5 i 6, więc energia rozlewa się na sąsiednie biny. To zjawisko nazywa się
spectral leakage. W testach oznacza to, że porównanie FPGA-vs-float nie powinno
opierać się na założeniu, że cała energia sinusoidy 1000 Hz znajduje się w jednym
binie.

Przykład:

```text
N = 256
Fs = 48000 Hz
bin_spacing = 187.5 Hz
1000 Hz -> bin około 5.333
nearest bins: 5 and 6
```

Dla testów stricte bin-centered wygodniej wybierać częstotliwości będące
wielokrotnością 187.5 Hz.

## Modyfikacja widma

Lokalny model PC może opisywać modyfikacje jako dowolne pasma:

```text
center_frequency_hz, bandwidth_hz, gain
```

Aktualne FPGA upraszcza to do trzech pasm:

```text
BASS   effective_bin <= 1
MID    effective_bin 2..21
TREBLE effective_bin >= 22
```

`effective_bin` uwzględnia symetrię widma:

```text
effective_bin = min(bin_index, N - bin_index)
```

To uproszczenie jest świadomą decyzją implementacyjną: pozwala pokazać pełny
przepływ PC -> FPGA -> PC bez budowania ogólnego edytora widma w RTL.

## Fixed-point, wzrost wartości i saturacja

FPGA liczy w arytmetyce stałoprzecinkowej. Próbki wejściowe i wyjściowe są
signed int16, a gain jest signed Q2.14:

```text
1.0 = 16384
0.5 = 8192
1.8 = 29491
max = 32767 = 1.99994
min = -32768 = -2.0
```

Wartości wewnętrzne FFT mogą być większe niż amplituda pojedynczej próbki
czasowej, ponieważ bin FFT jest sumą wielu próbek przemnożonych przez współczynniki
zespolone. Dlatego rdzeń używa szerszych ścieżek wewnętrznych niż samo int16
wejścia/wyjścia, a końcowy wynik jest ograniczany saturacją do signed int16.

Kwantyzacja i saturacja wpływają na porównanie FPGA z modelem float:

- gainy spoza zakresu signed Q2.14 są obcinane,
- mnożenia fixed-point wprowadzają zaokrąglenia,
- saturacja ogranicza próbki przekraczające zakres int16,
- wynik bit-exact/fixed-point jest właściwszym odniesieniem niż idealny model
  zmiennoprzecinkowy.

Lokalny model float może liczyć z gainem 4.0 albo 10.0, ale FPGA nie może
reprezentować takich gainów w Q2.14. Dlatego wynik ideal-float i wynik FPGA mogą
się różnić. Poprawnym odniesieniem dla sprzętu jest model fixed-point zgodny
z RTL.

## Dlaczego FPGA

FFT/IFFT i modyfikacja widma są naturalnymi kandydatami do implementacji
sprzętowej:

- operują na powtarzalnych blokach danych,
- korzystają z wielu prostych operacji arytmetycznych,
- mają dobrze określone stany `start`, `busy`, `done`,
- mogą być sterowane przez mały procesor i rejestry MMIO,
- są łatwe do testowania wektorami referencyjnymi.
