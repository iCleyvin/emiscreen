"""Tests for emiscreen.config module."""
import os
import pytest
from emiscreen.config import (
    CaptureConfig,
    ServerConfig,
    ADBConfig,
    RelayConfig,
    QUALITY_PRESETS,
    get_source,
    load_from_env,
)


class TestCaptureConfig:
    def test_default_values(self):
        config = CaptureConfig(type="windows")
        assert config.type == "windows"
        assert config.resolution == "1920x1080"
        assert config.fps == 30
        assert config.codec == "h264"
        assert config.bitrate == "8M"

    def test_custom_values(self):
        config = CaptureConfig(
            type="linux",
            resolution="1280x720",
            fps=24,
            codec="vp8",
            bitrate="4M",
        )
        assert config.resolution == "1280x720"
        assert config.fps == 24
        assert config.codec == "vp8"
        assert config.bitrate == "4M"


class TestQualityPresets:
    def test_preset_keys(self):
        assert "fast" in QUALITY_PRESETS
        assert "balanced" in QUALITY_PRESETS
        assert "quality" in QUALITY_PRESETS
        assert "native" in QUALITY_PRESETS

    def test_fast_preset(self):
        res, fps = QUALITY_PRESETS["fast"]
        assert res == "1280x720"
        assert fps == 24

    def test_balanced_preset(self):
        res, fps = QUALITY_PRESETS["balanced"]
        assert res == "1920x1080"
        assert fps == 24


class TestGetSource:
    def test_windows_source(self):
        config = get_source("windows-pc")
        assert config.type == "windows"

    def test_linux_source(self):
        config = get_source("ubuntu-desktop")
        assert config.type == "linux"

    def test_nas_source(self):
        config = get_source("nas-omv")
        assert config.type == "virtual"

    def test_invalid_source(self):
        with pytest.raises(KeyError):
            get_source("invalid-source")


class TestLoadFromEnv:
    def test_load_port(self, monkeypatch):
        monkeypatch.setenv("EMISCREEN_PORT", "9090")
        load_from_env()
        # Should not raise, just verify it runs

    def test_load_resolution(self, monkeypatch):
        monkeypatch.setenv("EMISCREEN_RESOLUTION", "2560x1440")
        load_from_env()
