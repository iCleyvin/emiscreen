"""
Emiscreen Input Relay Module

Receives input events from the FireTV browser via WebSocket
and translates them to system input commands.

Backends:
  - Linux: xdotool
  - Windows: native SendInput via ctypes (zero deps)
"""

import asyncio
import logging
import platform
from abc import ABC, abstractmethod
from typing import Optional

from emiscreen.relay.adb import ADBController

logger = logging.getLogger(__name__)


class InputBackend(ABC):
    """Abstract input backend for a given OS."""

    @abstractmethod
    async def move_mouse(self, x: int, y: int): ...

    @abstractmethod
    async def mouse_down(self, button: int): ...

    @abstractmethod
    async def mouse_up(self, button: int): ...

    @abstractmethod
    async def scroll(self, delta_y: int): ...

    @abstractmethod
    async def key_down(self, key: str): ...

    @abstractmethod
    async def key_up(self, key: str): ...

    @abstractmethod
    async def type_text(self, text: str): ...


class LinuxInputBackend(InputBackend):
    """xdotool-based input for Linux/X11."""

    XDO_KEY_MAP = {
        "enter": "Return",
        "space": "space",
        "tab": "Tab",
        "backspace": "BackSpace",
        "delete": "Delete",
        "home": "Home",
        "end": "End",
        "page_up": "Page_Up",
        "page_down": "Page_Down",
        "escape": "Escape",
        "dpad_center": "Return",
        "play_pause": "space",
        "next": "Next",
        "prev": "Prior",
        "volume_up": "XF86AudioRaiseVolume",
        "volume_down": "XF86AudioLowerVolume",
        "mute": "XF86AudioMute",
    }

    def __init__(self, xdotool_path: str = "xdotool"):
        self.xdotool_path = xdotool_path

    async def _run(self, args: list[str]):
        cmd = [self.xdotool_path] + args
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()

    async def move_mouse(self, x: int, y: int):
        await self._run(["mousemove", str(x), str(y)])

    async def mouse_down(self, button: int):
        btn = {0: 1, 1: 2, 2: 3}.get(button, 1)
        await self._run(["mousedown", str(btn)])

    async def mouse_up(self, button: int):
        btn = {0: 1, 1: 2, 2: 3}.get(button, 1)
        await self._run(["mouseup", str(btn)])

    async def scroll(self, delta_y: int):
        if delta_y < 0:
            await self._run(["click", "4"])
        else:
            await self._run(["click", "5"])

    async def key_down(self, key: str):
        mapped = self.XDO_KEY_MAP.get(key, key)
        if len(mapped) == 1 and mapped.isprintable():
            await self._run(["keydown", mapped])
        else:
            await self._run(["keydown", mapped])

    async def key_up(self, key: str):
        mapped = self.XDO_KEY_MAP.get(key, key)
        await self._run(["keyup", mapped])

    async def type_text(self, text: str):
        safe = text.replace(" ", "%s").replace("'", "\\'")
        await self._run(["type", safe])


class WindowsInputBackend(InputBackend):
    """Native SendInput backend for Windows (ctypes, zero deps)."""

    def __init__(self):
        # Import lazily so we don't crash on Linux
        from emiscreen.relay import windows_input as wi
        self._wi = wi

    async def move_mouse(self, x: int, y: int):
        self._wi.move_mouse(x, y)

    async def mouse_down(self, button: int):
        self._wi.mouse_down(button)

    async def mouse_up(self, button: int):
        self._wi.mouse_up(button)

    async def scroll(self, delta_y: int):
        self._wi.scroll_vertical(delta_y)

    async def key_down(self, key: str):
        self._wi.key_down(key)

    async def key_up(self, key: str):
        self._wi.key_up(key)

    async def type_text(self, text: str):
        self._wi.type_text(text)


def create_backend(system: Optional[str] = None, xdotool_path: str = "xdotool") -> InputBackend:
    """Factory: create the right backend for the OS."""
    sys = (system or platform.system()).lower()
    if sys == "linux":
        return LinuxInputBackend(xdotool_path)
    elif sys == "windows":
        return WindowsInputBackend()
    else:
        logger.warning(f"No input backend for {sys}; input relay will be a no-op.")
        return LinuxInputBackend(xdotool_path)  # fallback that will likely fail silently


