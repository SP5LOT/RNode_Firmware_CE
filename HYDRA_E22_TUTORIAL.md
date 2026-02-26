# DIY RNode na ESP32 + Ebyte E22-900M30S — Tutorial od zera

## Sprzęt

| Komponent | Model |
|-----------|-------|
| MCU | ESP32-WROOM-32U (30-pin, CH340 USB) |
| Radio | Ebyte E22-900M30S (SX1262, 30 dBm, 900 MHz) |
| PCB | Płytka Hydra Designs (dostępna m.in. na meshtastic.pop.pl) |
| Wyświetlacz | SSD1306 OLED (I2C) |

Płytka jest kompatybilna ze schematem Hydra Designs:
https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb

---

## Wymagania — oprogramowanie

- **Python 3.13** (lub nowszy)
- **PlatformIO** (jako rozszerzenie VS Code lub CLI)
- **rnodeconf**: `pip install rns` lub `pip install rnodeconf`
- **pyserial**: `pip install pyserial`

---

## Krok 1 — Pobierz firmware RNode CE

```bash
git clone https://github.com/markqvist/RNode_Firmware_CE.git
cd RNode_Firmware_CE
```

Albo pobierz ZIP ze strony projektu i wypakuj.

---

## Krok 2 — Dodaj definicję płytki BOARD_HYDRA_E22 (src/Boards.h)

### 2a — Dodaj stałą na liście #define na początku pliku

```c
#define BOARD_HYDRA_E22     0x46  // Hydra Designs DIY PCB: ESP32-WROOM-32U + E22-900M30S
```

### 2b — Dodaj blok konfiguracji (przed #elif BOARD_MODEL == BOARD_XIAO_S3 lub podobnym)

```c
#elif BOARD_MODEL == BOARD_HYDRA_E22
  // Hydra Designs DIY PCB: ESP32-WROOM-32U + Ebyte E22-900M30S (SX1262, 30dBm)
  // Schematic: https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb
  #define VALIDATE_FIRMWARE false
  #define HAS_DISPLAY true
  #define DISPLAY OLED
  #define HAS_BLUETOOTH true
  #define HAS_CONSOLE true
  #define HAS_SD false
  #define HAS_EEPROM true
  #define I2C_SDA 21
  #define I2C_SCL 22
  #define INTERFACE_COUNT 1
  const int pin_led_rx = 2;
  const int pin_led_tx = 2;

  const uint8_t interfaces[INTERFACE_COUNT] = {SX1262};
  const bool interface_cfg[INTERFACE_COUNT][3] = {
      {
          false, // DEFAULT_SPI
          true,  // HAS_TCXO
          false  // DIO2_AS_RF_SWITCH (using explicit TXEN/RXEN pins)
      },
  };
  const int8_t interface_pins[INTERFACE_COUNT][10] = {
      {
          18, // pin_ss   (NSS,   GPIO18)
           5, // pin_sclk (SCK,   GPIO5)
          27, // pin_mosi (MOSI,  GPIO27)
          19, // pin_miso (MISO,  GPIO19)
          32, // pin_busy (BUSY,  GPIO32)
          33, // pin_dio  (DIO1,  GPIO33)
          23, // pin_reset(RST,   GPIO23)
          13, // pin_txen (TXEN,  GPIO13)
          14, // pin_rxen (RXEN,  GPIO14)   <-- PRZECINEK OBOWIAZKOWY! (patrz uwaga nizej)
          -1  // pin_tcxo_enable
      }
  };
```

> **KRYTYCZNE — przecinek po 14:**
> Linia `14, // pin_rxen` MUSI mieć przecinek. Bez niego C++ parsuje
> `14 -1` jako wyrażenie arytmetyczne `14 - 1 = 13`, przez co:
> - RXEN dostaje GPIO13 zamiast GPIO14 (ten sam pin co TXEN!)
> - tcxo_enable dostaje GPIO0 (pin BOOT!) zamiast -1
> Efekt: antena nie przełącza się prawidłowo, radio nie nadaje,
> niebieski LED świeci 15-20 sekund przy każdym TX, potem restart.

---

## Krok 3 — Napraw napięcie TCXO (src/Radio.cpp)

Znajdź funkcję `sx126x::enableTCXO()`. Wygląda mniej więcej tak:

```c
void sx126x::enableTCXO() {
  if (_tcxo) {
    #if BOARD_MODEL == BOARD_RAK4631 || ...
      uint8_t buf[4] = {MODE_TCXO_3_3V_6X, 0x00, 0x00, 0xFF};
    // ... inne plytki ...
    #elif BOARD_MODEL == BOARD_E22_ESP32
      uint8_t buf[4] = {MODE_TCXO_1_8V_6X, 0x00, 0x00, 0xFF};
    #else
      uint8_t buf[4] = {0};   // <-- 1.6V -- za malo dla E22!
    #endif
    executeOpcode(OP_DIO3_TCXO_CTRL_6X, buf, 4);
  }
}
```

