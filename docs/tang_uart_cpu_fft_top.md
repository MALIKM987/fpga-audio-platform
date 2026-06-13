# Tang Nano UART CPU FFT console top

## Cel etapu

Ten etap dodaje niski poziom ryzyka dla uruchomienia istniejącej konsoli UART
na płytce Tang Nano 20K. Nowy top nie zmienia rdzenia FFT/IFFT, mini CPU ani
istniejącego sprzętowego self-testu FFT/IFFT.

Przepływ sprzętowy:

```text
PC / UART
    -> uart_rx pin FPGA
    -> tang_uart_cpu_fft_console_top
    -> uart_cpu_fft_console
    -> mini_cpu_fft_system
    -> mini CPU
    -> FFT/IFFT MMIO accelerator
    -> CPU readback/debug registers
    -> uart_tx pin FPGA
    -> PC
```

## Top-level module

Nowy top znajduje się w:

```text
rtl/top/tang_uart_cpu_fft_console_top.v
```

Porty:

| Port | Kierunek | Znaczenie |
| --- | --- | --- |
| `clk` | input | Zegar płytki Tang Nano 20K. |
| `uart_rx` | input | Dane z konwertera USB-UART do FPGA. |
| `uart_tx` | output | Dane z FPGA do konwertera USB-UART. |
| `led` | output | Jedna dioda statusu. Domyślnie aktywna stanem niskim. |

Top generuje wewnętrzny power-on reset, więc nie wymaga zewnętrznego pinu
resetu.

## Parametry UART

Domyślne parametry topu:

- `CLK_FREQ_HZ = 27_000_000`,
- `BAUD_RATE = 115_200`,
- 8 bitów danych,
- brak parzystości,
- 1 bit stopu.

Zegar 27 MHz wynika z istniejącego projektu Tang Nano i pliku:

```text
gowin_impl/tang_audio_hw/src/constraints.sdc
```

gdzie okres zegara to około 37.037 ns.

## Protokół komend

Protokół pozostaje binarny i zgodny z `uart_cpu_fft_console`.

Komenda z PC do FPGA:

```text
A5 01 5A
```

Znaczenie:

| Bajt | Wartość | Znaczenie |
| --- | --- | --- |
| 0 | `0xA5` | Start pakietu. |
| 1 | `0x01` | Uruchom test impulsowy mini CPU. |
| 2 | `0x5A` | Koniec pakietu. |

## Format odpowiedzi

FPGA zwraca 18 bajtów. To nie jest pełna ramka 256 próbek, tylko raport
statusu i siedem wybranych próbek wyjściowych:

```text
A5 81 STATUS out0 out1 out2 out16 out64 out128 out255 5A
```

Próbki są signed 16-bit little-endian.

Status:

| Bit | Nazwa | Znaczenie |
| --- | --- | --- |
| 0 | `PASS` | Mini CPU zgłosił poprawny wynik. |
| 1 | `DONE` | Akcelerator zakończył obliczenia. |
| 2 | `OVERFLOW` | Wystąpiło overflow. |
| 3 | `ERROR` | Wystąpił błąd. |
| 4 | `TIMEOUT` | Konsola przekroczyła limit oczekiwania. |

Oczekiwany wynik testu impulsowego:

| Próbka | Oczekiwana wartość |
| --- | --- |
| `out0` | `64` |
| `out1` | `0` |
| `out2` | `0` |
| `out16` | `0` |
| `out64` | `0` |
| `out128` | `0` |
| `out255` | `0` |

## LED status

Top używa jednego wyjścia `led`.

Domyślnie `LED_ACTIVE_LOW = 1`, ponieważ diody na płytkach Tang Nano często są
aktywne stanem niskim. Jeżeli używana dioda jest aktywna stanem wysokim, można
w symulacji lub wariancie projektu ustawić `LED_ACTIVE_LOW = 0`.

Zachowanie:

- wolne miganie: układ jest po resecie i czeka na komendę,
- szybkie miganie: konsola pracuje albo wysyła odpowiedź,
- świecenie ciągłe: ostatni przebieg zakończył się `PASS`,
- wolne miganie po błędzie: mini CPU zakończył pracę bez wartości PASS.

## Status constraints UART

W repozytorium potwierdzone są tylko piny używane przez obecny hardware
self-test:

```text
clk -> pin 4
led -> pin 15
```

Nie znaleziono w repozytorium wiarygodnego przypisania pinów dla:

```text
uart_rx -> TODO
uart_tx -> TODO
```

Z tego powodu pliki `gowin_impl/` pozostają bez zmian. To celowe: istniejący
top sprzętowego self-testu FFT/IFFT ma pozostać nietknięty, a pinów UART nie
wolno zgadywać.

Przed dodaniem constraintów trzeba potwierdzić:

1. które fizyczne piny Tang Nano 20K mają być użyte jako `uart_rx`
   i `uart_tx`,
2. czy te piny są dostępne na złączu i nie kolidują z funkcjami specjalnymi,
3. czy poziomy napięć są 3.3 V,
4. czy używany USB-UART ma wspólną masę z płytką,
5. czy linie są skrzyżowane:
   `USB-UART TXD -> FPGA uart_rx` oraz `USB-UART RXD -> FPGA uart_tx`.

Po potwierdzeniu pinów można dodać osobny wariant `.cst` albo osobny projekt
Gowin dla topu UART. Nie należy nadpisywać znanego, działającego wariantu
self-testu bez potrzeby.

## Instrukcja Gowin EDA

Aby zbudować wariant UART w Gowin EDA:

1. Otwórz istniejący projekt albo utwórz osobny wariant projektu dla UART.
2. Dodaj pliki RTL wymagane przez konsolę:

