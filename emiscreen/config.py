"""
Emiscreen - Centralized Configuration

All configuration for the Emiscreen server, capture sources,
relay settings, and FireTV control.
"""

import os
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class CaptureConfig:
    """Configuration for a capture source."""
    type: str  # "linux", "windows", "virtual"
    display: str = ":0"
    resolution: str = "1280x720"
    fps: int = 24
    codec: str = "h264"  # "h264" or "vp8"
    bitrate: str = "4M"
    virtual: bool = False
    host: Optional[str] = None  # For remote Windows capture
    low_latency: bool = True  # Optimize for minimal latency


@dataclass
class ServerConfig:
    """Configuration for the Emiscreen server."""
    host: str = "0.0.0.0"
    port: int = 8445
    ssl_cert: str = "certs/cert.pem"
    ssl_key: str = "certs/key.pem"
    ws_input_port: int = 8444
    token: Optional[str] = None  # Simple auth token for LAN


@dataclass
class ADBConfig:
    """Configuration for FireTV ADB control."""
    enabled: bool = True
    host: Optional[str] = None
    port: int = 5555
    auto_launch: bool = True
    stay_awake: bool = True
    screen_timeout: int = 1800000  # 30 minutes in ms


@dataclass
class RelayConfig:
    """Configuration for input relay."""
    enabled: bool = True
    xdotool_path: str = "xdotool"
    adb_path: str = "adb"
    input_buffer_size: int = 100  # Max buffered input events
    dpad_step: int = 20  # Pixels per D-Pad press


# Available capture sources
SOURCES: dict[str, CaptureConfig] = {
    "ubuntu-desktop": CaptureConfig(
        type="linux",
        display=":0",
        resolution="1280x720",
        fps=24,
        codec="h264",
    ),
    "windows-pc": CaptureConfig(
        type="windows",
        resolution="1280x720",
        fps=24,
        codec="h264",
    ),
    "nas-omv": CaptureConfig(
        type="virtual",
        display=":99",
        resolution="1280x720",
        fps=24,
        codec="h264",
        virtual=True,
    ),
}

# Quality presets (resolution + fps + tuning)
QUALITY_PRESETS: dict[str, tuple[str, int]] = {
    "fast": ("1280x720", 24),       # WiFi / low-latency, 16:9
    "balanced": ("1920x1080", 24),  # 1080p 16:9, sharp and smooth
    "quality": ("1920x1080", 30),   # Best 1080p, more bandwidth
    "native": ("auto", 20),         # Native monitor res (may show black bars)
}

# Server defaults
SERVER = ServerConfig()

# ADB defaults
ADB = ADBConfig()

# Relay defaults
RELAY = RelayConfig()


def get_source(name: str) -> CaptureConfig:
    """Get capture source config by name."""
    if name not in SOURCES:
        raise ValueError(f"Unknown source '{name}'. Available: {list(SOURCES.keys())}")
    return SOURCES[name]


def load_from_env():
    """Override config from environment variables."""
    if os.environ.get("EMISCREEN_HOST"):
        SERVER.host = os.environ["EMISCREEN_HOST"]
    if os.environ.get("EMISCREEN_PORT"):
        SERVER.port = int(os.environ["EMISCREEN_PORT"])
    if os.environ.get("EMISCREEN_TOKEN"):
        SERVER.token = os.environ["EMISCREEN_TOKEN"]
    if os.environ.get("EMISCREEN_FIRETV_IP"):
        ADB.host = os.environ["EMISCREEN_FIRETV_IP"]
    if os.environ.get("EMISCREEN_SOURCE"):
        # Override default source resolution from env
        src_name = os.environ["EMISCREEN_SOURCE"]
        if src_name in SOURCES:
            if os.environ.get("EMISCREEN_RESOLUTION"):
                SOURCES[src_name].resolution = os.environ["EMISCREEN_RESOLUTION"]
            if os.environ.get("EMISCREEN_FPS"):
                SOURCES[src_name].fps = int(os.environ["EMISCREEN_FPS"])


def get_native_resolution() -> tuple[int, int]:
    """Detect the REAL native resolution of the primary monitor (ignores DPI scaling)."""
    import platform
    import subprocess

    system = platform.system()

    if system == "Windows":
        try:
            import ctypes
            from ctypes import wintypes

            user32 = ctypes.windll.user32

            class DEVMODE(ctypes.Structure):
                _fields_ = [
                    ("dmDeviceName", ctypes.c_wchar * 32),
                    ("dmSpecVersion", wintypes.WORD),
                    ("dmDriverVersion", wintypes.WORD),
                    ("dmSize", wintypes.WORD),
                    ("dmDriverExtra", wintypes.WORD),
                    ("dmFields", wintypes.DWORD),
                    ("dmOrientation", ctypes.c_short),
                    ("dmPaperSize", ctypes.c_short),
                    ("dmPaperLength", ctypes.c_short),
                    ("dmPaperWidth", ctypes.c_short),
                    ("dmScale", ctypes.c_short),
                    ("dmCopies", ctypes.c_short),
                    ("dmDefaultSource", ctypes.c_short),
                    ("dmPrintQuality", ctypes.c_short),
                    ("dmColor", ctypes.c_short),
                    ("dmDuplex", ctypes.c_short),
                    ("dmYResolution", ctypes.c_short),
                    ("dmTTOption", ctypes.c_short),
                    ("dmCollate", ctypes.c_short),
                    ("dmFormName", ctypes.c_wchar * 32),
                    ("dmLogPixels", wintypes.WORD),
                    ("dmBitsPerPel", wintypes.DWORD),
                    ("dmPelsWidth", wintypes.DWORD),
                    ("dmPelsHeight", wintypes.DWORD),
                    ("dmDisplayFlags", wintypes.DWORD),
                    ("dmDisplayFrequency", wintypes.DWORD),
                    ("dmICMMethod", wintypes.DWORD),
                    ("dmICMIntent", wintypes.DWORD),
                    ("dmMediaType", wintypes.DWORD),
                    ("dmDitherType", wintypes.DWORD),
                    ("dmReserved1", wintypes.DWORD),
                    ("dmReserved2", wintypes.DWORD),
                    ("dmPanningWidth", wintypes.DWORD),
                    ("dmPanningHeight", wintypes.DWORD),
                ]

            dm = DEVMODE()
            dm.dmSize = ctypes.sizeof(DEVMODE)

            if user32.EnumDisplaySettingsW(None, ctypes.c_uint32(0xFFFFFFFF), ctypes.byref(dm)):
                return int(dm.dmPelsWidth), int(dm.dmPelsHeight)
        except Exception:
            pass

    elif system == "Linux":
        # Try xrandr first
        try:
            result = subprocess.run(
                ["xrandr"], capture_output=True, text=True, timeout=5
            )
            for line in result.stdout.splitlines():
                if "*" in line:
                    # Format: "   2560x1440     59.95*+"
                    parts = line.strip().split()
                    if parts:
                        res = parts[0]
                        if "x" in res:
                            w, h = res.split("x")
                            return int(w), int(h)
        except Exception:
            pass

        # Fallback to xdpyinfo
        try:
            result = subprocess.run(
                ["xdpyinfo"], capture_output=True, text=True, timeout=5
            )
            for line in result.stdout.splitlines():
                if "dimensions:" in line:
                    # Format: "  dimensions:    2560x1440 pixels (677x381 millimeters)"
                    parts = line.split()
                    for part in parts:
                        if "x" in part and part[0].isdigit():
                            w, h = part.split("x")
                            return int(w), int(h)
        except Exception:
            pass

    return 1920, 1080
