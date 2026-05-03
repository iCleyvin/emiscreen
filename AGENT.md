# Emiscreen — Project Documentation

## Overview

**Emiscreen** is a WebRTC-based remote display system that streams a source screen (Ubuntu, Windows, or headless NAS) to any browser (FireTV, Chrome, Firefox) with low latency (~50-150ms). It enables using a FireTV as a wireless monitor with full keyboard/mouse/D-Pad relay.

**Repository:** https://github.com/iCleyvin/emiscreen
**License:** Apache 2.0
**Author:** Cleyvin © 2026

---

## Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  SOURCE      │────▶│  EMISCREEN       │────▶│  TARGET      │
│  (Desktop)   │     │  SERVER          │     │  (Browser)   │
│              │     │                  │     │              │
│  FFmpeg      │     │  aiortc +        │     │  WebRTC      │
│  x11grab/    │     │  aiohttp         │     │  Receiver    │
│  gdigrab     │     │                  │     │  (HTML/JS)   │
└──────────────┘     └──────────────────┘     └──────────────┘
                            │
                     WebSocket Input
                            │
                      xdotool / ADB
```

### Core Components

| File | Purpose |
|------|---------|
| `emiscreen/server.py` | Main server — aiohttp HTTPS + WebSocket signaling |
| `emiscreen/webrtc.py` | WebRTC peer connection + VideoStreamTrack |
| `emiscreen/capture/linux.py` | FFmpeg x11grab + Xvfb capture + FFmpegVideoTrack |
| `emiscreen/capture/windows.py` | FFmpeg gdigrab capture for Windows |
| `emiscreen/relay/input.py` | WebSocket input relay to xdotool |
| `emiscreen/relay/adb.py` | ADB controller for FireTV control |
| `emiscreen/static/viewer.js` | Browser WebRTC client with D-Pad mapping |
| `emiscreen/config.py` | Configuration management |

---

## Installation

### One-Line Install (Recommended)

**Linux / macOS / WSL:**
```bash
curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
```

**With FireTV:**
```bash
# Linux
curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash -s -- --firetv 192.168.1.100

# Windows
iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex -FireTV "192.168.1.100"
```

### Manual Setup

See [docs/SETUP.md](docs/SETUP.md) for detailed instructions.

---

## Quick Start

### Start Server

```bash
# Linux with physical display
source .venv/bin/activate
python -m emiscreen.server --source ubuntu-desktop --firetv 192.168.1.100

# Linux headless (NAS)
python -m emiscreen.server --source nas-omv

# Windows
.\.venv\Scripts\Activate.ps1
python -m emiscreen.server --source windows-pc

# Docker
docker compose up -d
docker compose --profile headless up -d
```

### Connect FireTV

1. Enable Developer Options: Settings → My Fire TV → About → Click device name 7 times
2. Enable ADB Debugging: Settings → My Fire TV → Developer Options → ADB Debugging = ON
3. Find IP: Settings → My Fire TV → About → Network
4. Connect:
```bash
./scripts/connect-firetv.sh 192.168.1.100
```

### Access

- Open `https://<SERVER_IP>:8445` in any browser
- FireTV: The browser auto-launches when server starts with `--firetv`

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EMISCREEN_HOST` | Server bind address | `0.0.0.0` |
| `EMISCREEN_PORT` | Server port | `8445` |
| `EMISCREEN_SOURCE` | Capture source | `ubuntu-desktop` |
| `EMISCREEN_RESOLUTION` | Capture resolution | `1920x1080` |
| `EMISCREEN_FPS` | Frame rate | `30` |
| `EMISCREEN_FIRETV_IP` | FireTV IP address | — |
| `EMISCREEN_TOKEN` | Auth token (optional) | — |

### Available Sources

| Source | Platform | Description |
|--------|----------|-------------|
| `ubuntu-desktop` | Linux | Physical display `:0` via x11grab |
| `windows-pc` | Windows | Full desktop via gdigrab |
| `nas-omv` | Linux | Virtual Xvfb display `:99` (headless) |

### Command-Line Options

```bash
python -m emiscreen.server [OPTIONS]

Options:
  --source SOURCE    Capture source (ubuntu-desktop, windows-pc, nas-omv)
  --firetv IP        FireTV IP address for ADB control
  --resolution RES   Capture resolution (e.g., 1920x1080)
  --fps N            Capture frame rate
  --no-adb           Disable ADB/FireTV control
  --no-relay         Disable input relay
  --verbose          Enable debug logging
  --help             Show help
