# Interfejs przyszlego akceleratora FFT/IFFT

Plik `rtl/dsp/fft_ifft_accel_stub.v` zawiera tylko stub interfejsu. Nie jest to implementacja FFT/IFFT.

## Sygnaly sterujace

- `start` rozpoczyna przetwarzanie nowej ramki, gdy `busy = 0`.
- `inverse` wybiera tryb pracy: `0` dla FFT, `1` dla IFFT. W stubie tryb jest tylko zapamiety.
- `busy` oznacza, ze blok jest w trakcie przyjmowania lub przetwarzania ramki.
- `done` jest impulsem jednocyklowym po zakonczeniu ramki `FFT_N` probek.

## Handshake danych

- `sample_in_valid` informuje, ze wejscia `sample_in_real` i `sample_in_imag` zawieraja wazna probke.
- `sample_in_ready` informuje, ze blok przyjmuje dane. W stubie jest aktywne podczas `busy`.
- `sample_out_valid` informuje, ze `sample_out_real` i `sample_out_imag` zawieraja wazny wynik.

Aktualny stub przepuszcza dane real/imag bez obliczen i konczy ramke po `FFT_N` zaakceptowanych probkach.

## Format danych

Dane sa w formacie signed fixed-point o szerokosci `DATA_WIDTH`, domyslnie 16 bitow. Dokladna interpretacja liczby bitow ulamkowych powinna zostac ustalona przy implementacji mnoznika zespolonego i skalowania FFT/IFFT. Na tym etapie interfejs zaklada tylko signed two's complement.

## Plan przyszlej implementacji

Docelowy akcelerator powinien zawierac:

- `sample RAM` na ramke `FFT_N` probek,
- `bit reversal` dla adresowania wejscia albo wyjscia FFT,
- `twiddle ROM` z wartosciami wspolczynnikow zespolonych,
- `butterfly unit` dla operacji radix-2,
- `complex multiplier` dla mnozenia przez twiddle i gain widmowy,
- FSM etapow `0...log2(N)-1`,
- `spectral_processor` po FFT,
- IFFT korzystajace z tego samego lub podobnego datapathu,
- overlap-add dla ciaglego przetwarzania audio.

Planowany przeplyw danych:

```text
sample buffer -> FFT -> spectral_processor -> IFFT -> overlap-add -> volume -> I2S TX
```

`spectral_processor` powinien dla kazdego binu wykonac:

```text
FFT bin -> spectral_gain_select -> mnozenie real/imag przez gain Q2.14
```
