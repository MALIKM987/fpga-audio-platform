# Gowin IP vendor area

Ten katalog jest przeznaczony na pliki IP wygenerowane lokalnie w Gowin EDA.
Na tym etapie repozytorium nie zawiera jeszcze wygenerowanego FFT ani IFFT IP.

Docelowo katalog będzie przechowywał osobne podkatalogi dla bloków:

- `fft256/` - forward FFT 256 punktów,
- `ifft256/` - inverse FFT 256 punktów.

Wygenerowane pliki IP należy dodać dopiero w osobnym PR, po potwierdzeniu:

- licencji i możliwości przechowywania plików w repozytorium,
- rzeczywistych nazw modułów i portów,
- parametrów Verilog / konfiguracji IP,
- formatu danych wejściowych i wyjściowych,
- skalowania,
- kolejności wyjścia,
- plików potrzebnych do symulacji,
- bibliotek wymaganych przez Gowin EDA.

Nie należy mieszać wygenerowanych plików IP z katalogiem `gowin_impl/`.
`gowin_impl/` pozostaje projektem narzędziowym Gowin, a `vendor/gowin_ip/`
ma być miejscem na kontrolowane kopie źródeł IP używanych przez RTL.

Obecne moduły `fft_accel_wrapper.v` i `ifft_accel_wrapper.v` nadal są modelami
passthrough. Ten katalog przygotowuje tylko miejsce na przyszły import Gowin IP.
