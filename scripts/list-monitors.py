#!/usr/bin/env python3
"""List connected monitors on Windows (ignores DPI scaling)."""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from emiscreen.capture.windows import list_monitors

if __name__ == "__main__":
    print(list_monitors())
    print("\nUsage:")
    print("  emiscreen --source windows-pc --display desktop  # Capture all monitors")
    print("  emiscreen --source windows-pc --display 1        # Capture monitor 1 (primary)")
    print("  emiscreen --source windows-pc --display 2        # Capture monitor 2 (secondary)")
