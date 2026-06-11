# Plan integracji Gowin FFT IP

## 1. Cel etapu

Celem kolejnego etapu jest zastąpienie obecnych modeli passthrough:

- `fft_accel_wrapper.v`
- `ifft_accel_wrapper.v`

prawdziwymi blokami FFT/IFFT wygenerowanymi w Gowin EDA.

Ten dokument nie implementuje IP i nie zmienia RTL. Opisuje techniczny plan:
co trzeba wygenerować, jak dopasować IP do istniejących wrapperów, jak testować
wynik i jak porównać go z Pythonowym `math_reference_model`.

## 2. Aktualny stan projektu

Projekt ma już przygotowaną infrastrukturę potrzebną przed integracją IP:

- sterowanie rejestrami przez `fft_control_regs`,
- moduł nadrzędny `fft_accelerator_core`,
- pipeline RTL `fft_ifft_pipeline`,
- testbenche Verilog,
- Pythonowy model referencyjny `tools/fft_reference_model.py`,
- generowanie wektorów testowych CSV,
- porównanie obecnego RTL z `rtl_passthrough_model`,
- GitHub Actions uruchamiające testy.

Obecnie wrappery FFT/IFFT są modelami passthrough. To jest świadomy etap
pośredni: sprawdza sterowanie, indeksy, `valid/done` i przepływ danych, ale nie
wykonuje jeszcze matematycznej FFT/IFFT w RTL.

## 3. Obecny przepływ danych

Aktualny przepływ danych:

```text
sample input
    -> sample_block_buffer
    -> fft_accel_wrapper passthrough
    -> spectral_processor
    -> ifft_accel_wrapper passthrough
    -> output sample
```

W tym wariancie `spectral_processor` działa na danych przechodzących przez
passthrough wrappery, więc obecny RTL porównujemy z `rtl_passthrough_model`, a
nie z pełnym modelem matematycznym FFT/IFFT.

## 4. Docelowy przepływ danych po integracji IP

Docelowy przepływ po integracji Gowin IP:

```text
sample input
    -> sample_block_buffer
    -> Gowin FFT IP adapter
    -> spectral_processor
    -> Gowin IFFT IP adapter
    -> output sample
```

Adaptery mają ukryć szczegóły interfejsu wygenerowanego IP tak, aby reszta
projektu nadal widziała stabilny interfejs wrapperów.

## 5. Dlaczego potrzebny jest adapter

Istniejące moduły projektu używają własnego, prostego interfejsu:

- `start`,
- `in_valid`,
- `in_index`,
- `real_in`,
- `imag_in`,
- `out_valid`,
- `out_index`,
- `real_out`,
- `imag_out`,
- `busy`,
- `done`.

Gowin FFT IP może mieć inny interfejs niż obecne wrappery. Dokładne nazwy
portów, handshake i parametry trzeba potwierdzić dopiero po wygenerowaniu IP w
Gowin EDA.

Adapter będzie potrzebny do dopasowania:

- `valid/ready`,
- kolejności próbek,
- indeksów binów,
- formatu danych,
- skalowania,
- opóźnienia pipeline,
- sygnałów `start` i `done`.

## 6. Parametry do ustalenia w Gowin EDA

Przy generowaniu IP trzeba sprawdzić i zapisać:

- rozmiar FFT: `256` punktów,
- tryb FFT i IFFT,
- szerokość danych: minimum 16 bitów dla `real` i `imag`,
- format signed fixed-point,
- kolejność wejścia i wyjścia,
- czy wynik jest w natural order czy bit-reversed,
- skalowanie albo block floating,
- opóźnienie pipeline,
- interfejs `valid/ready` albo streaming,
- obsługę sygnału start/reset,
- wykorzystanie zasobów FPGA,
- maksymalną częstotliwość pracy,
- kompatybilność z Tang Nano 20K.

Nie należy zakładać tych parametrów z góry. Trzeba je potwierdzić w plikach i
dokumentacji wygenerowanych przez Gowin EDA.

## 7. Format danych i Q2.14

