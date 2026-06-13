# RTL UART frame packet protocol

## Cel etapu

Ten etap dodaje samodzielną implementację RTL dla nowego protokołu pakietów UART
opisanych w:

```text
docs/uart_frame_protocol.md
```

Moduły z tego etapu służą wyłącznie do walidacji parsera i formattera pakietów
w symulacji Verilog. Nie są jeszcze podłączone do akceleratora FFT/IFFT, mini
CPU, MMIO ani bufora ramek.

Stary pakiet testu impulsowego:

```text
A5 01 5A
```

pozostaje obsługiwany przez istniejący `uart_cpu_fft_console` i nie został
zmieniony.

## Format pakietu

RTL implementuje ten sam format, co helper Python:

```text
SOF      1 byte   0xA5
CMD      1 byte
SEQ      1 byte
LEN_L    1 byte
LEN_H    1 byte
PAYLOAD  LEN bytes
CHK      1 byte
EOF      1 byte   0x5A
```

Checksum:

```text
CHK = (CMD + SEQ + LEN_L + LEN_H + sum(PAYLOAD)) & 0xFF
```

Jawne pole `LEN` pozwala przesyłać payload zawierający dowolne bajty, także
`0xA5` i `0x5A`.

## RX packet parser

Moduł:

```text
rtl/uart/uart_frame_packet_rx.v
```

Wejście modułu jest bajtowym strumieniem w stylu istniejącego `uart_rx`:

```text
rx_valid
rx_data[7:0]
```

Parser rozpoznaje:

- `SOF`,
- `CMD`,
- `SEQ`,
- `LEN_L`,
- `LEN_H`,
- `PAYLOAD`,
- `CHK`,
- `EOF`.

Waliduje:

- bajt startu,
- bajt końca,
- jawnie podaną długość,
- maksymalną długość payloadu,
- checksum.

Po poprawnym pakiecie wystawia impuls `packet_valid` oraz pola:

```text
cmd
seq
payload_len
payload_rd_addr
payload_rd_data
```

Payload jest przechowywany w małym buforze wewnętrznym odczytywanym przez
adres `payload_rd_addr`.

Flagi błędów:

- `error_bad_checksum`,
- `error_bad_eof`,
- `error_length_too_large`,
- `error_malformed`.

Flagi są impulsami diagnostycznymi. Błędny pakiet nie generuje `packet_valid`.

## TX packet formatter

Moduł:

```text
rtl/uart/uart_frame_packet_tx.v
```

Wejście modułu:

```text
start
cmd
seq
payload_len
payload_rd_addr
payload_rd_data
```

Wyjście jest bajtowym strumieniem:

```text
tx_valid
tx_data[7:0]
tx_ready
```

Formatter generuje:

```text
A5 CMD SEQ LEN_L LEN_H PAYLOAD CHK 5A
```

z checksumą zgodną z dokumentacją i helperem Python.

Sygnały statusu:

- `busy`,
- `done`,
- `error_length_too_large`.

## Mock backend

Moduł:

```text
rtl/uart/uart_frame_mock_backend.v
```

Mock backend odbiera poprawnie zdekodowane pakiety z RX parsera i przygotowuje
odpowiedź dla TX formattera. Nie dotyka FFT/IFFT, mini CPU ani MMIO.

Obsługiwane komendy:

| Komenda | Odpowiedź | Uwagi |
| --- | --- | --- |
| `0x10 PING` | `0x90 PONG` | Brak payloadu. |
| `0x15 GET_STATUS` | `0x95 STATUS` | Payload statusu `0x00`. |
| `0x11 SET_GAINS` | `0x95 STATUS` | Akceptowane tylko przy payloadzie 6 bajtów. |
| `0x12 WRITE_FRAME_CHUNK` | `0x95 STATUS` | Waliduje `offset`, `count` i długość payloadu. |
| nieznana | `0x7F ERROR` | Payload zawiera kod nieznanej komendy. |

Błędne pakiety, na przykład ze złą checksumą albo złym EOF, są odrzucane przez
RX parser i nie dochodzą do mock backendu.

## Testbenchy

Dodane testbenchy:

```text
tb/uart_frame_packet_rx_tb.v
tb/uart_frame_packet_tx_tb.v
tb/uart_frame_packet_mock_backend_tb.v
```

Zakres testów:

- poprawny `PING` jest dekodowany przez RX,
- payload zawierający bajty `A5` i `5A` jest dekodowany dzięki polu `LEN`,
- zła checksum jest odrzucana,
- zły EOF jest odrzucany,
- zbyt długa ramka jest odrzucana,
- TX generuje bajty zgodne z formatem i checksumą,
- mock backend zwraca `PONG` dla `PING`,
- mock backend zwraca `ERROR` dla nieznanej komendy,
- payload podobny do `WRITE_FRAME_CHUNK` jest akceptowany,
- stary pakiet `A5 01 5A` nie jest obsługiwany przez nowy backend i pozostaje
  domeną istniejącego `uart_cpu_fft_console`.

Pełna regresja:

```text
python tools/run_all_tests.py
```

## Relacja do Python reference

Pythonowy helper:

```text
tools/uart_frame_protocol.py
```

pozostaje modelem referencyjnym formatu pakietów. RTL implementuje ten sam
układ pól i tę samą checksumę modulo 256.

W tym branchu nie dodano jeszcze automatycznego porównywania bajt po bajcie
między Pythonem i Verilogiem. Testbenchy Verilog używają ręcznie zapisanych
pakietów z oczekiwanymi wartościami checksum.

## Ograniczenia

Ten etap nie dodaje jeszcze:

- integracji z `uart_cpu_fft_console`,
- integracji z `fft_accelerator_mmio`,
- zapisu do `INPUT_SAMPLE[0..255]`,
- odczytu z `OUTPUT_SAMPLE[0..255]`,
- sterowania mini CPU,
- pełnego backendu PC -> FPGA,
- constraintów Tang Nano,
- fizycznego I2S,
- AXI-Lite,
- Gowin FFT IP.

## Następny etap

Rekomendowany kolejny branch:

```text
codex/fpga-frame-buffer-integration
```

W tym etapie nowy parser pakietów może zostać połączony z buforem wejściowym,
rejestrami gain, sygnałem START i buforem wyników.
