#!/usr/bin/env python3
"""
Emiscreen - Remote Display via WebRTC

Simple launcher that auto-activates venv and starts the server.
Works cross-platform after installation.

Usage:
    emiscreen                    Start with defaults
    emiscreen --help             Show this help
    emiscreen --source windows-pc
    emiscreen --firetv 192.168.1.100

After installation, 'emiscreen' will be available from any terminal.
"""

import sys
import os
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_PYTHON = os.path.join(SCRIPT_DIR, ".venv", "Scripts", "python.exe") if sys.platform == "win32" else os.path.join(SCRIPT_DIR, ".venv", "bin", "python")

HELP_TEXT = """Emiscreen - Remote Display via WebRTC

Usage: emiscreen [options]

Options:
  --source, -s NAME    Capture source (ubuntu-desktop, windows-pc, nas-omv)
  --firetv, -f IP      FireTV IP for auto-launch
  --resolution, -r RES  Resolution (default: 1920x1080)
  --fps N              Frame rate (default: 30)
  --port, -p N         Server port (default: 8445)
  --verbose, -v        Enable debug logging
  --help               Show this help

Examples:
  emiscreen                           Start with defaults
  emiscreen --source windows-pc      Windows capture
  emiscreen --firetv 192.168.1.100    With FireTV auto-launch

Then open https://localhost:8445 in your browser

For more options: emiscreen --help-all
"""

def ensure_venv():
    """Ensure venv exists and has dependencies."""
    if not os.path.exists(VENV_PYTHON):
        print("First-time setup...", flush=True)
        subprocess.run([sys.executable, "-m", "venv", ".venv"], cwd=SCRIPT_DIR, check=True)
        print("Installing dependencies...", flush=True)
        subprocess.run([VENV_PYTHON, "-m", "pip", "install", "-r", "requirements.txt"], cwd=SCRIPT_DIR, check=True)
        print("Ready!", flush=True)

def main():
    # Show help without needing venv
    if "--help" in sys.argv or "-h" in sys.argv:
        print(HELP_TEXT)
        return

    if not os.path.exists(VENV_PYTHON):
        ensure_venv()

    # Pass all arguments to server
    result = subprocess.run([VENV_PYTHON, "-m", "emiscreen.server"] + sys.argv[1:])
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()