"""
Emiscreen Windows Input Backend (ctypes)

Simulates keyboard and mouse input on Windows using the native SendInput API.
Zero external dependencies — only uses stdlib ctypes.
"""

import ctypes
import logging
import struct
from ctypes import wintypes

logger = logging.getLogger(__name__)

# Windows constants
INPUT_MOUSE = 0
INPUT_KEYBOARD = 1
INPUT_HARDWARE = 2

KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_SCANCODE = 0x0008
KEYEVENTF_UNICODE = 0x0004

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_ABSOLUTE = 0x8000
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_HWHEEL = 0x1000

# Virtual-key codes
VK_MAP = {
    "enter": 0x0D,
    "return": 0x0D,
    "space": 0x20,
    "tab": 0x09,
    "backspace": 0x08,
    "delete": 0x2E,
    "home": 0x24,
    "end": 0x23,
    "page_up": 0x21,
    "page_down": 0x22,
    "escape": 0x1B,
    "dpad_up": 0x26,
    "dpad_down": 0x28,
    "dpad_left": 0x25,
    "dpad_right": 0x27,
    "dpad_center": 0x0D,
    "play_pause": 0xB3,
    "next": 0xB0,
    "prev": 0xB1,
    "volume_up": 0xAF,
    "volume_down": 0xAE,
    "mute": 0xAD,
}

# Mouse button mapping
MOUSE_BTN_DOWN = {0: MOUSEEVENTF_LEFTDOWN, 1: MOUSEEVENTF_MIDDLEDOWN, 2: MOUSEEVENTF_RIGHTDOWN}
MOUSE_BTN_UP = {0: MOUSEEVENTF_LEFTUP, 1: MOUSEEVENTF_MIDDLEUP, 2: MOUSEEVENTF_RIGHTUP}


class _MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG)),
    ]


class _KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG)),
    ]


class _HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD),
    ]


class _INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [
            ("mi", _MOUSEINPUT),
            ("ki", _KEYBDINPUT),
            ("hi", _HARDWAREINPUT),
        ]
    _anonymous_ = ("u",)
    _fields_ = [
        ("type", wintypes.DWORD),
        ("u", _U),
    ]


_user32 = ctypes.windll.user32
_kernel32 = ctypes.windll.kernel32

# Cache screen metrics for absolute mouse coordinates
_screen_x = _user32.GetSystemMetrics(0)
_screen_y = _user32.GetSystemMetrics(1)


def _send_input(*inputs):
    """Send one or more INPUT structures to Windows."""
    n = len(inputs)
    arr = (_INPUT * n)(*inputs)
    cb_size = ctypes.sizeof(_INPUT)
    sent = _user32.SendInput(n, arr, cb_size)
    if sent != n:
        logger.warning(f"SendInput sent {sent}/{n}")


def _key_input(vk: int, flags: int = 0) -> _INPUT:
    """Build a KEYBDINPUT structure."""
    inp = _INPUT()
    inp.type = INPUT_KEYBOARD
    inp.ki.wVk = vk
    inp.ki.wScan = _user32.MapVirtualKeyW(vk, 0)
    inp.ki.dwFlags = flags
    return inp


def move_mouse(x: int, y: int):
    """Move the cursor to absolute screen coordinates."""
    # Absolute coordinates are 0-65535
    abs_x = int(x * 65535 / (_screen_x - 1)) if _screen_x > 1 else 0
    abs_y = int(y * 65535 / (_screen_y - 1)) if _screen_y > 1 else 0
    inp = _INPUT()
    inp.type = INPUT_MOUSE
    inp.mi.dx = abs_x
    inp.mi.dy = abs_y
    inp.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE
    _send_input(inp)


def mouse_down(button: int = 0):
    """Press a mouse button (0=left, 1=middle, 2=right)."""
    flag = MOUSE_BTN_DOWN.get(button)
    if not flag:
        return
    inp = _INPUT()
    inp.type = INPUT_MOUSE
    inp.mi.dwFlags = flag
    _send_input(inp)


def mouse_up(button: int = 0):
    """Release a mouse button."""
    flag = MOUSE_BTN_UP.get(button)
    if not flag:
        return
    inp = _INPUT()
    inp.type = INPUT_MOUSE
    inp.mi.dwFlags = flag
    _send_input(inp)


def scroll_vertical(delta: int):
    """Scroll vertically (positive=up, negative=down)."""
    # WHEEL_DELTA = 120
    wheel = int(delta / 3)  # scale browser delta to Windows wheel units
    if wheel == 0:
        wheel = 120 if delta > 0 else -120
    inp = _INPUT()
    inp.type = INPUT_MOUSE
    inp.mi.mouseData = wheel
    inp.mi.dwFlags = MOUSEEVENTF_WHEEL
    _send_input(inp)


def key_down(name: str):
    """Press a named key."""
    vk = _resolve_vk(name)
    if vk is None:
        logger.debug(f"No VK mapping for key: {name}")
        return
    _send_input(_key_input(vk))


def key_up(name: str):
    """Release a named key."""
    vk = _resolve_vk(name)
    if vk is None:
        return
    _send_input(_key_input(vk, KEYEVENTF_KEYUP))


def type_text(text: str):
    """Type a string by simulating individual key presses."""
    for ch in text:
        vk = _char_to_vk(ch)
        if vk:
            _send_input(_key_input(vk))
            _send_input(_key_input(vk, KEYEVENTF_KEYUP))
        else:
            logger.debug(f"Cannot type character: {ch!r}")


def _resolve_vk(name: str) -> int | None:
    """Resolve a key name to a Windows virtual-key code."""
    name = name.lower()
    if name in VK_MAP:
        return VK_MAP[name]
    if len(name) == 1:
        return _char_to_vk(name)
    return None


def _char_to_vk(ch: str) -> int | None:
    """Map a single character to VK code."""
    if "a" <= ch <= "z":
        return ord(ch.upper())
    if "0" <= ch <= "9":
        return ord(ch)
    # Common punctuation (US layout)
    pmap = {
        " ": 0x20,
        "\t": 0x09,
        "\n": 0x0D,
        "\r": 0x0D,
        "-": 0xBD,
        "=": 0xBB,
        ",": 0xBC,
        ".": 0xBE,
        "/": 0xBF,
        ";": 0xBA,
        "'": 0xDE,
        "[": 0xDB,
        "]": 0xDD,
        "\\": 0xDC,
        "`": 0xC0,
    }
    return pmap.get(ch)
