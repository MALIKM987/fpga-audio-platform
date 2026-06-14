# Kalibracja modelu fixed-point FPGA

Ten dokument opisuje relację między trzema wynikami:

1. lokalną symulacją ideal-float w aplikacji PC Spectrum Lab,
2. lokalnym modelem fixed-point zgodnym z RTL,
3. realnym wynikiem FPGA odczytanym przez UART z Tang Nano 20K.

Zakres tej gałęzi nie zmienia protokołu UART, mailboxa, mini CPU ani rdzenia
FFT/IFFT. Celem jest wyjaśnienie, kiedy FPGA powinno być porównywane z modelem
fixed-point zamiast z idealnym modelem float.

## Stan po PR #61 i PR #62

PR #61 naprawił problem skalowania IFFT, który wyglądał jak utrata starszego
bajtu wyniku i dawał int8-like output.

PR #62 poszerzył wewnętrzną ścieżkę FFT/IFFT do 24 bitów i dodał saturację w
krytycznych miejscach. Po fizycznym teście na Tang Nano 20K stary limit około
`-128..127` nie występuje już dla poprawionego bitstreamu. FPGA potrafi zwracać
pełne signed int16 próbki przez `READ_RESULT_CHUNK`.

## Format gain w FPGA

Aktualny UART frame protocol wysyła trzy wartości:

- `bass_gain`
- `mid_gain`
- `treble_gain`

Każda wartość jest signed 16-bit w formacie Q2.14.

```text
1.00 -> 16384
0.50 -> 8192
1.50 -> 24576
2.00 -> 32767 po saturacji
```

Zakres reprezentowalny:

```text
min = -32768 / 16384 = -2.0
max =  32767 / 16384 =  1.99993896484375
```

W praktyce dodatni gain większy niż około `2.0` nie jest obecnie
reprezentowalny. Aplikacja PC koduje go przez saturację do `32767`.

Oznacza to:

- `gain=4` nie jest wysyłany jako 4.0,
- `gain=10` nie jest wysyłany jako 10.0,
- oba przypadki trafiają do FPGA jako około `1.99994`.

To jest poprawne dla obecnego formatu Q2.14, ale nie odpowiada idealnej
symulacji float, która dalej może liczyć z gainem 4.0 lub 10.0.

## Różnica modelu float i sprzętu

Lokalny model float w PC Spectrum Lab obsługuje dowolne pasma:

```text
center_frequency_hz, bandwidth_hz, gain
```

Model sprzętowy FPGA ma obecnie tylko trzy pasma:

```text
BASS   effective_bin <= 1
MID    effective_bin 2..21
TREBLE effective_bin >= 22
```

Dla `Fs = 48 kHz` i `N = 256` rozdzielczość binu wynosi `187.5 Hz`, więc:

- BASS obejmuje okolice `0..187.5 Hz`,
- MID obejmuje okolice `375..3937.5 Hz`,
- TREBLE obejmuje resztę widma dodatniego.

Jeżeli GUI ma kilka modyfikacji wpadających w to samo pasmo sprzętowe, FPGA
dostaje tylko jeden gain dla tego pasma. Obecne mapowanie zachowuje się tak, że
późniejsza modyfikacja dla danego pasma wygrywa.

Przykład:

```text
1000 Hz gain 1.5 -> MID
2700 Hz gain 0.5 -> MID
```

Hardware nie może zastosować jednocześnie `1.5` dla 1000 Hz i `0.5` dla
2700 Hz, bo oba leżą w MID. Do FPGA trafia jeden `mid_gain`.

## Wyniki CSV po PR #62

Do analizy użyto dostępnych eksportów:

- `REAL_PR62_TG1_sine_0015_gain05_boundary.csv`
- `REAL_PR62_TG2_sine_0001_gain4_boundary.csv`
- `REAL_PR62_TG3_sine_0003_gain10_fail.csv`
- `REAL_PR62_TG4_multitone_near_overload.csv`

Pliki nie są commitowane do repo. Są lokalnymi wynikami pomiarów sprzętowych.

