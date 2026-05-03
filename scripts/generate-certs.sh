#!/usr/bin/env bash
# Emiscreen - Generate self-signed SSL certificates for local HTTPS
# WebRTC requires a secure context (HTTPS or localhost)

set -e

CERT_DIR="$(cd "$(dirname "$0")/.." && pwd)/certs"
mkdir -p "${CERT_DIR}"

echo "Generating SSL certificates for Emiscreen..."
echo "Certificate directory: ${CERT_DIR}"
echo ""

# Generate private key
openssl genrsa -out "${CERT_DIR}/key.pem" 4096 2>/dev/null

# Generate self-signed certificate (valid for 10 years)
openssl req -new -x509 -key "${CERT_DIR}/key.pem" \
    -out "${CERT_DIR}/cert.pem" \
    -days 3650 \
    -subj "/CN=emiscreen.local/O=Emiscreen/C=US" \
    -addext "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1" \
    2>/dev/null

echo "Certificates generated:"
echo "  ${CERT_DIR}/cert.pem"
echo "  ${CERT_DIR}/key.pem"
echo ""
echo "NOTE: Browser will show a security warning for self-signed certs."
echo "      Click 'Advanced' > 'Proceed' on the FireTV browser."
echo ""
echo "To trust this certificate system-wide (optional):"
echo "  sudo cp ${CERT_DIR}/cert.pem /usr/local/share/ca-certificates/emiscreen.crt"
echo "  sudo update-ca-certificates"
