@echo off
REM Flash RNode Firmware CE - Hydra E22 (ESP32 + SX1262)
REM Zmien COM11 na swoj port / Change COM11 to your port

set PORT=COM11
set BAUD=921600

echo Flashing RNode Firmware CE - Hydra E22...
python -m esptool --chip esp32 --port %PORT% --baud %BAUD% --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 80m --flash_size 4MB 0x1000 bootloader.bin 0x8000 partitions.bin 0xe000 boot_app0.bin 0x10000 firmware.bin

echo.
echo Done! Now provision with:
echo   rnodeconf %PORT% -r
echo   rnodeconf %PORT% --product f0 --model fe --hwrev 1
pause
