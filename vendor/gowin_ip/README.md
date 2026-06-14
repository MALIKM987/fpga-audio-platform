# Gowin IP vendor area

Ten katalog jest miejscem na przyszłe pliki IP wygenerowane lokalnie w Gowin
EDA. Aktualny działający tor FFT/IFFT używa własnego rdzenia RTL
`fft_radix2_core.v`, a nie Gowin FFT IP.

Planowane podkatalogi:

- `fft256/` - potencjalny forward FFT IP 256 punktów,
- `ifft256/` - potencjalny inverse FFT IP 256 punktów.

Przed dodaniem wygenerowanego IP trzeba potwierdzić:

- licencję i możliwość przechowywania plików w repozytorium,
- rzeczywiste nazwy modułów i portów,
- format wejścia/wyjścia,
- skalowanie,
- kolejność próbek/binów,
- latency,
- wymagane biblioteki symulacyjne,
- zgodność z obecnym interfejsem wrapperów.

Nie należy mieszać wygenerowanego IP z `gowin_impl/`. `gowin_impl/` jest
projektem narzędziowym Gowin, a `vendor/gowin_ip/` ma być kontrolowanym miejscem
na źródła IP.
