# Podsumowanie prac — FPGA Audio Platform
Data: 2026-04-15

## Stan projektu na dziœ

Uda³o siê zrealizowaæ podstawowy etap organizacyjny i pierwszy etap uruchomienia sprzêtu.

### Zrobione
- utworzone repozytorium Git dla projektu
- przygotowana struktura katalogów projektu:
  - rtl/
  - rtl/audio/
  - rtl/dsp/
  - rtl/common/
  - rtl/top/
  - tb/
  - sim/
  - gowin_impl/
  - docs/
- utworzony i uzupe³niony plik .gitignore
- utworzony plik README.md
- za³o¿ony projekt symulacyjny w Vivado
- za³o¿ony projekt implementacyjny w Gowin
- utworzony pierwszy modu³ HDL:
  - rtl/audio/tone_gen.v
- utworzony pierwszy testbench:
  - tb/tone_gen_tb.v
- uruchomiona poprawnie pierwsza symulacja w Vivado
- utworzony modu³ nadajnika I2S:
  - rtl/audio/i2s_tx.v
- utworzony top do symulacji transmisji audio:
  - rtl/top/audio_tx_top.v
- utworzony testbench:
  - tb/audio_tx_top_tb.v
- uruchomiona poprawnie symulacja I2S:
  - sygna³y bclk, lrck i sdata dzia³aj¹ poprawnie
- utworzony top sprzêtowy dla Tang Nano 20K:
  - rtl/top/tang_audio_top.v
- dodane constraints pinów w Gowin dla:
  - clk
  - I2S_BCLK
  - I2S_LRCK
  - I2S_DIN
  - PA_SD
- rozwi¹zany problem z pinami SSPI przez w³¹czenie:
  - Use SSPI as regular IO
- dodany constraint zegara 27 MHz przez plik constraints.sdc
- poprawnie wygenerowany bitstream i zaprogramowana p³ytka Tang Nano 20K
- wykonany test sprzêtowy LED
- ustalony poprawny pin diody LED:
  - led -> pin 15
- dioda LED zaczê³a migaæ po poprawnym przypisaniu pinu

## Najwa¿niejsze wnioski
- flow projektowy dzia³a:
  - Vivado do symulacji
  - Gowin do implementacji i programowania
- FPGA dzia³a poprawnie na sprzêcie
- zegar dzia³a poprawnie
- projekt mo¿na syntezowaæ, implementowaæ i programowaæ
- wczeœniejszy problem z testem LED wynika³ z b³êdnego pinu LED, a nie z b³êdu logiki
- tor I2S dzia³a poprawnie w symulacji, ale nie by³ jeszcze testowany ods³uchowo na realnym wyjœciu audio

## Aktualny stan techniczny
Dzia³aj¹ce elementy:
- repozytorium projektu
- struktura plików
- tone_gen
- i2s_tx
- testbenche
- symulacja Vivado
- implementacja Gowin
- programowanie Tang Nano 20K
- test LED na sprzêcie

Elementy jeszcze niezweryfikowane sprzêtowo:
- poprawnoœæ dzia³ania wyjœcia audio na wbudowanym torze MAX98357A
- jakoœæ generowanego sygna³u audio
- rzeczywisty ods³uch sygna³u na wyjœciu p³ytki

## Nastêpne cele
### Cel bezpoœredni
- przygotowaæ lepszy generator tonu testowego, najlepiej prostok¹t 440 Hz lub 1 kHz
- zostawiæ heartbeat LED w topie jako debug
- zintegrowaæ tone_gen + i2s_tx + PA_SD + led w finalnym topie
- ponownie zbudowaæ projekt i wgraæ bitstream
- sprawdziæ wyjœcie audio na p³ytce Tang Nano 20K

### Kolejny etap
- potwierdziæ realne dzia³anie audio out
- dopracowaæ nadajnik I2S pod wersjê sprzêtow¹
- uporz¹dkowaæ top-level sprzêtowy

### Nastêpne fazy projektu
- dodaæ prosty blok DSP:
  - volume
- dodaæ pierwszy filtr:
  - biquad
- przygotowaæ prosty 3-pasmowy EQ
- dodaæ prosty efekt:
  - delay
- dopiero póŸniej przejœæ do wejœcia audio przez zewnêtrzny ADC/kodek I2S

## Notatka organizacyjna
Na obecnym etapie projekt jest poprawnie przygotowany do dalszych prac. Najbli¿szy nastêpny kamieñ milowy to:
- pierwszy rzeczywisty dŸwiêk z Tang Nano 20K

