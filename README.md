# RNode Firmware CE — Hydra E22 (ESP32 + SX1262)

This is a fork of [RNode Firmware Community Edition](https://github.com/liberatedsystems/RNode_Firmware_CE) with added support for the **Hydra Designs DIY PCB** — ESP32-WROOM-32U + Ebyte E22-900M30S (SX1262, 30 dBm).

The board is available from [meshtastic.pop.pl](https://meshtastic.pop.pl) and is based on the [Hydra Designs schematic](https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb).

> **Branch `hydra-e22`** contains all modifications and a compiled firmware binary ready to flash.

---

## Hardware

| Component | Model |
|-----------|-------|
| MCU | ESP32-WROOM-32U (30-pin, CH340 USB) |
| Radio | Ebyte E22-900M30S (SX1262, 30 dBm, 900 MHz) |
| PCB | Hydra Designs modular Meshtastic board |
| Display | SSD1306 OLED (I2C) |

## Quick Start — Flash Prebuilt Firmware

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

## Build from Source

See [HYDRA_E22_TUTORIAL.md](HYDRA_E22_TUTORIAL.md) for a complete step-by-step guide.

Requires: Python 3.10+, PlatformIO (VS Code extension or CLI).

```bash
pio run -e hydra_e22
pio run -e hydra_e22 -t upload --upload-port COM11
```

## What Was Changed vs Upstream

| File | Change |
|------|--------|
| `Boards.h` | Added `BOARD_HYDRA_E22` (0x46) with correct GPIO pinout |
| `Radio.cpp` | TCXO set to 1.8V (required by E22-900M30S); `!_preinit_done` guards |
| `main.cpp` | Pre-echo radio params before `startRadio()`; `MAX_CYCLES=128` |
| `Display.h` | SSD1306 constructor with 400 kHz I2C clock fix |
| `Utilities.h` | LED helpers and `eeprom_model_valid()` for BOARD_HYDRA_E22 |
| `platformio.ini` | PlatformIO build environment for `hydra_e22` |

## Pinout

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

## License

Based on RNode Firmware CE by Jacob Eva / [Liberated Embedded Systems](https://liberatedsystems.co.uk), licensed under **GPLv3**.
Original firmware by Mark Qvist / [unsigned.io](https://unsigned.io).