Dodaj case dla BOARD_HYDRA_E22 **przed** `#else`:

```c
    #elif BOARD_MODEL == BOARD_HYDRA_E22
      uint8_t buf[4] = {MODE_TCXO_1_8V_6X, 0x00, 0x00, 0xFF};
```

> **Dlaczego 1.8V:** TCXO w module E22-900M30S jest zasilany przez pin DIO3
> SX1262. Potrzebuje 1.8V. Przy 1.6V (domyślne `#else`) oscylator nie startuje
> stabilnie — SX1262 zawiesza się z BUSY=HIGH, każdy zapis bajtu do bufora TX
> czeka 100ms na timeout, ~150 bajtów × 100ms = 15 sekund zawieszenia przy TX.

---

## Krok 4 — Dodaj guardy `!_preinit_done` (src/Radio.cpp)

Bez tego firmware wywołuje operacje SPI zanim SPI jest zainicjalizowane.
Każda taka operacja czeka 100ms na timeout — przez co rnsd (okno 250ms) nie
zdąży odebrać wszystkich parametrów i odrzuca połączenie z błędem "4 mismatches".

W każdej z poniższych funkcji dodaj guard **po** zapamiętaniu wartości,
**przed** wywołaniem SPI:

```c
void sx126x::setFrequency(uint32_t frequency) {
    _frequency = frequency;
    if (!_preinit_done) return;  // <-- dodaj
    // ... reszta ...
}

void sx126x::setTxPower(int level, int outputPin) {
    if (level > 22) { level = 22; }
    else if (level < -9) { level = -9; }
    _txp = level;
    if (!_preinit_done) return;  // <-- dodaj
    // ... reszta ...
}

void sx126x::setSignalBandwidth(long sbw) {
    // ... obliczenia _bw ...
    _bw = bw_val;
    if (!_preinit_done) return;  // <-- dodaj po zapamiętaniu _bw
    setModulationParams(...);
}

void sx126x::setSpreadingFactor(int sf) {
    _sf = sf;
    if (!_preinit_done) return;  // <-- dodaj
    setModulationParams(...);
}

void sx126x::setCodingRate4(int denominator) {
    // ... obliczenia _cr ...
    _cr = cr;
    if (!_preinit_done) return;  // <-- dodaj po zapamiętaniu _cr
    setModulationParams(...);
}
```

---

## Krok 5 — Pre-echo parametrów radia (src/main.cpp)

rnsd wysyła parametry i oczekuje ich echa w ciągu 250ms. Bez tej zmiany
firmware echuje parametry dopiero po operacjach SPI (za późno).

Znajdź obsługę `CMD_RADIO_STATE` z wartością `0x01`:

```c
// PRZED (wolne — echo przychodzi po SPI):
} else if (sbyte == 0x01) {
    startRadio(selected_radio);
}

// PO (szybkie — echo wysłane natychmiast, SPI potem):
} else if (sbyte == 0x01) {
    kiss_indicate_frequency(selected_radio);
    kiss_indicate_bandwidth(selected_radio);
    kiss_indicate_txpower(selected_radio);
    kiss_indicate_spreadingfactor(selected_radio);
    kiss_indicate_codingrate(selected_radio);
    startRadio(selected_radio);
}
```

---

## Krok 6 — Zwiększ MAX_CYCLES (src/main.cpp)

```c
// PRZED:
#define MAX_CYCLES 20

// PO:
#define MAX_CYCLES 128
```

> rnsd wysyła ~54+ bajtów podczas initRadio. Przy MAX_CYCLES=20 firmware
> przetwarza tylko 20 bajtów na iterację pętli głównej — CMD_RADIO_STATE
> trafia do przetworzenia zbyt późno. Przy 128 wszystko przechodzi
> w jednym przebiegu.

---

## Krok 7 — Napraw konstruktor SSD1306 (src/Display.h)

Znajdź (ok. linia 170):

```c
// PRZED:
Adafruit_SSD1306 display(DISP_W, DISP_H, &Wire, DISP_RST);

// PO:
Adafruit_SSD1306 display(DISP_W, DISP_H, &Wire, DISP_RST, 400000UL, 400000UL);
```

> Utrzymuje prędkość I2C na 400kHz po każdej transakcji wyświetlacza.
> Bez tego biblioteka Adafruit resetuje taktowanie do 100kHz.

