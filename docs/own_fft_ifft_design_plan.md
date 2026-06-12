# Plan własnej implementacji FFT/IFFT w RTL

## 1. Cel

Celem jest przygotowanie własnego, sekwencyjnego rdzenia FFT/IFFT w RTL dla
ramek 256 próbek. Rdzeń ma być zrozumiały, możliwy do wyjaśnienia na obronie i
porównywalny z istniejącym modelem referencyjnym w Pythonie.

Dokument opisuje decyzje architektoniczne, algorytm, format danych, strukturę
sterowania i plan testów dla własnego rdzenia FFT/IFFT. Pierwsza wersja rdzenia
RTL jest wdrażana etapami jako osobne, małe PR-y.

## 2. Dlaczego własna FFT/IFFT

Własna implementacja lepiej pokazuje najważniejsze elementy projektu:

- znajomość algorytmu FFT/IFFT,
- projektowanie RTL,
- arytmetykę fixed-point,
- projektowanie FSM/FSMD,
- kontrolę przepływu danych w sprzęcie,
- integrację z rejestrami sterującymi i pipeline,
- weryfikację sprzętu względem modelu referencyjnego.

Gowin FFT IP pozostaje możliwą późniejszą optymalizacją albo wariantem
porównawczym. Nie jest jednak pierwszym wyborem implementacyjnym dla wersji
edukacyjnej i obronieniowej.

Obecne `fft_accel_wrapper.v` i `ifft_accel_wrapper.v` korzystają już ze
wspólnego `fft_radix2_core.v`: wrapper FFT używa `inverse=0`, a wrapper IFFT
używa `inverse=1`. Dla trybu IFFT dodano normalizację `1/N` dla `N = 256`,
realizowaną jako arytmetyczne przesunięcie w prawo o 8 bitów w stanie
wyjściowym rdzenia. Model bit-exact w Pythonie i testbenche Verilog zostały
zaktualizowane tak, aby odpowiadały tej wersji RTL.

## 3. Wybór algorytmu

Planowany algorytm to FFT radix-2 dla rozmiaru:

```text
N = 256
```

Dla tego rozmiaru:

- liczba etapów wynosi `log2(256) = 8`,
- w każdym etapie jest `N / 2 = 128` operacji butterfly,
- łączna liczba operacji butterfly wynosi `128 * 8 = 1024`.

Pierwsza wersja ma być sekwencyjna, nie w pełni potokowa. Oznacza to, że jeden
lub kilka zasobów arytmetycznych będzie używanych wielokrotnie przez wiele
cykli zegara.

## 4. Przepływ danych

Docelowy przepływ po dodaniu własnych rdzeni:

```text
sample_block_buffer
    -> own_fft_radix2_core
    -> spectral_processor
    -> own_ifft_radix2_core
    -> output sample
```

Integracja może zostać wykonana przez obecne wrappery:

```text
fft_accel_wrapper
    -> own_fft_radix2_core

ifft_accel_wrapper
    -> own_ifft_radix2_core
```

Dzięki temu reszta projektu zachowuje stabilny interfejs, a wewnętrzna
implementacja wrapperów może używać własnego rdzenia FFT/IFFT albo w przyszłości
wariantu porównawczego z Gowin FFT IP.

## 5. Interfejs rdzenia

Proponowany interfejs rdzenia powinien być zgodny z obecnymi wrapperami:

```verilog
input  wire clk
input  wire rst
input  wire start
input  wire inverse
input  wire in_valid
input  wire [7:0] in_index
input  wire signed [DATA_WIDTH-1:0] real_in
input  wire signed [DATA_WIDTH-1:0] imag_in

output wire out_valid
output wire [7:0] out_index
output wire signed [DATA_WIDTH-1:0] real_out
output wire signed [DATA_WIDTH-1:0] imag_out
output wire busy
output wire done
```

Sygnał `inverse` może wybrać tryb FFT albo IFFT. Dokładny interfejs może zostać
dopracowany podczas implementacji, ale powinien pozostać zgodny funkcjonalnie z
obecnym modelem `start -> busy -> done`.

## 6. Organizacja pamięci

Rdzeń będzie potrzebował bufora 256 próbek zespolonych:

- pamięć `real_mem[0:255]`,
- pamięć `imag_mem[0:255]`,
- licznik zapisu wejścia,
- licznik etapów FFT,
- liczniki indeksów butterfly,
- licznik odczytu wyjścia.

