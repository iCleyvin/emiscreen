"""
Emiscreen Windows Capture Module

Captures the Windows desktop using FFmpeg gdigrab, outputting raw YUV420P
frames that are fed directly into the WebRTC pipeline.

Optimizations:
- No downscaling if target resolution matches native monitor resolution
- Lanczos scaling for better sharpness when downscaling is needed
"""

import asyncio
import ctypes
import logging
from typing import Optional

from emiscreen.capture.base import CaptureSource, FFmpegRawVideoTrack
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


def _get_monitors() -> list[dict]:
    """List all connected monitors with their resolutions (ignores DPI scaling)."""
    monitors = []
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
                # dmPosition (union with print fields)
                ("dmPositionX", wintypes.LONG),
                ("dmPositionY", wintypes.LONG),
                ("dmDisplayOrientation", wintypes.DWORD),
                ("dmDisplayFixedOutput", wintypes.DWORD),
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

        def enum_display_monitors():
            """Enumerate all monitors using GetMonitorInfo for accurate virtual-desktop coords."""
            class MONITORINFO(ctypes.Structure):
                _fields_ = [
                    ("cbSize", wintypes.DWORD),
                    ("rcMonitor", wintypes.RECT),
                    ("rcWork", wintypes.RECT),
                    ("dwFlags", wintypes.DWORD),
                ]

            def mon_callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
                mi = MONITORINFO()
                mi.cbSize = ctypes.sizeof(MONITORINFO)
                if user32.GetMonitorInfoW(hMonitor, ctypes.byref(mi)):
                    is_primary = (mi.dwFlags & 1) != 0
                    width = mi.rcMonitor.right - mi.rcMonitor.left
                    height = mi.rcMonitor.bottom - mi.rcMonitor.top
                    monitors.append({
                        "id": len(monitors) + 1,
                        "name": f"Monitor{len(monitors)+1}",
                        "width": width,
                        "height": height,
                        "refresh": 60,
                        "x": mi.rcMonitor.left,
                        "y": mi.rcMonitor.top,
                    })
                return 1

            CMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMONITOR, wintypes.HDC, ctypes.POINTER(wintypes.RECT), wintypes.LPARAM)
            user32.EnumDisplayMonitors(None, None, CMPROC(mon_callback), 0)

        enum_display_monitors()

        if not monitors:
            # Fallback to EnumDisplaySettings
            def enum_display_devices():
                class DISPLAY_DEVICE(ctypes.Structure):
                    _fields_ = [
                        ("cb", wintypes.DWORD),
                        ("DeviceName", ctypes.c_wchar * 32),
                        ("DeviceString", ctypes.c_wchar * 128),
                        ("StateFlags", wintypes.DWORD),
                        ("DeviceID", ctypes.c_wchar * 128),
                        ("DeviceKey", ctypes.c_wchar * 128),
                    ]

                device = DISPLAY_DEVICE()
                device.cb = ctypes.sizeof(DISPLAY_DEVICE)
                i = 0
                active_idx = 1
                while user32.EnumDisplayDevicesW(None, i, ctypes.byref(device), 0):
                    if device.StateFlags & 0x00000001:
                        dm = DEVMODE()
                        dm.dmSize = ctypes.sizeof(DEVMODE)
                        if user32.EnumDisplaySettingsW(device.DeviceName, ctypes.c_uint32(0xFFFFFFFF), ctypes.byref(dm)):
                            monitors.append({
                                "id": active_idx,
                                "name": device.DeviceName,
                                "width": dm.dmPelsWidth,
                                "height": dm.dmPelsHeight,
                                "refresh": dm.dmDisplayFrequency,
                                "x": dm.dmPositionX,
                                "y": dm.dmPositionY,
                            })
                            active_idx += 1
                    i += 1
            enum_display_devices()

        if not monitors:
            # Fallback: primary monitor only
            dm = DEVMODE()
            dm.dmSize = ctypes.sizeof(DEVMODE)
            if user32.EnumDisplaySettingsW(None, ctypes.c_uint32(0xFFFFFFFF), ctypes.byref(dm)):
                monitors.append({
                    "id": 1,
                    "name": "Primary",
                    "width": dm.dmPelsWidth,
                    "height": dm.dmPelsHeight,
                    "refresh": dm.dmDisplayFrequency,
                })
    except Exception as e:
        logger.warning(f"Could not enumerate monitors: {e}")
        monitors.append({"id": 1, "name": "Primary", "width": 1920, "height": 1080, "refresh": 60})

    return monitors


