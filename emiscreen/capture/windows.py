"""
Emiscreen Windows Capture Module

Captures the Windows desktop using FFmpeg gdigrab.
"""

import asyncio
import logging
import platform
from typing import Optional

from aiortc.mediastreams import VideoStreamTrack as AiortcVideoTrack

from emiscreen.capture.base import CaptureSource
from emiscreen.capture.linux import FFmpegVideoTrack
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


class WindowsCapture(CaptureSource):
    """Captures Windows desktop via FFmpeg gdigrab."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._width, self._height = self._parse_resolution()
        self._fps = config.fps

    def _parse_resolution(self) -> tuple[int, int]:
        """Parse resolution string into width/height tuple."""
        parts = self.config.resolution.split("x")
        return int(parts[0]), int(parts[1])

    async def start(self):
        """Start FFmpeg gdigrab capture."""
        await super().start()

        # Build FFmpeg command for Windows
        cmd = [
            "ffmpeg",
            "-f", "gdigrab",
            "-framerate", str(self._fps),
            "-i", "desktop",
            "-vf", f"scale={self._width}:{self._height}",
            "-pix_fmt", "yuv420p",
            "-f", "rawvideo",
            "-",
        ]

        logger.info(f"Starting FFmpeg gdigrab: {' '.join(cmd)}")

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

        logger.info(f"Windows capture started: {self._width}x{self._height} @ {self._fps}fps")

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
                line_str = line.decode("utf-8", errors="replace").strip()
                if line_str:
                    logger.debug(f"FFmpeg: {line_str}")
        except Exception as e:
            logger.debug(f"FFmpeg stderr reader stopped: {e}")
