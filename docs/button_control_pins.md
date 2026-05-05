# Przypisanie pinow panelu przyciskow

Projekt nie zgaduje fizycznych pinow przyciskow dla Tang Nano 20K. Do uruchomienia topu `tang_audio_control_top` trzeba przypisac w constraints Gowin (`.cst`) nastepujace porty:

- `btn_vol_up`
- `btn_vol_down`
- `btn_bass_up`
- `btn_bass_down`
- `btn_mid_up`
- `btn_mid_down`
- `btn_treble_up`
- `btn_treble_down`
- `btn_channel_select`
- `led_left_active`
- `led_right_active`

Istniejacy plik `gowin_impl/tang_audio_hw/src/tang_audio_hw.cst` zawiera piny dla zegara, I2S, `PA_SD` i starego portu `led`, ale nie zawiera jeszcze pinow panelu przyciskow ani nowych LED. Nie wpisano losowych pinow. TODO: uzupelnic `.cst` po ustaleniu faktycznego okablowania przyciskow i LED.

Domyslnie `button_onepulse` zaklada przyciski aktywne stanem wysokim. Jesli panel jest aktywny stanem niskim, ustaw parametr `BUTTON_ACTIVE_LEVEL` na `1'b0` w instancji `button_control_top` albo `tang_audio_control_top`.
