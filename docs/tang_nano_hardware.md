# Tang Nano 20K hardware

Aktualny test sprzętowy używa płytki Sipeed Tang Nano 20K i komunikacji UART
przez onboard BL616 USB-UART. System przetwarza ramki wysyłane z PC. Nie jest
to jeszcze ciągły fizyczny strumień audio I2S.

## Top module

Top dla aktualnego wariantu CPU-owned UART frame:

```text
tang_cpu_owned_frame_uart_top
```

Plik źródłowy:

```text
rtl/top/tang_cpu_owned_frame_uart_top.v
```

Top instancjonuje:

- `uart_rx`,
- `uart_frame_packet_rx`,
- `uart_frame_buffer_backend`,
- `mini_cpu_uart_frame_system`,
- `uart_frame_packet_tx`,
- `uart_tx`.

## UART

Parametry używane przez top:

```text
baud: 115200
data bits: 8
parity: none
stop bits: 1
clock: 27_000_000 Hz
```

## Piny używane w planie bring-up

W repozytorium dokumentowany był pierwszy bring-up z onboard BL616 USB-UART:

| Sygnał | Pin | Opis |
| --- | ---: | --- |
| `clk` | 4 | zegar płytki |
| `led` | 15 | LED statusu, zwykle aktywny niskim poziomem |
| `uart_tx` | 69 | `SYS_TX`, dane z FPGA do PC |
| `uart_rx` | 70 | `SYS_RX`, dane z PC do FPGA |

Przed testem sprzętowym należy sprawdzić, czy aktywny projekt Gowin używa
constraints zgodnych z tym wariantem. W aktualnym repozytorium plik:

```text
gowin_impl/tang_audio_hw/src/tang_audio_hw.cst
```

zawiera constraints dla `clk` i `led` wariantu self-test. Nie zawiera w tej
gałęzi przypisań `uart_rx` i `uart_tx`. Jeśli budowany jest
`tang_cpu_owned_frame_uart_top`, należy dodać albo wybrać osobny plik constraints
dla `clk`, `led`, `uart_tx` i `uart_rx`. Dokładny aktywny plik constraints trzeba
zweryfikować w projekcie Gowin pod `gowin_impl/tang_audio_hw/`.

## LED

LED jest używana jako prosty wskaźnik statusu/debug. Dokładne zachowanie należy
zawsze weryfikować z aktualnym `rtl/top/tang_cpu_owned_frame_uart_top.v`.

W obecnej implementacji topu:

- `LED_ACTIVE_LOW` domyślnie wynosi `1`,
- `error_latched` powoduje szybkie miganie,
- `pass_latched` ustawia LED w stan aktywny,
- aktywność UART/CPU/DSP powoduje szybkie miganie,
- brak aktywności daje wolniejsze miganie.

Nie jest to pełny panel diagnostyczny. LED informuje orientacyjnie o stanie
bring-up, a właściwym kanałem diagnostycznym pozostaje UART i aplikacja PC.

## Budowanie w Gowin EDA

1. Otwórz projekt w `gowin_impl/tang_audio_hw/`.
2. Ustaw top module: `tang_cpu_owned_frame_uart_top`.
3. Upewnij się, że wszystkie wymagane pliki RTL są dodane do projektu.
4. Upewnij się, że aktywny `.cst` zawiera `clk`, `led`, `uart_tx`, `uart_rx`.
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

`COM6` jest tylko przykładem z jednej maszyny Windows. Rzeczywisty numer portu
zależy od komputera i trzeba go sprawdzić w Menedżerze urządzeń albo na liście
portów szeregowych systemu operacyjnego.

GUI:

```powershell
python tools/spectrum_lab_app.py
```

W GUI wybierz `Serial FPGA backend` i poprawny port COM.

## Ograniczenia hardware

- Obecny demonstrator nie używa PCM1808 ani PCM5102A.
- Fizyczne I2S audio input/output pozostaje future work.
- UART wystarcza do testu ramek 256 próbek, ale nie jest docelowym interfejsem
  realtime audio streaming.
- Piny UART powinny zostać potwierdzone na konkretnej rewizji płytki i w aktywnym
  projekcie Gowin przed traktowaniem bring-up jako zamknięty.
