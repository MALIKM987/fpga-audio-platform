# Dokumentacja projektu


## Zalecana kolejność czytania

1. [requirements_and_functionality.md](requirements_and_functionality.md) -
   wymagania, zakres i ograniczenia.
2. [architecture.md](architecture.md) - architektura systemu i przepływ danych.
3. [problem_analysis.md](problem_analysis.md) - analiza problemu DSP.
4. [pc_application.md](pc_application.md) - instrukcja aplikacji PC Spectrum Lab.
5. [uart_protocol.md](uart_protocol.md) - protokół ramek UART.
6. [mini_cpu.md](mini_cpu.md) - własny mini CPU soft-core i service loop.
7. [fft_dsp_accelerator.md](fft_dsp_accelerator.md) - akcelerator FFT/IFFT.
8. [fixed_point_model.md](fixed_point_model.md) - fixed-point, Q2.14 i różnice
   względem modelu float.
9. [tang_nano_hardware.md](tang_nano_hardware.md) - uruchomienie na Tang Nano.
10. [testing_and_validation.md](testing_and_validation.md) - testy i raport
    walidacji.
11. [design_patterns.md](design_patterns.md) - wzorce projektowe użyte w kodzie.
12. [maintenance_and_deployment.md](maintenance_and_deployment.md) - utrzymanie,
    workflow GitHub i budowanie bitstreamu.
13. [bibliography.md](bibliography.md) - bibliografia i źródła.

## Mapa dokumentów

| Dokument | Zawartość |
| --- | --- |
| `architecture.md` | diagram komponentów, data-flow, deployment |
| `requirements_and_functionality.md` | wymagania funkcjonalne i niefunkcjonalne |
| `problem_analysis.md` | ramki próbek, FFT, IFFT, fixed-point |
| `pc_application.md` | GUI, backendy, presety, CSV |
| `uart_protocol.md` | format ramek, komendy, statusy |
| `mini_cpu.md` | soft-core CPU, ROM programu, service loop |
| `fft_dsp_accelerator.md` | pipeline FFT/IFFT, BASS/MID/TREBLE, MMIO |
| `fixed_point_model.md` | signed int16, Q2.14, saturacja |
| `tang_nano_hardware.md` | top, piny, Gowin EDA, test sprzętowy |
| `testing_and_validation.md` | testy Python/Verilog/hardware i tabela fixów |
| `design_patterns.md` | Strategy, Command, Adapter, Facade, FSM, MMIO |
| `maintenance_and_deployment.md` | PR workflow, testy, bitstream, reprodukcja |
| `bibliography.md` | książki, dokumentacje i materiały kursowe |
