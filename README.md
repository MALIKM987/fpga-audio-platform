# FPGA Audio Platform (Tang Nano 20K)

## Opis projektu
FPGA Audio Platform to projekt platformy audio realizowanej na układzie FPGA Tang Nano 20K. Projekt koncentruje się na implementacji i organizacji modułów cyfrowych związanych z przetwarzaniem sygnałów audio oraz przygotowaniu struktury umożliwiającej rozwój, testowanie i wdrożenie rozwiązania na sprzęcie.

Repozytorium obejmuje kod RTL, testbenche oraz pliki związane z implementacją sprzętową.

## Cele projektu
- opracowanie modułów cyfrowych do przetwarzania sygnałów audio,
- implementacja logiki w języku Verilog,
- przygotowanie środowiska do symulacji i testów,
- wdrożenie projektu na platformie FPGA Tang Nano 20K.

## Wykorzystane technologie
- Verilog
- FPGA
- Tang Nano 20K
- RTL design
- testbench / simulation

## Struktura projektu
- `rtl/audio/` – moduły RTL związane z torem audio,
- `tb/` – testbenche do weryfikacji działania,
- `gowin_impl/tang_audio_hw/` – pliki implementacyjne i sprzętowe,
- `docs/` – dokumentacja projektu.

## Zakres mojej pracy
W projekcie zajmowałem się:
- projektowaniem i organizacją modułów RTL,
- przygotowaniem struktury projektu pod rozwój systemu audio na FPGA,
- tworzeniem i uruchamianiem testbenchy,
- przygotowaniem projektu do implementacji na docelowej platformie sprzętowej.

## Status projektu
Projekt stanowi rozwijaną platformę do eksperymentów i implementacji funkcji audio na układzie FPGA.

## Możliwe kierunki rozwoju
- rozbudowa toru audio o kolejne moduły DSP,
- integracja z interfejsami wejścia/wyjścia audio,
- rozszerzenie testów symulacyjnych,
- optymalizacja wykorzystania zasobów FPGA,
- przygotowanie demonstracji działania na sprzęcie.

## Autor
Maciej Molik

# FPGA Audio Platform (Tang Nano 20K)

## Project Overview
FPGA Audio Platform is an audio-oriented project implemented on the Tang Nano 20K FPGA board. The project focuses on designing and organizing digital modules related to audio signal processing, while providing a structure for further development, verification, and hardware deployment.

The repository includes RTL code, testbenches, and hardware implementation files.

## Project Goals
- develop digital modules for audio signal processing,
- implement logic in Verilog,
- prepare an environment for simulation and verification,
- deploy the design on the Tang Nano 20K FPGA platform.

## Technologies Used
- Verilog
- FPGA
- Tang Nano 20K
- RTL design
- testbench / simulation

## Project Structure
- `rtl/audio/` – RTL modules related to the audio path,
- `tb/` – testbenches for functional verification,
- `gowin_impl/tang_audio_hw/` – implementation and hardware-related files,
- `docs/` – project documentation.

## My Contribution
In this project, I was responsible for:
- designing and organizing RTL modules,
- preparing the project structure for an FPGA-based audio system,
- creating and running testbenches,
- preparing the design for implementation on the target hardware platform.

## Project Status
The project is an evolving platform for experimentation and implementation of audio-related functions on FPGA.

## Possible Future Improvements
- extend the audio path with additional DSP modules,
- integrate audio input/output interfaces,
- expand simulation coverage,
- optimize FPGA resource usage,
- prepare a hardware demonstration.

## Author
Maciej Molik
