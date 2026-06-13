# UART frame protocol dla pełnych ramek próbek

## Cel

Ten dokument opisuje pierwszy format protokołu UART dla przyszłego przesyłania
pełnych ramek 256 próbek między aplikacją PC Spectrum Lab a systemem FPGA.

Obecna konsola sprzętowa nadal obsługuje stary, prosty test impulsowy:

```text
PC -> FPGA: A5 01 5A
FPGA -> PC: A5 81 STATUS out0 out1 out2 out16 out64 out128 out255 5A
```

Ten pakiet pozostaje wspierany i nie jest zmieniany przez ten etap. Nowy format
ramkowy jest przygotowaniem pod przyszły transfer pełnych danych wejściowych i
wynikowych.

## Dlaczego stary format nie wystarcza

Stary format ma tylko bajt startu i bajt końca. Działa dla krótkiej komendy
`RUN_IMPULSE_TEST`, ale nie jest bezpieczny dla pełnych ramek próbek, ponieważ
dane audio mogą zawierać dowolne bajty, także `0xA5` i `0x5A`.

Pełny transfer musi więc używać jawnej długości payloadu i checksumy. Dzięki
temu odbiornik nie kończy pakietu tylko dlatego, że w danych pojawił się bajt
`0x5A`.

## Format pakietu

Nowy format pakietu:

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

Pole `LEN` jest liczbą bajtów payloadu w formacie little-endian:

```text
LEN = LEN_L + 256 * LEN_H
```

## Checksum

W tej wersji checksum jest prostą sumą modulo 256:

```text
CHK = (CMD + SEQ + LEN_L + LEN_H + sum(PAYLOAD)) & 0xFF
```

Do checksumy nie wchodzą pola `SOF`, `CHK` ani `EOF`.

To nie jest kryptograficzne zabezpieczenie danych. Celem jest tanie wykrycie
typowych błędów transmisji i pomyłek w długości pakietu.

## Sekwencja

Pole `SEQ` jest numerem sekwencyjnym pakietu. W pierwszej wersji służy głównie
do diagnostyki PC <-> FPGA i do łatwego powiązania odpowiedzi z żądaniem.

## Format próbek i gainów

Próbki audio:

- signed int16,
- little-endian,
- zakres `-32768..32767`.

Gainy:

- signed int16,
- little-endian,
- format Q2.14,
- `1.00 = 16384`,
- `0.75 = 12288`,
- `1.50 = 24576`.

## Komendy wersji 1

| CMD | Nazwa | Kierunek | Znaczenie |
| --- | --- | --- | --- |
| `0x01` | `RUN_IMPULSE_TEST` | PC -> FPGA | Stara komenda testu impulsowego pozostaje zgodna z `A5 01 5A`. |
| `0x10` | `PING` | PC -> FPGA | Test obecności urządzenia. |
| `0x90` | `PONG` | FPGA -> PC | Odpowiedź na `PING`. |
| `0x11` | `SET_GAINS` | PC -> FPGA | Ustawia gainy bass/mid/treble Q2.14. |
| `0x12` | `WRITE_FRAME_CHUNK` | PC -> FPGA | Zapisuje fragment wejściowej ramki 256 próbek. |
| `0x13` | `RUN_FRAME` | PC -> FPGA | Uruchamia przyszłe przetwarzanie przesłanej ramki. |
| `0x14` | `READ_RESULT_CHUNK` | PC -> FPGA | Żąda fragmentu ramki wynikowej. |
| `0x94` | `RESULT_CHUNK` | FPGA -> PC | Zwraca fragment ramki wynikowej. |
| `0x15` | `GET_STATUS` | PC -> FPGA | Żąda bieżącego statusu. |
| `0x95` | `STATUS` | FPGA -> PC | Zwraca bieżący status. |
| `0x7F` | `ERROR` | FPGA -> PC | Błąd komendy, długości, checksumy, zakresu albo stanu busy. |

## Payload SET_GAINS

Komenda:

```text
CMD = 0x11
```

Payload:

```text
bass_gain_q2_14    int16 little-endian
mid_gain_q2_14     int16 little-endian
treble_gain_q2_14  int16 little-endian
```

Łączna długość payloadu: 6 bajtów.

## Payload WRITE_FRAME_CHUNK

Komenda:

```text
CMD = 0x12
```

Payload:

```text
offset_u16 little-endian
count_u8
samples[count] signed int16 little-endian
```

Ograniczenia pierwszej wersji:

- rozmiar pełnej ramki: 256 próbek,
- `offset` w zakresie `0..255`,
- `count > 0`,
- `offset + count <= 256`,
- zalecany maksymalny chunk: 32 próbki.

