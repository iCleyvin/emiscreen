"""
Emiscreen Linux Capture Module

Captures the Linux desktop using FFmpeg x11grab.
Supports both physical displays and virtual Xvfb displays.
"""

import asyncio
import logging
import os
import subprocess
from fractions import Fraction
from typing import Optional

import av
from aiortc import VideoStreamTrack
from aiortc.mediastreams import VideoStreamTrack as AiortcVideoTrack

from emiscreen.capture.base import CaptureSource
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


class LinuxCapture(CaptureSource):
    """Captures Linux desktop via FFmpeg x11grab."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._width, self._height = self._parse_resolution()
        self._fps = config.fps
        self._display = config.display

    def _parse_resolution(self) -> tuple[int, int]:
        """Parse resolution string into width/height tuple."""
        parts = self.config.resolution.split("x")
        return int(parts[0]), int(parts[1])

    async def start(self):
        """Start FFmpeg x11grab capture."""
        await super().start()

        # Build FFmpeg command
        cmd = [
            "ffmpeg",
            "-f", "x11grab",
            "-framerate", str(self._fps),
            "-video_size", f"{self._width}x{self._height}",
            "-i", self._display,
            "-vf", f"scale={self._width}:{self._height}",
            "-pix_fmt", "yuv420p",
            "-f", "rawvideo",
            "-",
        ]

        logger.info(f"Starting FFmpeg capture: {' '.join(cmd)}")

        self._ffmpeg_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Create video track
        self._video_track = FFmpegVideoTrack(
            self._ffmpeg_process.stdout,
            self._width,
            self._height,
            self._fps,
        )

        # Log FFmpeg stderr in background
        asyncio.create_task(self._log_ffmpeg_stderr())

        logger.info(f"Linux capture started: {self._width}x{self._height} @ {self._fps}fps")

    async def stop(self):
        """Stop FFmpeg capture."""
        await super().stop()

        if self._ffmpeg_process:
            try:
                self._ffmpeg_process.terminate()
                await asyncio.wait_for(self._ffmpeg_process.wait(), timeout=5.0)
            except (asyncio.TimeoutError, ProcessLookupError):
                self._ffmpeg_process.kill()
                await self._ffmpeg_process.wait()
            logger.info("FFmpeg capture stopped")

    async def _log_ffmpeg_stderr(self):
        """Log FFmpeg stderr output."""
        if not self._ffmpeg_process or not self._ffmpeg_process.stderr:
            return
        try:
            while self._running:
                line = await self._ffmpeg_process.stderr.readline()
                if not line:
                    break
                line_str = line.decode().strip()
                if line_str:
                    logger.debug(f"FFmpeg: {line_str}")
        except Exception as e:
            logger.debug(f"FFmpeg stderr reader stopped: {e}")


class VirtualCapture(LinuxCapture):
    """Captures a virtual Xvfb display for headless environments (NAS)."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._xvfb_process = None

    async def start(self):
        """Start Xvfb virtual display, then capture it."""
        # Start Xvfb if not already running
        await self._ensure_xvfb()
        await super().start()

    async def stop(self):
        """Stop capture and Xvfb."""
        await super().stop()
        if self._xvfb_process:
            try:
                self._xvfb_process.terminate()
                await asyncio.wait_for(self._xvfb_process.wait(), timeout=3.0)
            except (asyncio.TimeoutError, ProcessLookupError):
                self._xvfb_process.kill()
            logger.info("Xvfb stopped")

    async def _ensure_xvfb(self):
        """Ensure Xvfb is running on the configured display."""
        display_num = self._display.lstrip(":")

        # Check if display is already available
        try:
            proc = await asyncio.create_subprocess_exec(
                "xdpyinfo", "-display", self._display,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.wait()
            if proc.returncode == 0:
                logger.info(f"Display {self._display} already exists, skipping Xvfb")
                return
        except FileNotFoundError:
            pass  # xdpyinfo not installed, try to start Xvfb anyway

        # Start Xvfb
        cmd = [
            "Xvfb",
            self._display,
            "-screen", "0", f"{self._width}x{self._height}x24",
            "-ac",
            "-nolisten", "tcp",
        ]
        logger.info(f"Starting Xvfb: {' '.join(cmd)}")

        self._xvfb_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Wait for Xvfb to be ready
        await asyncio.sleep(1)
        logger.info(f"Xvfb started on {self._display}")


class FFmpegVideoTrack(AiortcVideoTrack):
    """
    VideoStreamTrack that reads raw video frames from FFmpeg stdout pipe.
    Converts raw YUV420P frames to aiortc VideoFrame objects.
    """

    kind = "video"

    def __init__(self, stream: asyncio.StreamReader, width: int, height: int, fps: int):
        super().__init__()
        self._stream = stream
        self._width = width
        self._height = height
        self._fps = fps
        self._frame_size = width * height * 3 // 2  # YUV420P
        self._timestamp = 0
        self._frame_interval = 1 / fps

    async def recv(self) -> av.VideoFrame:
        """Read next frame from FFmpeg pipe and return as VideoFrame."""
        # Read raw frame data
        data = await self._stream.readexactly(self._frame_size)

        # Create VideoFrame from raw YUV420P data
        frame = av.VideoFrame(self._width, self._height, "yuv420p")
        frame.planes[0].update(data[:self._width * self._height])
        frame.planes[1].update(
            data[self._width * self._height:self._width * self._height * 5 // 4]
        )
        frame.planes[2].update(
            data[self._width * self._height * 5 // 4:]
        )

        # Set timestamp
        frame.pts = int(self._timestamp * 90000)  # 90kHz clock
        frame.time_base = Fraction(1, 90000)

        self._timestamp += self._frame_interval

        return frame
