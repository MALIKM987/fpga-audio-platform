# Model fixed-point

FPGA nie liczy w idealnym float. Aktualny tor DSP jest stałoprzecinkowy i musi
być porównywany z modelem fixed-point zgodnym z RTL.

## Reprezentacja próbek

Próbki wejściowe i wyjściowe są signed int16:

```text
min = -32768
max =  32767
```

Wyniki pośrednie w FFT/IFFT używają szerszych ścieżek wewnętrznych i saturacji w
krytycznych miejscach.

## Format gain Q2.14

Gainy `BASS`, `MID`, `TREBLE` są signed 16-bit Q2.14:

```text
1.00 -> 16384
0.50 -> 8192
1.80 -> 29491
2.00 -> 32767 po saturacji dodatniej
```

Zakres:

```text
min = -32768 / 16384 = -2.0
max =  32767 / 16384 =  1.99993896484375
```

Gain `>= 2.1` nie jest reprezentowalny w aktualnym formacie.
FPGA zachowuje się wtedy jak gain bliski `2.0`.

