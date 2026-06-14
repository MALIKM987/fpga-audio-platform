# Wzorce projektowe i wzorce architektoniczne

Ten dokument opisuje wzorce widoczne w aktualnej implementacji projektu.
Nie wszystkie z nich są klasycznymi wzorcami GoF. Część, szczególnie MMIO
i CPU-owned control, to wzorce architektoniczne typowe dla systemów embedded
i FPGA.

## Strategy

Aplikacja PC wybiera strategię wykonania obliczeń bez zmiany kodu odpowiedzialnego
za wykresy i metryki porównawcze.

Konkretne pliki:

- `tools/spectrum_lab_app.py` - wybór trybu pracy GUI,
- `tools/spectrum_lab_hardware_backend.py` - wspólna ścieżka backendu FPGA,
- `tools/spectrum_lab_model.py` - lokalny model obliczeń,
- `tools/uart_transport.py` - transport mock albo serial.

Przykładowy pseudokod:

```text
backend = select_backend(mode)
local_result = run_local_simulation(samples, gains)
backend_result = backend.run_frame(samples, gains)
plot(input_signal, local_result, backend_result)
```

Dzięki temu GUI może pracować z lokalną symulacją, mockiem FPGA albo prawdziwym
UART bez przepisywania logiki prezentacji.

## Command

Protokół UART jest oparty o jawne komendy. Każda komenda ma określony kod,
payload, odpowiedź i sposób obsługi błędów.

Konkretne pliki:

- `tools/uart_frame_protocol.py` - definicje komend i kodowanie ramek po stronie PC,
- `rtl/uart/uart_frame_packet_rx.v` - odbiór ramek bajtowych,
- `rtl/uart/uart_frame_packet_tx.v` - nadawanie ramek bajtowych,
- `rtl/uart/uart_frame_buffer_backend.v` - interpretacja komend jako mailbox CPU.

Przykładowy flow komend:

```text
send PING
send SET_GAINS
send WRITE_FRAME_CHUNK x8
send RUN_FRAME
poll GET_STATUS until DONE
send READ_RESULT_CHUNK x8
```

Ten podział ułatwia testowanie i debugowanie, bo każdą operację można sprawdzić
osobno.

## Adapter

Warstwa transportu ukrywa różnice między portem szeregowym i mockiem.

Konkretne pliki:

- `tools/uart_transport.py` - `SerialTransport`, `MockFpgaTransport`,
  `UartTransport`,
- `tools/spectrum_lab_hardware_backend.py` - używa transportu przez wspólny
  interfejs.

`SerialTransport` wymaga `pyserial` dopiero przy realnym sprzęcie. Testy mock
nie mają tej zależności.

## Facade

`tools/spectrum_lab_hardware_backend.py` działa jako fasada dla GUI. Aplikacja
nie musi ręcznie budować ramek UART, dzielić danych na chunki, pollować statusu
ani sklejać wyniku.

Fasada wystawia operacje wyższego poziomu:

- ustaw gainy,
- wyślij ramkę 256 próbek,
- uruchom przetwarzanie,
- odbierz pełną ramkę wynikową,
- zdekoduj status.

## State machine

FSM są naturalnym sposobem opisu sekwencyjnej logiki FPGA.

Konkretne pliki:

- `rtl/uart/uart_rx.v` - odbiór bitów UART 8N1,
- `rtl/uart/uart_tx.v` - nadawanie bitów UART 8N1,
- `rtl/uart/uart_frame_packet_rx.v` - parser ramek `SOF..EOF`,
- `rtl/uart/uart_frame_packet_tx.v` - formatter ramek,
- `rtl/uart/uart_frame_buffer_backend.v` - obsługa komend mailboxa,
- `rtl/control/fft_accelerator_mmio.v` - sterowanie `IDLE/FEED/WAIT`,
- `rtl/dsp/fft_ifft_pipeline.v` - zbieranie ramki i przetwarzanie,
- `rtl/cpu/mini_cpu_core.v` - cykl `FETCH/DECODE/EXECUTE/MEM/HALT`.

FSM porządkują zależności czasowe: najpierw odebranie bajtów, potem złożenie
pakietu, zapis mailboxa, praca CPU, start DSP i odczyt wyniku.

## Embedded/FPGA architectural pattern: MMIO

Memory-mapped I/O nie jest klasycznym wzorcem GoF. W tym projekcie jest to
wzorzec architektoniczny embedded/FPGA: rejestry i pamięci próbek są widoczne
dla mini CPU pod adresami magistrali.

Konkretne pliki:

- `rtl/control/fft_mmio_regs.v` - rejestry i pamięci wejścia/wyjścia FFT,
- `rtl/control/fft_accelerator_mmio.v` - wrapper start/busy/done,
- `rtl/cpu/mini_cpu_uart_frame_system.v` - dekoder adresów CPU,
- `rtl/cpu/mini_cpu_program_rom.v` - program używający adresów MMIO.

Typowy przebieg:

```text
CPU writes INPUT_SAMPLE[0..255]
CPU writes BASS/MID/TREBLE gains
CPU writes CONTROL.START
CPU polls STATUS.DONE
CPU reads OUTPUT_SAMPLE[0..255]
```

## CPU-owned hardware control

Najważniejsza reguła projektu brzmi: tylko mini CPU steruje
`fft_accelerator_mmio`.

Konkretne pliki:

- `rtl/cpu/mini_cpu_uart_frame_system.v` - CPU jako właściciel magistrali FFT MMIO,
- `rtl/cpu/mini_cpu_program_rom.v` - program service-loop,
- `rtl/uart/uart_frame_buffer_backend.v` - mailbox, bez bezpośredniego startu FFT,
- `rtl/top/tang_cpu_owned_frame_uart_top.v` - integracja UART, mailboxa i CPU.

UART backend przechowuje ramkę, gainy i request. Nie uruchamia bezpośrednio
akceleratora. Takie rozdzielenie odpowiedzialności ułatwia rozbudowę programu
CPU, debugowanie oraz późniejsze dodanie nowych komend bez mieszania warstwy
komunikacji z warstwą sterowania DSP.
