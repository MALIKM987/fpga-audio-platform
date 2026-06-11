# Gowin IFFT 256 IP placeholder

Ten katalog jest miejscem na przyszły inverse FFT IP wygenerowany w Gowin EDA.
Pliki IP nie są jeszcze dodane.

Planowana konfiguracja:

- rozmiar: 256 punktów,
- tryb: IFFT / inverse FFT,
- dane wejściowe: complex signed fixed-point,
- minimalna szerokość danych: 16 bitów dla `real` i 16 bitów dla `imag`,
- docelowe użycie: zamiana obecnego modelu passthrough w
  `ifft_accel_wrapper.v`.

Po wygenerowaniu IP trzeba potwierdzić i zapisać:

- nazwę modułu IFFT,
- nazwy portów,
- czy interfejs używa `valid/ready`, czy innego streamingu,
- kolejność próbek wejściowych,
- kolejność próbek wyjściowych,
- format danych wejściowych,
- format danych wyjściowych,
- latency,
- reset i start,
- sygnały końca ramki lub `done`,
- kompatybilność symulacyjną,
- wymagane biblioteki Gowin.

Szczególnie ważne jest potwierdzenie skalowania:

- czy IP dzieli wynik przez `N = 256`,
- czy wynik nie jest skalowany,
- czy używa skalowania etapowego,
- czy wymaga kompensacji w adapterze lub w dalszym torze DSP.

Nie wolno zakładać powyższych szczegółów przed wygenerowaniem IP w Gowin EDA.
Adapter RTL zostanie przygotowany dopiero po spisaniu rzeczywistego interfejsu.