Możliwe są dwa warianty:

- obliczenia in-place, czyli wynik butterfly nadpisuje te same komórki pamięci,
- bufor pomocniczy dla prostszej kontroli kolejności.

Pierwsza wersja powinna preferować prostotę i czytelność. Jeżeli in-place będzie
czytelne w RTL, można go użyć. Jeżeli utrudni debug, warto rozważyć bufor
pomocniczy.

## 7. Butterfly radix-2

Podstawowa operacja butterfly:

```text
a' = a + W * b
b' = a - W * b
```

`W` jest współczynnikiem twiddle factor. Dla liczb zespolonych:

```text
a = ar + j*ai
b = br + j*bi
W = wr + j*wi
```

Mnożenie zespolone `W * b` wymaga:

```text
real = br * wr - bi * wi
imag = br * wi + bi * wr
```

W RTL oznacza to co najmniej cztery mnożenia i dwa dodawania/odejmowania, chyba
że później zostanie użyta zoptymalizowana wersja mnożnika zespolonego.

## 8. Twiddle factors

Twiddle factors powinny być przechowywane w osobnym ROM, np.:

```text
fft_twiddle_rom.v
```

Współczynniki można zapisać jako wartości fixed-point:

- Q1.15 dla sin/cos z zakresem około `[-1.0, 1.0)`,
- albo Q2.14, jeżeli wygodniej dopasować do obecnego formatu gainów.

Dla FFT używane są współczynniki:

```text
W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)
```

Dla IFFT można użyć sprzężenia zespolonego albo przeciwnego znaku części
urojonej:

```text
W_N^-k = cos(2*pi*k/N) + j*sin(2*pi*k/N)
```

Dokładny format ROM powinien być zgodny z Pythonowym generatorem wartości
referencyjnych, aby testy mogły wykrywać błędy kwantyzacji.

## 9. Fixed-point i skalowanie

Wejściowe próbki audio są signed 16-bit. Obliczenia FFT mogą jednak wymagać
większej szerokości wewnętrznej, np. 24 albo 32 bity, ponieważ suma butterfly
zwiększa zakres sygnału.

Proponowane zasady:

- wejście: signed 16-bit,
- twiddle factors: Q1.15 albo Q2.14,
- produkty mnożenia: szerszy format pośredni,
- akumulacja: co najmniej 24 lub 32 bity,
- po etapach FFT opcjonalne przesunięcie w prawo,
- wynik końcowy: saturacja do signed 16-bit.

Skalowanie można wykonać:

- po każdym etapie, aby ograniczać overflow,
- tylko na końcu, jeżeli szerokość wewnętrzna wystarczy,
- adaptacyjnie w późniejszej wersji.

Pierwsza wersja powinna wybrać prosty i łatwy do wyjaśnienia wariant, nawet
kosztem mniejszej dynamiki sygnału.

## 10. IFFT

Są dwie sensowne opcje implementacji IFFT:

1. Wspólny rdzeń z trybem `inverse=1`.
2. Metoda matematyczna:

```text
IFFT(x) = conj(FFT(conj(x))) / N
```

Dla `N = 256` dzielenie przez `N` jest obecnie wykonywane jako arytmetyczne
przesunięcie o 8 bitów w prawo na wyjściu trybu `inverse`. Forward FFT nie jest
normalizowana. Dalsze wersje mogą dodać skalowanie etapowe lub saturację, ale
obecny krok utrzymuje minimalną zmianę: tylko końcową normalizację IFFT.

Wersja z trybem `inverse` jest wygodna sprzętowo, bo pozwala współdzielić ROM,
liczniki, mnożnik zespolony i logikę butterfly.

## 11. FSM/FSMD

Rdzeń powinien być wielocyklowym FSMD, czyli połączeniem automatu sterującego i
ścieżki danych. Proponowane stany:

- `IDLE`,
- `LOAD`,
- `BIT_REVERSE` albo `REORDER`,
- `COMPUTE_STAGE`,
- `COMPUTE_BUTTERFLY`,
- `SCALE`,
- `OUTPUT`,
- `DONE`.

Typowy przebieg:

```text
start -> busy=1 -> load frame -> reorder -> compute stages -> output -> done
```

