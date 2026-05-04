"""Tests for Windows capture module."""
import pytest
import sys
from unittest.mock import patch, MagicMock

# Mock Windows API before importing
mock_user32 = MagicMock()
mock_gdi32 = MagicMock()

# Setup mock EnumDisplayMonitors
class MockRECT:
    left = 0
    top = 0
    right = 1920
    bottom = 1080

def mock_enum_monitors_callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
    return 1

@pytest.fixture
def mock_windows_api():
    with patch.dict('sys.modules', {'ctypes': MagicMock(), 'ctypes.wintypes': MagicMock()}):
        with patch('emiscreen.capture.windows._get_monitors') as mock_get:
            mock_get.return_value = [
                {"id": 1, "name": "DISPLAY1", "width": 1920, "height": 1080, "refresh": 60, "x": 0, "y": 0},
                {"id": 2, "name": "DISPLAY2", "width": 1920, "height": 1080, "refresh": 60, "x": 1920, "y": 0},
            ]
            yield mock_get


class TestGetMonitors:
    def test_returns_list(self, mock_windows_api):
        from emiscreen.capture.windows import _get_monitors
        monitors = _get_monitors()
        assert isinstance(monitors, list)
        assert len(monitors) == 2

    def test_monitor_has_required_fields(self, mock_windows_api):
        from emiscreen.capture.windows import _get_monitors
        monitors = _get_monitors()
        for m in monitors:
            assert "id" in m
            assert "name" in m
            assert "width" in m
            assert "height" in m
            assert "refresh" in m
            assert "x" in m
            assert "y" in m

    def test_fallback_on_error(self):
        with patch('emiscreen.capture.windows._get_monitors', side_effect=Exception("Windows API error")):
            from emiscreen.capture.windows import list_monitors
            result = list_monitors()
            assert "Connected monitors" in result


class TestWindowsCapture:
    def test_parse_resolution(self, mock_windows_api):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        config = CaptureConfig(type="windows", resolution="1920x1080", fps=30)
        capture = WindowsCapture(config)
        assert capture._width == 1920
        assert capture._height == 1080

    def test_monitor_selection(self, mock_windows_api):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        config = CaptureConfig(type="windows", resolution="1920x1080", fps=30, display="2")
        capture = WindowsCapture(config)
        assert capture._monitor_x == 1920
        assert capture._monitor_y == 0

    def test_display_desktop(self, mock_windows_api):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        config = CaptureConfig(type="windows", resolution="1920x1080", fps=30, display="desktop")
        capture = WindowsCapture(config)
        assert capture._display == "desktop"
