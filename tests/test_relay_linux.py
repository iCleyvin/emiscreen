"""Tests for Linux input relay module."""
import pytest
from unittest.mock import patch, MagicMock


class TestLinuxInputBackend:
    @pytest.fixture
    def mock_subprocess(self):
        with patch('emiscreen.relay.linux_input.subprocess') as mock_sub:
            mock_sub.run.return_value = MagicMock(returncode=0)
            yield mock_sub

    def test_send_key(self, mock_subprocess):
        from emiscreen.relay.linux_input import LinuxInputBackend
        backend = LinuxInputBackend()
        backend.send_key('a', 'keydown')
        mock_subprocess.run.assert_called()

    def test_send_click(self, mock_subprocess):
        from emiscreen.relay.linux_input import LinuxInputBackend
        backend = LinuxInputBackend()
        backend.send_click(100, 200, 'left')
        mock_subprocess.run.assert_called()

    def test_mouse_move(self, mock_subprocess):
        from emiscreen.relay.linux_input import LinuxInputBackend
        backend = LinuxInputBackend()
        backend.mouse_move(500, 300)
        mock_subprocess.run.assert_called()
