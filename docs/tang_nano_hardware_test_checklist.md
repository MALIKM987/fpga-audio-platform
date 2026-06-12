# Checklist testu sprzętowego Tang Nano / Gowin

## 1. Cel testu sprzętowego

Celem testu jest potwierdzenie, że aktualny tor FFT/IFFT:

- buduje się w Gowin EDA dla płytki Tang Nano,
- mieści się w zasobach FPGA,
- zamyka timing dla wybranego zegara,
- zachowuje stabilne sygnały `start`, `busy`, `done`, `valid`,
- może być dalej integrowany z diagnostyką UART albo top-level testowym.

Ten dokument nie zawiera wyników sprzętowych. Użytkownik musi zebrać je lokalnie
z Gowin EDA i z realnej płytki.

## 2. Przed syntezą

Przed uruchomieniem Gowin:

- sprawdź, że jesteś na właściwym branchu,
- sprawdź czysty status repo:

```powershell
git status --short --branch
```

- wygeneruj wektory:

```powershell
python tools/generate_fft_radix2_core_vectors.py
python tools/generate_fft_test_vectors.py
```

- uruchom pełny runner:

```powershell
python tools/run_all_tests.py
```

- upewnij się, że wygenerowane pliki `tb/generated/*.mem` są w repo,
- nie dodawaj do syntezy plików `tb/` jako produkcyjnego RTL,
- nie dodawaj artefaktów `sim/`, `__pycache__`, `.vvp`, `.log`, `.jou`.

## 3. Gowin EDA: synthesis / place and route

Kroki w Gowin EDA:

1. Otwórz projekt Gowin używany w repozytorium.
2. Ustaw właściwy top-level dla wariantu testowego.
3. Dodaj wymagane pliki RTL z `rtl/`.
4. Uruchom Synthesis.
5. Sprawdź ostrzeżenia syntezy.
6. Uruchom Place & Route.
7. Sprawdź timing.
8. Wygeneruj bitstream.
9. Zapisz raporty do analizy.

Nie wpisuj ręcznie liczb zasobów bez raportu. Nie zakładaj, że timing jest
zamknięty, dopóki Gowin tego nie potwierdzi.

## 4. Zasoby do spisania z raportu

Uzupełnij po syntezie:

| Metryka | Wartość z Gowin | Uwagi |
| --- | --- | --- |
| LUT | TODO | z raportu utilization |
| FF | TODO | z raportu utilization |
| B-SRAM | TODO | czy pamięci ramek trafiły do RAM/BRAM |
| DSP / multipliers | TODO | czy `complex_mult.v` używa DSP |
| Fmax | TODO | z raportu timing |
| Timing slack | TODO | wartość najgorszej ścieżki |
| Zegar testowy | TODO | np. 27 MHz, jeśli używany |

## 5. Na co uważać

Podczas analizy raportów sprawdź:

- czy pamięci próbek nie zostały zmapowane nadmiernie do FF,
- czy mnożniki zespolone używają zasobów DSP lub sensownej logiki,
- czy najdłuższa ścieżka nie przechodzi przez zbyt dużą kombinację DSP/LUT,
- czy sygnały reset/start/done nie generują ostrzeżeń,
- czy nie ma przypadkowo niedowiązanych portów,
- czy top-level nie zawiera pinów, których nie ma w constraints,
- czy constraints odpowiadają realnie podłączonej płytce.

## 6. Test na Tang Nano

Po wygenerowaniu bitstreamu:

1. Podłącz Tang Nano do komputera.
2. Uruchom Gowin Programmer.
3. Wybierz właściwy bitstream.
4. Zaprogramuj FPGA.
5. Jeśli istnieje UART/self-test, odbierz logi.
6. Jeśli istnieje ścieżka diagnostyczna, porównaj wyniki z wektorami.
7. Zapisz obserwacje i komunikaty narzędzi.

Nie zakładaj, że USB płytki automatycznie udostępnia UART z FPGA jako port COM.
Jeżeli UART nie jest pewny, użyj potwierdzonego pinu `uart_tx` i zewnętrznego
konwertera USB-UART 3.3 V.

## 7. Wariant `tang_fft_ifft_selftest_top`

Dla pierwszego testu sprzętowego realnego pipeline FFT/IFFT użyj osobnego topu:

```text
tang_fft_ifft_selftest_top
```

Ten top ma tylko porty `clk` i `led`, więc można użyć istniejących constraintów:

```text
clk -> pin 4
led -> pin 15
```

Kroki:

1. Dodaj do projektu Gowin pliki RTL opisane w
   `docs/tang_fft_ifft_selftest_top.md`.
2. Ustaw top module na `tang_fft_ifft_selftest_top`.
3. Uruchom Synthesis.
4. Sprawdź, czy `fft_radix2_core` występuje w aktywnej hierarchii/netliście.
5. Spisz ostrzeżenia syntezy.
6. Uruchom Place & Route.
7. Spisz wykorzystanie LUT, FF, B-SRAM i DSP.
8. Sprawdź timing/slack.
9. Wygeneruj bitstream.
10. Zaprogramuj Tang Nano.
11. Obserwuj LED:

    - test w toku: szybkie miganie,
    - PASS: świecenie ciągłe,
    - FAIL: wolne miganie.

Jeżeli LED na płytce jest aktywny stanem niskim, zachowanie może wyglądać
odwrócone. Wklej obserwację razem z raportami Gowin.

## 8. Co wkleić z powrotem do ChatGPT/Codex

Po teście wklej:

- raport utilization z Gowin,
- raport timing/Fmax,
- ostrzeżenia syntezy,
- ostrzeżenia Place & Route,
- log Programmer,
- log UART/self-test, jeśli istnieje,
- informację, jaki top-level był użyty,
- listę plików RTL dodanych do projektu Gowin,
- zrzuty ekranu z raportów, jeśli są wygodne.

Na podstawie tych danych można ocenić, czy trzeba optymalizować RAM, DSP,
skalowanie, timing albo strukturę top-levelu.
