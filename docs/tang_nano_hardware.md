# Tang Nano 20K hardware

Aktualny test sprzętowy używa płytki Sipeed Tang Nano 20K i komunikacji UART
przez onboard BL616 USB-UART. System przetwarza ramki wysyłane z PC, a nie
ciągły fizyczny strumień audio I2S.

## Top module

```text
tang_cpu_owned_frame_uart_top
```

Plik:

```text
rtl/top/tang_cpu_owned_frame_uart_top.v
```

## UART

Parametry:

```text
baud: 115200
data bits: 8
parity: none
stop bits: 1
clock: 27_000_000 Hz
```

## Potwierdzone piny

| Sygnał | Pin | Opis |
| --- | ---: | --- |
| `clk` | 4 | zegar płytki |
| `led` | 15 | LED statusu, aktywny niskim poziomem |
| `uart_tx` | 69 | `SYS_TX`, FPGA -> PC |
| `uart_rx` | 70 | `SYS_RX`, PC -> FPGA |

## LED

LED jest aktywna niskim poziomem. Top używa jej jako prostego statusu:

- wolne miganie - idle/waiting,
- szybkie miganie - aktywność UART/CPU/DSP,
- świecenie po sukcesie - pass/done,
- miganie błędu - błąd protokołu, timeout lub DSP error.

## Budowanie w Gowin EDA

1. Otwórz projekt w `gowin_impl/tang_audio_hw/`.
2. Ustaw top module: `tang_cpu_owned_frame_uart_top`.
3. Upewnij się, że wszystkie wymagane pliki RTL są dodane do projektu.
4. Użyj constraints dla `clk`, `led`, `uart_tx`, `uart_rx`.
5. Uruchom `Synthesize`.
6. Uruchom `Place & Route`.
7. Uruchom `Generate Bitstream`.
8. W `Programmer` wybierz `SRAM Program`.

Folder `gowin_impl/` może zawierać kopie źródeł używane przez projekt Gowin.
Kiedy zmienia się hardware-relevant RTL w `rtl/`, kopie w `gowin_impl/` trzeba
zsynchronizować świadomie.

## Test po zaprogramowaniu

Klient konsolowy:

```powershell
python tools/spectrum_lab_uart_client.py --port COM6
```

GUI:

```powershell
python tools/spectrum_lab_app.py
```

W GUI wybierz `Serial FPGA backend` i poprawny port COM.

## Ograniczenia hardware

- Obecny demonstrator nie używa PCM1808 ani PCM5102A.
- Fizyczne I2S audio input/output pozostaje future work.
- UART jest wystarczający do testu ramek 256 próbek, ale nie jest docelowym
  interfejsem realtime audio streaming.