```text
rtl/uart/uart_rx.v
rtl/uart/uart_tx.v
rtl/uart/uart_cpu_fft_console.v
rtl/top/tang_uart_cpu_fft_console_top.v
rtl/cpu/mini_cpu_defs.vh
rtl/cpu/mini_cpu_program_rom.v
rtl/cpu/mini_cpu_core.v
rtl/cpu/mini_cpu_fft_system.v
rtl/control/fft_mmio_regs.v
rtl/control/fft_accelerator_mmio.v
rtl/dsp/sample_block_buffer.v
rtl/dsp/spectral_gain_select.v
rtl/dsp/spectral_processor.v
rtl/dsp/fft_bit_reverse.v
rtl/dsp/fft_butterfly_addr_gen.v
rtl/dsp/fft_twiddle_rom.v
rtl/dsp/complex_mult.v
rtl/dsp/fft_radix2_core.v
rtl/dsp/fft_accel_wrapper.v
rtl/dsp/ifft_accel_wrapper.v
rtl/dsp/fft_ifft_pipeline.v
```

3. Ustaw top module:

```text
tang_uart_cpu_fft_console_top
```

4. Zostaw zegar zgodny z istniejącym projektem:

```text
clk -> pin 4
```

5. Diodę `led` można przypisać do znanego pinu używanego w self-teście:

```text
led -> pin 15
```

6. Piny `uart_rx` i `uart_tx` są celowo oznaczone jako TODO. Nie ma pewności,
   że USB Debugger Tang Nano automatycznie udostępnia UART FPGA jako port COM.
   Użyj potwierdzonych pinów FPGA i zewnętrznego konwertera USB-UART 3.3 V.

7. Po uzupełnieniu potwierdzonych pinów ustaw:

```text
Top Module = tang_uart_cpu_fft_console_top
```

8. Uruchom w Gowin:

```text
Synthesis
Place & Route
Generate Bitstream
Program Device
```

Przykładowy kierunek połączeń z zewnętrznym USB-UART:

```text
USB-UART TXD -> FPGA uart_rx
USB-UART RXD -> FPGA uart_tx
USB-UART GND -> FPGA GND
```

Nie podawaj sygnałów 5 V na piny FPGA.

## Test z PC

Dodano pomocniczy skrypt:

```text
tools/uart_fft_console_client.py
```

Przykład użycia w Windows:

```text
python tools/uart_fft_console_client.py COM6
```

Przykład użycia w Linux:

```text
python3 tools/uart_fft_console_client.py /dev/ttyUSB0
```

Skrypt wymaga tylko opcjonalnego pakietu `pyserial`:

```text
python -m pip install pyserial
```

`pyserial` nie jest wymagany do `tools/run_all_tests.py`.

Procedura testu:

1. Zaprogramuj bitstream z topem `tang_uart_cpu_fft_console_top`.
2. Podłącz zewnętrzny konwerter USB-UART 3.3 V do potwierdzonych pinów.
3. Ustaw parametry portu:

```text
115200 baud
8 data bits
no parity
1 stop bit
```

4. Uruchom helper:

```text
python tools/uart_fft_console_client.py COM6
```

5. Helper wyśle:

```text
A5 01 5A
```

6. Oczekiwana odpowiedź ma 18 bajtów i zawiera status oraz wybrane próbki:

```text
out0, out1, out2, out16, out64, out128, out255
```

Poprawny wynik powinien mieć `PASS=1`, `DONE=1`, `OVERFLOW=0`, `ERROR=0`,
`TIMEOUT=0`, `out0=64` i pozostałe wybrane próbki równe `0`.

## Symulacja

Lekki test topu:

```text
tb/tang_uart_cpu_fft_console_top_tb.v
```

Test wysyła pakiet `A5 01 5A`, odbiera odpowiedź UART i sprawdza:

- nagłówek odpowiedzi,
- status `PASS` i `DONE`,
- brak `OVERFLOW`, `ERROR` i `TIMEOUT`,
- wybrane próbki wyniku,
- aktywne wyjście LED po wyniku PASS.

Uruchomienie pełnej regresji:

```text
python tools/run_all_tests.py
```

## Ograniczenia

Ten etap nadal nie dodaje:

- fizycznego I2S,
- AXI-Lite,
- Gowin FFT IP,
- dużego parsera tekstowego UART,
- pełnego systemu PC -> dowolna ramka danych,
- potwierdzonych constraintów dla `uart_rx` i `uart_tx`.

## Troubleshooting

- Brak odpowiedzi UART: sprawdź, czy wybrano top
  `tang_uart_cpu_fft_console_top`, a nie self-test LED.
- Brak portu COM: nie zakładaj, że USB Debugger Tang Nano udostępnia UART FPGA.
  Użyj zewnętrznego USB-UART 3.3 V.
- Same zera albo timeout: sprawdź, czy linie UART są skrzyżowane:
  `TXD -> uart_rx`, `RXD -> uart_tx`.
- Losowe bajty: sprawdź baud rate `115200`, format `8N1` i wspólną masę.
- Brak LED PASS: sprawdź, czy `led` jest przypisany do pinu 15 i czy dioda jest
  aktywna stanem niskim.
- Błąd constraints: nie dodawaj `uart_rx` ani `uart_tx` do `.cst`, dopóki piny
  nie są potwierdzone w dokumentacji płytki albo w realnym okablowaniu.

## Następne kroki

Rekomendowany kolejny branch:

```text
codex/uart-frame-protocol
```

Osobny wariant constraints Gowin dla topu UART powinien powstać dopiero po
potwierdzeniu fizycznych pinów `uart_rx` i `uart_tx`.
