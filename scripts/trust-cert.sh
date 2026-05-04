#!/usr/bin/env bash
# Emiscreen - Trust Self-Signed Certificate (Linux)
# Requires sudo to update system CA store.

set -e

CERT_PATH="$(cd "$(dirname "$0")/.." && pwd)/certs/cert.pem"

if [ ! -f "$CERT_PATH" ]; then
    echo "Certificate not found at $CERT_PATH"
    echo "Start Emiscreen once to generate it, then run this script."
    exit 1
fi

echo "Installing Emiscreen certificate to system trust store..."
sudo cp "$CERT_PATH" /usr/local/share/ca-certificates/emiscreen.crt
sudo update-ca-certificates

echo "Certificate trusted. Restart your browser for changes to take effect."
