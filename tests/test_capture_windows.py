"""Tests for Windows capture module."""
import pytest
from unittest.mock import patch, MagicMock


class TestGetMonitors:
    def test_returns_list(self):
        from emiscreen.capture.windows import _get_monitors
        monitors = _get_monitors()
        assert isinstance(monitors, list)
        # Should return at least the primary monitor
        assert len(monitors) >= 1

    def test_monitor_has_required_fields(self):
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


class TestWindowsCapture:
    def test_parse_resolution(self):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        config = CaptureConfig(type="windows", resolution="1920x1080", fps=30)
        capture = WindowsCapture(config)
        assert capture._width == 1920
        assert capture._height == 1080

    def test_display_desktop(self):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        config = CaptureConfig(type="windows", resolution="1920x1080", fps=30, display="desktop")
        capture = WindowsCapture(config)
        assert capture._display == "desktop"

    def test_monitor_selection(self):
        from emiscreen.capture.windows import WindowsCapture
        from emiscreen.config import CaptureConfig
        # Only test if there's a second monitor
        from emiscreen.capture.windows import _get_monitors
        monitors = _get_monitors()
        if len(monitors) >= 2:
            config = CaptureConfig(type="windows", resolution="1920x1080", fps=30, display="2")
            capture = WindowsCapture(config)
            assert capture._monitor_x == monitors[1]["x"]
            assert capture._monitor_y == monitors[1]["y"]
