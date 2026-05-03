"""
Emiscreen Capture Source - Base Class

Abstract base class for all screen capture implementations.
Each platform (Linux, Windows, Virtual) implements this interface.
"""

import asyncio
import logging
import platform
from abc import ABC, abstractmethod
from typing import Optional

from aiortc.mediastreams import VideoStreamTrack as AiortcVideoTrack

from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


class CaptureSource(ABC):
    """Abstract base class for screen capture sources."""

    def __init__(self, config: CaptureConfig):
        self.config = config
        self._running = False
        self._video_track: Optional[AiortcVideoTrack] = None
        self._ffmpeg_process = None

    @property
    def video_track(self) -> AiortcVideoTrack:
        """Return the video track for WebRTC."""
        if self._video_track is None:
            raise RuntimeError("Capture not started. Call start() first.")
        return self._video_track

    @abstractmethod
    async def start(self):
        """Start the capture process."""
        self._running = True

    @abstractmethod
    async def stop(self):
        """Stop the capture process."""
        self._running = False

    @classmethod
    def create(cls, config: CaptureConfig) -> "CaptureSource":
        """Factory method to create the appropriate capture source."""
        system = platform.system()

        if config.type == "linux":
            from emiscreen.capture.linux import LinuxCapture
            return LinuxCapture(config)
        elif config.type == "windows":
            from emiscreen.capture.windows import WindowsCapture
            return WindowsCapture(config)
        elif config.type == "virtual":
            from emiscreen.capture.linux import VirtualCapture
            return VirtualCapture(config)
        else:
            # Auto-detect based on OS
            if system == "Linux":
                from emiscreen.capture.linux import LinuxCapture
                return LinuxCapture(config)
            elif system == "Windows":
                from emiscreen.capture.windows import WindowsCapture
                return WindowsCapture(config)
            else:
                raise RuntimeError(f"Unsupported platform: {system}")
