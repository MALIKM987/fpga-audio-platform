# CPU-facing MMIO wrapper akceleratora FFT/IFFT

## Cel

Ten dokument opisuje moduły:

- `rtl/control/fft_mmio_regs.v`,
- `rtl/control/fft_accelerator_mmio.v`.

To jest etap interfejsu CPU-facing MMIO dla istniejącego pipeline:

```text
CPU-like testbench
    -> rejestry i pamięć MMIO
    -> fft_ifft_pipeline
    -> pamięć wyjściowa MMIO
```

W tym branchu nie dodajemy jeszcze CPU, UART, AXI-Lite ani fizycznego I2S.
Testbench zachowuje się jak prosty procesor: zapisuje rejestry, wpisuje ramkę
wejściową, ustawia `START`, odpytuje `STATUS`, a potem czyta wybrane próbki
wyjściowe.

## Mapa adresów

Adresy są adresami słów w prostym interfejsie testowym, nie adresami bajtowymi
AXI-Lite.

| Adres | Nazwa | Dostęp | Opis |
| --- | --- | --- | --- |
| `0x0000` | `CONTROL` | W/R | Start i clear. Odczyt zwraca `0`. |
| `0x0001` | `STATUS` | R | Bity `busy`, `done`, `overflow`, `error`. |
| `0x0002` | `MODE` | W/R | Rejestr trybu, obecnie tylko przechowywany. |
| `0x0003` | `BASS_GAIN` | W/R | Gain Q2.14 dla pasma bass. |
| `0x0004` | `MID_GAIN` | W/R | Gain Q2.14 dla pasma mid. |
| `0x0005` | `TREBLE_GAIN` | W/R | Gain Q2.14 dla pasma treble. |
| `0x0006` | `DEBUG` | R | Wersja/debug, obecnie `0x00020000`. |
| `0x0100..0x01FF` | `INPUT_SAMPLE[i]` | W/R | 256 próbek wejściowych signed 16-bit. |
| `0x0200..0x02FF` | `OUTPUT_SAMPLE[i]` | R | 256 próbek wyjściowych signed 16-bit. |

Mapa odpowiada stałym w `rtl/control/fft_mmio_regs.v`.

## CONTROL

| Bit | Nazwa | Znaczenie |
| --- | --- | --- |
| `0` | `START` | Jednocyklowy impuls startu. |
| `1` | `CLEAR` | Czyści status i pamięć wyjściową. |

`CONTROL` nie przechowuje trwałej wartości startu. Odczyt `CONTROL` zwraca
zero, ponieważ start i clear są impulsami sterującymi.

## STATUS

| Bit | Nazwa | Znaczenie |
| --- | --- | --- |
| `0` | `BUSY` | Wrapper albo pipeline jest w trakcie pracy. |
| `1` | `DONE` | Zakończenie przetwarzania zostało zatrzaśnięte. |
| `2` | `OVERFLOW` | Zatrzaśnięty overflow z pipeline. |
| `3` | `ERROR` | Zatrzaśnięty błąd, np. drugi `START` podczas `BUSY`. |

`DONE`, `OVERFLOW` i `ERROR` są czyszczone przez `CONTROL[1]`.

## Gain Q2.14

Gainy są zapisywane w dolnych 16 bitach rejestru i interpretowane jako signed
Q2.14.

Przykłady:

- `16384` = `1.00`,
- `12288` = `0.75`,
- `20480` = `1.25`,
- `24576` = `1.50`.

## Pamięć próbek

`INPUT_SAMPLE[i]` jest zapisywane przez CPU-like interfejs przed startem.
`fft_accelerator_mmio` odczytuje potem kolejne indeksy i podaje ramkę do
`fft_ifft_pipeline`.

`OUTPUT_SAMPLE[i]` jest zapisywane przez wrapper, gdy pipeline wystawia
`out_valid`. Po resecie albo `CLEAR` pamięć wyjściowa jest zerowana, aby testy
mogły deterministycznie sprawdzić stan początkowy.

## Zachowanie `START` podczas `BUSY`

Drugi `START` podczas trwającego przetwarzania nie uruchamia nowej ramki.
Wrapper ignoruje taki start i zgłasza `ERROR` w `STATUS[3]`.

To zachowanie jest celowe dla pierwszego prostego interfejsu MMIO. Kolejna
wersja może dodać kolejkę komend albo double buffering, ale nie jest to zakres
tego etapu.

## Pokrycie testami

### Stage 1 — warstwa rejestrów i pamięci

Test:

```text
tb/fft_mmio_regs_tb.v
```

Sprawdza:

- zapis/odczyt `CONTROL`, gdzie ma to sens,
- domyślny `STATUS`,
- zapis/odczyt `MODE`,
- zapis/odczyt `BASS_GAIN`, `MID_GAIN`, `TREBLE_GAIN`,
- zapis/odczyt `INPUT_SAMPLE` dla indeksów `0, 1, 2, 16, 64, 128, 255`,
- odczyt zerowej pamięci `OUTPUT_SAMPLE` po resecie i po `CLEAR`.

Ten test nie wymaga zakończenia pipeline FFT/IFFT.

### Stage 2 — wrapper sterujący pipeline

Test:

```text
tb/fft_accelerator_mmio_control_tb.v
```

Sprawdza:

- `START` uruchamia przetwarzanie,
- `BUSY` jest aktywne podczas pracy,
- `DONE` pojawia się po zakończeniu,
- `OVERFLOW` pozostaje wyzerowane w normalnym przebiegu,
- `ERROR` zgłasza odrzucony drugi `START` podczas `BUSY`,
- `CLEAR` przywraca znany stan idle/status.

### Stage 3 — test CPU-like end-to-end

Test:

```text
tb/fft_accelerator_mmio_cpu_tb.v
```

Sprawdza sekwencję podobną do pracy prostego CPU:

1. Zapisuje unity gain `16384, 16384, 16384`.
2. Wpisuje ramkę impulsową:
   - `sample[0] = 64`,
   - `sample[1..255] = 0`.
3. Zapisuje `START`.
4. Polluje `STATUS` do `DONE`.
5. Czyta wybrane wyjścia:
   - `0`,
   - `1`,
   - `2`,
   - `16`,
   - `64`,
   - `128`,
   - `255`.
6. Sprawdza:
   - `output[0]` około `64`,
   - pozostałe wybrane wyjścia około `0`,
   - tolerancję `+/-2` LSB,
   - `DONE=1`,
   - `OVERFLOW=0`,
   - `ERROR=0`.

## Uruchamianie

Pełny zestaw testów:

```powershell
python tools/run_all_tests.py
```

Jeżeli lokalnie nie ma `iverilog` i `vvp`, lokalna symulacja Verilog może być
oznaczona jako `STATUS=SKIPPED`. Testbenche pozostają dodane do runnera i są
uruchamiane przez GitHub Actions, gdzie Icarus Verilog jest instalowany.

## Ograniczenia

Ten etap nie implementuje:

- CPU,
- UART,
- AXI-Lite,
- fizycznego I2S,
- integracji z top-level Tang Nano,
- double buffering,
- kolejki komend,
- DMA.

To jest wyłącznie MMIO wrapper i testy warstwowe dla istniejącego pipeline
FFT/IFFT.
