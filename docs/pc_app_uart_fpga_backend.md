# PC app UART FPGA backend

Ten etap dodaje warstwę PC-side, która pozwala użyć aplikacji Spectrum Lab jako
przyszłego klienta sprzętowego dla FPGA. Kod działa na istniejącym protokole
ramek UART i nie zmienia RTL, mini CPU ani zachowania akceleratora.

## Cel

Celem jest przygotowanie ścieżki:

```text
Spectrum Lab app / CLI
    -> UART frame backend
    -> transport mock albo serial
    -> FPGA UART frame mailbox
    -> mini CPU
    -> FFT/IFFT MMIO accelerator
    -> result frame buffer
    -> UART frame response
    -> PC app / CLI
```

PC nie steruje bezpośrednio rejestrami FFT/IFFT. PC wysyła tylko próbki,
gainy i komendy protokołu ramek. Właścicielem przetwarzania po stronie FPGA
pozostaje mini CPU.

## Dodane moduły PC-side

- `tools/spectrum_lab_hardware_backend.py` - wysokopoziomowy backend ramki
  256 próbek.
- `tools/uart_transport.py` - wspólny interfejs transportu, mock i opcjonalny
  transport serial.
- `tools/spectrum_lab_uart_client.py` - klient CLI do testu mock albo realnego
  portu UART.
- `tools/test_spectrum_lab_hardware_backend.py` - testy backendu PC bez
  zależności od pyserial.

## Sekwencja pakietów

Backend wykonuje pełny transfer jednej ramki w tej kolejności:

```text
PING
SET_GAINS
WRITE_FRAME_CHUNK x8
RUN_FRAME
GET_STATUS repeated until DONE
READ_RESULT_CHUNK x8
```

Każdy `WRITE_FRAME_CHUNK` przenosi 32 próbki signed int16. Pełna ramka ma
256 próbek, więc backend wysyła osiem chunków z offsetami:

```text
0, 32, 64, 96, 128, 160, 192, 224
```

Do kodowania i dekodowania pakietów używany jest wyłącznie istniejący helper:

```text
tools/uart_frame_protocol.py
```

Backend nie dubluje formatu ramek.

## Mock FPGA backend

Mock `MockFpgaTransport` jest przeznaczony do testów aplikacji i CI. Obsługuje:

- `PING`,
- `SET_GAINS`,
- `WRITE_FRAME_CHUNK`,
- `RUN_FRAME`,
- `GET_STATUS`,
- `READ_RESULT_CHUNK`.

Obecne zachowanie mocka jest deterministyczne i proste: po `RUN_FRAME` wynik
jest kopią wejściowej ramki. To jest celowy loopback na poziomie protokołu,
nie model matematyczny FFT/IFFT i nie zamiennik symulacji RTL.

Mock sprawdza, że aplikacja potrafi:

- wysłać gainy,
- podzielić ramkę na chunki,
- obsłużyć status busy/done,
- odczytać i zrekonstruować pełne 256 próbek,
- przesyłać payload zawierający bajty `A5` i `5A`.

## Opcjonalny serial backend

`SerialTransport` używa pyserial tylko wtedy, gdy użytkownik wybierze realny
port UART. Brak pyserial nie wpływa na `tools/run_all_tests.py`.

Jeżeli pyserial nie jest zainstalowany, ścieżka serial wypisuje czytelny błąd:

```text
pyserial is required for SerialTransport.
Install it with: python -m pip install pyserial
```

Przykład użycia z realnym portem:

```powershell
python tools/spectrum_lab_uart_client.py --port COM5
```

Parametry UART dla przyszłego testu sprzętowego:

- 115200 baud,
- 8 bitów danych,
- brak parzystości,
- 1 bit stopu.

Piny UART Tang Nano nadal są TODO. Nie należy zgadywać pinów RX/TX ani
modyfikować constraints bez potwierdzenia połączeń.

## CLI

Test mock bez sprzętu:

```powershell
python tools/spectrum_lab_uart_client.py --mock
```

Test realnego portu:

```powershell
python tools/spectrum_lab_uart_client.py --port COM5
```

Opcjonalny zapis wyniku:

```powershell
python tools/spectrum_lab_uart_client.py --mock --csv result.csv
```

Domyślna ramka to impuls `sample[0] = 64`, reszta próbek zero. Klient wypisuje
flagi statusu i wybrane próbki wyjściowe.

## GUI

`tools/spectrum_lab_app.py` ma teraz wybór backendu:

- `Local simulation` - dotychczasowe zachowanie lokalnego modelu Python.
- `Mock FPGA backend` - wysłanie próbek przez backend PC i mock transport.
- `Serial FPGA backend` - wysłanie próbek przez realny port UART, opcjonalne
  i zależne od pyserial oraz potwierdzonych pinów sprzętowych.

Tryb lokalny pozostaje domyślny. CI i testy nie wymagają tkinter, pyserial ani
fizycznego sprzętu.

## Testy

Nowy test:

```powershell
python tools/test_spectrum_lab_hardware_backend.py
```

Pełny zestaw:

```powershell
python tools/run_all_tests.py
```

Testy sprawdzają:

- osiem chunków po 32 próbki,
- `SET_GAINS`,
- offsety `WRITE_FRAME_CHUNK`,
- `RUN_FRAME` po zapisie chunków,
- polling `GET_STATUS`,
- rekonstrukcję 256 próbek z `READ_RESULT_CHUNK`,
- payload z bajtami `A5` i `5A`,
- brak wymogu pyserial,
- brak regresji lokalnego modelu Spectrum Lab.

## Ograniczenia

- To nie jest nowy RTL.
- Protokół UART nie został zmieniony.
- Mock backend zwraca loopback, nie prawdziwy wynik FFT/IFFT.
- Serial backend wymaga potwierdzonych pinów UART na Tang Nano.
- Backend nie dodaje GUI zależnego od pyserial w testach.
- Fizyczny test FPGA wymaga kolejnego etapu z topem i constraints dla UART.

## Następne kroki

Rekomendowane kolejne gałęzie:

- `codex/tang-cpu-owned-frame-uart-top`
- `codex/mini-cpu-frame-service-loop`
- `codex/pc-fpga-result-comparison-plots`
