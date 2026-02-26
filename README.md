# RNode Firmware — Community Edition

Community-maintained fork of the open firmware powering RNode devices. Created to continue expanding hardware support after the [upstream repository](https://github.com/markqvist/RNode_Firmware) stopped accepting new hardware PRs.

An RNode is an open, unrestricted digital radio transceiver — especially well suited for use with [Reticulum](https://reticulum.network). It can be built from cheap, readily available hardware and used for encrypted long-range communications, LoRa TNC, packet sniffing, and more.

> **Hydra E22 (ESP32 + SX1262) support** → see branch [`hydra-e22`](../../tree/hydra-e22)

---

## Supported Hardware

### Products
| Name | Transceiver | MCU |
| :--- | :---: | :---: |
| [Handheld v2.x RNode](https://unsigned.io/shop/product/handheld-rnode) | SX1276 | ESP32 |
| [openCom XL](https://store.liberatedsystems.co.uk/product/opencom-xl/) | SX1262 & SX1280 | nRF52 |

### Homebrew / DIY
| Board | Transceiver | MCU |
| :--- | :---: | :---: |
| RAK4631 | SX1262 | nRF52 |
| LilyGO T-BEAM v1.1 | SX1276/8 or SX1262 | ESP32 |
| LilyGO T-Beam Supreme | SX1262 | ESP32-S3 |
| LilyGO LoRa32 v2.1 | SX1276/8 | ESP32 |
| Heltec LoRa32 v3 | SX1262 | ESP32 |
| LilyGo T3S3 v1.0 | SX1262/76/80 | ESP32-S3 |
| LilyGo T-Echo | SX1262 | nRF52 |
| Heltec T114 | SX1262 | nRF52 |
| **Hydra E22 (ESP32 + E22-900M30S)** | **SX1262** | **ESP32** |
| Generic ESP32 Feather boards | Any supported | ESP32 |

## Getting Started

```bash
pip install rns --upgrade
rnodeconf --autoinstall
```

Or use [Liam Cottle's Web Flasher](https://liamcottle.github.io/rnode-flasher/) for a browser-based install.

## Contributing

See [CONTRIBUTING.md](Documentation/CONTRIBUTING.md). New board definitions welcome.

## License

RNode Firmware CE © Jacob Eva / [Liberated Embedded Systems](https://liberatedsystems.co.uk) — **GPLv3**.
Original firmware © Mark Qvist / [unsigned.io](https://unsigned.io).
