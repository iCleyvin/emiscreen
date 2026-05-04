"""Tests for Windows input relay module."""
import pytest
from unittest.mock import patch, MagicMock


class TestWindowsInputBackend:
    @pytest.fixture
    def mock_windows(self):
        with patch('emiscreen.relay.windows_input.ctypes') as mock_ctypes:
            mock_user32 = MagicMock()
            mock_ctypes.windll.user32 = mock_user32
            mock_ctypes.wintypes = MagicMock()
            mock_ctypes.c_uint = int
            mock_ctypes.c_ulong = int
            mock_ctypes.byref = lambda x: x
            mock_ctypes.sizeof = lambda x: 28
            yield mock_user32

    def test_send_key_press(self, mock_windows):
        from emiscreen.relay.windows_input import WindowsInputBackend
        backend = WindowsInputBackend()
        backend.send_key('a', 'keydown')
        mock_windows.SendInput.assert_called()

    def test_send_key_release(self, mock_windows):
        from emiscreen.relay.windows_input import WindowsInputBackend
        backend = WindowsInputBackend()
        backend.send_key('a', 'keyup')
        mock_windows.SendInput.assert_called()

    def test_send_click(self, mock_windows):
        from emiscreen.relay.windows_input import WindowsInputBackend
        backend = WindowsInputBackend()
        backend.send_click(100, 200, 'left')
        mock_windows.SetCursorPos.assert_called_with(100, 200)
        mock_windows.mouse_event.assert_called()

    def test_mouse_move(self, mock_windows):
        from emiscreen.relay.windows_input import WindowsInputBackend
        backend = WindowsInputBackend()
        backend.mouse_move(500, 300)
        mock_windows.SetCursorPos.assert_called_with(500, 300)

    def test_scroll(self, mock_windows):
        from emiscreen.relay.windows_input import WindowsInputBackend
        backend = WindowsInputBackend()
        backend.scroll(3)
        mock_windows.mouse_event.assert_called()
