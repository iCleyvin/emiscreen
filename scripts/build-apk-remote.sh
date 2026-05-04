#!/usr/bin/env bash
# Emiscreen - Build Fire TV APK remotely on cleyvinserv
# Usage: ./scripts/build-apk-remote.sh
# Builds the debug APK on the server and downloads it to ./emiscreen-firetv.apk

set -e

SERVER="cleyvinserv"
REMOTE_PATH="/mnt/datos/dev/emiscreen"
OUTPUT_PATH="./emiscreen-firetv.apk"

while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER="$2"; shift 2 ;;
        --path) REMOTE_PATH="$2"; shift 2 ;;
        --output) OUTPUT_PATH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== Emiscreen Fire TV APK Build ==="
echo "Server: ${SERVER}"
echo "Output: ${OUTPUT_PATH}"
echo ""

# Ensure code is synced first
echo "[1/3] Syncing code..."
"$(dirname "$0")/sync-to-server.sh" --server "${SERVER}" --path "${REMOTE_PATH}" --no-tests

# Build APK on server
echo ""
echo "[2/3] Building APK on server..."
echo "  This may take 2-5 minutes on first run..."
ssh "${SERVER}" "cd ${REMOTE_PATH}/firetv-app && if [ -x ./gradlew ]; then ./gradlew assembleDebug; else gradle assembleDebug; fi"

# Download APK
echo ""
echo "[3/3] Downloading APK..."
scp "${SERVER}:${REMOTE_PATH}/firetv-app/app/build/outputs/apk/debug/app-debug.apk" "${OUTPUT_PATH}"

echo ""
echo "============================================"
echo "  APK ready!"
echo "============================================"
echo ""
echo "Location: ${OUTPUT_PATH}"
echo ""
echo "Install on Fire TV:"
echo "  adb connect <FIRETV_IP>:5555"
echo "  adb install ${OUTPUT_PATH}"
echo ""
echo "Or run directly:"
echo "  adb connect <FIRETV_IP>:5555 && adb install ${OUTPUT_PATH} && adb shell am start -n com.icleyvin.emiscreen/.MainActivity"
