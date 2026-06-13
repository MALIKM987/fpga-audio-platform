# CPU-owned UART frame flow

## Cel

Ten etap zmienia kierunek integracji pełnych ramek UART tak, aby aplikacja PC
nie sterowała bezpośrednio akceleratorem FFT/IFFT. Host może tylko:

- wysłać próbki wejściowe,
- wysłać nastawy gain,
- poprosić o przetwarzanie,
- odczytać status,
- odczytać próbki wyniku.

Jedynym blokiem, który zapisuje rejestry `fft_accelerator_mmio`, jest mini CPU
pracujący wewnątrz FPGA.

## Architektura

```text
PC application
    -> UART framed protocol
    -> uart_frame_buffer_backend
    -> CPU-visible frame mailbox
    -> mini_cpu_uart_frame_system
    -> mini_cpu_core
    -> fft_accelerator_mmio
    -> FFT/IFFT pipeline
    -> CPU writes result_frame
    -> UART framed protocol response
```

Ważna zasada własności:

```text
UART backend -> frame mailbox
mini CPU     -> fft_accelerator_mmio
```

Nie ma ścieżki:

```text
UART backend -> fft_accelerator_mmio
```

## Relacja do legacy A5 01 5A

Istniejący tryb:

```text
A5 01 5A
```

pozostaje bez zmian. Nadal jest obsługiwany przez `uart_cpu_fft_console` i
istniejący program impulsowy mini CPU. Ten etap dodaje osobną ścieżkę dla
pakietowego protokołu pełnych ramek i nie usuwa starszego testu.

## Moduły

Zmodyfikowany backend:

```text
rtl/uart/uart_frame_buffer_backend.v
```

Dodany system CPU:

```text
rtl/cpu/mini_cpu_uart_frame_system.v
```

Zaktualizowany ROM programu:

```text
rtl/cpu/mini_cpu_program_rom.v
```

Programy ROM dla tego flow:

```text
MINI_CPU_PROGRAM_UART_FRAME_ONCE
MINI_CPU_PROGRAM_UART_FRAME_SERVICE
```

`MINI_CPU_PROGRAM_UART_FRAME_ONCE` pozostaje jako jednorazowy wariant
historyczny. Domyślny `mini_cpu_uart_frame_system` używa teraz
`MINI_CPU_PROGRAM_UART_FRAME_SERVICE`, który po zakończeniu ramki wraca do
stanu oczekiwania na kolejne `RUN_FRAME` zamiast zatrzymywać CPU.

## Mapa mailboxa

Mailbox jest widoczny dla mini CPU pod adresami:

| Adres | Nazwa | Dostęp | Znaczenie |
| --- | --- | --- | --- |
| `0xA000` | `FRAME_CONTROL` | CPU read/write | Bit 0: `run_request`. CPU zapisuje bit 0, żeby potwierdzić request. Bit 1: clear. |
| `0xA001` | `FRAME_STATUS` | CPU read/write | Status ramki. CPU zapisuje busy/done/error. |
| `0xA003` | `FRAME_BASS_GAIN` | CPU read | Gain bass Q2.14 ustawiony przez UART. |
| `0xA004` | `FRAME_MID_GAIN` | CPU read | Gain mid Q2.14 ustawiony przez UART. |
| `0xA005` | `FRAME_TREBLE_GAIN` | CPU read | Gain treble Q2.14 ustawiony przez UART. |
| `0xA100..0xA1FF` | `FRAME_INPUT_SAMPLE` | CPU read | 256 próbek wejściowych signed int16. |
| `0xA200..0xA2FF` | `FRAME_RESULT_SAMPLE` | CPU write/read | 256 próbek wyniku signed int16. |

Adresy nie kolidują z aktualną mapą FFT:

```text
0x9000..0x9006   FFT registers
0x9100..0x91FF   FFT input samples
0x9200..0x92FF   FFT output samples
```

## Status

Bajt statusu w mailboxie:

| Bit | Nazwa | Znaczenie |
| --- | --- | --- |
| 0 | `INPUT_LOADED` | Host zapisał poprawny chunk wejściowy. |
| 1 | `CPU_BUSY` | Mini CPU przetwarza ramkę. |
| 2 | `DONE` | Mini CPU zakończył przetwarzanie i zapisał wynik. |
| 3 | `ERROR` | Wykryto błąd komendy, payloadu albo FFT status error. |
| 4 | `TIMEOUT` | Zarezerwowane dla przyszłego watchdog timeout. |

