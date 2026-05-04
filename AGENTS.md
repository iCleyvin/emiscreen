# Emiscreen

One-command WebRTC remote display: Linux/Windows → FireTV/browser.

## Quick Start

```bash
# Install (Linux/macOS/WSL)
curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash

# Install (Windows)
irm https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex

# Run
emiscreen
```

Then open **https://localhost:8445** in your browser.

## Start Server (after install)

```bash
emiscreen --firetv 192.168.1.100  # with FireTV
emiscreen --source nas-omv        # headless NAS (Xvfb display :99)
emiscreen --source windows-pc     # Windows capture
```

## Important Quirks

- **Port 8445** — port 8443 is taken by Coolify on the production server
- **Source names**: `ubuntu-desktop` (x11grab), `windows-pc` (gdigrab), `nas-omv` (Xvfb `:99`)
  - Not "windows-desktop" or "ubuntu" — QA will fail
- **Package name is `av`** — not PyAV. PyAV not on PyPI for Python 3.12
- **SSL required** — WebRTC needs secure context. Auto-generates self-signed certs on first run if OpenSSL unavailable
- **Systemd service is user-level** — avoids `sudo`, won't conflict with Docker/Coolify

## Key Files

| File | Purpose |
|------|---------|
| `emiscreen/server.py` | aiohttp HTTPS + WebSocket signaling — main entrypoint |
| `emiscreen/webrtc.py` | aiortc peer connection + VideoStreamTrack |
| `emiscreen/capture/linux.py` | FFmpeg x11grab + Xvfb capture + FFmpegVideoTrack |
| `emiscreen/capture/windows.py` | FFmpeg gdigrab capture |
| `emiscreen/relay/adb.py` | ADB controller for FireTV |
| `emiscreen/relay/input.py` | WebSocket → xdotool input relay |
| `emiscreen/static/viewer.html` | Browser WebRTC client |
| `install.sh` / `install.ps1` | One-line installers (Linux/Windows) |
| `AGENT.md` | Full project documentation |

## Deployment

- **Production server**: `cleviserv@10.0.0.90`, path `/mnt/datos/dev/emiscreen`
- **Server**: SSH to `ubuntu-lan` (key `~/.ssh/ubuntu_server_key`)
- **NAS backup**: `root@10.0.0.14:/mnt/datos/backups/emiscreen/emiscreen_20260503/`
- Server has 80+ Docker containers — Docker commands must not break anything

## Testing

```bash
cd /mnt/datos/dev/emiscreen
source .venv/bin/activate
pytest tests/

# Single test
pytest tests/test_config.py -v
```

## No敏感 Data

- GitHub repo is public — no IPs, server names, or infrastructure references
- README/docs contain no real IPs or hostnames