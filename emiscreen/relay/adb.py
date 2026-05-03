"""
Emiscreen ADB Control Module

Handles all ADB communication with FireTV devices:
- TCP/IP connection management
- Device wake/unlock
- Browser auto-launch with stream URL
- D-Pad and key event simulation
- Auto-reconnection on disconnect
"""

import asyncio
import logging
import subprocess
from typing import Optional

logger = logging.getLogger(__name__)

# FireTV key codes
KEYCODES = {
    "dpad_up": "KEYCODE_DPAD_UP",
    "dpad_down": "KEYCODE_DPAD_DOWN",
    "dpad_left": "KEYCODE_DPAD_LEFT",
    "dpad_right": "KEYCODE_DPAD_RIGHT",
    "dpad_center": "KEYCODE_DPAD_CENTER",
    "enter": "KEYCODE_ENTER",
    "home": "KEYCODE_HOME",
    "back": "KEYCODE_BACK",
    "menu": "KEYCODE_MENU",
    "power": "KEYCODE_POWER",
    "play_pause": "KEYCODE_MEDIA_PLAY_PAUSE",
    "next": "KEYCODE_MEDIA_NEXT",
    "prev": "KEYCODE_MEDIA_PREVIOUS",
    "volume_up": "KEYCODE_VOLUME_UP",
    "volume_down": "KEYCODE_VOLUME_DOWN",
    "mute": "KEYCODE_VOLUME_MUTE",
}


class ADBController:
    """Controls a FireTV device via ADB over TCP/IP."""

    def __init__(self, host: str, port: int = 5555, adb_path: str = "adb"):
        self.host = host
        self.port = port
        self.adb_path = adb_path
        self.serial = f"{host}:{port}"
        self._connected = False
        self._reconnect_task: Optional[asyncio.Task] = None

    async def connect(self) -> bool:
        """Establish ADB TCP/IP connection to FireTV."""
        try:
            result = await self._run(["connect", self.serial])
            if "connected" in result.lower() or "already connected" in result.lower():
                self._connected = True
                logger.info(f"ADB connected to {self.serial}")
                return True
            logger.warning(f"ADB connect output: {result}")
            return False
        except Exception as e:
            logger.error(f"ADB connect failed: {e}")
            return False

    async def disconnect(self):
        """Disconnect from FireTV."""
        try:
            await self._run(["disconnect", self.serial])
            self._connected = False
            logger.info(f"ADB disconnected from {self.serial}")
        except Exception as e:
            logger.error(f"ADB disconnect failed: {e}")

    async def wake(self):
        """Wake the FireTV device and prevent sleep."""
        await self.send_keyevent("power")
        await asyncio.sleep(1)
        await self.send_keyevent("home")
        try:
            await self._settings_put("global", "stay_on_while_plugged_in", "7")
            await self._settings_put("system", "screen_off_timeout", "1800000")
        except Exception as e:
            logger.debug(f"Could not set display settings: {e}")

    async def sleep(self):
        """Put FireTV to sleep."""
        await self._settings_put("global", "stay_on_while_plugged_in", "0")
        await self.send_keyevent("power")
        logger.info("FireTV put to sleep")

    async def launch_browser(self, url: str):
        """Launch FireTV browser (Silk or Firefox) with the given URL."""
        # Try Silk browser first (default on FireTV)
        silk_activities = [
            "com.amazon.silk/.BrowserActivity",
            "com.amazon.silk/.SimplifiedBrowserActivity",
        ]
        for activity in silk_activities:
            result = await self._run([
                "shell", "am", "start",
                "-a", "android.intent.action.VIEW",
                "-d", url,
                "-n", activity,
            ])
            if "Starting" in result or not result.strip():
                logger.info(f"Launched Silk browser: {url}")
                return True

        # Fallback: try Firefox for Fire TV
        result = await self._run([
            "shell", "am", "start",
            "-a", "android.intent.action.VIEW",
            "-d", url,
            "-n", "org.mozilla.tv.firefox/.MainActivity",
        ])
        if "Starting" in result or not result.strip():
            logger.info(f"Launched Firefox: {url}")
            return True

        # Last resort: generic VIEW intent
        result = await self._run([
            "shell", "am", "start",
            "-a", "android.intent.action.VIEW",
            "-d", url,
        ])
        logger.info(f"Launched generic browser: {url}")
        return True

    async def send_keyevent(self, key: str):
        """Send a key event to FireTV."""
        keycode = KEYCODES.get(key, key)
        await self._run(["shell", "input", "keyevent", keycode])

    async def send_text(self, text: str):
        """Send text input to FireTV."""
        # Escape spaces and special chars for adb shell
        safe_text = text.replace(" ", "%s").replace("'", "\\'")
        await self._run(["shell", "input", "text", safe_text])

    async def tap(self, x: int, y: int):
        """Simulate a tap at coordinates."""
        await self._run(["shell", "input", "tap", str(x), str(y)])

    async def swipe(self, x1: int, y1: int, x2: int, y2: int, duration: int = 300):
        """Simulate a swipe gesture."""
        await self._run([
            "shell", "input", "swipe",
            str(x1), str(y1), str(x2), str(y2), str(duration),
        ])

    async def get_installed_apps(self) -> list[str]:
        """List all installed app package names."""
        result = await self._run(["shell", "pm", "list", "packages", "-3"])
        return [line.split(":")[1] for line in result.strip().split("\n") if ":" in line]

    async def start_app(self, package: str):
        """Launch an app by package name."""
        await self._run([
            "shell", "am", "start",
            "-a", "android.intent.action.MAIN",
            "-n", f"{package}/.MainActivity",
        ])

    async def stop_app(self, package: str):
        """Force stop an app."""
        await self._run(["shell", "am", "force-stop", package])

    async def is_connected(self) -> bool:
        """Check if ADB connection is alive."""
        try:
            result = await self._run(["shell", "echo", "ping"])
            return "ping" in result
        except Exception:
            return False

    async def start_auto_reconnect(self, interval: float = 5.0):
        """Start background task to auto-reconnect if disconnected."""
        if self._reconnect_task and not self._reconnect_task.done():
            return
        self._reconnect_task = asyncio.create_task(
            self._reconnect_loop(interval)
        )

    async def stop_auto_reconnect(self):
        """Stop auto-reconnect task."""
        if self._reconnect_task:
            self._reconnect_task.cancel()
            try:
                await self._reconnect_task
            except asyncio.CancelledError:
                pass

    async def _reconnect_loop(self, interval: float):
        """Background loop that reconnects if disconnected."""
        while True:
            try:
                await asyncio.sleep(interval)
                if not await self.is_connected():
                    logger.warning("ADB disconnected, attempting reconnect...")
                    if await self.connect():
                        logger.info("ADB reconnected successfully")
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Auto-reconnect error: {e}")

    async def _settings_put(self, namespace: str, key: str, value: str):
        """Put a system setting via ADB."""
        await self._run(["shell", "settings", "put", namespace, key, value])

    async def _run(self, args: list[str], timeout: float = 10.0) -> str:
        """Run an ADB command and return stdout."""
        cmd = [self.adb_path, "-s", self.serial] + args
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=timeout
            )
            output = stdout.decode().strip()
            if stderr:
                err = stderr.decode().strip()
                if err and "error" in err.lower():
                    logger.debug(f"ADB stderr: {err}")
            return output
        except asyncio.TimeoutError:
            logger.error(f"ADB command timed out: {' '.join(cmd)}")
            return ""
        except Exception as e:
            logger.error(f"ADB command failed: {e}")
            return ""
