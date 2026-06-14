# `gowin_impl/`

Projekt Gowin EDA i pliki potrzebne do budowy bitstreamu.

Aktualny projekt znajduje się w:

```text
gowin_impl/tang_audio_hw/
```

Folder `src/` może zawierać kopie wybranych plików RTL. `rtl/` pozostaje
głównym źródłem prawdy. Przy zmianach sprzętowych trzeba ręcznie i świadomie
zsynchronizować kopie używane przez Gowin.

Nie należy nadpisywać działającego setupu Gowin bez testu. Dla aktualnego
bring-upu UART top powinien być ustawiony na:

```text
tang_cpu_owned_frame_uart_top
```

Potwierdzone piny bring-upu są opisane w
`../docs/tang_nano_hardware.md`.
