# Wzorce projektowe

Projekt używa kilku praktycznych wzorców projektowych. Nie są one dodane
sztucznie; wynikają z podziału odpowiedzialności między PC, UART, CPU i DSP.

## Strategy

Aplikacja PC wybiera strategię backendu:

- `Local simulation`,
- `Mock FPGA backend`,
- `Serial FPGA backend`.

GUI może pracować z różnymi sposobami uzyskania wyniku bez zmiany logiki
rysowania wykresów i liczenia metryk.

## Command

Protokół UART jest oparty o komendy:

- `PING`,
- `SET_GAINS`,
- `WRITE_FRAME_CHUNK`,
- `RUN_FRAME`,
- `GET_STATUS`,
- `READ_RESULT_CHUNK`.

Każda komenda ma jednoznaczny payload i odpowiedź. To upraszcza testowanie i
debugowanie.

## Adapter

`SerialTransport` i `MockFpgaTransport` udostępniają podobny interfejs
komunikacji. Dzięki temu wyższa warstwa backendu może używać mocka albo
prawdziwego portu UART.

## Facade

`spectrum_lab_hardware_backend.py` ukrywa szczegóły ramek UART przed GUI.
Aplikacja nie musi ręcznie budować pakietów, pollować statusu ani sklejać
chunków wyniku. Widzi operację wysokiego poziomu: wyślij ramkę i odbierz wynik.

## State machine

FSM występują w kilku miejscach:

- `uart_rx` i `uart_tx`,
- `uart_frame_packet_rx`,
- `uart_frame_packet_tx`,
- `uart_frame_buffer_backend`,
- `fft_accelerator_mmio`,
- programowy service loop mini CPU.

FSM są naturalne dla logiki FPGA, bo odpowiadają sekwencyjnym etapom protokołu i
przetwarzania.

## Memory-mapped I/O

Mini CPU steruje akceleratorem przez rejestry i pamięci próbek MMIO. To oddziela
sterowanie od obliczeń:

```text
CPU writes CONTROL.START
CPU polls STATUS.DONE
CPU reads OUTPUT_SAMPLE
```

## CPU-owned hardware control

UART backend nie steruje akceleratorem bezpośrednio. Pełni rolę mailboxa.
Decyzje sprzętowe podejmuje mini CPU. Ten wzorzec porządkuje system i ułatwia
przyszłe rozszerzenia programu CPU.
