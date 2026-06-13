# Integracja mini CPU z akceleratorem FFT/IFFT MMIO

## Cel etapu

Ten etap łączy istniejący własny mini CPU z istniejącym wrapperem
`fft_accelerator_mmio`. Celem nie jest dodanie nowego algorytmu FFT/IFFT, tylko
pokazanie kompletnego mechanizmu sterowania:

```text
mini CPU
    -> memory-mapped bus
    -> fft_accelerator_mmio
    -> fft_ifft_pipeline
    -> output sample memory
    -> CPU readback / GPIO PASS-FAIL
```

W ten sposób projekt spełnia wymagany model laboratoryjny: jednostka sterująca
zapisuje dane i parametry do dedykowanego procesora, uruchamia obliczenia,
polluje status i odczytuje wynik.

## Dodane bloki

| Plik | Rola |
| --- | --- |
| `rtl/cpu/mini_cpu_fft_system.v` | System symulacyjny łączący CPU, ROM, GPIO/debug i `fft_accelerator_mmio`. |
| `rtl/cpu/mini_cpu_program_rom.v` | Dodaje program `MINI_CPU_PROGRAM_FFT_IMPULSE`. |
| `rtl/cpu/mini_cpu_defs.vh` | Dodaje identyfikator programu impulsowego. |

`mini_cpu_fft_system` nie jest top-levelem Tang Nano. To blok do symulacji i
przyszłej integracji.

## Diagram blokowy

```text
                 +----------------------+
                 | mini_cpu_program_rom |
                 +----------^-----------+
                            |
                         rom_addr
                            |
+-----------+       +-------+-------+       +------------------+
| clk / rst | ----> | mini_cpu_core | ----> | bus decoder      |
+-----------+       +---------------+       +----+--------+----+
                                                   |        |
                                                   |        |
                                           +-------v--+  +--v----------------+
                                           | GPIO /   |  | fft_accelerator   |
                                           | debug    |  | _mmio            |
                                           +----------+  +---------+---------+
                                                               |
                                                               v
                                                        fft_ifft_pipeline
```

## Mapa adresów CPU

Adresy CPU są 16-bitowe. Rejestry FFT/IFFT są mapowane na istniejące adresy
wewnętrzne `fft_accelerator_mmio`.

| Adres CPU | Nazwa | Znaczenie |
| --- | --- | --- |
| `0x8000` | `GPIO_RESULT` | Wynik programu: `0x00A5` PASS, `0x00E1` FAIL. |
| `0x8010` | `DEBUG_OUT0` | Próbka wyjściowa odczytana przez CPU: index 0. |
| `0x8011` | `DEBUG_OUT1` | Próbka wyjściowa odczytana przez CPU: index 1. |
| `0x8012` | `DEBUG_OUT2` | Próbka wyjściowa odczytana przez CPU: index 2. |
| `0x8013` | `DEBUG_OUT16` | Próbka wyjściowa odczytana przez CPU: index 16. |
| `0x8014` | `DEBUG_OUT64` | Próbka wyjściowa odczytana przez CPU: index 64. |
| `0x8015` | `DEBUG_OUT128` | Próbka wyjściowa odczytana przez CPU: index 128. |
| `0x8016` | `DEBUG_OUT255` | Próbka wyjściowa odczytana przez CPU: index 255. |
| `0x8020` | `CPU_STATUS` | Bit 0 pokazuje `cpu_halted`. |
| `0x9000` | `FFT_CONTROL` | Mapowane na `CONTROL_REG`. |
| `0x9001` | `FFT_STATUS` | Mapowane na `STATUS_REG`. |
| `0x9002` | `FFT_MODE` | Mapowane na `MODE_REG`. |
| `0x9003` | `FFT_BASS_GAIN` | Gain Q2.14 dla basu. |
| `0x9004` | `FFT_MID_GAIN` | Gain Q2.14 dla środka. |
| `0x9005` | `FFT_TREBLE_GAIN` | Gain Q2.14 dla góry. |
| `0x9100..0x91FF` | `FFT_INPUT_SAMPLE[0..255]` | Pamięć wejściowej ramki próbek. |
| `0x9200..0x92FF` | `FFT_OUTPUT_SAMPLE[0..255]` | Pamięć wyjściowej ramki próbek. |

Nieznane adresy zwracają `0x0000` i nie modyfikują GPIO ani rejestrów FFT.

## Przepływ programu CPU

Program `MINI_CPU_PROGRAM_FFT_IMPULSE` wykonuje następujące kroki:

1. Czyści akcelerator przez zapis `FFT_CONTROL = 0x0002`.
2. Ustawia unity gains:
   - `FFT_BASS_GAIN = 16384`,
   - `FFT_MID_GAIN = 16384`,
   - `FFT_TREBLE_GAIN = 16384`.
3. Zapisuje ramkę impulsową:
   - `input[0] = 64`,
   - `input[1..255] = 0`.
4. Startuje akcelerator przez zapis `FFT_CONTROL = 0x0001`.
5. Polluje `FFT_STATUS`, aż bit `DONE` będzie ustawiony.
6. Sprawdza bity `OVERFLOW` i `ERROR`.
7. Odczytuje próbki wyjściowe:
   - `0`,
   - `1`,
   - `2`,
   - `16`,
   - `64`,
   - `128`,
   - `255`.
8. Zapisuje je do rejestrów debug `0x8010..0x8016`.
9. Zapisuje `0x00A5` do `GPIO_RESULT`, jeśli status nie zgłasza błędu.
10. Zapisuje `0x00E1` do `GPIO_RESULT`, jeśli status zgłasza błąd.
11. Wykonuje `HALT`.

Obecny CPU nie ma jeszcze wygodnych instrukcji porównania zakresowego, więc
tolerancja próbek `+/-2 LSB` jest sprawdzana w testbenchu na wartościach, które
CPU rzeczywiście odczytał i przepisał do rejestrów debug.

## Testy

| Etap | Testbench | Co sprawdza |
| --- | --- | --- |
| Stage 1 | `tb/mini_cpu_fft_bus_decode_tb.v` | Dekoder adresów GPIO, FFT, wejścia próbek i nieznanych adresów. |
| Stage 2 | `tb/mini_cpu_fft_register_write_tb.v` | CPU zapisuje gainy unity i wybrane próbki wejściowe. |
| Stage 3 | `tb/mini_cpu_fft_start_done_tb.v` | CPU zapisuje START, polluje STATUS, widzi DONE i nie startuje drugi raz podczas BUSY. |
| Stage 4 | `tb/mini_cpu_fft_impulse_program_tb.v` | Pełny program impulsowy, PASS w GPIO, odczyt wybranych próbek i status bez błędów. |
| Stage 5 | `tools/run_all_tests.py` | Uruchamia nowe testy oraz pełną regresję istniejących testów. |

## Ograniczenia

Ten etap nadal nie dodaje:

- UART,
- AXI-Lite,
- fizycznego I2S,
- top-levelu Tang Nano,
- sterowania z komputera przez konsolę,
- nowej implementacji FFT/IFFT.

Kolejny naturalny etap to `codex/uart-cpu-fft-console`, czyli dodanie warstwy
raportowania/komend konsolowych nad już istniejącą integracją CPU -> MMIO ->
akcelerator.
