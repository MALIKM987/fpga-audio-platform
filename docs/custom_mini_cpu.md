# Własny mini CPU dla FPGA Audio Platform

## Cel

`mini_cpu_core` jest prostym, edukacyjnym rdzeniem CPU napisanym w Verilogu.
Nie jest zgodny z RISC-V, ARM ani żadną gotową architekturą procesora.

Celem tego etapu jest zbudowanie małego sterownika, który w kolejnych branchach
będzie mógł zapisywać rejestry MMIO akceleratora FFT/IFFT, uruchamiać
przetwarzanie i odczytywać status oraz wyniki.

W tym branchu CPU nie jest jeszcze podłączony do FFT/IFFT, UART ani top-levelu
Tang Nano. Testujemy go niezależnie na prostych rejestrach MMIO/GPIO.

## Miejsce w projekcie

Docelowy kierunek:

```text
mini CPU
    -> memory-mapped bus
    -> FFT/IFFT MMIO accelerator
    -> status / output samples / UART report
```

Aktualny branch dodaje tylko:

```text
mini CPU
    -> program ROM
    -> simple MMIO test registers
    -> GPIO/LED register
```

## Bloki RTL

| Plik | Rola |
| --- | --- |
| `rtl/cpu/mini_cpu_defs.vh` | Definicje opcode i identyfikatorów programów. |
| `rtl/cpu/mini_cpu_core.v` | Rdzeń CPU: PC, fetch, decode, rejestry, ALU, bus. |
| `rtl/cpu/mini_cpu_program_rom.v` | Prosty ROM z programami testowymi. |
| `rtl/cpu/mini_cpu_system.v` | System testowy: CPU + ROM + GPIO/MMIO. |

## Diagram blokowy

```text
                 +----------------------+
                 |  mini_cpu_program_rom |
                 +----------^-----------+
                            |
                         rom_addr
                            |
+-----------+       +-------+-------+       +--------------------+
| clk / rst | ----> | mini_cpu_core | ----> | MMIO/GPIO registers |
+-----------+       +---------------+       +--------------------+
                         |
                         +--> halted / debug signals
```

## Rejestry CPU

Rdzeń ma 8 rejestrów ogólnego przeznaczenia:

```text
R0..R7
```

W obecnej implementacji każdy rejestr ma 16 bitów. `R0` nie jest rejestrem
zerowym, więc można go normalnie zapisywać.

## Flagi

Na tym etapie jest jedna flaga:

| Flaga | Znaczenie |
| --- | --- |
| `zero_flag` | Ustawiana, gdy wynik operacji ALU/LDI/LD/CMP wynosi zero. |

`JZ` i `JNZ` używają `zero_flag`.

## Format instrukcji

Instrukcje mają 16-bitowe słowo opcode. Instrukcje z immediate albo adresem
używają drugiego słowa programu.

Format rejestrowy:

```text
[15:12] opcode
[11:9]  rd
[8:6]   rs
[5:0]   reserved
```

Format immediate/adresowy:

```text
word 0:
[15:12] opcode
[11:9]  rd/source register
[8:0]   reserved

word 1:
[15:0]  immediate albo address
```

Dzięki dwuwyrazowemu formatowi `LD`, `ST`, `JMP`, `JZ` i `JNZ` mogą używać
pełnych 16-bitowych adresów, np. `0x8000`.

## Zestaw instrukcji

| Opcode | Instrukcja | Opis |
| --- | --- | --- |
| `0x0` | `NOP` | Brak operacji. |
| `0x1` | `LDI rd, imm16` | Wpisuje immediate do rejestru. |
| `0x2` | `LD rd, addr16` | Czyta słowo z MMIO do rejestru. |
| `0x3` | `ST rs, addr16` | Zapisuje rejestr do MMIO. |
| `0x4` | `ADD rd, rs` | `rd = rd + rs`. |
| `0x5` | `ADDI rd, imm16` | `rd = rd + imm16`. |
| `0x6` | `SUB rd, rs` | `rd = rd - rs`. |
| `0x7` | `AND rd, rs` | `rd = rd & rs`. |
| `0x8` | `CMP rd, rs` | Ustawia flagę zero dla `rd - rs`. |
| `0x9` | `JMP addr16` | Skok bezwarunkowy. |
| `0xA` | `JZ addr16` | Skok, jeśli `zero_flag = 1`. |
| `0xB` | `JNZ addr16` | Skok, jeśli `zero_flag = 0`. |
| `0xF` | `HALT` | Zatrzymuje CPU. |

