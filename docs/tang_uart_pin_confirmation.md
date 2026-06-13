# Tang UART pin confirmation flow

## Cel

Ten dokument przygotowuje fizyczny test topu:

```text
tang_cpu_owned_frame_uart_top
```

na Tang Nano 20K przez zewnętrzny konwerter USB-UART 3.3 V.

Ten etap nie zmienia RTL, protokołu UART, mini CPU, FFT/IFFT ani constraints
Gowin. Jego celem jest uporządkowanie procedury i jawne wskazanie, że piny
`uart_rx` oraz `uart_tx` nie są jeszcze potwierdzone w repozytorium.

## Status pinów

W repozytorium znaleziono istniejący constraint:

```text
gowin_impl/tang_audio_hw/src/tang_audio_hw.cst
```

Zawiera on aktualnie znane przypisania:

| Sygnał | Pin | Status |
| --- | --- | --- |
| `clk` | `4` | istnieje w repo jako clock Tang Nano setup |
| `led` | `15` | istnieje w repo jako pojedynczy LED testowy |
| `uart_rx` | TODO | brak jednoznacznie potwierdzonego pinu |
| `uart_tx` | TODO | brak jednoznacznie potwierdzonego pinu |

Nie ma w repo jednoznacznego, sprawdzonego przypisania fizycznych pinów
`uart_rx` i `uart_tx` dla `tang_cpu_owned_frame_uart_top`. Dlatego w tym branchu
nie dodano nowego pliku `.cst` i nie zmieniono `gowin_impl/`.

Do dodania constraints brakuje:

1. Potwierdzonego numeru pinu FPGA dla `uart_rx`.
2. Potwierdzonego numeru pinu FPGA dla `uart_tx`.
3. Informacji, czy wybrane piny pracują w banku 3.3 V.
4. Potwierdzenia kierunku połączeń z konwerterem USB-UART.
5. Potwierdzenia, że używany konwerter UART ma poziomy 3.3 V, a nie 5 V.

## Top module w Gowin

W Gowin EDA ustaw:

```text
Top Module = tang_cpu_owned_frame_uart_top
```

Nie nadpisuj istniejącego setupu self-testu. Najbezpieczniej przygotować osobny
wariant projektu albo osobny plik constraints dopiero po potwierdzeniu pinów
UART.

## Minimalne sygnały topu

```verilog
input  wire clk
input  wire uart_rx
output wire uart_tx
output wire led
```

Parametry domyślne:

- `CLK_FREQ_HZ = 27_000_000`
- `BAUD_RATE = 115_200`
- UART: 8N1
- `LED_ACTIVE_LOW = 1`

## Pliki RTL do dodania w Gowin

Dodaj co najmniej:

```text
rtl/uart/uart_rx.v
rtl/uart/uart_tx.v
rtl/uart/uart_frame_packet_rx.v
rtl/uart/uart_frame_packet_tx.v
rtl/uart/uart_frame_buffer_backend.v
rtl/cpu/mini_cpu_defs.vh
rtl/cpu/mini_cpu_program_rom.v
rtl/cpu/mini_cpu_core.v
rtl/cpu/mini_cpu_uart_frame_system.v
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
rtl/top/tang_cpu_owned_frame_uart_top.v
```

Jeżeli Gowin nie widzi definicji z pliku `mini_cpu_defs.vh`, upewnij się, że
katalog `rtl/cpu/` jest dostępny jako include path albo że plik jest dodany do
projektu przed modułami CPU.

## Constraints po potwierdzeniu pinów

Nie używaj poniższego jako gotowego `.cst`, dopóki `uart_rx` i `uart_tx` nie
zostaną potwierdzone. To jest wyłącznie szablon:

```text
IO_LOC "clk" 4;
IO_PORT "clk" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;

IO_LOC "led" 15;
IO_PORT "led" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;

IO_LOC "uart_rx" TODO_CONFIRMED_RX_PIN;
IO_PORT "uart_rx" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;

IO_LOC "uart_tx" TODO_CONFIRMED_TX_PIN;
IO_PORT "uart_tx" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;

CLOCK_LOC "clk_d" LOCAL_CLOCK;
```

