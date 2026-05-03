"""Tests for Emiscreen configuration module."""

import pytest
from emiscreen.config import (
    SOURCES,
    CaptureConfig,
    ServerConfig,
    ADBConfig,
    RelayConfig,
    get_source,
)


class TestCaptureConfig:
    """Test capture source configuration."""

    def test_ubuntu_desktop_source_exists(self):
        assert "ubuntu-desktop" in SOURCES
        config = SOURCES["ubuntu-desktop"]
        assert config.type == "linux"
        assert config.display == ":0"
        assert config.fps == 30
        assert config.codec == "h264"

    def test_windows_pc_source_exists(self):
        assert "windows-pc" in SOURCES
        config = SOURCES["windows-pc"]
        assert config.type == "windows"
        assert config.fps == 30
        assert config.codec == "h264"

    def test_nas_omv_source_exists(self):
        assert "nas-omv" in SOURCES
        config = SOURCES["nas-omv"]
        assert config.type == "virtual"
        assert config.virtual is True
        assert config.display == ":99"

    def test_get_source_valid(self):
        config = get_source("ubuntu-desktop")
        assert config.type == "linux"

    def test_get_source_invalid(self):
        with pytest.raises(ValueError, match="Unknown source"):
            get_source("nonexistent")


class TestServerConfig:
    """Test server configuration."""

    def test_defaults(self):
        config = ServerConfig()
        assert config.host == "0.0.0.0"
        assert config.port == 8443
        assert "cert.pem" in config.ssl_cert
        assert "key.pem" in config.ssl_key


class TestADBConfig:
    """Test ADB configuration."""

    def test_defaults(self):
        config = ADBConfig()
        assert config.enabled is True
        assert config.port == 5555
        assert config.auto_launch is True
        assert config.stay_awake is True


class TestRelayConfig:
    """Test relay configuration."""

    def test_defaults(self):
        config = RelayConfig()
        assert config.enabled is True
        assert config.dpad_step == 20
