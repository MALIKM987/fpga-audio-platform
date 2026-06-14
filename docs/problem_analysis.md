# Analiza problemu DSP

## Sygnał dyskretny i ramka

System przetwarza dyskretny sygnał audio reprezentowany jako ramka 256 próbek.
Każda próbka przesyłana do FPGA jest signed int16. Dla domyślnego
`Fs = 48000 Hz` jedna ramka opisuje krótki fragment sygnału, a rozdzielczość
widma wynosi:

```text
bin_hz = Fs / N = 48000 / 256 = 187.5 Hz
```

Granica Nyquista to `24000 Hz`.

## FFT i IFFT

FFT zamienia ramkę czasową na zbiór zespolonych binów częstotliwościowych. Po
modyfikacji widma IFFT zamienia dane z powrotem na próbki czasowe. W projekcie
tor logiczny jest następujący:

```text
input frame
    -> FFT
    -> spectral processor
    -> IFFT
    -> output frame
```

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
przepływ PC -> FPGA -> PC bez budowania ogólnego edytora widma.

## Fixed-point

FPGA liczy w arytmetyce stałoprzecinkowej. Próbki wejściowe i wyjściowe są
signed int16, a gain jest signed Q2.14:

```text
1.0 = 16384
0.5 = 8192
1.8 = 29491
max = 32767 = 1.99994
min = -32768 = -2.0
```

Lokalny model float może liczyć z gainem 4.0 albo 10.0, ale FPGA nie może
reprezentować takich gainów w Q2.14. Dlatego wynik ideal-float i wynik FPGA mogą
się różnić. Poprawnym odniesieniem dla sprzętu jest model fixed-point zgodny z
RTL.

## Dlaczego FPGA

FFT/IFFT i modyfikacja widma są naturalnymi kandydatami do implementacji
sprzętowej:

- operują na powtarzalnych blokach danych,
- korzystają z wielu prostych operacji arytmetycznych,
- mają dobrze określone stany `start`, `busy`, `done`,
- mogą być sterowane przez mały procesor i rejestry MMIO,
- są łatwe do testowania wektorami referencyjnymi.
