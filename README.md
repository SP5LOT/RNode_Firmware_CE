# RNode Firmware CE — Hydra E22 (ESP32 + SX1262)

🇵🇱 [Polski](#polski) | 🇬🇧 [English](#english)

---

## Polski

To jest fork [RNode Firmware Community Edition](https://github.com/liberatedsystems/RNode_Firmware_CE) z dodaną obsługą płytki **Hydra Designs DIY PCB** — ESP32-WROOM-32U + Ebyte E22-900M30S (SX1262, 30 dBm).

Projekt powstał w środowisku polskiej społeczności LoRa/Meshtastic na [meshtastic.pop.pl](https://meshtastic.pop.pl) — polskie forum DIY z poradnikami jak zbudować takie urządzenie, listami komponentów i pomocą techniczną. Płytka bazuje na otwartym schemacie [Hydra Designs](https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb).

> **Branch `hydra-e22`** zawiera wszystkie modyfikacje i skompilowany firmware gotowy do wgrania.

---

### Sprzęt

| Komponent | Model |
|-----------|-------|
| MCU | ESP32-WROOM-32U (30-pin, CH340 USB) |
| Radio | Ebyte E22-900M30S (SX1262, 30 dBm, 900 MHz) |
| PCB | Płytka modułowa Hydra Designs (Meshtastic) |
| Wyświetlacz | SSD1306 OLED (I2C) |

### Szybki start — wgranie gotowego firmware

1. Zainstaluj wymagane narzędzia:
   ```bash
   pip install rns pyserial
   ```

2. Wgraj firmware (zamień `COM11` na swój port):
   ```bash
   python -m esptool --port COM11 --baud 921600 write_flash 0x10000 firmware/firmware_hydra_e22.bin
   ```

3. Provisionuj urządzenie:
   ```bash
   rnodeconf COM11 -r
   rnodeconf COM11 --product f0 --model fe --hwrev 1
   ```

4. Skonfiguruj Reticulum (`%USERPROFILE%\.reticulum\config` lub `~/.reticulum/config`):
   ```ini
   [[LORA V2]]
     type = RNodeInterface
     interface_enabled = true
     port = COM11
     frequency = 869185000
     bandwidth = 125000
     txpower = 17
     spreadingfactor = 8
     codingrate = 8
   ```

5. Uruchom:
   ```bash
   rnsd -v
   ```

### Budowanie ze źródeł

Pełny tutorial krok po kroku: [HYDRA_E22_TUTORIAL.md](HYDRA_E22_TUTORIAL.md)

Wymagania: Python 3.10+, PlatformIO (rozszerzenie VS Code lub CLI).

```bash
pio run -e hydra_e22
pio run -e hydra_e22 -t upload --upload-port COM11
```

### Co zostało zmienione względem oryginału

| Plik | Zmiana |
|------|--------|
| `Boards.h` | Dodano `BOARD_HYDRA_E22` (0x46) z poprawnymi pinami GPIO |
| `Radio.cpp` | Napięcie TCXO ustawione na 1.8V (wymagane przez E22-900M30S); guardy `!_preinit_done` |
| `main.cpp` | Pre-echo parametrów radia przed `startRadio()`; `MAX_CYCLES=128` |
| `Display.h` | Konstruktor SSD1306 z poprawką zegara I2C 400 kHz |
| `Utilities.h` | Pomocniki LED i `eeprom_model_valid()` dla BOARD_HYDRA_E22 |
| `platformio.ini` | Środowisko PlatformIO dla `hydra_e22` |

### Pinout

| Sygnał | GPIO |
|--------|------|
| NSS/CS | 18 |
| SCK | 5 |
| MOSI | 27 |
| MISO | 19 |
| BUSY | 32 |
| DIO1 | 33 |
| RST | 23 |
| TXEN | 13 |
| RXEN | 14 |
| I2C SDA | 21 |
| I2C SCL | 22 |

### Licencja

Bazuje na RNode Firmware CE autorstwa Jacob Eva / [Liberated Embedded Systems](https://liberatedsystems.co.uk), licencja **GPLv3**.
Oryginalny firmware autorstwa Mark Qvist / [unsigned.io](https://unsigned.io).

---

## English

This is a fork of [RNode Firmware Community Edition](https://github.com/liberatedsystems/RNode_Firmware_CE) with added support for the **Hydra Designs DIY PCB** — ESP32-WROOM-32U + Ebyte E22-900M30S (SX1262, 30 dBm).

The build was inspired by the [Polish LoRa/Meshtastic community at meshtastic.pop.pl](https://meshtastic.pop.pl) — a Polish-language DIY forum with guides on how to build nodes like this one, component lists, and community support. The board is based on the open [Hydra Designs schematic](https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb).

> **Branch `hydra-e22`** contains all modifications and a compiled firmware binary ready to flash.

---

### Hardware

| Component | Model |
|-----------|-------|
| MCU | ESP32-WROOM-32U (30-pin, CH340 USB) |
| Radio | Ebyte E22-900M30S (SX1262, 30 dBm, 900 MHz) |
| PCB | Hydra Designs modular Meshtastic board |
| Display | SSD1306 OLED (I2C) |

### Quick Start — Flash Prebuilt Firmware

1. Install dependencies:
   ```bash
   pip install rns pyserial
   ```

2. Flash the binary (replace `COM11` with your port):
   ```bash
   python -m esptool --port COM11 --baud 921600 write_flash 0x10000 firmware/firmware_hydra_e22.bin
   ```

3. Provision the device:
   ```bash
   rnodeconf COM11 -r
   rnodeconf COM11 --product f0 --model fe --hwrev 1
   ```

4. Configure Reticulum (`~/.reticulum/config`):
   ```ini
   [[LORA V2]]
     type = RNodeInterface
     interface_enabled = true
     port = COM11
     frequency = 869185000
     bandwidth = 125000
     txpower = 17
     spreadingfactor = 8
     codingrate = 8
   ```

5. Start:
   ```bash
   rnsd -v
   ```

### Build from Source

See [HYDRA_E22_TUTORIAL.md](HYDRA_E22_TUTORIAL.md) for a complete step-by-step guide.

Requires: Python 3.10+, PlatformIO (VS Code extension or CLI).

```bash
pio run -e hydra_e22
pio run -e hydra_e22 -t upload --upload-port COM11
```

### What Was Changed vs Upstream

| File | Change |
|------|--------|
| `Boards.h` | Added `BOARD_HYDRA_E22` (0x46) with correct GPIO pinout |
| `Radio.cpp` | TCXO set to 1.8V (required by E22-900M30S); `!_preinit_done` guards |
| `main.cpp` | Pre-echo radio params before `startRadio()`; `MAX_CYCLES=128` |
| `Display.h` | SSD1306 constructor with 400 kHz I2C clock fix |
| `Utilities.h` | LED helpers and `eeprom_model_valid()` for BOARD_HYDRA_E22 |
| `platformio.ini` | PlatformIO build environment for `hydra_e22` |

### Pinout

| Signal | GPIO |
|--------|------|
| NSS/CS | 18 |
| SCK | 5 |
| MOSI | 27 |
| MISO | 19 |
| BUSY | 32 |
| DIO1 | 33 |
| RST | 23 |
| TXEN | 13 |
| RXEN | 14 |
| I2C SDA | 21 |
| I2C SCL | 22 |

### License

Based on RNode Firmware CE by Jacob Eva / [Liberated Embedded Systems](https://liberatedsystems.co.uk), licensed under **GPLv3**.
Original firmware by Mark Qvist / [unsigned.io](https://unsigned.io).
