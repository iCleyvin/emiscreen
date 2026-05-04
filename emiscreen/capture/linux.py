"""
Emiscreen Linux Capture Module

Captures the Linux desktop using FFmpeg x11grab.
Supports both physical displays and virtual Xvfb displays.

Optimizations:
- No downscaling if target resolution matches native display resolution
- Lanczos scaling for better sharpness when downscaling is needed
"""

import asyncio
import logging
import os
import subprocess
from typing import Optional

from emiscreen.capture.base import CaptureSource, FFmpegRawVideoTrack
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


def _get_x11_resolution(display: str = ":0") -> tuple[int, int]:
    """Get resolution of an X11 display via xrandr or xdpyinfo."""
    # Try xrandr first
    try:
        result = subprocess.run(
            ["xrandr", "--display", display],
            capture_output=True, text=True, timeout=5,
        )
        for line in result.stdout.splitlines():
            if "*" in line:
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
            ["xdpyinfo", "-display", display],
            capture_output=True, text=True, timeout=5,
        )
        for line in result.stdout.splitlines():
            if "dimensions:" in line:
                parts = line.split()
                for part in parts:
                    if "x" in part and part[0].isdigit():
                        w, h = part.split("x")
                        return int(w), int(h)
    except Exception:
        pass

    return 1920, 1080


class LinuxCapture(CaptureSource):
    """Captures Linux desktop via FFmpeg x11grab."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._width, self._height = self._parse_resolution()
        self._fps = config.fps
        self._display = config.display
        self._native_w, self._native_h = _get_x11_resolution(self._display)

    def _parse_resolution(self) -> tuple[int, int]:
        """Parse resolution string into width/height tuple."""
        parts = self.config.resolution.split("x")
        return int(parts[0]), int(parts[1])

    async def start(self):
        """Start FFmpeg x11grab capture to raw YUV420P."""
        await super().start()

        target_w, target_h = self._width, self._height
        native_w, native_h = self._native_w, self._native_h

        if target_w == native_w and target_h == native_h:
            vf = "format=yuv420p"
            logger.info(f"Native capture: {native_w}x{native_h} (no downscaling)")
        else:
            vf = f"scale={target_w}:{target_h}:flags=lanczos,format=yuv420p"
            logger.info(f"Downscaling: {native_w}x{native_h} → {target_w}x{target_h} (lanczos)")

        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel", "error",
            "-f", "x11grab",
            "-framerate", str(self._fps),
            "-video_size", f"{native_w}x{native_h}",
            "-i", self._display,
            "-vf", vf,
            "-pix_fmt", "yuv420p",
            "-f", "rawvideo",
            "-threads", "2",
            "-",
        ]

        logger.info(f"Starting Linux capture: {' '.join(cmd)}")

        self._ffmpeg_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        self._video_track = FFmpegRawVideoTrack(
            self._ffmpeg_process.stdout,
            target_w,
            target_h,
            self._fps,
        )

        asyncio.create_task(self._log_ffmpeg_stderr())
        logger.info(f"Linux capture started: {target_w}x{target_h} @ {self._fps}fps")

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

        await asyncio.sleep(1)
        logger.info(f"Xvfb started on {self._display}")