`done` powinien być impulsem albo stanem jasno opisanym w wrapperze. Obecne
moduły projektu oczekują semantyki, w której przetwarzanie jest widoczne przez
`busy`, a zakończenie przez `done`.

## 12. Bit reversal / kolejność próbek

FFT radix-2 wymaga świadomej decyzji o kolejności danych:

- wejście natural order i wyjście bit-reversed,
- albo wejście bit-reversed i wyjście natural order.

Dla pierwszej wersji najbardziej czytelny jest jawny etap bit-reversal. Rdzeń
może przyjmować próbki w naturalnej kolejności, przepisać je do pamięci według
odwróconych bitów indeksu, a potem wykonać kolejne etapy FFT.

Dla `N = 256` indeks ma 8 bitów, więc bit reversal oznacza odwrócenie kolejności
bitów indeksu:

```text
index[7:0] -> {index[0], index[1], ..., index[7]}
```

Tę funkcję warto osobno przetestować, bo błędy kolejności są jednymi z
najczęstszych problemów w FFT.

## 13. Plan testowania

Testy powinny wykorzystać istniejące narzędzia:

- `tools/fft_reference_model.py`,
- `tools/generate_fft_test_vectors.py`,
- `tools/compare_fft_pipeline_outputs.py`.

Obecnie RTL jest porównywany z modelem aktualnego toru:

```text
FFT core -> spectral gain -> normalized IFFT core
```

Model floating-point `math_reference_model` pozostaje punktem odniesienia dla
analizy jakości, ale testy PASS/FAIL używają bit-exact modelu RTL. Należy
testować co najmniej:

- impuls,
- sygnał stały,
- pojedynczy bin niskiego pasma,
- pojedynczy bin średniego pasma,
- pojedynczy bin wysokiego pasma,
- sygnał mieszany,
- przypadki bliskie saturacji.

Wyniki RTL mogą różnić się od modelu floating-point przez fixed-point i
kwantyzację twiddle factors. Test powinien używać tolerancji liczbowej zamiast
oczekiwać idealnej zgodności bit-do-bitu.

## 14. Etapy implementacji

Proponowana kolejność prac:

1. `fft_twiddle_rom.v`
2. `complex_mult.v`
3. `fft_radix2_core.v`
4. `fft_radix2_core_tb.v`
5. tryb `inverse`
6. `ifft_radix2_core_tb.v` albo wspólny test FFT/IFFT
7. podłączenie do wrapperów
8. normalizację IFFT `1/N`
9. porównanie CSV z bit-exact modelem RTL

Warto utrzymać małe PR-y. Każdy nowy moduł powinien mieć własny testbench i
czytelny raport `STATUS=PASS` albo `STATUS=FAIL`.

## 15. Ryzyka

Najważniejsze ryzyka techniczne:

- overflow w etapach butterfly,
- błędy skalowania,
- błędny bit-reversal,
- pomylony znak części urojonej twiddle factors,
- niewystarczająca precyzja twiddle factors,
- wydłużony czas symulacji,
- większe zużycie DSP/LUT,
- różnice względem modelu Python wynikające z fixed-point,
- trudniejsze debugowanie niż w modelach passthrough.

Ryzyka należy ograniczać przez małe kroki implementacyjne, testy jednostkowe i
porównanie CSV z modelem referencyjnym.

## 16. Decyzja projektowa

Projekt będzie rozwijany tak, aby posiadał własny rdzeń FFT/IFFT jako wersję
edukacyjną i obronieniową. Taki rdzeń lepiej pokazuje algorytm, strukturę RTL,
arytmetykę fixed-point i proces weryfikacji.

Gowin FFT IP pozostaje w projekcie jako opcja późniejszej optymalizacji albo
wariant porównawczy. Scaffold i checklisty dla Gowin IP są nadal przydatne, ale
nie zastępują planu własnej implementacji.

## 17. Status przed testem sprzętowym

Aktualny stan jest przygotowany do lokalnej próby syntezy w Gowin EDA i do
pierwszych testów na Tang Nano, ale nie oznacza jeszcze potwierdzenia
sprzętowego. W tym PR nie wygenerowano bitstreamu, nie uruchomiono Place & Route
i nie zmierzono zasobów ani timingów. Użytkownik powinien lokalnie uruchomić
Gowin, zebrać raport wykorzystania LUT/FF/B-SRAM/DSP oraz raport timing/Fmax,
a następnie wkleić wyniki z powrotem do dalszej analizy.
