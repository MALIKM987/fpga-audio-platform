# Wymagania i funkcjonalność

## Cel projektu

Celem projektu jest demonstracja kompletnego, testowalnego systemu DSP na FPGA:
PC wysyła ramkę audio do Tang Nano 20K, FPGA przetwarza ją w torze FFT/IFFT, a PC
odbiera wynik i porównuje go z modelem referencyjnym.

## Wymagania funkcjonalne

- Generowanie testowych ramek 256 próbek po stronie PC.
- Lokalna symulacja float w aplikacji PC.
- Wysyłanie ramek signed int16 przez UART.
- Ustawianie gainów `BASS`, `MID`, `TREBLE` w formacie Q2.14.
- Odbiór ramek UART na FPGA.
- Buforowanie danych w mailboxie widocznym dla mini CPU.
- Sterowanie akceleratorem wyłącznie przez mini CPU.
- Przetwarzanie ramki w torze FFT -> spectral gain -> IFFT.
- Odesłanie wyniku do PC.
- Wizualizacja wejścia, wyniku lokalnego, wyniku FPGA i różnic.
- Eksport CSV.
- Testowanie bez sprzętu przez Mock FPGA backend.

## Wymagania niefunkcjonalne

- Kod RTL ma być prosty do symulacji w Icarus Verilog.
- Testy mają być uruchamiane jedną komendą `python tools/run_all_tests.py`.
- System ma być możliwy do zbudowania w Gowin EDA.
- Dokumentacja ma jasno odróżniać aktualny demonstrator od przyszłego realtime
  audio I/O.
- Komunikacja PC-FPGA ma być powtarzalna i możliwa do debugowania w konsoli.

## Aktualnie zaimplementowany zakres

- PC Spectrum Lab GUI.
- Backend lokalny, mock i serial.
- Protokół UART dla pełnych ramek.
- Top Tang Nano `tang_cpu_owned_frame_uart_top`.
- Mini CPU soft-core i program ROM.
- CPU-owned UART frame service loop.
- MMIO wrapper dla akceleratora.
- Własny tor FFT/IFFT fixed-point.
- Spectral processor z pasmami `BASS`, `MID`, `TREBLE`.
- Testy Python, Verilog i GitHub Actions.

## Poza zakresem aktualnej wersji

- Real-time wejście I2S z PCM1808.
- Real-time wyjście I2S do PCM5102A.
- Streaming audio bez udziału PC.
- AXI-Lite.
- System operacyjny, ARM, RISC-V albo STM32.
- Dowolne niezależne filtry float w FPGA.
- Gowin FFT IP jako główny backend.

## Ograniczenia

Aktualna wersja jest frame-based FPGA DSP demonstrator, a nie kompletnym
produktem realtime audio I/O. FPGA obsługuje trzy pasma sprzętowe i gain Q2.14.
Gainy większe niż około `+2.0` saturują. Wiele modyfikacji GUI w tym samym
paśmie sprzętowym daje efekt "last one wins".
