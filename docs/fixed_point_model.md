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

Gain `2.1`, `4.0` albo `10.0` nie jest reprezentowalny w aktualnym formacie.
FPGA zachowuje się wtedy jak gain bliski `2.0`.

## Potwierdzone zachowanie

- `gain=1.8` działa jako zalecany wysoki, ale bezpieczny przypadek.
- `gain=2.0` jest praktycznym dodatnim limitem.
- `gain=2.1` saturuje do około `1.99994`.
- `gain=4.0` saturuje do około `1.99994`, a nie działa jak idealne 4.0.
- Kilka modyfikacji w tym samym paśmie sprzętowym używa semantyki
  "last one wins".
- Różnice local float vs FPGA są oczekiwane przy przekroczeniu limitów Q2.14 lub
  przy uproszczonym mapowaniu do `BASS/MID/TREBLE`.

## Wynik końcowy kalibracji

Wcześniejsze problemy z zakresem dynamicznym zostały rozwiązane w obecnym stanie
projektu:

- IFFT nie daje już wyniku wyglądającego jak int8/high-byte loss.
- Stary limit około `-128..127` nie obowiązuje dla poprawionego bitstreamu.
- Modele Python fixed-point zgadzają się z wynikami sprzętowymi w testach CSV.
- GUI pokazuje ostrzeżenia, gdy użytkownik prosi o zachowanie nieosiągalne dla
  obecnego formatu sprzętowego.

To nie jest opis błędu, tylko opis końcowego modelu numerycznego aktualnej
wersji.
