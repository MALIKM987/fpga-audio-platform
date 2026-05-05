# Bring-up topu tang_audio_eq_top w Gowin

Projekt Gowin w `gowin_impl/tang_audio_hw/` aktualnie uzywa plikow z katalogu `gowin_impl/tang_audio_hw/src/` dla podstawowego topu. Nie zmieniono automatycznie `.gprj`, poniewaz `tang_audio_eq_top` ma nowe porty przyciskow i LED, ktore wymagaja fizycznych pinow w `.cst`.

Do testu `tang_audio_eq_top` nalezy dodac do projektu Gowin ponizsze pliki RTL z katalogu `rtl/`:

- `rtl/audio/test_mix_gen.v`
- `rtl/audio/i2s_tx.v`
- `rtl/common/sync_2ff.v`
- `rtl/common/debounce.v`
- `rtl/common/button_onepulse.v`
- `rtl/control/audio_param_regs.v`
- `rtl/control/button_control_top.v`
- `rtl/dsp/gain_lut_q2_14.v`
- `rtl/dsp/eq3band_simple.v`
- `rtl/dsp/eq3band_stereo.v`
- `rtl/dsp/volume_lut_q2_14.v`
- `rtl/dsp/volume_control.v`
- `rtl/top/tang_audio_eq_top.v`

Nie dodano `i2s_tx_stereo.v`, bo obecny `rtl/audio/i2s_tx.v` ma juz tryb stereo przez parametr `USE_STEREO_INPUTS`.

## Constraints

Nie wpisano losowych pinow. Przed synteza topu EQ trzeba przypisac:

- `clk`
- `rst`
- `btn_vol_up`
- `btn_vol_down`
- `btn_bass_up`
- `btn_bass_down`
- `btn_mid_up`
- `btn_mid_down`
- `btn_treble_up`
- `btn_treble_down`
- `btn_channel_select`
- `I2S_BCLK`
- `I2S_LRCK`
- `I2S_DIN`
- `PA_SD`
- `led_heartbeat`
- `led_left_active`
- `led_right_active`
- `led_clip`

Istniejacy `.cst` ma piny dla starego topu i nie zawiera jeszcze kompletu portow dla `tang_audio_eq_top`.
