# DIY RNode on ESP32 + Ebyte E22-900M30S — From Scratch Tutorial

## Hardware

| Component | Model |
|-----------|-------|
| MCU | ESP32-WROOM-32U (30-pin, CH340 USB) |
| Radio | Ebyte E22-900M30S (SX1262, 30 dBm, 900 MHz) |
| PCB | Hydra Designs board (see [meshtastic.pop.pl](https://meshtastic.pop.pl)) |
| Display | SSD1306 OLED (I2C) |

The board is compatible with the Hydra Designs schematic:
https://github.com/Hydra-Designs/project-hydra-meshtastic-pcb

---

## Software Requirements

- **Python 3.13** (or newer)
- **PlatformIO** (VS Code extension or CLI)
- **rnodeconf**: `pip install rns` or `pip install rnodeconf`
- **pyserial**: `pip install pyserial`

---

## Step 1 — Get the RNode CE Firmware

```bash
git clone https://github.com/SP5LOT/RNode_Firmware_CE.git
cd RNode_Firmware_CE
git checkout hydra-e22
```

Or download the ZIP from this branch and extract it.

---

## Step 2 — Add BOARD_HYDRA_E22 Definition (Boards.h)

### 2a — Add the constant to the `#define` list at the top of the file

```c
#define BOARD_HYDRA_E22     0x46  // Hydra Designs DIY PCB: ESP32-WROOM-32U + E22-900M30S
```

### 2b — Add the configuration block (before `#elif BOARD_MODEL == BOARD_XIAO_S3` or similar)

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
          14, // pin_rxen (RXEN,  GPIO14)   <-- COMMA IS MANDATORY! (see note below)
          -1  // pin_tcxo_enable
      }
  };
```

> **CRITICAL — comma after 14:**
> The line `14, // pin_rxen` MUST have a comma. Without it, C++ parses
> `14 -1` as an arithmetic expression `14 - 1 = 13`, which means:
> - RXEN gets GPIO13 instead of GPIO14 (same pin as TXEN!)
> - tcxo_enable gets GPIO0 (the BOOT pin!) instead of -1
>
> Result: the antenna switch doesn't work, the radio can't transmit,
> the blue LED stays on for 15–20 seconds on every TX, then the ESP32 restarts.

---

## Step 3 — Fix TCXO Voltage (Radio.cpp)

Find the `sx126x::enableTCXO()` function. It looks roughly like this:

```c
void sx126x::enableTCXO() {
  if (_tcxo) {
    #if BOARD_MODEL == BOARD_RAK4631 || ...
      uint8_t buf[4] = {MODE_TCXO_3_3V_6X, 0x00, 0x00, 0xFF};
    // ... other boards ...
    #elif BOARD_MODEL == BOARD_E22_ESP32
      uint8_t buf[4] = {MODE_TCXO_1_8V_6X, 0x00, 0x00, 0xFF};
    #else
      uint8_t buf[4] = {0};   // <-- 1.6V -- too low for E22!
    #endif
    executeOpcode(OP_DIO3_TCXO_CTRL_6X, buf, 4);
  }
}
```

Add a case for BOARD_HYDRA_E22 **before** `#else`:

```c
    #elif BOARD_MODEL == BOARD_HYDRA_E22
      uint8_t buf[4] = {MODE_TCXO_1_8V_6X, 0x00, 0x00, 0xFF};
```

> **Why 1.8V:** The TCXO in the E22-900M30S module is powered by the SX1262's DIO3 pin.
> It requires 1.8V. At 1.6V (the default `#else`), the oscillator doesn't start reliably —
> the SX1262 hangs with BUSY=HIGH, every byte written to the TX buffer waits 100ms for
> the timeout, ~150 bytes × 100ms = 15 seconds of hang on every transmission.

---

## Step 4 — Add `!_preinit_done` Guards (Radio.cpp)

Without this, the firmware calls SPI operations before SPI is initialized.
Each such operation waits 100ms for a timeout — causing `rnsd` (which has a 250ms window)
to miss all the parameter echoes and reject the connection with "4 mismatches".

In each of the following functions, add the guard **after** saving the value,
**before** the SPI call:

```c
void sx126x::setFrequency(uint32_t frequency) {
    _frequency = frequency;
    if (!_preinit_done) return;  // <-- add this
    // ... rest ...
}

void sx126x::setTxPower(int level, int outputPin) {
    if (level > 22) { level = 22; }
    else if (level < -9) { level = -9; }
    _txp = level;
    if (!_preinit_done) return;  // <-- add this
    // ... rest ...
}

void sx126x::setSignalBandwidth(long sbw) {
    // ... _bw calculation ...
    _bw = bw_val;
    if (!_preinit_done) return;  // <-- add after saving _bw
    setModulationParams(...);
}

void sx126x::setSpreadingFactor(int sf) {
    _sf = sf;
    if (!_preinit_done) return;  // <-- add this
    setModulationParams(...);
}

void sx126x::setCodingRate4(int denominator) {
    // ... _cr calculation ...
    _cr = cr;
    if (!_preinit_done) return;  // <-- add after saving _cr
    setModulationParams(...);
}
```

---

## Step 5 — Pre-echo Radio Parameters (main.cpp)