class InputRelay:
    """Relays input events from browser clients to the system."""

    def __init__(
        self,
        adb: Optional[ADBController] = None,
        xdotool_path: str = "xdotool",
        dpad_step: int = 20,
    ):
        self.adb = adb
        self.dpad_step = dpad_step
        self._clients: dict[int, object] = {}  # client_id -> ws
        self._current_x = 960
        self._current_y = 540
        self._cmd_queue: asyncio.Queue = asyncio.Queue(maxsize=100)
        self._running = False
        self._processor_task: Optional[asyncio.Task] = None

        # Select backend based on OS where the SERVER runs
        self._backend = create_backend(xdotool_path=xdotool_path)
        logger.info(f"Input relay using {type(self._backend).__name__}")

    def add_client(self, client_id: int, ws: object):
        """Register a new input client."""
        self._clients[client_id] = ws
        logger.info(f"Input client registered: {client_id}")

    def remove_client(self, client_id: int):
        """Remove an input client."""
        self._clients.pop(client_id, None)
        logger.info(f"Input client removed: {client_id}")

    async def start(self):
        """Start the input processing loop."""
        self._running = True
        self._processor_task = asyncio.create_task(self._process_queue())
        logger.info("Input relay started")

    async def stop(self):
        """Stop the input processing loop."""
        self._running = False
        if self._processor_task:
            self._processor_task.cancel()
            try:
                await self._processor_task
            except asyncio.CancelledError:
                pass
        logger.info("Input relay stopped")

    async def process_event(self, client_id: int, event: dict):
        """Queue an input event from a client."""
        try:
            await self._cmd_queue.put(event)
        except asyncio.QueueFull:
            logger.warning("Input queue full, dropping event")

    async def _process_queue(self):
        """Process commands from the queue sequentially."""
        while self._running:
            try:
                event = await asyncio.wait_for(self._cmd_queue.get(), timeout=1.0)
                await self._dispatch(event)
                self._cmd_queue.task_done()
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error executing input event: {e}")

    async def _dispatch(self, event: dict):
        """Dispatch a single event to the backend."""
        etype = event.get("type", "")
        try:
            if etype == "keydown":
                await self._handle_keydown(event)
            elif etype == "keyup":
                await self._handle_keyup(event)
            elif etype == "mousemove":
                x = event.get("x", 0)
                y = event.get("y", 0)
                self._current_x = x
                self._current_y = y
                await self._backend.move_mouse(x, y)
            elif etype == "mousedown":
                await self._backend.mouse_down(event.get("button", 0))
            elif etype == "mouseup":
                await self._backend.mouse_up(event.get("button", 0))
            elif etype == "wheel":
                await self._backend.scroll(event.get("deltaY", 0))
            elif etype == "touchstart":
                x = event.get("x", 0)
                y = event.get("y", 0)
                self._current_x = x
                self._current_y = y
                await self._backend.move_mouse(x, y)
                await self._backend.mouse_down(0)
            elif etype == "touchmove":
                x = event.get("x", 0)
                y = event.get("y", 0)
                self._current_x = x
                self._current_y = y
                await self._backend.move_mouse(x, y)
            elif etype == "touchend":
                await self._backend.mouse_up(0)
            else:
                logger.debug(f"Unknown event type: {etype}")
        except Exception as e:
            logger.error(f"Error in {etype}: {e}")

    async def _handle_keydown(self, event: dict):
        key = event.get("key", "")
        if key in ("dpad_up", "dpad_down", "dpad_left", "dpad_right"):
            step = self.dpad_step
            if key == "dpad_up":
                self._current_y = max(0, self._current_y - step)
            elif key == "dpad_down":
                self._current_y += step
            elif key == "dpad_left":
                self._current_x = max(0, self._current_x - step)
            elif key == "dpad_right":
                self._current_x += step
            await self._backend.move_mouse(self._current_x, self._current_y)
            return

        if key == "dpad_center":
            await self._backend.key_down("enter")
            await self._backend.key_up("enter")
            return

        if key == "back":
            await self._backend.key_down("escape")
            await self._backend.key_up("escape")
            return

        await self._backend.key_down(key)

    async def _handle_keyup(self, event: dict):
        key = event.get("key", "")
        if key in ("dpad_up", "dpad_down", "dpad_left", "dpad_right", "dpad_center", "back"):
            return
        await self._backend.key_up(key)
