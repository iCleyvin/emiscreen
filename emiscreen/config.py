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
    resolution: str = "1920x1080"
    fps: int = 30
    codec: str = "h264"  # "h264" or "vp8"
    bitrate: str = "4M"
    virtual: bool = False
    host: Optional[str] = None  # For remote Windows capture


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
        resolution="1920x1080",
        fps=30,
        codec="h264",
    ),
    "windows-pc": CaptureConfig(
        type="windows",
        resolution="1920x1080",
        fps=30,
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
