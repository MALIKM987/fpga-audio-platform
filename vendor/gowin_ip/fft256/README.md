# Gowin FFT 256 IP placeholder

Ten katalog jest miejscem na przyszły forward FFT IP wygenerowany w Gowin EDA.
Pliki IP nie są jeszcze dodane.

Planowana konfiguracja:

- rozmiar: 256 punktów,
- tryb: FFT forward,
- dane wejściowe: complex signed fixed-point,
- minimalna szerokość danych: 16 bitów dla `real` i 16 bitów dla `imag`,
- docelowe użycie: zamiana obecnego modelu passthrough w
  `fft_accel_wrapper.v`.

Po wygenerowaniu IP trzeba potwierdzić i zapisać:

- nazwę modułu FFT,
- nazwy portów,
- czy interfejs używa `valid/ready`, czy innego streamingu,
- kolejność próbek wejściowych,
- kolejność binów wyjściowych,
- czy wyjście jest natural order, czy bit-reversed,
- format danych wejściowych,
- format danych wyjściowych,
- tryb skalowania,
- latency,
- reset i start,
- sygnały końca ramki lub `done`,
- kompatybilność symulacyjną,
- wymagane biblioteki Gowin.

Nie wolno zakładać powyższych szczegółów przed wygenerowaniem IP w Gowin EDA.
Adapter RTL zostanie przygotowany dopiero po spisaniu rzeczywistego interfejsu.
