# Aplikacja PC Spectrum Lab

PC Spectrum Lab jest aplikacją Tkinter uruchamianą z katalogu repozytorium:

```powershell
python tools/spectrum_lab_app.py
```

## Tryby backendu

- `Local simulation` - idealny model float po stronie PC.
- `Mock FPGA backend` - backend protokołu UART bez sprzętu; zwraca loopback, nie
  wykonuje DSP.
- `Serial FPGA backend` - realny Tang Nano 20K przez UART.

Mock backend jest celowo prosty. Jeśli lokalna symulacja zmienia widmo, a mock
zwraca wejście, różnica `mock - local` jest oczekiwana.

## Format wejścia

Składowe sygnału:

```text
frequency_hz, amplitude, phase_rad
```

Przykład:

```text
1000, 0.25, 0
2700, 0.10, 0.3
```

Modyfikacje widma:

```text
center_frequency_hz, bandwidth_hz, gain
```

Przykład:

```text
1000, 600, 1.5
6200, 1200, 0.8
```

## Wykresy

GUI pokazuje sześć wykresów:

1. `Input signal` - wygenerowany sygnał wejściowy w dziedzinie czasu.
2. `Local float simulation` - idealny wynik PC-side spectrum modification.
3. `Mock FPGA backend` - wynik mock backendu.
4. `Serial FPGA backend` - wynik realnego FPGA, jeśli port jest dostępny.
5. `Mock - local difference` - różnica mock loopback minus ideal float.
6. `Serial - local difference` - różnica realnego FPGA minus ideal float.

Oś X to indeks próbki, a oś Y to znormalizowana amplituda.

## Presety

Aktualne presety:

- `Sine gain 1.0`
- `Sine gain 0.5`
- `Sine gain 1.8`
- `Sine gain 2.0 limit`
- `Gain clipping demo 4.0`
- `Multitone moderate`
- `Multitone near limit`
- `Same band warning demo`
- `Nyquist warning demo`

Presety pomagają szybko pokazać normalne przypadki, granice Q2.14, clipping,
multitone, kolizję pasm i przekroczenie Nyquista.

## Ostrzeżenia

GUI raportuje:

- częstotliwość powyżej Nyquista,
- clipping wejścia lub wyjścia,
- gain większy niż `+1.99994`,
- gain mniejszy niż `-2.0`,
- kilka modyfikacji przypisanych do tego samego pasma sprzętowego,
- różnice fixed-point względem idealnego float.

## CSV export

Przycisk `Export samples` zapisuje CSV z wejściem, lokalnym wynikiem, wynikiem
mock, wynikiem serial i różnicami. Plik CSV jest użyteczny do raportów i dalszej
analizy w arkuszu kalkulacyjnym.

## Klient konsolowy

Do szybkiego testu bez GUI:

```powershell
python tools/spectrum_lab_uart_client.py --mock
python tools/spectrum_lab_uart_client.py --port COM6
```