Obecny `spectral_processor` używa gainów w formacie Q2.14, a próbki audio są
signed 16-bit. Po integracji prawdziwego FFT trzeba sprawdzić, czy wyjście IP
powinno mieć większą szerokość niż 16 bitów.

Możliwe kierunki:

- zachować 16-bit na granicy wrapperów i skalować wewnątrz adaptera,
- użyć 24-bit albo 32-bit wewnętrznie dla `real` i `imag`,
- dodać saturację/zaokrąglenie dopiero na wyjściu IFFT,
- rozszerzyć `spectral_processor`, jeśli będzie trzeba przetwarzać szersze dane.

Najważniejsze jest uniknięcie przepełnień i zachowanie porównywalności z
Pythonowym modelem referencyjnym.

## 8. Problem skalowania FFT/IFFT

FFT/IFFT może zmieniać amplitudę zależnie od wybranego skalowania. Trzeba
zdecydować:

- czy skaluje FFT,
- czy skaluje IFFT,
- czy stosowane jest dzielenie przez `N`,
- czy wynik końcowy ma odpowiadać Pythonowemu `math_reference_model`,
- jaka tolerancja błędu jest akceptowalna w porównaniu CSV.

Pythonowy `math_reference_model` wykonuje `IDFT` z dzieleniem przez `N`. Jeśli
Gowin IP użyje innej konwencji skalowania, adapter albo porównywarka muszą to
jawnie uwzględnić.

## 9. Plan testowania po integracji IP

Po podłączeniu IP trzeba:

1. wygenerować te same wektory testowe,
2. uruchomić symulację RTL,
3. zapisać wyjście pipeline do CSV,
4. porównać wynik z `math_reference_model`,
5. ustalić tolerancję błędu,
6. osobno sprawdzić sygnały `busy`, `done` i `overflow`.

Obecne porównanie z `rtl_passthrough_model` powinno zostać zachowane jako test
starego trybu/modelu, ale PASS/FAIL dla prawdziwego FFT/IFFT powinien przejść na
porównanie z `math_reference_model`.

## 10. Proponowana kolejność prac

Proponowana kolejność:

1. Wygenerować Gowin FFT IP w osobnym katalogu roboczym.
2. Sprawdzić pliki i interfejs wygenerowanego IP.
3. Udokumentować dokładne porty, parametry i ograniczenia IP.
4. Przygotować adapter `gowin_fft_adapter.v`.
5. Przygotować adapter `gowin_ifft_adapter.v`.
6. Podmienić wnętrze wrapperów albo dodać parametr `USE_GOWIN_IP`.
7. Uruchomić testy symulacyjne.
8. Porównać wynik z `math_reference_model`.
9. Dopiero potem planować top-level Tang Nano.

## 11. Ryzyka

Najważniejsze ryzyka:

- inna kolejność binów,
- inne skalowanie amplitudy,
- większa szerokość danych niż obecne 16 bitów,
- opóźnienie pipeline,
- różnice między symulacją IP i syntezą,
- trudność uruchomienia wygenerowanego IP w GitHub Actions,
- zależność od plików generowanych przez Gowin EDA,
- niepełna dokumentacja interfejsu IP,
- ograniczenia zasobów Tang Nano 20K.

## 12. Decyzja projektowa

Na tym etapie nie należy usuwać Pythonowego modelu referencyjnego ani porównania
CSV. Te elementy są podstawą weryfikacji przyszłego Gowin FFT IP.

Obecne wrappery passthrough nadal są przydatne jako prosty tryb kontrolny, który
sprawdza sterowanie i przepływ danych bez włączania złożonego IP.

## 13. Następny etap po tym dokumencie

Następny etap powinien obejmować:

- wygenerowanie Gowin FFT IP w Gowin EDA,
- dodanie wygenerowanych plików do kontrolowanego katalogu,
- opisanie dokładnego interfejsu IP,
- przygotowanie adapterów,
- uruchomienie symulacji z tym samym zestawem wektorów testowych.

Dopiero po przejściu tych testów warto wracać do fizycznego I2S, top-levelu Tang
Nano i bitstreamu sprzętowego.
