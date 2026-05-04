"""Tests for Windows input relay module."""
import pytest
import sys
from unittest.mock import patch, MagicMock


class TestWindowsInputBackend:
    def test_class_exists(self):
        from emiscreen.relay.input import WindowsInputBackend
        assert WindowsInputBackend is not None

    def test_has_required_methods(self):
        from emiscreen.relay.input import WindowsInputBackend
        required = ['move_mouse', 'mouse_down', 'mouse_up', 'scroll', 'key_down', 'key_up', 'type_text']
        for method in required:
            assert hasattr(WindowsInputBackend, method), f"Missing method: {method}"

    def test_linux_backend_exists(self):
        from emiscreen.relay.input import LinuxInputBackend
        assert LinuxInputBackend is not None

    def test_linux_has_xdo_key_map(self):
        from emiscreen.relay.input import LinuxInputBackend
        backend = LinuxInputBackend()
        assert "enter" in backend.XDO_KEY_MAP
        assert "space" in backend.XDO_KEY_MAP
        assert backend.XDO_KEY_MAP["enter"] == "Return"

    def test_create_backend_factory(self):
        from emiscreen.relay.input import create_backend
        # Test that factory returns correct type for known systems
        linux_backend = create_backend("linux")
        assert type(linux_backend).__name__ == "LinuxInputBackend"
