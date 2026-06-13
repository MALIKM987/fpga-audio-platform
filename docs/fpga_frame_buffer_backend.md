# FPGA frame buffer backend dla protokołu UART

## Cel etapu

Ten etap dodaje samodzielny backend RTL dla pakietowego protokołu UART.
Backend łączy parser/formatter ramek UART z prawdziwą pamięcią jednej ramki
wejściowej i jednej ramki wynikowej po 256 próbek signed 16-bit.

To nadal nie jest integracja z FFT/IFFT. Komenda `RUN_FRAME` działa obecnie jako
kontrolowany tryb loopback:

```text
input_frame[0..255] -> result_frame[0..255]
```

Dzięki temu można zweryfikować pełną ścieżkę:

```text
PC packet
    -> UART frame parser
    -> frame buffer backend
    -> UART frame formatter
    -> PC response
```

bez ryzyka zmiany istniejącego pipeline FFT/IFFT, mini CPU albo topów Tang Nano.

## Moduł RTL

Dodany moduł:

```text
rtl/uart/uart_frame_buffer_backend.v
```

Moduł używa tego samego stylu interfejsu co `uart_frame_mock_backend`:

- wejście zdekodowanego pakietu: `packet_valid`, `packet_cmd`,
  `packet_seq`, `packet_payload_len`,
- odczyt payloadu przez `packet_payload_rd_addr` i `packet_payload_rd_data`,
- wyjście odpowiedzi dla formattera TX: `tx_start`, `tx_cmd`, `tx_seq`,
  `tx_payload_len`,
- odczyt payloadu odpowiedzi przez `tx_payload_rd_addr` i
  `tx_payload_rd_data`.

Dodatkowe wyjścia diagnostyczne w testbenchu pokazują:

- `frame_loaded`,
- `frame_done`,
- `bass_gain_q2_14`,
- `mid_gain_q2_14`,
- `treble_gain_q2_14`,
- `status_debug`.

## Komendy

Format pakietu pozostaje zgodny z dokumentem:

```text
docs/uart_frame_protocol.md
```

Obsługiwane komendy:

| Komenda | Nazwa | Odpowiedź | Uwagi |
| --- | --- | --- | --- |
| `0x10` | `PING` | `0x90 PONG` | Brak payloadu. |
| `0x11` | `SET_GAINS` | `0x95 STATUS` | Payload 6 bajtów: bass, mid, treble Q2.14 LE. |
| `0x12` | `WRITE_FRAME_CHUNK` | `0x95 STATUS` | Zapisuje maksymalnie 32 próbki do `input_frame`. |
| `0x13` | `RUN_FRAME` | `0x95 STATUS` | Na razie kopiuje input do result bez FFT/IFFT. |
| `0x14` | `READ_RESULT_CHUNK` | `0x94 RESULT_CHUNK` | Odczytuje maksymalnie 32 próbki z `result_frame`. |
| `0x15` | `GET_STATUS` | `0x95 STATUS` | Zwraca bieżący bajt statusu. |
| inne | unknown | `0x7F ERROR` | Payload zawiera kod błędnej komendy. |

## Payloady

### SET_GAINS

Payload ma dokładnie 6 bajtów:

```text
bass_gain_l
bass_gain_h
mid_gain_l
mid_gain_h
treble_gain_l
treble_gain_h
```

Wartości są przechowywane jako 16-bitowe Q2.14 little-endian. Przykłady:

- `0x4000` = `1.00`,
- `0x6000` = `1.50`,
- `0x3000` = `0.75`.

### WRITE_FRAME_CHUNK

Payload:

```text
offset_l
offset_h
count
sample0_l
sample0_h
...
```

Warunki walidacji:

- `count` musi być większe od zera,
- `count <= 32`,
- `payload_len == 3 + 2 * count`,
- `offset + count <= 256`.

Próbki są signed int16 little-endian.

### READ_RESULT_CHUNK

Payload komendy:

```text
offset_l
offset_h
count
```

Odpowiedź `RESULT_CHUNK` ma payload:

```text
status
offset_l
offset_h
count
sample0_l
sample0_h
...
```

## Bajt statusu

Status jest prosty i deterministyczny:

| Bit | Znaczenie |
| --- | --- |
| 0 | `PASS` ustawiany po poprawnym `RUN_FRAME`. |
| 1 | `DONE` ustawiany po zakończeniu `RUN_FRAME`. |
| 2 | `FRAME_LOADED` ustawiany po poprawnym `WRITE_FRAME_CHUNK`. |
| 3 | `ERROR` ustawiany po błędnej komendzie albo błędnym payloadzie. |

Po resecie status wynosi `0x00`.

Udany zapis chunku ustawia status na `0x04`. Udane `RUN_FRAME` po załadowaniu
ramki ustawia status na `0x07`.

## Tryb RUN_FRAME

`RUN_FRAME` nie uruchamia jeszcze akceleratora FFT/IFFT. W tym branchu jest to
celowy tryb loopback:

```text
for i in 0..255:
    result_frame[i] = input_frame[i]
```

To pozwala przetestować:

- zapis ramki z PC,
- przechowanie signed int16,
- odczyt wybranych fragmentów wyniku,
- status `DONE/PASS`,
- odpowiedzi UART z checksumą.

## Testbench

Dodany testbench:

```text
tb/uart_frame_buffer_backend_tb.v
```

Zakres testów:

- reset i domyślne gainy,
- `PING -> PONG`,
- zapis gainów Q2.14,
- zapis chunku od offsetu 0,
- zapis chunku od offsetu 16,
- `RUN_FRAME` jako loopback,
- odczyt wyników z offsetu 0 i 16,
- `GET_STATUS`,
- błąd przy niepoprawnym zakresie odczytu,
- błąd przy nieznanej komendzie.

Pełna regresja:

```text
python tools/run_all_tests.py
```

Test protokołu Python:

```text
python tools/test_uart_frame_protocol.py
```

Kompilacja helpera Python:

```text
python -m py_compile tools/uart_frame_protocol.py
```

## Ograniczenia

Ten etap nie dodaje jeszcze:

- połączenia z `fft_accelerator_mmio`,
- połączenia z mini CPU,
- połączenia z `uart_cpu_fft_console`,
- fizycznego UART RX/TX top-level dla tego nowego protokołu,
- prawdziwej FFT/IFFT w ścieżce `RUN_FRAME`,
- I2S,
- AXI-Lite,
- Gowin FFT IP,
- zmian w constraints Tang Nano.

Stary pakiet:

```text
A5 01 5A
```

pozostaje obsługiwany przez istniejący `uart_cpu_fft_console` i nie został
zmieniony.

## Następny etap

Rekomendowany kolejny krok to osobny branch, który połączy ten backend z
istniejącym akceleratorem MMIO albo doda top UART dla pełnych ramek, bez
mieszania tego z fizycznym I2S.
