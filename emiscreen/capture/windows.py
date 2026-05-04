"""
Emiscreen Windows Capture Module

Captures the Windows desktop using FFmpeg gdigrab with h264 encoding.
Uses h264 passthrough for efficient WebRTC streaming.
"""

import asyncio
import logging
import platform
from fractions import Fraction
from typing import Optional

import av
from aiortc import VideoStreamTrack
from aiortc.mediastreams import VideoStreamTrack as AiortcVideoTrack

from emiscreen.capture.base import CaptureSource
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


class WindowsCapture(CaptureSource):
    """Captures Windows desktop via FFmpeg gdigrab with h264 encoding."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._width, self._height = self._parse_resolution()
        self._fps = config.fps
        self._decoder = None

    def _parse_resolution(self) -> tuple[int, int]:
        """Parse resolution string into width/height tuple."""
        parts = self.config.resolution.split("x")
        return int(parts[0]), int(parts[1])

    async def start(self):
        """Start FFmpeg gdigrab capture with h264 encoding."""
        await super().start()

        # Build FFmpeg command with h264 encoding
        cmd = [
            "ffmpeg",
            "-f", "gdigrab",
            "-framerate", str(self._fps),
            "-i", "desktop",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-profile:v", "baseline",
            "-level", "3.0",
            "-pix_fmt", "yuv420p",
            "-vf", f"scale={self._width}:{self._height}",
            "-bufsize", "512k",
            "-maxrate", "2M",
            "-an",
            "-f", "h264",
            "-flush_packets", "1",
            "-",
        ]

        logger.info(f"Starting FFmpeg gdigrab h264: {' '.join(cmd)}")

        self._ffmpeg_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Create video track for h264 decoding
        self._video_track = H264DecodeTrack(
            self._ffmpeg_process.stdout,
            self._width,
            self._height,
            self._fps,
        )

        # Log FFmpeg stderr in background
        asyncio.create_task(self._log_ffmpeg_stderr())

        logger.info(f"Windows capture started: {self._width}x{self._height} @ {self._fps}fps h264")

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


class H264DecodeTrack(AiortcVideoTrack):
    """
    VideoStreamTrack that reads h264 frames from FFmpeg, decodes to raw,
    then passes to WebRTC. Uses av library for h264 decoding.
    """

    kind = "video"

    def __init__(self, stream: asyncio.StreamReader, width: int, height: int, fps: int):
        super().__init__()
        self._stream = stream
        self._width = width
        self._height = height
        self._fps = fps
        self._timestamp = 0
        self._frame_interval = 1 / fps
        self._frame_count = 0
        self._decoder = None
        self._packet_buffer = b""

    async def recv(self) -> av.VideoFrame:
        """Read next h264 frame, decode, and return as VideoFrame."""
        if self._decoder is None:
            self._decoder = av.CodecContext.create("h264", "r")
            logger.info("H264 decoder initialized")

        # Feed packets until we get a frame
        while True:
            # Try to decode what we have
            try:
                frames = self._decoder.decode(self._packet_buffer)
                if frames:
                    frame = frames[0]
                    self._frame_count += 1
                    if self._frame_count % 30 == 0:
                        logger.info(f"Frame {self._frame_count}: {frame.width}x{frame.height} fmt={frame.format}")
                    frame.pts = int(self._timestamp * 90000)
                    frame.time_base = Fraction(1, 90000)
                    self._timestamp += self._frame_interval
                    return frame
            except Exception as e:
                logger.warning(f"Decode error: {e}, clearing buffer")
                self._packet_buffer = b""

            # Need more data - read from stream
            try:
                # Read length prefix (4 bytes big endian)
                size_data = await self._stream.readexactly(4)
                size = int.from_bytes(size_data, "big")
                if size > 0 and size < 2000000:  # Sanity check
                    packet = await self._stream.readexactly(size)
                    self._packet_buffer += packet
                    if self._frame_count < 5:
                        logger.debug(f"Packet {self._frame_count}: size={size}, buffer={len(self._packet_buffer)}")
                else:
                    logger.warning(f"Invalid packet size: {size}")
                    break
            except asyncio.IncompleteReadError:
                logger.warning("H264 stream ended")
                raise
            except Exception as e:
                logger.error(f"H264 read error: {e}")
                break