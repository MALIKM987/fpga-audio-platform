# Wektory testowe FFT/IFFT

## Cel

Wektory testowe służą do powtarzalnej weryfikacji przepływu danych przez obecny
model pipeline FFT/IFFT. Ten etap nie implementuje jeszcze prawdziwej FFT ani
IFFT w RTL. Zamiast tego rozdzielamy dwa modele odniesienia:

- `rtl_passthrough_model` - model aktualnego zachowania RTL.
- `math_reference_model` - matematyczny golden model dla przyszłej integracji.

## `rtl_passthrough_model`

Ten model odpowiada obecnym wrapperom RTL:

```text
sample index
    -> fft_accel_wrapper passthrough
    -> spectral_processor gain według indeksu
    -> ifft_accel_wrapper passthrough
```

Dla każdej próbki model wybiera pasmo na podstawie indeksu próbki/binu i stosuje
gain Q2.14:

- `BASS = 24576`, czyli `1.50`
- `MID = 16384`, czyli `1.00`
- `TREBLE = 12288`, czyli `0.75`

To właśnie ten model jest używany jako kryterium PASS/FAIL dla obecnego RTL.

## `math_reference_model`

Ten model używa `tools/fft_reference_model.py` i wykonuje:

```text
DFT -> spectral gain -> IDFT
```

Jest to golden model matematyczny przygotowany na przyszłość. Obecnego RTL nie
porównujemy jeszcze do niego jako warunku PASS, ponieważ wrappery FFT/IFFT są
na razie modelami passthrough. Wyniki powinny się różnić dla ramek innych niż
trywialne przypadki.

## Generowane pliki CSV

Skrypt `tools/generate_fft_test_vectors.py` tworzy katalog:

```text
sim/vectors/
```

Dla każdej ramki:

- `impulse`
- `constant`
- `single_bin_low`
- `single_bin_mid`
- `single_bin_high`
- `mixed`

generowane są trzy pliki:

```text
<frame>.csv
<frame>_expected_rtl_passthrough.csv
<frame>_expected_math_reference.csv
```

Format CSV:

```text
index,sample
0,...
1,...
```

Testbench `fft_accelerator_core_tb` zapisuje wyjście obecnego RTL do:

```text
sim/fft_accelerator_core_output.csv
```

Porównanie wykonuje `tools/compare_fft_pipeline_outputs.py`. Domyślnie używa
ramki `mixed` i tolerancji `1` LSB.

## Uruchamianie

Pełny przepływ:

```powershell
python tools/run_all_tests.py
```

Runner wykonuje kolejno:

1. testy Python modelu referencyjnego,
2. generowanie wektorów CSV,
3. testy Verilog, jeśli dostępne są `iverilog` i `vvp`,
4. porównanie `sim/fft_accelerator_core_output.csv` z
   `mixed_expected_rtl_passthrough.csv`, jeśli plik RTL istnieje.

Jeżeli lokalnie nie ma `iverilog` albo `vvp`, część Verilog oraz porównanie RTL
mogą zostać oznaczone jako `STATUS=SKIPPED`. Testy Python i generowanie wektorów
powinny nadal przejść.

## Następny etap

Po zastąpieniu passthrough wrapperów przez Gowin FFT IP albo prawdziwy RTL FFT
porównanie PASS/FAIL powinno zostać przełączone z `rtl_passthrough_model` na
`math_reference_model`.
