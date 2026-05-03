# Emiscreen

**Remote Display via WebRTC** — Cast any desktop to any FireTV or browser with near-zero latency.

<p align="center">
  <strong>Turn any TV into a wireless monitor.</strong><br>
  <em>WebRTC · ~50ms latency · 1080p · Open Source</em>
</p>

<p align="center">
  <a href="https://www.paypal.com/donate/?hosted_button_id=&business=cleyvinos@gmail.com&currency_code=USD">
    <img src="https://img.shields.io/badge/Donate-PayPal-blue.svg?style=for-the-badge&logo=paypal" alt="Donate with PayPal" />
  </a>
</p>

> This project is free and open source. If you find it useful, consider supporting the developer!

---

## Features

- **Ultra-low latency** — ~50-150ms via direct WebRTC peer-to-peer
- **Multi-source** — Linux (x11grab), Windows (gdigrab), Headless NAS (Xvfb)
- **Full input relay** — Keyboard, mouse, touch, and FireTV D-Pad → xdotool/ADB
- **FireTV native** — ADB auto-connect, wake, browser auto-launch, D-Pad mapping
- **Zero install on target** — Only a browser needed on the receiving device
- **Docker ready** — Includes Dockerfile and docker-compose with headless profile

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

## Quick Start

### Linux (Ubuntu/Debian)

```bash
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
./scripts/setup.sh
./scripts/start.sh --source ubuntu-desktop --firetv <FIRETV_IP>
```

### Windows

```powershell
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
.\scripts\setup.ps1
.\scripts\start.ps1 -Source windows-pc
```

### Docker

```bash
# Standard mode (with X11 display)
docker compose up -d

# Headless mode (NAS, no display)
docker compose --profile headless up -d
```

## FireTV Setup

1. **Enable Developer Options**: Settings → My Fire TV → About → Click device name 7 times
2. **Enable ADB Debugging**: Settings → My Fire TV → Developer Options → ADB Debugging = ON
3. **Find IP**: Settings → My Fire TV → About → Network
4. **Connect**: `./scripts/connect-firetv.sh <FIRETV_IP>`

The server will auto-launch the browser on the FireTV when started with `--firetv`.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EMISCREEN_PORT` | Server port | `8445` |
| `EMISCREEN_SOURCE` | Capture source | `ubuntu-desktop` |
| `EMISCREEN_RESOLUTION` | Capture resolution | `1920x1080` |
| `EMISCREEN_FPS` | Frame rate | `30` |
| `EMISCREEN_FIRETV_IP` | FireTV IP for auto-launch | — |

### Available Sources

| Source | Platform | Description |
|--------|----------|-------------|
| `ubuntu-desktop` | Linux | Physical display `:0` via x11grab |
| `windows-pc` | Windows | Full desktop via gdigrab |
| `nas-omv` | Linux | Virtual Xvfb display `:99` (headless) |

## Performance

| Metric | Target |
|--------|--------|
| Video latency (P95) | <150ms |
| Input latency (P95) | <50ms |
| Frame rate | 24-30 fps |
| Resolution | Up to 1920×1080 |
| Bandwidth | 2-8 Mbps (H.264) |
| Server CPU | <25% |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — Component diagram and data flow
- [Setup Guide](docs/SETUP.md) — Installation and configuration
- [FireTV Config](docs/FIRETV.md) — FireTV-specific setup and D-Pad mapping
- [Windows Config](docs/WINDOWS.md) — Windows deployment guide
- [NAS Config](docs/NAS.md) — Headless NAS / OpenMediaVault setup
- [Development](docs/DEVELOPMENT.md) — Contributing and debugging
- [API Reference](docs/API.md) — HTTP endpoints and WebSocket protocol

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | Python 3.10+, aiohttp |
| WebRTC | aiortc (pure Python) |
| Capture | FFmpeg (x11grab / gdigrab) |
| Input | xdotool (Linux), ADB (FireTV) |
| Client | Vanilla HTML/JS/CSS (no framework) |
| Container | Docker + docker-compose |

## Support the Project

If Emiscreen has been useful to you, consider making a donation. Every contribution helps keep the project alive!

<p align="center">
  <a href="https://www.paypal.com/donate/?hosted_button_id=&business=cleyvinos@gmail.com&currency_code=USD">
    <img src="https://img.shields.io/badge/Donate-PayPal-blue.svg?style=for-the-badge&logo=paypal" alt="Donate with PayPal" />
  </a>
</p>

## License

Apache 2.0 — See [LICENSE](LICENSE)

---

**by Cleyvin** © 2026