def _get_native_resolution() -> tuple[int, int]:
    """Get the REAL native resolution of the primary monitor (ignores DPI scaling)."""
    monitors = _get_monitors()
    if monitors:
        primary = next((m for m in monitors if m["id"] == 1), monitors[0])
        return primary["width"], primary["height"]
    return 1920, 1080


def list_monitors() -> str:
    """Return a formatted list of connected monitors."""
    monitors = _get_monitors()
    lines = ["Connected monitors:"]
    for m in monitors:
        lines.append(f"  {m['id']}: {m['name']} ({m['width']}x{m['height']} @ {m['refresh']}Hz)")
    return "\n".join(lines)


class WindowsCapture(CaptureSource):
    """Captures Windows desktop via FFmpeg gdigrab → raw YUV420P."""

    def __init__(self, config: CaptureConfig):
        super().__init__(config)
        self._width, self._height = self._parse_resolution()
        self._fps = config.fps
        self._display = config.display  # "desktop" or "1", "2", etc.

        # Get resolution/position of the specific monitor being captured
        monitors = _get_monitors()
        self._monitor_x = 0
        self._monitor_y = 0
        if self._display != "desktop" and self._display.isdigit():
            monitor_id = int(self._display)
            selected = next((m for m in monitors if m["id"] == monitor_id), None)
            if selected:
                self._native_w, self._native_h = selected["width"], selected["height"]
                self._monitor_x = selected.get("x", 0)
                self._monitor_y = selected.get("y", 0)
                logger.info(f"Selected monitor {monitor_id}: {self._native_w}x{self._native_h} at ({self._monitor_x},{self._monitor_y})")
            else:
                logger.warning(f"Monitor {monitor_id} not found, using primary")
                self._native_w, self._native_h = _get_native_resolution()
        else:
            self._native_w, self._native_h = _get_native_resolution()

    def _parse_resolution(self) -> tuple[int, int]:
        """Parse resolution string into width/height tuple."""
        parts = self.config.resolution.split("x")
        return int(parts[0]), int(parts[1])

    async def start(self):
        """Start FFmpeg gdigrab capture to raw YUV420P."""
        await super().start()

        # Build video filter: lanczos scaling for sharpness
        target_w, target_h = self._width, self._height
        native_w, native_h = self._native_w, self._native_h

        if target_w == native_w and target_h == native_h:
            # Native capture — no scaling needed
            vf = "format=yuv420p"
            logger.info(f"Native capture: {native_w}x{native_h}")
        else:
            # Scale with lanczos for best sharpness
            vf = f"scale={target_w}:{target_h}:flags=lanczos,format=yuv420p"
            logger.info(f"Scaling: {native_w}x{native_h} → {target_w}x{target_h} (lanczos)")

        # Build FFmpeg command
        if self._display != "desktop":
            # Capture specific monitor via offset + video_size
            cmd = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel", "error",
                "-f", "gdigrab",
                "-framerate", str(self._fps),
                "-video_size", f"{self._native_w}x{self._native_h}",
                "-offset_x", str(self._monitor_x),
                "-offset_y", str(self._monitor_y),
                "-i", "desktop",
                "-vf", vf,
                "-pix_fmt", "yuv420p",
                "-f", "rawvideo",
                "-threads", "2",
                "-",
            ]
        else:
            cmd = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel", "error",
                "-f", "gdigrab",
                "-framerate", str(self._fps),
                "-i", "desktop",
                "-vf", vf,
                "-pix_fmt", "yuv420p",
                "-f", "rawvideo",
                "-threads", "2",
                "-",
            ]

        logger.info(f"Starting Windows capture: {' '.join(cmd)}")

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
        logger.info(f"Windows capture started: {target_w}x{target_h} @ {self._fps}fps from monitor '{self._display}'")

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
