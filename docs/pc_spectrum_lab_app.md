# PC Spectrum Lab App

## Cel aplikacji

PC Spectrum Lab App to pierwszy front-end po stronie komputera dla obecnego
kierunku FPGA-only FFT/IFFT. Aplikacja generuje ramkę próbek, liczy lokalnie
DFT, nakłada proste modyfikacje widma, liczy IDFT i pokazuje wynik graficznie.
Aktualna wersja potrafi też porównać lokalny wynik z backendem Mock FPGA oraz,
jeśli użytkownik wybierze port, z backendem Serial FPGA.

## Miejsce w projekcie FPGA

Docelowy przepływ projektu ma wyglądać tak:

```text
PC app
    -> samples over UART
    -> Tang Nano UART RX
    -> mini CPU / MMIO control
    -> FFT/IFFT accelerator
    -> selected or full output over UART
    -> PC app plots and reports
```

Podstawowy lokalny model:

```text
PC app simulation
    -> generated 256-sample frame
    -> local DFT
    -> local spectrum modification
    -> local IDFT
    -> plots and int16 preparation
```

Porównanie z backendem:

```text
local output frame
    -> comparison metrics
FPGA backend output frame
    -> max abs error / mean abs error / RMS error
    -> difference plot
```

## Pliki

Model i aplikacja:

```text
tools/spectrum_lab_model.py
tools/spectrum_lab_comparison.py
tools/spectrum_lab_app.py
tools/spectrum_lab_demo.py
tools/test_spectrum_lab_model.py
tools/test_spectrum_lab_comparison.py
```

Model nie wymaga `numpy`, `scipy`, `matplotlib` ani `pyserial`.

## Tryby pracy

Aplikacja zawsze liczy lokalny wynik symulacji. Dla ramki 256 próbek może też
uruchomić backendy zgodne z protokołem pełnych ramek UART:

- `Local simulation` - tylko lokalny model Python jako punkt odniesienia.
- `Mock FPGA backend` - deterministyczny backend protokołu, który zwraca
  loopback wejścia.
- `Serial FPGA backend` - opcjonalny realny port UART, jeśli pyserial i piny
  sprzętowe są dostępne.

Mock backend nie jest modelem matematycznym FFT/IFFT. Jeżeli lokalna symulacja
zmienia widmo, a mock zwraca kopię wejścia, różnica `mock - local` jest
oczekiwana i widoczna w metrykach.

## Generowanie sygnału

Użytkownik może zdefiniować wiele składowych sinusoidalnych:

```text
frequency_hz, amplitude, phase_rad
```

Przykład:

```text
1000, 0.70, 0
2700, 0.35, 0.3
6200, 0.20, 0
```

Domyślne parametry:

- sample rate: `48000 Hz`,
- frame size: `256` próbek.

Częstotliwości nie muszą trafiać dokładnie w biny FFT. Jeżeli częstotliwość
nie pasuje do siatki binów, w widmie pojawi się naturalny spectral leakage.
Aplikacja tego nie ukrywa, bo jest to ważne zjawisko dla przyszłych testów
sprzętowych.

## Modyfikacje widma

Modyfikacje widma są definiowane jako proste pasma:

```text
center_frequency_hz, bandwidth_hz, gain
```

Przykład:

```text
1000, 300, 1.8
2700, 500, 0.5
```

Model zamienia pasma na maskę gainów dla binów DFT. Częstotliwość binu jest
liczona z uwzględnieniem symetrii widma:

```text
effective_frequency = min(k, N-k) * sample_rate / N
```

Dzięki temu pasmo obejmuje zarówno dodatnią, jak i lustrzaną część widma.

## Przygotowanie int16

Model potrafi przeliczyć próbki float na signed int16. Jest to przygotowanie
pod przyszły transfer ramek do FPGA:

- wartości są skalowane,
- wynik jest zaokrąglany,
- przekroczenia są saturacją ograniczane do zakresu `-32768..32767`,
- model raportuje, czy wystąpiło clipping.

W obecnym MVP int16 jest tylko przygotowaniem danych i diagnostyką. Nie ma
jeszcze transferu ramki do Tang Nano.

## GUI

Uruchomienie aplikacji:

```text
python tools/spectrum_lab_app.py
```

GUI używa standardowego `tkinter` i rysuje wykresy na `Canvas`, więc nie wymaga
`matplotlib`.

Minimalne funkcje:

- edycja składowych sygnału,
- edycja modyfikacji widma,
- ustawienie sample rate i frame size,
- przycisk `Generate / Simulate`,
- przycisk `Clear`,
- eksport próbek do CSV,
- wykres wejścia w dziedzinie czasu,
- wykres lokalnego wyjścia po symulacji,
- wykres wyniku Mock FPGA backend,
- wykres wyniku Serial FPGA backend, jeśli został uruchomiony,
- wykres różnicy `mock - local`,
- wykres różnicy `serial - local`, jeśli serial jest dostępny,
- status z clippingiem i metrykami `max abs`, `mean abs`, `RMS error`.

## CLI demo

Bez GUI można uruchomić demonstrację:

```text
python tools/spectrum_lab_demo.py
```

Demo przygotowuje też lokalnie pakiety `WRITE_FRAME_CHUNK` dla wygenerowanej
ramki signed int16 i wypisuje, ile chunków zostałoby wysłanych. Pakiety nie są
jeszcze wysyłane do FPGA.

Opcjonalny eksport CSV:

```text
python tools/spectrum_lab_demo.py --csv spectrum_demo.csv
```

## Testy

Model nie-GUI jest testowany przez:

```text
python tools/test_spectrum_lab_model.py
python tools/test_spectrum_lab_comparison.py
```

Pełny runner projektu:

```text
python tools/run_all_tests.py
```

Test sprawdza:

- generowanie dokładnie `N` próbek,
- bezpieczną konwersję do signed int16,
- długość wektora magnitude DFT,
- zmianę oczekiwanego fragmentu widma po nałożeniu gain band,
- długość wyjścia IDFT,
- pełny przebieg modelu bez zależności GUI.
- metryki porównawcze `max abs`, `mean abs`, `RMS error`,
- ścieżkę Mock FPGA backend i oczekiwaną różnicę względem lokalnej symulacji.

## Ograniczenia

Ten etap nie dodaje:

- sterowania sprzętem Tang Nano z GUI,
- fizycznego I2S,
- AXI-Lite,
- Gowin FFT IP,
- zmian w RTL FFT/IFFT, mini CPU ani `uart_cpu_fft_console`.

## Następne kroki

Rekomendowane kolejne branche:

```text
codex/tang-uart-constraints
codex/uart-frame-protocol
codex/pc-app-uart-fpga-backend
```