### TG1: sine 0.015, gain 0.5

```text
gains_float: bass=1.0 mid=0.5 treble=1.0
input_range:       -492..492
local_float_range: -271..366
local_fixed_range: -258..339
serial_range:      -258..339
```

Wynik:

```text
local_float_vs_fpga max_abs_error=102 rms=28.677 corr=0.988155
local_fixed_vs_fpga max_abs_error=0   rms=0.000  corr=1.000000
```

### TG2: sine 0.001, requested gain 4

```text
requested gain=4.0
effective FPGA gain=1.99993896484375
local_float_range: -144..140
local_fixed_range: -70..67
serial_range:      -70..67
```

Wynik:

```text
local_float_vs_fpga max_abs_error=77 rms=45.886 corr=0.992051
local_fixed_vs_fpga max_abs_error=0  rms=0.000  corr=1.000000
```

`gain=4` nie ma prawa zgadzać się z idealną lokalną symulacją float, bo FPGA
nie może reprezentować gainu 4.0 w signed Q2.14.

### TG3: sine 0.003, requested gain 10

```text
requested gain=10.0
effective FPGA gain=1.99993896484375
local_float_range: -1099..1067
local_fixed_range: -207..199
serial_range:      -207..199
```

Wynik:

```text
local_float_vs_fpga max_abs_error=895 rms=546.690 corr=0.987942
local_fixed_vs_fpga max_abs_error=0   rms=0.000   corr=1.000000
```

`gain=10` jest poza obecnym zakresem sprzętowego gainu. To jest przypadek
testujący limit formatu, a nie awaria UART ani FFT.

### TG4: multitone near-overload

Użyte modyfikacje GUI:

```text
1000 Hz  gain 1.8 -> MID
2000 Hz  gain 1.6 -> MID, nadpisuje wcześniejszy MID
4500 Hz  gain 1.4 -> TREBLE
9000 Hz  gain 1.2 -> TREBLE
15000 Hz gain 1.0 -> TREBLE, nadpisuje wcześniejszy TREBLE
```

Efektywnie FPGA używa:

```text
bass=1.0
mid=1.599976
treble=1.0
```

Wynik:

```text
input_range:       -364..309
local_float_range: -553..479
local_fixed_range: -496..422
serial_range:      -496..422

local_float_vs_fpga max_abs_error=88 rms=34.374 corr=0.991856
local_fixed_vs_fpga max_abs_error=0  rms=0.000  corr=1.000000
```

To potwierdza, że fizyczny FPGA pasuje do modelu fixed-point dla aktualnej
architektury trzech pasm.

## Automatyczny sweep gainu

Dodano test:

```text
tools/test_fpga_fixed_point_reference_calibration.py
```

Test używa wejścia:

```text
1000 Hz, amplitude 0.001, phase 0
```

oraz modyfikacji:

```text
1000 Hz, bandwidth 1000 Hz, gain sweep
```

Sprawdzane gainy:

```text
0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0, 10.0
```

Najważniejszy wynik:

```text
gain=2.0  -> encoded_q2_14=32767 fixed_peak=70
gain=3.0  -> encoded_q2_14=32767 fixed_peak=70
gain=4.0  -> encoded_q2_14=32767 fixed_peak=70
gain=8.0  -> encoded_q2_14=32767 fixed_peak=70
gain=10.0 -> encoded_q2_14=32767 fixed_peak=70
```

To jest oczekiwane zachowanie obecnego sprzętu.

## Narzędzie porównawcze CSV

Dodano:

```text
tools/compare_float_fixed_fpga.py
```

Przykłady:

```powershell
python tools/compare_float_fixed_fpga.py `
  --mod 1000,1000,0.5 `
  C:\Users\molik\Downloads\REAL_PR62_TG1_sine_0015_gain05_boundary.csv
```

```powershell
python tools/compare_float_fixed_fpga.py `
  --mod 1000,1000,4.0 `
  C:\Users\molik\Downloads\REAL_PR62_TG2_sine_0001_gain4_boundary.csv
```