## Połączenie USB-UART 3.3 V

Po potwierdzeniu pinów połącz:

```text
USB-UART TXD -> FPGA uart_rx
USB-UART RXD -> FPGA uart_tx
USB-UART GND -> FPGA GND
```

Nie podłączaj 5 V do pinów FPGA. Konwerter musi pracować z poziomami 3.3 V.

## Budowa w Gowin

1. Ustaw `Top Module = tang_cpu_owned_frame_uart_top`.
2. Dodaj pliki RTL z listy powyżej.
3. Przygotuj osobny constraints z potwierdzonymi pinami.
4. Uruchom:

   ```text
   Synthesis
   Place & Route
   Generate Bitstream
   Program Device
   ```

5. Nie zmieniaj działającego wariantu self-testu FFT/IFFT, jeśli nadal jest
   potrzebny jako fallback.

## Test z klientem CLI

Po zaprogramowaniu FPGA i podłączeniu USB-UART uruchom:

```powershell
python tools/spectrum_lab_uart_client.py --port COMx
```

gdzie `COMx` to port widoczny w Windows, np. `COM5`.

Oczekiwany przepływ:

```text
PING
SET_GAINS
WRITE_FRAME_CHUNK x8
RUN_FRAME
GET_STATUS until DONE
READ_RESULT_CHUNK x8
```

Klient powinien wypisać status `DONE=1`, `ERROR=0`, `TIMEOUT=0` oraz wybrane
próbki wyniku.

## Test z GUI Spectrum Lab

Uruchom:

```powershell
python tools/spectrum_lab_app.py
```

W GUI:

1. Ustaw `Frame size = 256`.
2. Wybierz `Serial FPGA backend`.
3. Wpisz port, np. `COM5`.
4. Ustaw baud `115200`.
5. Kliknij `Generate / Simulate`.

GUI pokaże lokalną symulację, wynik Serial FPGA backendu, różnicę względem
lokalnego wyniku i metryki błędu.

Jeżeli port albo pyserial nie są dostępne, GUI nadal pokazuje lokalną symulację
i Mock FPGA backend, a serial opisuje jako niedostępny.

## Checklist testu sprzętowego

- [ ] Potwierdzono fizyczny pin FPGA dla `uart_rx`.
- [ ] Potwierdzono fizyczny pin FPGA dla `uart_tx`.
- [ ] Potwierdzono, że oba piny są bezpieczne dla LVCMOS 3.3 V.
- [ ] Przygotowano osobny plik constraints dla topu UART.
- [ ] Top module w Gowin ustawiony na `tang_cpu_owned_frame_uart_top`.
- [ ] Dodano wszystkie wymagane pliki RTL.
- [ ] Synthesis zakończone bez błędów.
- [ ] Place & Route zakończone bez błędów.
- [ ] Bitstream wygenerowany.
- [ ] Device zaprogramowany.
- [ ] USB-UART TXD podłączony do `uart_rx`.
- [ ] USB-UART RXD podłączony do `uart_tx`.
- [ ] USB-UART GND połączony z GND FPGA.
- [ ] Używany konwerter pracuje z poziomami 3.3 V.
- [ ] `python tools/spectrum_lab_uart_client.py --port COMx` kończy się bez
      błędu protokołu.
- [ ] GUI Spectrum Lab pokazuje wynik serial albo czytelny błąd portu.

## Ograniczenia

- Piny `uart_rx` i `uart_tx` nadal są TODO.
- W tym branchu nie dodano constraints UART.
- Nie wykonano lokalnego Gowin Synthesis/P&R/Bitstream.
- Nie zmieniono legacy ścieżki `A5 01 5A`.
- Nie dodano I2S, AXI-Lite ani Gowin FFT IP.