`rnsd` sends parameters and expects echoes within 250ms. Without this change,
the firmware echoes parameters only after SPI operations (too late).

Find the `CMD_RADIO_STATE` handler with value `0x01`:

```c
// BEFORE (slow — echo arrives after SPI):
} else if (sbyte == 0x01) {
    startRadio(selected_radio);
}

// AFTER (fast — echo sent immediately, SPI runs after):
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

## Step 6 — Increase MAX_CYCLES (main.cpp)

```c
// BEFORE:
#define MAX_CYCLES 20

// AFTER:
#define MAX_CYCLES 128
```

> `rnsd` sends ~54+ bytes during `initRadio`. With `MAX_CYCLES=20`, the firmware
> processes only 20 bytes per main loop iteration — `CMD_RADIO_STATE` arrives too late.
> With 128, everything fits in one pass.

---

## Step 7 — Fix SSD1306 Constructor (Display.h)

Find (around line 170):

```c
// BEFORE:
Adafruit_SSD1306 display(DISP_W, DISP_H, &Wire, DISP_RST);

// AFTER:
Adafruit_SSD1306 display(DISP_W, DISP_H, &Wire, DISP_RST, 400000UL, 400000UL);
```

> Keeps I2C speed at 400 kHz after every display transaction.
> Without this, the Adafruit library resets the clock to 100 kHz.

---

## Step 8 — Configure PlatformIO (platformio.ini)

Add the new environment:

```ini
[env:hydra_e22]
platform = espressif32
board = esp32dev
framework = arduino
board_build.partitions = no_ota.csv
board_build.filesystem = spiffs
board_build.f_cpu = 240000000L
board_build.f_flash = 80000000L
board_build.flash_mode = dio
upload_speed = 921600
monitor_speed = 115200
lib_deps =
  adafruit/Adafruit GFX Library@^1.11.9
  adafruit/Adafruit SSD1306@^2.5.9
  rweather/Crypto@^0.4.0
build_unflags =
  -Werror=reorder
build_flags =
  -D BOARD_MODEL=0x46
  -Wno-unused-variable
  -Wno-maybe-uninitialized
  -Wno-reorder
```

---

## Step 9 — Build and Flash

```bash
# Build
pio run -e hydra_e22

# Flash (change COM11 to your actual port)
pio run -e hydra_e22 -t upload --upload-port COM11
```

Find your port:
- Windows: `powershell -Command "[System.IO.Ports.SerialPort]::GetPortNames()"`
- Linux/Mac: `ls /dev/tty*`

---

## Step 10 — Provision with rnodeconf

After flashing, the firmware has no EEPROM data — `rnsd` will reject the device.

```bash
# Check state before
rnodeconf COM11 --info

# Bootstrap and provision in one command
rnodeconf COM11 -r --product f0 --model fe --hwrev 1

# Verify — should show HMBRW, model FE, hwrev 1
rnodeconf COM11 --info
```

Parameter meanings:
- `--product f0` = HMBRW (homebrew/custom)
- `--model fe` = custom model
- `--hwrev 1` = hardware revision 1

---

## Step 11 — Configure Reticulum

File: `%USERPROFILE%\.reticulum\config` (Windows) or `~/.reticulum/config` (Linux/Mac)

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

Radio parameters (868 MHz, Europe):
- `frequency`: 869185000 Hz
- `bandwidth`: 125000 Hz
- `txpower`: 17 dBm (max 22 = ~30 dBm at antenna via E22 PA; check local regulations)
- `spreadingfactor`: 8
- `codingrate`: 8

---

## Step 12 — Run and Test

```bash
rnsd -v
```

Expected output:
```
RNodeInterface[LORA V2] is configured and powered up
```

After connecting:
- Blue LED lights for ~0.5s when transmitting a packet
- Quick flash on receive
- RF signal visible on SDR waterfall on announce

---

## Pinout Summary

| Signal | GPIO | Notes |
|--------|------|-------|
| NSS/CS | 18 | SPI chip select |
| SCK | 5 | SPI clock |
| MOSI | 27 | SPI data out |
| MISO | 19 | SPI data in |
| BUSY | 32 | SX1262 busy flag |
| DIO1 | 33 | SX1262 interrupt |
| RST | 23 | SX1262 reset |
| TXEN | 13 | E22 TX enable (active HIGH) |
| RXEN | 14 | E22 RX enable (active HIGH) |
| I2C SDA | 21 | OLED display |
| I2C SCL | 22 | OLED display |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| rnsd: "4 mismatches" | Parameter echoes delayed (>250ms) | Steps 4, 5, 6 |
| Blue LED 15–20s, ESP32 restarts | Wrong TCXO voltage (1.6V) or missing comma in pinout | Steps 2 (comma!), 3 |
| No RF signal on SDR | Same as above (antenna not switching to TX) | Same as above |
| Radio not responding at all | Wrong SPI pins | Check pinout |
| rnodeconf: "device not identified" | Missing EEPROM provisioning | Step 10 |
| Display slows after first refresh | Missing clkAfter in SSD1306 constructor | Step 7 |

---

## After a Firmware Update (new RNode CE version)

1. Re-apply changes from Steps 2–7
2. `pio run -e hydra_e22`
3. `pio run -e hydra_e22 -t upload`
4. EEPROM stays valid — **no need to re-provision**
