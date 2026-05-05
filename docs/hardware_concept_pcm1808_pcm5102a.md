# Koncepcja hardware: PCM1808 -> FPGA -> PCM5102A

## Glowny tor sygnalu

```text
generator funkcyjny
    -> PCM1808 ADC stereo
    -> Tang Nano 20K / FPGA
    -> PCM5102A DAC stereo
    -> oscyloskop
```

Generator funkcyjny dostarcza analogowy sygnal L/R do wejsc ADC. FPGA odbiera cyfrowy strumien I2S, wykonuje BYPASS albo DSP, a nastepnie wysyla I2S do DAC. Wyjscie analogowe PCM5102A jest traktowane jako wyjscie liniowe L/R do pomiaru oscyloskopem.

## Rola PCM1808

- ADC stereo.
- Wejscie analogowe L/R.
- Wyjscie I2S stereo.
- Jedna linia DATA przenosi kanaly L/R naprzemiennie.
- Wymaga poprawnego taktowania BCLK/LRCK oraz prawdopodobnie MCLK/SCKI zaleznie od modulu i trybu pracy.

## Rola FPGA

- Odbiera I2S stereo.
- Rozdziela `left_sample` i `right_sample`.
- Wykonuje BYPASS albo DSP.
- Sklada dane z powrotem do I2S stereo.

## Rola PCM5102A

- DAC stereo.
- Wejscie I2S stereo.
- Wyjscie liniowe analogowe L/R.
- Na tym etapie wyjscie mierzone jest oscyloskopem.
- Bez wzmacniacza mocy i bez glosnikow.

## Zasilanie i poziomy logiczne

- Moduly zasilac zgodnie z ich dokumentacja.
- Zapewnic wspolna mase GND.
- Nie podawac 5 V na wejscia FPGA.
- Upewnic sie, ze linie I2S sa w standardzie 3.3 V zgodnym z Tang Nano 20K.

## Sygnal testowy

- Startowo sinus 1 kHz.
- Amplituda poczatkowa ok. 0.2-0.5 Vpp.
- Offset zgodny z wejsciem uzytego modulu PCM1808.
- Nie przekraczac zakresu wejsciowego modulu ADC.

## Do rozstrzygniecia: architektura zegarow I2S

### Opcja A - FPGA jako master

- FPGA generuje BCLK, LRCK i ewentualnie MCLK.
- PCM1808 pracuje jako slave.
- PCM5102A odbiera BCLK/LRCK/DATA z FPGA.

### Opcja B - PCM1808 jako master

- PCM1808 generuje BCLK/LRCK.
- FPGA odbiera zegary z PCM1808.
- FPGA musi zsynchronizowac TX do PCM5102A.

### Rekomendacja

Na potrzeby projektu studenckiego preferowana jest jedna spojna domena audio clock. Najpierw nalezy ustalic, czy uzywany modul PCM1808 moze pracowac jako slave z zegarami z FPGA, czy wymaga wlasnego generatora MCLK.
