#!/usr/bin/env python3
"""
Emiscreen - Remote Display via WebRTC

Simple launcher that auto-activates venv and starts the server.
Works cross-platform after installation.

Usage:
    emiscreen                    Start with defaults
    emiscreen --source windows-pc
    emiscreen --firetv 192.168.1.100

After installation, 'emiscreen' will be available from any terminal.
"""

import sys
import os
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_PYTHON = os.path.join(SCRIPT_DIR, ".venv", "Scripts", "python.exe") if sys.platform == "win32" else os.path.join(SCRIPT_DIR, ".venv", "bin", "python")

def ensure_venv():
    """Ensure venv exists and has dependencies."""
    if not os.path.exists(VENV_PYTHON):
        print("First-time setup...", flush=True)
        subprocess.run([sys.executable, "-m", "venv", ".venv"], cwd=SCRIPT_DIR, check=True)
        print("Installing dependencies...", flush=True)
        subprocess.run([VENV_PYTHON, "-m", "pip", "install", "-r", "requirements.txt"], cwd=SCRIPT_DIR, check=True)
        print("Ready!", flush=True)

def main():
    if not os.path.exists(VENV_PYTHON):
        ensure_venv()

    # Pass all arguments to server
    result = subprocess.run([VENV_PYTHON, "-m", "emiscreen.server"] + sys.argv[1:])
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()