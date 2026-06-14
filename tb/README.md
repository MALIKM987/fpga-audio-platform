# `tb/`

Testbenche Verilog i pliki testowe.

Testbenche są uruchamiane przez:

```powershell
python tools/run_all_tests.py
```

Runner kompiluje wybrane źródła przez `iverilog -g2012` i uruchamia wynik przez
`vvp`. Każdy testbench powinien kończyć się linią:

```text
STATUS=PASS
```

Podkatalog `tb/generated/` zawiera wektory `.mem` dla testów FFT radix-2.
Wektory są generowane przez narzędzia Python i porównywane z modelem
fixed-point.
