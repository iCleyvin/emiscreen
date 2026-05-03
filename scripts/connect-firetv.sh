#!/bin/bash
# Emiscreen - FireTV ADB Connection Script
# Usage: ./connect-firetv.sh <FIRETV_IP> [PORT]

set -e

FIRETV_IP="${1:?Error: FireTV IP address required. Usage: $0 <IP> [PORT]}"
PORT="${2:-5555}"
ADB="${ADB:-adb}"
SERIAL="${FIRETV_IP}:${PORT}"

echo "============================================"
echo "  Emiscreen - FireTV ADB Connection Setup"
echo "============================================"
echo ""
echo "Target: ${SERIAL}"
echo ""

# Check if adb is available
if ! command -v "${ADB}" &> /dev/null; then
    echo "ERROR: adb not found. Install it:"
    echo "  Ubuntu: sudo apt install adb"
    echo "  Or download: https://developer.android.com/studio/releases/platform-tools"
    exit 1
fi

echo "[1/5] Checking adb version..."
"${ADB}" version | head -1
echo ""

echo "[2/5] Connecting to FireTV..."
"${ADB}" connect "${SERIAL}"
sleep 1

echo "[3/5] Verifying connection..."
if "${ADB}" -s "${SERIAL}" shell echo "connected" &> /dev/null; then
    echo "  Connection verified!"
else
    echo "  ERROR: Connection failed."
    echo ""
    echo "  Troubleshooting:"
    echo "  1. On FireTV: Settings > My Fire TV > Developer Options > ADB Debugging = ON"
    echo "  2. Make sure FireTV and this machine are on the same network"
    echo "  3. Check FireTV IP: Settings > My Fire TV > About > Network"
    echo "  4. First time? Check FireTV screen for ADB authorization prompt"
    exit 1
fi

echo ""
echo "[4/5] Configuring FireTV for remote display..."

# Keep screen awake
"${ADB}" -s "${SERIAL}" shell settings put global stay_on_while_plugged_in 7
echo "  - Screen stay-awake: enabled"

# Set screen timeout to 30 minutes
"${ADB}" -s "${SERIAL}" shell settings put system screen_off_timeout 1800000
echo "  - Screen timeout: 30 minutes"

# Disable screensaver if possible
"${ADB}" -s "${SERIAL}" shell settings put secure screensaver_enabled 0 2>/dev/null || true
echo "  - Screensaver: disabled"

echo ""
echo "[5/5] Device info:"
"${ADB}" -s "${SERIAL}" shell getprop ro.build.display.id 2>/dev/null || echo "  (unable to read)"
"${ADB}" -s "${SERIAL}" shell getprop ro.product.model 2>/dev/null || echo "  (unable to read)"

echo ""
echo "============================================"
echo "  FireTV connected and configured!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Start Emiscreen server: ./scripts/start.sh"
echo "  2. The server will auto-launch the browser on FireTV"
echo ""
echo "Manual controls:"
echo "  adb -s ${SERIAL} shell input keyevent KEYCODE_HOME"
echo "  adb -s ${SERIAL} shell input keyevent KEYCODE_BACK"
echo "  adb -s ${SERIAL} shell input keyevent KEYCODE_POWER"
echo ""