```powershell
python tools/compare_float_fixed_fpga.py `
  --mod 1000,700,1.8 `
  --mod 2000,700,1.6 `
  --mod 4500,1000,1.4 `
  --mod 9000,1500,1.2 `
  --mod 15000,2000,1.0 `
  C:\Users\molik\Downloads\REAL_PR62_TG4_multitone_near_overload.csv
```

Narzędzie wypisuje:

- zakres wejścia,
- zakres local float,
- zakres local fixed,
- zakres serial FPGA,
- `max_abs_error`,
- `mean_abs_error`,
- `RMS error`,
- korelację,
- best-fit scale factor,
- największe błędy próbek.

## Rekomendowany zakres pracy

Na obecnym etapie bezpieczny i zgodny z formatem sprzętowym zakres gainu to:

```text
0.0 .. 1.9999
```

Rekomendowany zakres użytkowy dla testów PC -> FPGA:

```text
0.25 .. 1.8
```

Wartości powyżej `~2.0` powinny być traktowane jako poza zakresem obecnego
formatu Q2.14. GUI pokazuje ostrzeżenie, że taki gain zostanie przycięty.

## Widoczność ograniczeń w GUI

PC Spectrum Lab App pokazuje teraz te ograniczenia bezpośrednio w interfejsie:

- panel fixed-point przypomina format signed Q2.14, zakres `-2.0..+1.99994`,
  zalecany zakres `0.25..1.8`, rozmiar ramki 256, `Fs = 48000 Hz` i Nyquista
  `24000 Hz`,
- presety `Sine gain 2.0 limit` oraz `Gain clipping demo 4.0` pokazują granicę
  dodatniego gainu,
- preset `Same band warning demo` pokazuje, że kilka pasm GUI może trafić do
  jednego sprzętowego pasma BASS/MID/TREBLE,
- preset `Nyquist warning demo` pokazuje ostrzeżenie dla częstotliwości powyżej
  Nyquista,
- status GUI rozdziela wynik lokalny ideal-float, mock loopback i realny serial
  FPGA fixed-point.

Mock backend nadal zwraca loopback wejścia, więc jego różnica względem lokalnej
symulacji float jest oczekiwana. Serial FPGA backend należy porównywać z
uwzględnieniem fixed-point Q2.14 i aktualnego sprzętowego mapowania
BASS/MID/TREBLE.

Rekomendowany zakres amplitudy zależy od liczby składowych i gainu. Po PR #62
pojedyncze sinusy testowane do około `0.015` działały poprawnie dla gainu
`0.5`, a złożony test TG4 zachował bardzo dobrą zgodność z fixed-point modelem.
Do dalszych testów fizycznych warto używać:

```text
single sine: 0.001 .. 0.015
multitone:  0.00025 .. 0.004 na składową, zależnie od liczby komponentów
gain:       0.25 .. 1.8
```

## Ograniczenia

Obecny sprzętowy backend nie jest jeszcze ogólnym edytorem widma. Ma tylko trzy
gainy pasmowe. Lokalna symulacja float nadal jest przydatna jako eksperyment
matematyczny, ale do porównania z realnym FPGA należy używać modelu
fixed-point.

Jeżeli projekt ma naprawdę obsługiwać `gain=4` albo `gain=10`, potrzebna będzie
osobna gałąź zmieniająca format gainu, na przykład na szerszy format albo
osobne skalowanie amplitudy. To nie powinno być robione w tej gałęzi
kalibracyjnej.

## Następne kroki

Rekomendowane kolejne testy fizyczne:

- powtórzyć TG1-TG4 po merge tej dokumentacji i narzędzi,
- dodać test `gain=1.8` dla pojedynczego tonu i kilku amplitud,
- dodać test wielu modyfikacji w tym samym paśmie, żeby potwierdzić semantykę
  "last gain wins",
- w GUI pokazywać obok ideal-float także wynik local fixed-point jako główny
  punkt odniesienia dla FPGA.
