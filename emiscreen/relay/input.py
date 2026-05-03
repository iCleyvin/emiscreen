"""
Emiscreen Input Relay Module

Receives input events from the FireTV browser via WebSocket
and translates them to system input commands (xdotool on Linux,
or ADB commands for FireTV control).
"""

import asyncio
import logging
import platform
import subprocess
from typing import Optional

from emiscreen.relay.adb import ADBController

logger = logging.getLogger(__name__)

# Key name to xdotool key mapping
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

# Mouse button mapping
MOUSE_BUTTON_MAP = {
    0: 1,  # Left
    1: 2,  # Middle
    2: 3,  # Right
}


class InputRelay:
    """Relays input events from browser clients to the system."""

    def __init__(
        self,
        adb: Optional[ADBController] = None,
        xdotool_path: str = "xdotool",
        dpad_step: int = 20,
    ):
        self.adb = adb
        self.xdotool_path = xdotool_path
        self.dpad_step = dpad_step
        self._clients: dict[int, object] = {}  # client_id -> ws
        self._current_x = 960  # Default center position
        self._current_y = 540
        self._system = platform.system()
        self._cmd_queue: asyncio.Queue = asyncio.Queue(maxsize=100)
        self._running = False
        self._processor_task: Optional[asyncio.Task] = None

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
        """Process an input event from a client."""
        event_type = event.get("type", "")

        try:
            if event_type == "keydown":
                await self._handle_keydown(event)
            elif event_type == "keyup":
                await self._handle_keyup(event)
            elif event_type == "mousemove":
                await self._handle_mousemove(event)
            elif event_type == "mousedown":
                await self._handle_mousedown(event)
            elif event_type == "mouseup":
                await self._handle_mouseup(event)
            elif event_type == "wheel":
                await self._handle_wheel(event)
            elif event_type == "touchstart":
                await self._handle_touchstart(event)
            elif event_type == "touchmove":
                await self._handle_touchmove(event)
            elif event_type == "touchend":
                await self._handle_touchend(event)
            else:
                logger.debug(f"Unknown event type: {event_type}")
        except Exception as e:
            logger.error(f"Error processing event {event_type}: {e}")

    async def _handle_keydown(self, event: dict):
        """Handle keydown event."""
        key = event.get("key", "")
        key_code = event.get("keyCode", 0)

        # D-Pad navigation (FireTV remote)
        if key in ("dpad_up", "dpad_down", "dpad_left", "dpad_right"):
            await self._handle_dpad(key)
            return

        # D-Pad center = Enter
        if key == "dpad_center":
            await self._execute_xdotool(["key", "Return"])
            return

        # Back button
        if key == "back":
            await self._execute_xdotool(["key", "Escape"])
            return

        # Regular keys
        xdotool_key = XDO_KEY_MAP.get(key)
        if xdotool_key:
            await self._execute_xdotool(["key", xdotool_key])
        elif len(key) == 1 and key.isprintable():
            # Single character - type it
            await self._execute_xdotool(["type", key])

    async def _handle_keyup(self, event: dict):
        """Handle keyup event (mostly ignored for xdotool)."""
        pass

    async def _handle_dpad(self, direction: str):
        """Handle D-Pad navigation as mouse movement."""
        step = self.dpad_step
        if direction == "dpad_up":
            self._current_y = max(0, self._current_y - step)
        elif direction == "dpad_down":
            self._current_y += step
        elif direction == "dpad_left":
            self._current_x = max(0, self._current_x - step)
        elif direction == "dpad_right":
            self._current_x += step

        await self._execute_xdotool([
            "mousemove", str(self._current_x), str(self._current_y)
        ])

    async def _handle_mousemove(self, event: dict):
        """Handle mouse move event."""
        x = event.get("x", 0)
        y = event.get("y", 0)
        self._current_x = x
        self._current_y = y
        await self._execute_xdotool(["mousemove", str(x), str(y)])

    async def _handle_mousedown(self, event: dict):
        """Handle mouse down event."""
        button = MOUSE_BUTTON_MAP.get(event.get("button", 0), 1)
        await self._execute_xdotool(["mousedown", str(button)])

    async def _handle_mouseup(self, event: dict):
        """Handle mouse up event."""
        button = MOUSE_BUTTON_MAP.get(event.get("button", 0), 1)
        await self._execute_xdotool(["mouseup", str(button)])

    async def _handle_wheel(self, event: dict):
        """Handle mouse wheel event."""
        delta_y = event.get("deltaY", 0)
        if delta_y < 0:
            await self._execute_xdotool(["click", "4"])  # Scroll up
        else:
            await self._execute_xdotool(["click", "5"])  # Scroll down

    async def _handle_touchstart(self, event: dict):
        """Handle touch start - treat as mouse down at position."""
        x = event.get("x", 0)
        y = event.get("y", 0)
        self._current_x = x
        self._current_y = y
        await self._execute_xdotool([
            "mousemove", str(x), str(y),
            "mousedown", "1",
        ])

    async def _handle_touchmove(self, event: dict):
        """Handle touch move - drag."""
        x = event.get("x", 0)
        y = event.get("y", 0)
        self._current_x = x
        self._current_y = y
        await self._execute_xdotool(["mousemove", str(x), str(y)])

    async def _handle_touchend(self, event: dict):
        """Handle touch end - release."""
        await self._execute_xdotool(["mouseup", "1"])

    async def _execute_xdotool(self, args: list[str]):
        """Execute an xdotool command asynchronously."""
        if self._system != "Linux":
            logger.debug(f"xdotool not available on {self._system}: {' '.join(args)}")
            return

        cmd = [self.xdotool_path] + args
        try:
            # Use queue to prevent overwhelming the system
            await self._cmd_queue.put(cmd)
        except asyncio.QueueFull:
            logger.warning("Input queue full, dropping event")

    async def _process_queue(self):
        """Process commands from the queue sequentially."""
        while self._running:
            try:
                cmd = await asyncio.wait_for(self._cmd_queue.get(), timeout=1.0)
                proc = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                await proc.wait()
                self._cmd_queue.task_done()
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error executing command: {e}")
