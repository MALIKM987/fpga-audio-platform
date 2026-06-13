# UART console dla mini CPU i akceleratora FFT/IFFT

## Cel etapu

Ten etap dodaje prostą ścieżkę komunikacji UART wokół istniejącej integracji:

```text
PC / UART
    -> uart_rx
    -> uart_cpu_fft_console
    -> mini_cpu_fft_system
    -> fft_accelerator_mmio
    -> fft_ifft_pipeline
    -> CPU readback
    -> uart_tx
    -> PC
```

Nie jest to jeszcze pełny terminal tekstowy ani sterownik produkcyjny. Celem
jest minimalny, deterministyczny protokół, który pozwala z komputera uruchomić
istniejący program impulsowy CPU i odebrać wynik.

## Parametry UART

Domyślne parametry:

- baud rate: `115200`,
- 8 bitów danych,
- brak parzystości,
- 1 bit stopu,
- zegar parametryzowany przez `CLK_FREQ_HZ`.

W testbenchach używany jest szybszy wariant symulacyjny:

- `CLK_FREQ_HZ = 1_000_000`,
- `BAUD_RATE = 100_000`.

## Protokół binarny

Wybrany został prosty protokół binarny, żeby FPGA nie musiało implementować
ogólnego parsera tekstu.

Komenda z PC:

| Bajt | Wartość | Znaczenie |
| --- | --- | --- |
| 0 | `0xA5` | Start pakietu. |
| 1 | `0x01` | `RUN_IMPULSE_TEST`. |
| 2 | `0x5A` | Koniec pakietu. |

Niepoprawna komenda jest ignorowana. Komenda odebrana podczas pracy konsoli
również jest ignorowana i nie uruchamia drugiego przebiegu.

## Format odpowiedzi

Odpowiedź ma 18 bajtów:

| Bajt | Znaczenie |
| --- | --- |
| 0 | `0xA5` start odpowiedzi. |
| 1 | `0x81` `RUN_IMPULSE_RESULT`. |
| 2 | Status. |
| 3..4 | `out0`, signed 16-bit little-endian. |
| 5..6 | `out1`, signed 16-bit little-endian. |
| 7..8 | `out2`, signed 16-bit little-endian. |
| 9..10 | `out16`, signed 16-bit little-endian. |
| 11..12 | `out64`, signed 16-bit little-endian. |
| 13..14 | `out128`, signed 16-bit little-endian. |
| 15..16 | `out255`, signed 16-bit little-endian. |
| 17 | `0x5A` koniec odpowiedzi. |

Status:

| Bit | Znaczenie |
| --- | --- |
| 0 | `PASS`. |
| 1 | `DONE`. |
| 2 | `OVERFLOW`. |
| 3 | `ERROR`. |
| 4 | `TIMEOUT`. |

## Jak działa komenda RUN

Po odebraniu poprawnego pakietu `0xA5 0x01 0x5A` moduł
`uart_cpu_fft_console`:

1. Resetuje lokalny `mini_cpu_fft_system`.
2. Uruchamia istniejący program `MINI_CPU_PROGRAM_FFT_IMPULSE`.
3. Czeka, aż CPU zapisze ramkę impulsową, wystartuje akcelerator i odczyta
   wyniki.
4. Zbiera `GPIO_RESULT`, status i siedem próbek debug.
5. Wysyła odpowiedź przez `uart_tx`.

Program CPU pozostaje taki sam jak w etapie integracji CPU -> FFT MMIO:

- zapisuje unity gains,
- zapisuje ramkę impulsową,
- zapisuje `START`,
- polluje `STATUS`,
- odczytuje wybrane próbki,
- zapisuje `GPIO_RESULT = 0x00A5` dla PASS.

## Pokrycie testami

| Etap | Testbench | Co sprawdza |
| --- | --- | --- |
| Stage 1 | `tb/uart_tx_tb.v` | Format ramki TX: start, 8 danych, stop, `busy`. |
| Stage 2 | `tb/uart_rx_tb.v` | Odbiór bajtu 8N1, `valid`, brak błędu ramki. |
| Stage 3 | `tb/uart_cpu_fft_console_cmd_tb.v` | Poprawna komenda RUN, błędna komenda, brak drugiego startu podczas busy. |
| Stage 4 | `tb/uart_cpu_fft_console_e2e_tb.v` | Pełny przepływ UART -> CPU -> FFT/IFFT MMIO -> UART. |
| Stage 5 | `tools/run_all_tests.py` | Regresja wszystkich wcześniejszych testów. |

## Ograniczenia

Ten etap nadal nie dodaje:

- fizycznego top-levelu Tang Nano dla UART,
- przypisania pinów UART w Gowin,
- AXI-Lite,
- fizycznego I2S,
- ogólnego parsera tekstowego,
- sterowania dowolnymi ramkami audio z PC.

Następny naturalny etap to `codex/tang-uart-cpu-fft-top`, czyli bezpieczny top
pod płytkę z `clk`, `uart_rx`, `uart_tx` i prostymi LED statusu.
