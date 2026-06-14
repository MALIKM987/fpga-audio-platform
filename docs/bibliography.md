# Bibliografia i źródła

## DSP i FFT

- Alan V. Oppenheim, Ronald W. Schafer,
  *Discrete-Time Signal Processing*, Prentice Hall.
  Dokładna edycja i rok do zweryfikowania przed finalnym raportem drukowanym.
- Sanjit K. Mitra,
  *Digital Signal Processing: A Computer-Based Approach*, McGraw-Hill.
  Dokładna edycja i rok do zweryfikowania przed finalnym raportem drukowanym.
- K. R. Rao, D. N. Kim, J. J. Hwang,
  *Fast Fourier Transform: Algorithms and Applications*, Springer.
  Dokładna edycja i rok do zweryfikowania przed finalnym raportem drukowanym.
- John G. Proakis, Dimitris G. Manolakis,
  *Digital Signal Processing: Principles, Algorithms, and Applications*,
  Prentice Hall.
  Dokładna edycja i rok do zweryfikowania przed finalnym raportem drukowanym.

## FPGA, Verilog i narzędzia

- Dokumentacja języka Verilog/SystemVerilog używana w narzędziach symulacyjnych.
- Dokumentacja Icarus Verilog, używana do lokalnych i CI symulacji testbenchy.
- Dokumentacja Gowin EDA, szczególnie przepływ synthesis, place and route,
  bitstream generation oraz Programmer.
- Dokumentacja układów Gowin GW2AR, w tym rodziny używanej na Tang Nano 20K.
- Dokumentacja Sipeed Tang Nano 20K oraz materiały dotyczące onboard BL616
  USB-UART.

Dokładne wersje dokumentów producenta zależą od wersji Gowin EDA, rewizji płytki
i paczki dokumentacji pobranej przez użytkownika. Przed finalnym raportem warto
dopisać numery wersji albo daty pobrania.

## Python i GUI

- Dokumentacja Python 3.
- Dokumentacja `tkinter`, używana przez GUI Spectrum Lab.
- Dokumentacja `matplotlib`, jeśli GUI jest uruchamiane z wykresami tego pakietu.
- Dokumentacja standardowych modułów Python użytych w projekcie:
  `argparse`, `csv`, `dataclasses`, `pathlib`, `time`.
- Dokumentacja `pyserial`, wymagana tylko dla realnego backendu serial UART.

## Materiały kursowe

- Instrukcje laboratoryjne dotyczące CORDIC/AXI/MMIO, wykorzystane jako
  inspiracja dla rejestrowego sterowania akceleratorem.
- Wymagania kursowe dotyczące dokumentacji: opis projektu, analiza problemu,
  projekt techniczny, diagramy UML, wzorce projektowe, testy, instrukcja
  użytkownika, utrzymanie i bibliografia.

## Źródła projektowe

- Kod źródłowy repozytorium `MALIKM987/fpga-audio-platform`.
- Testy Python i Verilog w katalogach `tools/` oraz `tb/`.
- Dokumenty projektowe w katalogu `docs/`, traktowane jako źródło aktualnej
  specyfikacji dla implementacji.
