# Polaczenia hardware TODO

Nie wpisywac konkretnych numerow pinow FPGA bez potwierdzenia polaczen i dokumentacji uzytych modulow.

| Sygnal | Kierunek wzgledem FPGA | Modul | Pin FPGA | Status |
| --- | --- | --- | --- | --- |
| `adc_i2s_data` | input | PCM1808 | TODO | do potwierdzenia |
| `adc_i2s_bclk` | input albo output | PCM1808 | TODO | zalezne od master/slave |
| `adc_i2s_lrck` | input albo output | PCM1808 | TODO | zalezne od master/slave |
| `adc_i2s_mclk` | output albo clock zewnetrzny | PCM1808 | TODO | sprawdzic wymagania modulu |
| `adc_power` | zasilanie | PCM1808 | TODO | zgodnie z modulem |
| `adc_gnd` | GND | PCM1808 | TODO | wspolna masa |
| `dac_i2s_data` | output | PCM5102A | TODO | do potwierdzenia |
| `dac_i2s_bclk` | output | PCM5102A | TODO | do potwierdzenia |
| `dac_i2s_lrck` | output | PCM5102A | TODO | do potwierdzenia |
| `dac_i2s_mclk` / `dac_sck` | output albo nieuzywany | PCM5102A | TODO | sprawdzic tryb modulu |
| `dac_power` | zasilanie | PCM5102A | TODO | zgodnie z modulem |
| `dac_gnd` | GND | PCM5102A | TODO | wspolna masa |
| `btn_vol_up` | input | sterowanie | TODO | do przypisania |
| `btn_vol_down` | input | sterowanie | TODO | do przypisania |
| `btn_bass_up` | input | sterowanie | TODO | do przypisania |
| `btn_bass_down` | input | sterowanie | TODO | do przypisania |
| `btn_mid_up` | input | sterowanie | TODO | do przypisania |
| `btn_mid_down` | input | sterowanie | TODO | do przypisania |
| `btn_treble_up` | input | sterowanie | TODO | do przypisania |
| `btn_treble_down` | input | sterowanie | TODO | do przypisania |
| `btn_bypass_mode` | input | sterowanie | TODO | przyszly tryb BYPASS |
| `led_power_fpga_active` | output | LED | TODO | do przypisania |
| `led_audio_active` | output | LED | TODO | do przypisania |
| `led_bypass` | output | LED | TODO | do przypisania |
| `led_clipping` | output | LED | TODO | do przypisania |
| `led_left_active` | output | LED | TODO | do przypisania |
| `led_right_active` | output | LED | TODO | do przypisania |

## SELFTEST / UART diagnostyczny

| Sygnal | Kierunek wzgledem FPGA | Modul | Pin FPGA | Status |
| --- | --- | --- | --- | --- |
| `uart_tx` | output | self-test UART | TODO | pin trzeba potwierdzic przed odbiorem przez USB-UART |
| `led_heartbeat` | output | LED | TODO | opcjonalny wskaznik pracy |
| `led_clip` | output | LED | TODO | opcjonalny wskaznik clippingu |
| `led_mode[2:0]` | output | LED | TODO | opcjonalny wskaznik trybu |

Nie wpisywac numerow pinow bez potwierdzenia schematu, dokumentacji modulu i faktycznego okablowania.