W obecnym programie testowym CPU ustawia `CPU_BUSY` na początku i `DONE` po
skopiowaniu wyników. Bit `TIMEOUT` jest zarezerwowany, ale nie ma jeszcze
pełnego watchdog countera w programie mini CPU.

## Zachowanie komend UART

`WRITE_FRAME_CHUNK` zapisuje próbki tylko do mailboxa.

`SET_GAINS` zapisuje gainy tylko do mailboxa.

`RUN_FRAME` nie uruchamia FFT. Ustawia tylko `run_request` w `FRAME_CONTROL`,
który jest widoczny dla mini CPU.

`READ_RESULT_CHUNK` zwraca próbki z `FRAME_RESULT_SAMPLE` dopiero po ustawieniu
statusu `DONE`. Przed `DONE` backend zwraca odpowiedź `ERROR`, ale nie próbuje
samodzielnie obliczać ani kopiować wyników.

## Sekwencja CPU

Program `MINI_CPU_PROGRAM_UART_FRAME_SERVICE` wykonuje:

1. Czeka na `FRAME_CONTROL.run_request`.
2. Ustawia `FRAME_STATUS.CPU_BUSY`.
3. Potwierdza request przez zapis do `FRAME_CONTROL`.
4. Czyta gainy z mailboxa.
5. Zapisuje gainy do `fft_accelerator_mmio`.
6. Czyści akcelerator przez `CONTROL.clear`.
7. Kopiuje `FRAME_INPUT_SAMPLE[0..255]` do `FFT_INPUT_SAMPLE[0..255]`.
8. Zapisuje `CONTROL.START`.
9. Polluje `FFT_STATUS` do `DONE` albo `ERROR/OVERFLOW`.
10. Kopiuje `FFT_OUTPUT_SAMPLE[0..255]` do `FRAME_RESULT_SAMPLE[0..255]`.
11. Ustawia status `INPUT_LOADED | DONE`.
12. Zapisuje `GPIO_RESULT=0x00A5`.
13. Wraca do kroku 1 i czeka na następny `RUN_FRAME`.

W wariancie błędu CPU zapisuje status `INPUT_LOADED | ERROR`, ustawia
`GPIO_RESULT=0x00E1` i również wraca do stanu oczekiwania. Dzięki temu stare
flagi `DONE` albo `ERROR` nie blokują kolejnej transakcji, o ile host wgra nową
ramkę i ponownie wyśle `RUN_FRAME`.

## Testy

Dodany test:

```text
tb/cpu_owned_uart_frame_flow_tb.v
```

Test sprawdza:

- zapis gainów przez UART backend,
- zapis impulsowej ramki wejściowej chunkami po 32 próbki,
- odrzucenie `READ_RESULT_CHUNK` przed `DONE`,
- wykrycie `run_request` przez mini CPU,
- zapis gainów przez CPU do `fft_accelerator_mmio`,
- zapis wybranych próbek wejściowych przez CPU do FFT input,
- zapis `CONTROL.START` przez CPU,
- zakończenie FFT/IFFT,
- zapis wyniku przez CPU do `FRAME_RESULT_SAMPLE`,
- odczyt wybranych próbek przez UART backend,
- dwie transakcje ramkowe bez resetu,
- wyczyszczenie starego `DONE` przed następnym uruchomieniem,
- powrót CPU do stanu idle/ready bez `HALT`,
- brak `ERROR/TIMEOUT` dla poprawnej ramki.

Istniejący test:

```text
tb/uart_frame_buffer_backend_tb.v
```

został zaktualizowany tak, aby sprawdzał mailbox CPU, a nie dawny lokalny
loopback.

Pełna regresja:

```text
python tools/run_all_tests.py
```

## Ograniczenia

Ten etap nadal nie dodaje:

- fizycznych pinów UART,
- constraints Tang Nano,
- GUI/pyserial jako zależności testów,
- I2S,
- AXI-Lite,
- Gowin FFT IP,
- fizycznej walidacji wielotransakcyjnej usługi na Tang Nano.

Program CPU jest już pętlą usługową w symulacji. Nadal wymaga potwierdzenia
pinów UART i testu na płytce przed traktowaniem go jako gotowego toru
sprzętowego.

## Następny branch

Rekomendowany następny etap:

```text
codex/pc-fpga-result-comparison-plots
```

Ten branch może porównać wyniki odebrane z FPGA z modelem PC i przygotować
wykresy różnic. Równolegle warto przygotować
`codex/tang-uart-pin-confirmation` dla fizycznego przypisania pinów UART.
