# Checklist — generowanie Gowin FFT IP

## 1. Cel

Celem etapu jest wygenerowanie w Gowin EDA dwóch bloków IP:

- FFT 256 punktów,
- IFFT 256 punktów.

Te bloki mają w przyszłości zastąpić obecne modele passthrough:

- `rtl/dsp/fft_accel_wrapper.v`,
- `rtl/dsp/ifft_accel_wrapper.v`.

Na tym etapie nie dodajemy jeszcze plików IP, adapterów ani prawdziwej
implementacji FFT/IFFT. Zbieramy tylko informacje potrzebne do bezpiecznego
importu.

## 2. Ustawienia projektu Gowin

Przed generowaniem IP sprawdź i zapisz:

- układ FPGA zgodny z Tang Nano 20K,
- dokładną wersję Gowin EDA,
- katalog eksportu IP,
- nazwę projektu lub workspace,
- nazwę IP forward FFT,
- nazwę IP inverse FFT,
- czy IP jest generowane jako Verilog, VHDL albo netlist,
- czy generowane są pliki symulacyjne.

## 3. Parametry FFT

Dla forward FFT sprawdź i zapisz:

- FFT size: `256`,
- input data width,
- output data width,
- signed fixed-point,
- format części rzeczywistej i urojonej,
- natural order albo bit-reversed order,
- scaling mode,
- streaming albo valid-ready,
- clock,
- reset,
- start,
- done albo frame complete,
- latency,
- resource usage,
- maksymalną częstotliwość pracy,
- dodatkowe wymagane sygnały sterujące.

Nie zakładaj nazw portów ani zachowania handshake przed wygenerowaniem IP.

## 4. Parametry IFFT

Dla inverse FFT sprawdź i zapisz:

- IFFT size: `256`,
- input data width,
- output data width,
- signed fixed-point,
- format części rzeczywistej i urojonej,
- natural order albo bit-reversed order,
- scaling mode,
- czy wynik jest dzielony przez `N = 256`,
- czy wynik nie jest skalowany,
- czy wymagane jest skalowanie etapowe,
- streaming albo valid-ready,
- clock,
- reset,
- start,
- done albo frame complete,
- latency,
- resource usage,
- dodatkowe wymagane sygnały sterujące.

Skalowanie IFFT jest krytyczne, bo wpływa bezpośrednio na poziom próbek po
powrocie do dziedziny czasu.

## 5. Informacje do spisania po wygenerowaniu IP

Po wygenerowaniu IP przygotuj krótką notatkę z rzeczywistym interfejsem.
Minimalna lista informacji:

| Informacja | FFT | IFFT |
| --- | --- | --- |
| Nazwa modułu | TODO | TODO |
| Lista portów | TODO | TODO |
| Parametry Verilog | TODO | TODO |
| Pliki wygenerowane przez Gowin | TODO | TODO |
| Plik symulacyjny | TODO | TODO |
| Wymagane biblioteki | TODO | TODO |
| Kompilacja w Icarus Verilog | TODO | TODO |
| Natural order / bit-reversed | TODO | TODO |
| Skalowanie | TODO | TODO |
| Latency | TODO | TODO |
| Reset/start/done | TODO | TODO |

Szczególnie ważne jest ustalenie, czy IP można symulować poza Gowin EDA.
Jeżeli IP wymaga bibliotek niedostępnych dla Icarus Verilog, trzeba opisać
alternatywną ścieżkę testu.

## 6. Gdzie umieścić pliki

Proponowana struktura:

```text
vendor/gowin_ip/
    README.md
    fft256/
        README.md
        <wygenerowane pliki FFT IP w osobnym PR>
    ifft256/
        README.md
        <wygenerowane pliki IFFT IP w osobnym PR>
```

Wygenerowane pliki dodajemy dopiero w osobnym PR. Nie należy mieszać ich z
`gowin_impl/`, bo `gowin_impl/` jest projektem narzędziowym, a `vendor/` ma
przechowywać kontrolowane źródła lub modele IP używane przez RTL.

## 7. Następny krok po wygenerowaniu IP

Po wygenerowaniu i opisaniu IP wykonaj osobny etap:

1. Dodaj wygenerowane pliki do repozytorium.
2. Przygotuj dokument z rzeczywistym interfejsem IP.
3. Przygotuj adapter `gowin_fft_adapter.v`.
4. Przygotuj adapter `gowin_ifft_adapter.v`.
5. Podłącz adaptery pod obecne wrappery lub zastąp modele passthrough.
6. Porównaj wynik z `math_reference_model`.
7. Rozszerz testy konsolowe i GitHub Actions.

Do tego momentu obecne `fft_accel_wrapper.v` i `ifft_accel_wrapper.v` pozostają
modelami passthrough do weryfikacji sterowania i przepływu danych.
