# Architektura systemu

Aktualna wersja projektu jest blokowym demonstratorem DSP na FPGA. Komputer PC
generuje ramkę 256 próbek, wysyła ją przez UART do Tang Nano 20K, a FPGA
przetwarza ramkę w stałoprzecinkowym torze FFT/IFFT. Wynik wraca do PC i jest
porównywany z lokalną symulacją.

## Komponenty

```mermaid
flowchart TB
    subgraph PC["PC"]
        GUI["Spectrum Lab GUI"]
        Local["Local float simulation"]
        Mock["Mock FPGA backend"]
        Serial["Serial FPGA backend"]
        ProtoPC["UART protocol helpers"]
    end

    subgraph FPGA["Tang Nano 20K FPGA"]
        UART["uart_rx / uart_tx"]
        Packet["uart_frame_packet_rx / tx"]
        Mailbox["uart_frame_buffer_backend"]
        CPU["custom mini CPU"]
        ROM["mini_cpu_program_rom"]
        MMIO["fft_accelerator_mmio"]
        DSP["FFT/IFFT DSP accelerator"]
    end

    GUI --> Local
    GUI --> Mock
    GUI --> Serial --> ProtoPC --> UART
    UART --> Packet --> Mailbox --> CPU
    ROM --> CPU
    CPU --> MMIO --> DSP --> MMIO --> CPU --> Mailbox --> Packet --> UART
    UART --> ProtoPC --> GUI
```

## Przepływ danych

```mermaid
flowchart LR
    A["PC: generate 256 samples"]
    B["SET_GAINS"]
    C["WRITE_FRAME_CHUNK x8"]
    D["RUN_FRAME"]
    E["mini CPU copies frame to MMIO"]
    F["FFT -> spectral gain -> IFFT"]
    G["mini CPU copies result"]
    H["READ_RESULT_CHUNK x8"]
    I["PC plots and CSV"]

    A --> B --> C --> D --> E --> F --> G --> H --> I
```

## Top FPGA

Główny top sprzętowy dla aktualnego systemu:

```text
rtl/top/tang_cpu_owned_frame_uart_top.v
```

Top łączy:

- bitowy `uart_rx`,
- bitowy `uart_tx`,
- parser i formatter ramek UART,
- `uart_frame_buffer_backend`,
- `mini_cpu_uart_frame_system`,
- aktywną niskim poziomem diodę statusu.

## Odpowiedzialność modułów

| Warstwa | Odpowiedzialność |
| --- | --- |
| PC GUI | generuje sygnał, uruchamia backendy, rysuje wykresy |
| UART protocol | pakuje 256 próbek w małe komendy i odpowiedzi |
| UART RTL | zamienia bajty na ramki i ramki na bajty |
| Mailbox | przechowuje ramkę wejściową, gainy, status i wynik |
| mini CPU | jedyny właściciel sterowania `fft_accelerator_mmio` |
| MMIO | udostępnia rejestry i pamięci próbek dla CPU |
| FFT/IFFT DSP | wykonuje przetwarzanie fixed-point ramki |

## Diagram deployment

```mermaid
flowchart LR
    PC["Windows/Linux PC\nPython + Tkinter"]
    USB["USB cable / BL616 USB-UART"]
    Board["Sipeed Tang Nano 20K\nGW2AR-18 FPGA"]

PC <-->|"115200 8N1"| USB <-->|"uart_rx / uart_tx"| Board
```

## UML-style structural dependency diagram

Ten diagram jest dokumentacyjnym widokiem strukturalnym. Nie jest ścisłą
hierarchią klas obiektowych dla całego projektu. Część elementów to klasy lub
moduły Pythona, a część to moduły RTL albo bloki architektoniczne.

```mermaid
classDiagram
    class SpectrumLabGUI {
        +generate_frame()
        +select_backend()
        +plot_results()
    }
    class HardwareBackend {
        +run_frame(samples, gains)
    }
    class UartFrameProtocol {
        +encode_packet()
        +decode_packet()
    }
    class FrameMailbox {
        +input_frame
        +result_frame
        +status
    }
    class MiniCPU {
        +program_counter
        +execute_service_loop()
    }
    class FftAcceleratorMmio {
        +CONTROL
        +STATUS
        +INPUT_SAMPLE
        +OUTPUT_SAMPLE
    }
    class FftIfftPipeline {
        +start
        +busy
        +done
    }

    SpectrumLabGUI --> HardwareBackend
    HardwareBackend --> UartFrameProtocol
    UartFrameProtocol --> FrameMailbox
    FrameMailbox --> MiniCPU
    MiniCPU --> FftAcceleratorMmio
    FftAcceleratorMmio --> FftIfftPipeline
```

## Use-case diagram

```mermaid
flowchart LR
    User["Użytkownik"]
    GUI["PC Spectrum Lab"]
    Mock["Uruchom test mock FPGA"]
    Serial["Uruchom test Serial FPGA"]
    Local["Porównaj z lokalną symulacją"]
    CSV["Eksportuj CSV"]
    HW["Przetwórz ramkę na FPGA"]

    User --> GUI
    GUI --> Mock
    GUI --> Serial
    GUI --> Local
    GUI --> CSV
    Serial --> HW
```

## Activity diagram jednej transakcji ramki

```mermaid
flowchart TD
    A["Wprowadź lub wybierz sygnał"]
    B["Wybierz backend"]
    C["Wyślij SET_GAINS"]
    D["Wyślij WRITE_FRAME_CHUNK x8"]
    E["Wyślij RUN_FRAME"]
    F["Poll GET_STATUS"]
    G{"DONE?"}
    H["Odczytaj READ_RESULT_CHUNK x8"]
    I["Policz metryki i narysuj wykres"]
    J["Zgłoś błąd/timeout"]

    A --> B --> C --> D --> E --> F --> G
    G -- tak --> H --> I
    G -- błąd albo timeout --> J
    G -- nie --> F
```

## Dlaczego CPU-owned flow

UART nie steruje bezpośrednio akceleratorem, ponieważ:

- akcelerator ma jednego właściciela sterowania,
- program CPU można rozszerzać bez zmiany protokołu transportowego,
- UART pozostaje warstwą komunikacji i mailboxa,
- testy łatwiej rozdzielają błędy protokołu od błędów DSP,
- debugowanie jest czytelniejsze: PC wysyła request, CPU wykonuje procedurę.

## Granice aktualnej architektury

System nie odbiera jeszcze próbek z fizycznego ADC i nie wysyła ich do fizycznego
DAC. Fizyczny tor PCM1808/PCM5102A jest przyszłą warstwą sprzętową. Obecnie
źródłem danych jest PC, a komunikacja z FPGA odbywa się przez UART.