Dla ramki 256 próbek i chunku 32 próbki potrzeba 8 pakietów
`WRITE_FRAME_CHUNK`.

## Payload RUN_FRAME

Komenda:

```text
CMD = 0x13
```

W tej wersji dokumentujemy semantykę przyszłej komendy. Docelowo FPGA po jej
odebraniu uruchomi:

```text
input sample memory
    -> FFT
    -> spectral modification
    -> IFFT
    -> output sample memory
```

W tym branchu nie integrowano jeszcze tej komendy z RTL.

## Payload READ_RESULT_CHUNK

Komenda:

```text
CMD = 0x14
```

Payload żądania:

```text
offset_u16 little-endian
count_u8
```

Odpowiedź:

```text
CMD = 0x94
```

Payload odpowiedzi:

```text
status_u8
offset_u16 little-endian
count_u8
samples[count] signed int16 little-endian
```

## Payload GET_STATUS

Komenda:

```text
CMD = 0x15
```

Odpowiedź:

```text
CMD = 0x95
PAYLOAD = status_u8
```

## Planowana transakcja PC -> FPGA

Docelowy przebieg dla PC Spectrum Lab:

```text
PING
SET_GAINS
WRITE_FRAME_CHUNK offset=0 count=32
WRITE_FRAME_CHUNK offset=32 count=32
...
WRITE_FRAME_CHUNK offset=224 count=32
RUN_FRAME
GET_STATUS repeated until DONE
READ_RESULT_CHUNK offset=0 count=32
READ_RESULT_CHUNK offset=32 count=32
...
READ_RESULT_CHUNK offset=224 count=32
```

Wynikowe próbki mogą potem zostać narysowane przez aplikację PC.

## Relacja do mini CPU i MMIO

Obecna architektura ma już memory-mapped warstwę akceleratora:

```text
INPUT_SAMPLE[0..255]
OUTPUT_SAMPLE[0..255]
BASS_GAIN
MID_GAIN
TREBLE_GAIN
CONTROL
STATUS
```

Nowy protokół jest warstwą transportową po UART. W przyszłym branchu parser RTL
albo firmware/mini CPU będzie mapować pakiety:

- `WRITE_FRAME_CHUNK` na zapisy do `INPUT_SAMPLE`,
- `SET_GAINS` na zapisy do rejestrów gain,
- `RUN_FRAME` na zapis bitu START w `CONTROL`,
- `GET_STATUS` i `READ_RESULT_CHUNK` na odczyty z `STATUS` i `OUTPUT_SAMPLE`.

## Pliki Pythona

Implementacja helperów:

```text
tools/uart_frame_protocol.py
```

Testy:

```text
tools/test_uart_frame_protocol.py
```

Najważniejsze helpery:

- `encode_packet`,
- `decode_packet`,
- `checksum`,
- `make_ping`,
- `make_set_gains`,
- `make_write_frame_chunk`,
- `make_run_frame`,
- `make_read_result_chunk`,
- `make_get_status`,
- `decode_result_chunk`,
- `build_write_frame_chunks`,
- `build_read_result_requests`.

Helper `build_write_frame_chunks` zamienia jedną ramkę 256 próbek signed int16
na pakiety `WRITE_FRAME_CHUNK`. To przygotowuje przyszły backend PC Spectrum
Lab, ale nie wymaga `pyserial` i nie uruchamia sprzętu.

## Testy

Uruchomienie testu protokołu:

```text
python tools/test_uart_frame_protocol.py
```

Pełna regresja projektu:

```text
python tools/run_all_tests.py
```

Test protokołu sprawdza:

- encode/decode `PING`,
- wartość checksumy,
- odrzucenie złej checksumy,
- payload zawierający bajty `A5` i `5A`,
- kodowanie gainów Q2.14,
- kodowanie signed int16 w `WRITE_FRAME_CHUNK`,
- walidację offset/count,
- dekodowanie `RESULT_CHUNK`,
- rozdzielenie starego pakietu `A5 01 5A` od nowego formatu ramkowego,
- budowanie 8 chunków dla ramki 256 próbek.

## Ograniczenia tej wersji

Ten branch nie dodaje jeszcze:

- parsera RTL pakietów ramkowych,
- integracji z `uart_cpu_fft_console`,
- transferu pełnej ramki przez fizyczny UART,
- backendu sprzętowego w GUI PC Spectrum Lab,
- zmian w mini CPU,
- zmian w FFT/IFFT core,
- I2S,
- AXI-Lite,
- Gowin FFT IP,
- constraintów UART dla Tang Nano.

## Następne branche

Rekomendowane kolejne kroki:

```text
codex/uart-frame-protocol-rtl
codex/pc-app-uart-fpga-backend
codex/fpga-frame-buffer-integration
```
