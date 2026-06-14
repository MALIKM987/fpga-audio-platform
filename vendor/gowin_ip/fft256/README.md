# Gowin FFT 256 IP placeholder

Ten katalog jest zarezerwowany na przyszły forward FFT IP 256 punktów
wygenerowany w Gowin EDA. Pliki IP nie są jeszcze dodane.

Aktualnie projekt używa własnego `rtl/dsp/fft_radix2_core.v`.

Przed integracją IP trzeba spisać:

- nazwę modułu,
- nazwy portów,
- handshake,
- kolejność wejścia i wyjścia,
- format fixed-point,
- skalowanie,
- latency,
- wymagane biblioteki Gowin,
- sposób testowania w symulacji.