```

---

## Files Structure

```
emiscreen/
├── __init__.py
├── server.py          # aiohttp HTTPS server + WebRTC signaling
├── webrtc.py          # aiortc peer connection management
├── config.py          # Configuration management
├── capture/
│   ├── __init__.py
│   ├── linux.py       # x11grab + Xvfb FFmpeg capture
│   └── windows.py     # gdigrab FFmpeg capture
├── relay/
│   ├── __init__.py
│   ├── input.py       # WebSocket → xdotool input relay
│   └── adb.py         # ADB FireTV controller
├── static/
│   ├── index.html    # Browser client UI
│   ├── viewer.js     # WebRTC receiver + input capture
│   └── style.css     # Minimal styling
└── resources/
    └── (optional assets)

scripts/
├── install.sh         # One-line Linux installer
├── install.ps1        # One-line Windows installer
├── setup.sh           # Manual setup Linux
├── setup.ps1          # Manual setup Windows
├── start.sh           # Start server Linux
├── start.ps1          # Start server Windows
├── connect-firetv.sh  # ADB FireTV connection
└── generate-certs.sh # SSL certificate generation

docs/
├── ARCHITECTURE.md    # Detailed architecture
├── SETUP.md           # Setup guide
├── FIRETV.md          # FireTV configuration
├── WINDOWS.md         # Windows deployment
├── NAS.md             # Headless NAS setup
├── DEVELOPMENT.md     # Contributing/debugging
└── API.md             # HTTP/WebSocket API

other/
├── requirements.txt   # Python dependencies
├── pyproject.toml     # Project metadata
├── docker-compose.yml  # Docker configuration
├── Dockerfile          # Container image
├── install.sh         # One-line installer (Linux/macOS)
├── install.ps1        # One-line installer (Windows)
└── emiscreen.service  # Systemd user service
```

---

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **Port 8445** | Changed from default 8443 to avoid conflict with Coolify on production server |
| **`av` not PyAV** | PyAV not available on PyPI for Python 3.12 |
| **`nas-omv` default** | Xvfb display `:99` already present on server |
| **User systemd service** | Avoids `sudo`, won't interfere with Docker/coolify |
| **Self-signed SSL** | WebRTC requires secure context; auto-generated |
| **H.264 codec** | Hardware decode on FireTV, better compression than VP8 |
| **aiortc (pure Python)** | No native WebRTC libraries needed, works in venv |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Video latency (P95) | <150ms |
| Input latency (P95) | <50ms |
| Frame rate | 24-30 fps |
| Resolution | Up to 1920×1080 |
| Bandwidth | 2-8 Mbps (H.264) |
| Server CPU | <25% |

---

## Deployment Context

- **Local PC (Windows):** Read-only, code/structure only. No compilation.
- **Compilation/Deployment:** On `cleviserv@10.0.0.90` via SSH
- **Production server:** 80+ Docker containers, must not break anything
- **Server location:** `/mnt/datos/dev/emiscreen`
- **Backup location:** `/mnt/datos/backups/emiscreen/emiscreen_20260503/`

---

## Security Notes

- WebRTC requires HTTPS (secure context)
- Self-signed certificates auto-generated on first run
- Server binds to local network only (no internet exposure)
- ADB auth requires physical confirmation on FireTV first time
- Optional token auth via `EMISCREEN_TOKEN` env var

---

## Troubleshooting

### "Connection refused" on FireTV
- Check server is running: `curl -k https://localhost:8445/health`
- Check firewall: `sudo ufw allow 8445/tcp`
- Verify same network: `ping <SERVER_IP>` from FireTV

### "ADB device unauthorized"
- Check FireTV screen for authorization prompt
- Accept the ADB debugging request
- Re-run: `./scripts/connect-firetv.sh <IP>`

### Black screen on FireTV
- Check FFmpeg is capturing: `ffmpeg -f x11grab -i :0 -frames:v 1 test.png`
- Check browser console for WebRTC errors
- Try different codec in `webrtc.py`

### High latency
- Reduce resolution: `--resolution 1280x720`
- Reduce FPS: `--fps 24`
- Use wired connection instead of WiFi

---

## WebRTC Flow

1. Browser opens `https://<server>:8445`
2. Browser POSTs SDP offer to `/offer`
3. Server creates aiortc RTCPeerConnection, sets remote description
4. Server generates SDP answer, POSTs back via WebSocket
5. ICE candidates exchanged via WebSocket
6. Direct P2P connection established
7. Video flows via RTP/RTCP (SRTP encrypted)
8. Input events sent via WebSocket to server, relayed to xdotool

---

## Related Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — Component diagram and data flow
- [SETUP.md](docs/SETUP.md) — Installation and configuration
- [FIRETV.md](docs/FIRETV.md) — FireTV-specific setup and D-Pad mapping
- [WINDOWS.md](docs/WINDOWS.md) — Windows deployment guide
- [NAS.md](docs/NAS.md) — Headless NAS / OpenMediaVault setup
- [DEVELOPMENT.md](docs/DEVELOPMENT.md) — Contributing and debugging
- [API.md](docs/API.md) — HTTP endpoints and WebSocket protocol