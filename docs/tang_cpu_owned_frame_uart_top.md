# Tang CPU-owned frame UART top

Ten etap dodaje top-level integrujący pełny protokół ramek UART z istniejącym
przepływem CPU-owned. Celem jest przygotowanie niskiego ryzyka wariantu pod
Tang Nano 20K, w którym PC Spectrum Lab App wysyła pełną ramkę próbek, a mini
CPU po stronie FPGA pozostaje jedynym blokiem sterującym akceleratorem FFT/IFFT.

## Top-level

Dodany top:

```text
rtl/top/tang_cpu_owned_frame_uart_top.v
```

Porty:

```verilog
input  wire clk
input  wire uart_rx
output wire uart_tx
output wire led
```

Domyślne parametry UART:

- `CLK_FREQ_HZ = 27_000_000`
- `BAUD_RATE = 115_200`
- format 8N1 przez istniejące `uart_rx.v` i `uart_tx.v`

## Architektura

Przepływ danych:

```text
PC Spectrum Lab App
    -> UART RX
    -> uart_rx
    -> uart_frame_packet_rx
    -> uart_frame_buffer_backend
    -> mini_cpu_uart_frame_system
    -> mini CPU
    -> fft_accelerator_mmio
    -> FFT/IFFT accelerator
    -> mini CPU writeback
    -> uart_frame_buffer_backend
    -> uart_frame_packet_tx
    -> uart_tx
    -> PC app
```

Najważniejsza zasada architektoniczna:

```text
PC ani UART backend nie sterują bezpośrednio fft_accelerator_mmio.
Jedynym właścicielem fft_accelerator_mmio pozostaje mini CPU.
```

UART backend pełni rolę mailboxa:

- zapisuje gainy,
- zapisuje wejściową ramkę 256 próbek,
- ustawia request po `RUN_FRAME`,
- udostępnia wynik zapisany przez mini CPU.

## Instancjonowane moduły

Top instancjonuje:

- `uart_rx`
- `uart_frame_packet_rx`
- `uart_frame_buffer_backend`
- `mini_cpu_uart_frame_system`
- `uart_frame_packet_tx`
- `uart_tx`

Nie instancjonuje `uart_cpu_fft_console`. Legacy ścieżka `A5 01 5A` pozostaje
osobnym topem i osobnymi testami.

## Sekwencja pakietów

Docelowa sekwencja PC -> FPGA:

```text
PING
SET_GAINS
WRITE_FRAME_CHUNK x8
RUN_FRAME
GET_STATUS repeated until DONE
READ_RESULT_CHUNK for requested result samples/chunks
```

Pełna ramka ma 256 próbek signed int16. Każdy `WRITE_FRAME_CHUNK` przenosi
32 próbki.

## LED

`led` ma zachowanie statusowe i domyślnie jest traktowany jako aktywny stanem
niskim przez parametr:

```verilog
LED_ACTIVE_LOW = 1
```

Logika LED:

- idle / waiting: wolne miganie,
- odbiór, nadawanie albo przetwarzanie: szybkie miganie,
- zakończenie bez błędu: LED stale aktywny,
- błąd UART, błąd protokołu, overflow albo timeout: szybkie miganie błędu.

## Symulacja

Dodany testbench:

```text
tb/tang_cpu_owned_frame_uart_top_tb.v
```

Test obejmuje poziom bitowego UART:

- wysłanie `PING` i weryfikację `PONG`,
- wysłanie `SET_GAINS`,
- wysłanie ośmiu `WRITE_FRAME_CHUNK` dla ramki impulsowej,
- wysłanie `RUN_FRAME`,
- polling `GET_STATUS` aż do `DONE`,
- odczyt wybranych próbek wyniku:
  `0, 1, 2, 16, 64, 128, 255`,
- sprawdzenie braku `ERROR` i `TIMEOUT`,
- sprawdzenie, że mini CPU zobaczył request i uruchomił FFT MMIO,
- sprawdzenie aktywnego LED po sukcesie.

Test jest dodany do:

```text
tools/run_all_tests.py
```

## Różnica względem legacy topu

`rtl/top/tang_uart_cpu_fft_console_top.v` obsługuje legacy komendę:

```text
A5 01 5A
```

Ten top jest prostym testem impulsowym i zwraca stały zestaw próbek.

Nowy `tang_cpu_owned_frame_uart_top` obsługuje pełny protokół ramek:

- upload gainów,
- upload 256 próbek,
- start request,
- status polling,
- odczyt wyników.

Legacy top i jego testy nie zostały zmienione.

## Gowin i piny

W tym etapie nie zmieniono constraints Gowin i nie zgadywano pinów UART.

Aktualne przypisania pozostają TODO:

```text
uart_rx -> TODO
uart_tx -> TODO
led     -> TODO albo znany LED z osobnego wariantu constraints
```

Po potwierdzeniu pinów należy przygotować osobny wariant constraints albo
osobny projekt Gowin dla tego topu. Nie należy nadpisywać istniejącego setupu
hardware self-testu FFT/IFFT.

## Test po potwierdzeniu pinów UART

Po przypisaniu pinów:

1. Ustawić top module w Gowin:

   ```text
   tang_cpu_owned_frame_uart_top
   ```

2. Dodać wymagane pliki RTL do projektu.
3. Ustawić `clk`, `uart_rx`, `uart_tx` i `led` w constraints.
4. Wygenerować bitstream i zaprogramować Tang Nano.
5. Uruchomić klienta PC:

   ```powershell
   python tools/spectrum_lab_uart_client.py --port COM5
   ```

## Ograniczenia

- Piny UART RX/TX nie są jeszcze potwierdzone.
- Nie dodano ani nie zmieniono constraints Gowin.
- Nie dodano I2S, AXI-Lite ani Gowin FFT IP.
- Top używa obecnego programu `mini_cpu_uart_frame_system`, który jest etapem
  bring-up CPU-owned frame flow i obsługuje kolejne `RUN_FRAME` bez resetu.
- Fizyczna walidacja na Tang Nano wymaga kolejnego kroku z pin confirmation.
