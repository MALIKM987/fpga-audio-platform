# Notatki symulacyjne

Testbenche sa samosprawdzajace i wypisuja PASS albo FAIL. Ponizsze komendy sa przykladem dla Icarus Verilog, jesli `iverilog` i `vvp` sa dostepne w PATH.

```powershell
iverilog -g2001 -o sim/eq3band_simple_tb.vvp rtl/dsp/gain_lut_q2_14.v rtl/dsp/eq3band_simple.v tb/eq3band_simple_tb.v
vvp sim/eq3band_simple_tb.vvp

iverilog -g2001 -o sim/eq3band_stereo_tb.vvp rtl/dsp/gain_lut_q2_14.v rtl/dsp/eq3band_simple.v rtl/dsp/eq3band_stereo.v tb/eq3band_stereo_tb.v
vvp sim/eq3band_stereo_tb.vvp

iverilog -g2001 -o sim/test_mix_gen_tb.vvp rtl/audio/test_mix_gen.v tb/test_mix_gen_tb.v
vvp sim/test_mix_gen_tb.vvp

iverilog -g2001 -o sim/tang_audio_eq_top_tb.vvp rtl/audio/test_mix_gen.v rtl/audio/i2s_tx.v rtl/common/sync_2ff.v rtl/common/debounce.v rtl/common/button_onepulse.v rtl/control/audio_param_regs.v rtl/control/button_control_top.v rtl/dsp/gain_lut_q2_14.v rtl/dsp/eq3band_simple.v rtl/dsp/eq3band_stereo.v rtl/dsp/volume_lut_q2_14.v rtl/dsp/volume_control.v rtl/top/tang_audio_eq_top.v tb/tang_audio_eq_top_tb.v
vvp sim/tang_audio_eq_top_tb.vvp

iverilog -g2001 -o sim/volume_control_tb.vvp rtl/dsp/volume_lut_q2_14.v rtl/dsp/volume_control.v tb/volume_control_tb.v
vvp sim/volume_control_tb.vvp

iverilog -g2001 -o sim/audio_param_regs_tb.vvp rtl/control/audio_param_regs.v tb/audio_param_regs_tb.v
vvp sim/audio_param_regs_tb.vvp
```

W Vivado/XSim albo ModelSim/Questa nalezy dodac te same pliki RTL i odpowiedni plik testbencha do symulacji behawioralnej.
