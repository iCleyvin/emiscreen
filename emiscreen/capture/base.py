"""
Emiscreen Capture Source - Base Class

Abstract base class for all screen capture implementations.
Each platform (Linux, Windows, Virtual) implements this interface.
"""

import asyncio
import logging
import platform
from abc import ABC, abstractmethod
from fractions import Fraction
from typing import Optional

import av
from aiortc.mediastreams import VideoStreamTrack as AiortcVideoTrack, AudioStreamTrack as AiortcAudioTrack

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

    async def change_bitrate(self, new_bitrate: str):
        """Change the video bitrate dynamically by restarting FFmpeg."""
        logger.info(f"Changing bitrate to {new_bitrate}")
        self.config.bitrate = new_bitrate
        await self.stop()
        await self.start()

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


class FFmpegRawVideoTrack(AiortcVideoTrack):
    """
    VideoStreamTrack that reads raw YUV420P frames from an FFmpeg stdout pipe.
    This is cross-platform: FFmpeg handles the OS-specific capture (x11grab,
    gdigrab, etc.) and always outputs raw YUV420P frames that we feed directly
    into aiortc/WebRTC.
    """

    kind = "video"

    def __init__(self, stream: asyncio.StreamReader, width: int, height: int, fps: int):
        super().__init__()
        self._stream = stream
        self._width = width
        self._height = height
        self._fps = fps
        # YUV420P frame size: Y plane (w*h) + U plane (w*h/4) + V plane (w*h/4)
        self._frame_size = width * height * 3 // 2
        self._timestamp = 0
        self._frame_interval = Fraction(1, fps)
        self._pts_step = int(90000 / fps)  # 90kHz clock / fps

    async def recv(self) -> av.VideoFrame:
        """Read next frame from FFmpeg pipe and return as VideoFrame."""
        # Read exact frame size
        data = await self._stream.readexactly(self._frame_size)

        # Build VideoFrame from raw YUV420P
        frame = av.VideoFrame(self._width, self._height, "yuv420p")
        y_size = self._width * self._height
        uv_size = y_size // 4

        frame.planes[0].update(data[:y_size])
        frame.planes[1].update(data[y_size:y_size + uv_size])
        frame.planes[2].update(data[y_size + uv_size:])

        frame.pts = self._timestamp
        frame.time_base = Fraction(1, 90000)
        self._timestamp += self._pts_step

        return frame


class FFmpegRawAudioTrack(AiortcAudioTrack):
    """
    AudioStreamTrack that reads raw PCM s16 frames from an FFmpeg stdout pipe.
    """

    kind = "audio"

    def __init__(self, stream: asyncio.StreamReader, sample_rate: int = 48000, channels: int = 2):
        super().__init__()
        self._stream = stream
        self._sample_rate = sample_rate
        self._channels = channels
        # 20ms of stereo s16 = sample_rate * 0.02 * channels * 2 bytes
        self._frame_samples = int(sample_rate * 0.02)
        self._frame_size = self._frame_samples * channels * 2
        self._timestamp = 0
        self._pts_step = int(48000 * 0.02)  # 960 samples @ 48kHz

    async def recv(self) -> av.AudioFrame:
        """Read next audio frame from FFmpeg pipe."""
        data = await self._stream.readexactly(self._frame_size)

        frame = av.AudioFrame(format="s16", layout="stereo", samples=self._frame_samples)
        frame.sample_rate = self._sample_rate
        frame.planes[0].update(data)

        frame.pts = self._timestamp
        frame.time_base = Fraction(1, self._sample_rate)
        self._timestamp += self._pts_step

        return frame