---

## Krok 8 — Skonfiguruj PlatformIO (platformio.ini)

Dodaj nowe środowisko:

```ini
[env:hydra_e22]
extends = esp32_common
board = esp32dev
board_build.partitions = no_ota.csv
build_flags =
    ${esp32_common.build_flags}
    -D BOARD_MODEL=0x46
```

---

## Krok 9 — Zbuduj i wgraj firmware

```bash
# Build
pio run -e hydra_e22

# Flash (zmień COM11 na aktualny port urządzenia)
pio run -e hydra_e22 -t upload --upload-port COM11
```

Aktualny port można sprawdzić:
- Windows: `powershell -Command "[System.IO.Ports.SerialPort]::GetPortNames()"`
- Linux/Mac: `ls /dev/tty*`

---

## Krok 10 — Provisionowanie przez rnodeconf

Po flashu firmware nie ma danych EEPROM — rnsd odrzuci urządzenie.

```bash
# Sprawdź stan przed
rnodeconf COM11 --info

# Reset EEPROM
rnodeconf COM11 -r

# Ustaw parametry produktu
rnodeconf COM11 --product f0 --model fe --hwrev 1

# Sprawdź wynik — powinno pokazać HMBRW, model FE, hwrev 1
rnodeconf COM11 --info
```

Znaczenie parametrów:
- `--product f0` = HMBRW (homebrew/custom)
- `--model fe` = custom model
- `--hwrev 1` = hardware revision 1

---

## Krok 11 — Skonfiguruj Reticulum

Plik: `%USERPROFILE%\.reticulum\config` (Windows) lub `~/.reticulum/config` (Linux/Mac)

```ini
[reticulum]
  enable_transport = False
  share_instance = No

[logging]
  loglevel = 4

[interfaces]
  [[LORA V2]]
    type = RNodeInterface
    interface_enabled = true
    port = COM11
    frequency = 869185000
    bandwidth = 125000
    txpower = 17
    spreadingfactor = 8
    codingrate = 8
    mode = gateway
```

Parametry radia (868 MHz, Europa):
- `frequency`: 869185000 Hz
- `bandwidth`: 125000 Hz
- `txpower`: 17 dBm (maks. 22 = ~30 dBm na antenie przez PA E22; sprawdź lokalne przepisy)
- `spreadingfactor`: 8
- `codingrate`: 8

---

## Krok 12 — Uruchom i przetestuj

```bash
rnsd -v
```

Oczekiwany wynik:
```
RNodeInterface[LORA V2] is configured and powered up
```

Po połączeniu:
- Niebieski LED zapala się na ~0.5s podczas nadawania pakietu
- Szybkie mrugnięcie przy odbiorze
- Sygnał RF widoczny na wodospadzie SDR przy announce

---

## Pinout — podsumowanie

| Sygnał | GPIO | Uwagi |
|--------|------|-------|
| NSS/CS | 18 | SPI chip select |
| SCK | 5 | SPI clock |
| MOSI | 27 | SPI data out |
| MISO | 19 | SPI data in |
| BUSY | 32 | SX1262 busy flag |
| DIO1 | 33 | SX1262 interrupt |
| RST | 23 | SX1262 reset |
| TXEN | 13 | E22 TX enable (aktywny HIGH) |
| RXEN | 14 | E22 RX enable (aktywny HIGH) |
| I2C SDA | 21 | OLED display |
| I2C SCL | 22 | OLED display |

---

## Najczęstsze problemy

| Objaw | Przyczyna | Rozwiązanie |
|-------|-----------|-------------|
| rnsd: „4 mismatches" | Echo parametrów spóźnione (>250ms) | Kroki 4, 5, 6 |
| Niebieski LED 15-20s, restart ESP32 | Zły TCXO (1.6V) lub brakujący przecinek w pinout | Kroki 2 (przecinek!), 3 |
| Brak sygnału RF na SDR | Jak wyżej (antena nie przełącza się na TX) | Jak wyżej |
| Radio nie odpowiada w ogóle | Błędne piny SPI | Sprawdź pinout |
| rnodeconf: „device not identified" | Brak provisjonowania EEPROM | Krok 10 |
| Wyświetlacz zwalnia po pierwszym odświeżeniu | Brak clkAfter w konstruktorze SSD1306 | Krok 7 |

---

## Po aktualizacji firmware (nowa wersja RNode CE)

1. Zastosuj ponownie zmiany z kroków 2–7
2. `pio run -e hydra_e22`
3. `pio run -e hydra_e22 -t upload`
4. EEPROM pozostaje ważny — **nie trzeba ponownie provisionować**
