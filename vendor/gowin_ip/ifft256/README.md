# Gowin IFFT 256 IP placeholder

Ten katalog jest zarezerwowany na przyszły inverse FFT IP 256 punktów
wygenerowany w Gowin EDA. Pliki IP nie są jeszcze dodane.

Aktualnie projekt używa własnego `rtl/dsp/fft_radix2_core.v` w trybie inverse.

Przed integracją IP trzeba szczególnie potwierdzić:

- czy IFFT dzieli wynik przez `N = 256`,
- czy wymaga osobnego skalowania,
- format fixed-point,
- kolejność próbek wyjściowych,
- latency,
- handshake,
- wymagane biblioteki Gowin,
- sposób testowania w symulacji.
