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

iverilog -g2001 -o sim/test_signal_gen_tb.vvp rtl/debug/test_signal_gen.v tb/test_signal_gen_tb.v
vvp sim/test_signal_gen_tb.vvp

iverilog -g2001 -o sim/modulation_core_tb.vvp rtl/dsp/gain_lut_q2_14.v rtl/dsp/volume_lut_q2_14.v rtl/dsp/modulation_core.v tb/modulation_core_tb.v
vvp sim/modulation_core_tb.vvp

iverilog -g2001 -o sim/debug_analyzer_tb.vvp rtl/debug/debug_analyzer.v tb/debug_analyzer_tb.v
vvp sim/debug_analyzer_tb.vvp

iverilog -g2001 -o sim/uart_tx_tb.vvp rtl/uart/uart_tx.v tb/uart_tx_tb.v
vvp sim/uart_tx_tb.vvp

iverilog -g2001 -o sim/tang_audio_selftest_top_tb.vvp rtl/debug/test_signal_gen.v rtl/debug/auto_param_controller.v rtl/dsp/gain_lut_q2_14.v rtl/dsp/volume_lut_q2_14.v rtl/dsp/modulation_core.v rtl/debug/debug_analyzer.v rtl/debug/uart_debug_formatter.v rtl/uart/uart_tx.v rtl/top/tang_audio_selftest_top.v tb/tang_audio_selftest_top_tb.v
vvp sim/tang_audio_selftest_top_tb.vvp
```

W Vivado/XSim albo ModelSim/Questa nalezy dodac te same pliki RTL i odpowiedni plik testbencha do symulacji behawioralnej.
