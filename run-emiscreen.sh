#!/bin/bash
# Emiscreen - Simple CLI launcher for Unix-like systems
# After installation, run 'emiscreen' from anywhere to start the server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/.venv/bin/python" ]; then
    exec "${SCRIPT_DIR}/.venv/bin/python" "${SCRIPT_DIR}/emiscreen.py" "$@"
elif command -v python3 &> /dev/null; then
    exec python3 "${SCRIPT_DIR}/emiscreen.py" "$@"
else
    echo "Error: Python not found"
    exit 1
fi