## Interfejs bus/MMIO

`mini_cpu_core` wystawia prosty interfejs memory-mapped:

```text
bus_addr
bus_wdata
bus_rdata
bus_we
bus_re
bus_ready
```

W testowym systemie `bus_ready` jest stale `1`. Strobingi `bus_we` i `bus_re`
są jednocyklowe dla obecnych programów testowych.

Ten interfejs nie jest jeszcze AXI-Lite. Jest celowo mały, aby najpierw
przetestować fetch/decode/ALU/MMIO bez dodatkowej infrastruktury.

## Mapa pamięci systemu testowego

`mini_cpu_system` używa prostej mapy MMIO:

| Adres | Nazwa | Opis |
| --- | --- | --- |
| `0x8000` | `GPIO_LED` | Rejestr GPIO/LED. |
| `0x8010` | `TEST_REG0` | Rejestr testowy 0. |
| `0x8012` | `TEST_REG1` | Rejestr testowy 1. |
| `0x8020` | `CPU_STATUS` | Bit 0 pokazuje `halted`. |

Ta mapa jest niezależna od mapy FFT/IFFT MMIO. Integracja obu map będzie
następnym etapem.

## Programy ROM

`mini_cpu_program_rom.v` zawiera kilka małych programów testowych:

| Program | Cel |
| --- | --- |
| `FETCH_HALT` | Sprawdza fetch, inkrementację PC i `HALT`. |
| `ALU` | Sprawdza `LDI`, `ADDI`, `ADD`, `SUB`, `AND`, `CMP`. |
| `BRANCH` | Sprawdza `JMP`, `JZ`, `JNZ`. |
| `MMIO` | Sprawdza `ST`, `LD` i rejestry testowe. |
| `GPIO` | Wpisuje wartość PASS do `GPIO_LED` i zatrzymuje CPU. |

ROM jest opisany przez `case`, żeby łatwo było dodać kolejny program bez
zewnętrznych plików `.mem`.

## Pokrycie testami

| Etap | Testbench | Co sprawdza |
| --- | --- | --- |
| Stage 1 | `tb/mini_cpu_fetch_halt_tb.v` | PC startuje od 0, fetch działa, PC rośnie, `HALT` zatrzymuje CPU. |
| Stage 2 | `tb/mini_cpu_alu_tb.v` | `LDI`, `ADDI`, `ADD`, `SUB`, `AND`, `CMP`, `zero_flag`. |
| Stage 3 | `tb/mini_cpu_branch_tb.v` | `JMP`, `JZ` taken/not taken, `JNZ` taken/not taken. |
| Stage 4 | `tb/mini_cpu_mmio_tb.v` | `ST`, `LD`, readback przez MMIO, stroby bus. |
| Stage 5 | `tb/mini_cpu_gpio_program_tb.v` | Program GPIO zapisuje PASS do `GPIO_LED` i wykonuje `HALT`. |

Pełny runner:

```powershell
python tools/run_all_tests.py
```

Jeżeli lokalnie nie ma `iverilog` i `vvp`, lokalne symulacje Verilog mogą być
oznaczone jako `STATUS=SKIPPED`. GitHub Actions instaluje Icarus Verilog i
uruchamia testbenchy.

## Ograniczenia obecnego etapu

Ten branch nie dodaje jeszcze:

- UART,
- AXI-Lite,
- RISC-V,
- integracji CPU z `fft_accelerator_mmio`,
- fizycznego I2S,
- nowego top-level Tang Nano.

Następny logiczny etap to osobny branch, w którym `mini_cpu_system` zostanie
podłączony do FFT/IFFT MMIO wrappera.
