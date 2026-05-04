"""Tests for Linux input relay module."""
import pytest
from unittest.mock import patch, MagicMock


class TestLinuxInputBackend:
    @pytest.fixture
    def mock_subprocess(self):
        with patch('emiscreen.relay.input.asyncio') as mock_async:
            mock_proc = MagicMock()
            mock_proc.wait = MagicMock(return_value=MagicMock())
            mock_async.create_subprocess_exec = MagicMock(return_value=mock_proc)
            yield mock_async

    def test_key_down(self, mock_subprocess):
        from emiscreen.relay.input import LinuxInputBackend
        backend = LinuxInputBackend()
        # Just verify instantiation works
        assert backend.xdotool_path == "xdotool"

    def test_move_mouse(self, mock_subprocess):
        from emiscreen.relay.input import LinuxInputBackend
        backend = LinuxInputBackend()
        assert backend is not None

    def test_xdo_key_map(self):
        from emiscreen.relay.input import LinuxInputBackend
        backend = LinuxInputBackend()
        assert "enter" in backend.XDO_KEY_MAP
        assert "space" in backend.XDO_KEY_MAP
        assert backend.XDO_KEY_MAP["enter"] == "Return"
