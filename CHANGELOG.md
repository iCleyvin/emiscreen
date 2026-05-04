# Changelog

## [1.1.0] - 2026-05-04 — Phase 1: Hardening

### Added
- **Auto-reconnect** (1-1): Smart reconnection with exponential backoff, max 5 attempts, countdown timer
- **Status overlay** (1-2): Real-time stats (bitrate, ping, resolution, FPS) toggled with Menu key
- **Error handling** (1-3): Spanish error messages for server timeout, cert errors, network loss, server closed
- **Bitrate adaptation** (1-4): Dynamic bitrate based on RTT and packet loss (2M→4M→6M→8M→12M)
- **Unit tests** (1-5): Tests for config, Windows capture, input relay (Windows/Linux), SSL certs
- **Smoke check** (1-6): `scripts/smoke-check.ps1` and `smoke-check.sh` for CI
- **Audio transmission** (1-7): PC desktop audio streamed to Fire TV via WebRTC audio track
- **Latency optimization** (1-8): `-tune zerolatency -profile:v baseline` for <100ms target
- **Windows packaging** (1-9): `scripts/build-windows.ps1` creates portable `.zip`
- **APK release build** (1-10): `scripts/build-apk-release.ps1` with git-based versioning
- **Multi-client support** (1-11): Server accepts multiple WebRTC peers via MediaRelay
- **Amazon Appstore docs** (1-12): Submission guide with manifest requirements
- **Latency benchmark** (1-13): `scripts/benchmark-latency.sh` for measuring end-to-end latency

### Changed
- `viewer.js` completely rewritten with ConnectionManager, error types, toast notifications
- `viewer.html` restructured with better overlay hierarchy
- `viewer.css` redesigned with stat rows, error styles, toast animations
- Windows capture uses `GetMonitorInfo` for accurate virtual-desktop coordinates
- FFmpeg commands include low-latency encoder flags

### Fixed
- Multi-monitor capture on Windows now correctly maps to virtual desktop coordinates
- Parsec VDD virtual display properly detected and captured
- `EnumDisplaySettings` coordinate mismatch resolved with `GetMonitorInfo`

## [1.0.0] - 2026-05-03

### Added
- Initial release: WebRTC remote display from PC to Fire TV
- Native Fire TV app (Kotlin WebView) with SSL auto-trust
- Cross-platform input relay (Linux xdotool, Windows SendInput)
- Unified FFmpeg → rawvideo YUV420P pipeline
- Quality presets: fast, balanced, quality, native
- Smart SSL certificates with LAN IP in SAN
- Multi-monitor support: `--display 1|2`

