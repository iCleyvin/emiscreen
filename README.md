# Emiscreen

**Remote Display via WebRTC** — Use your Fire TV (or any browser) as a wireless second monitor.

<p align="center">
  <strong>Turn any TV into a wireless monitor.</strong><br>
  <em>WebRTC · ~50-150ms latency · 1080p · Cross-Platform · Native Fire TV App</em>
</p>

---

## What Changed (v1.0)

- **Native Fire TV app** — No more browser SSL hassles. A dedicated Android app handles the stream in fullscreen with automatic certificate trust and proper D-Pad remote support.
- **Cross-platform input relay** — Keyboard, mouse, and Fire TV D-Pad now work on both **Linux (xdotool)** and **Windows (native SendInput via ctypes, zero extra dependencies)**.
- **Robust capture pipeline** — Unified FFmpeg → rawvideo YUV420P pipeline for both Linux and Windows. Removed the broken custom H.264 Annex-B decoder.
- **Better Web client** — Fixed key mappings, WebSocket ping/pong for connection health, automatic fullscreen, and a helpful SSL warning overlay for browser users.
- **Smart certificates** — Auto-generated self-signed certs now include your LAN IP in the Subject Alternative Name.

---

## Three Ways to Use Emiscreen

| Mode | What it does | Setup |
|------|--------------|-------|
| **Mirror** | Same screen on PC and TV | `Win + P` → Duplicate |
| **Extended** | TV becomes a *real* second monitor | Needs [Parsec VDD](https://github.com/nomi-san/parsec-vdd) (free) |
| **Solo TV** | PC screen off, TV only | Close lid or disable internal display |

> **Full guide:** [docs/MODES.md](docs/MODES.md) — Choose the mode that fits your workflow.

---

## Quick Start

### 1. Install Server (PC)

**Linux / macOS / WSL:**
```bash
curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
```

### 2. Run Server

```bash
# Linux
emiscreen --source ubuntu-desktop

# Windows (mirror mode — easiest)
emiscreen --source windows-pc

# Windows (extended mode — capture only the virtual monitor)
emiscreen --source windows-pc --display 2

# With Fire TV ADB auto-launch (optional)
emiscreen --source windows-pc --firetv 192.168.1.100
```

### 3. Connect Fire TV

**Recommended: Native App**
1. Build and sideload the `firetv-app/` Android project (see [FIRETV.md](docs/FIRETV.md)).
2. Open the app, enter your PC's IP address once, and it connects automatically.

**Alternative: Browser**
- Open `https://<PC_IP>:8445` in Silk or Firefox on your Fire TV.
- If you see a certificate warning, choose **Advanced → Proceed**.

---

## Options

```bash
emiscreen --source ubuntu-desktop   # linux | windows-pc | nas-omv
emiscreen --firetv 192.168.1.100     # Auto-launch browser via ADB
emiscreen --resolution 1280x720      # Capture resolution
emiscreen --fps 24                   # Frame rate
emiscreen --port 8445                 # Server port
emiscreen --no-adb                    # Disable ADB control
emiscreen --no-relay                  # Disable input relay
emiscreen --verbose                   # Debug logging
```

---

## Features

- **Three usage modes** — Mirror, Extended (real second monitor), or Solo TV
- **Ultra-low latency** — Direct WebRTC peer-to-peer (~50-150ms)
- **Multi-source capture** — Linux (`x11grab`), Windows (`gdigrab`), Headless NAS (`Xvfb`)
- **Multi-monitor support** — Capture all displays, or select one with `--display 1|2`
- **Cross-platform input relay** — Linux (`xdotool`) + Windows (`SendInput` native)
- **Native Fire TV app** — Kotlin, WebView, ignores SSL, D-Pad passthrough, settings screen
- **Web client fallback** — Works in any modern browser with auto-reconnect
- **Smart SSL** — Auto-generated certs include your LAN IP
- **Docker ready** — Dockerfile + docker-compose included

---

## Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  SOURCE      │────▶│  EMISCREEN       │────▶│  TARGET          │
│  (Desktop)   │     │  SERVER          │     │  (Fire TV /      │
│              │     │                  │     │   Browser)       │
│  FFmpeg      │     │  aiortc +        │     │                  │
│  x11grab/    │     │  aiohttp         │     │  Native App or   │
│  gdigrab     │     │                  │     │  WebRTC Receiver │
└──────────────┘     └──────────────────┘     └──────────────────┘
                            │
                     WebSocket Input
                            │
              Linux: xdotool  |  Windows: SendInput
```

---

## Fire TV Setup

### Native App (Recommended)
1. Clone this repo.
2. Open `firetv-app/` in Android Studio.
3. Build APK: **Build → Build Bundle(s) / APK(s) → Build APK(s)**.
4. Sideload to Fire TV:
   ```bash
   adb connect 192.168.1.100:5555
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```
5. Launch **Emiscreen** from your Fire TV apps list.

### Browser (Fallback)
1. **Enable Developer Options**: Settings → My Fire TV → About → Click device name 7 times
2. **Enable ADB Debugging**: Settings → My Fire TV → Developer Options → ADB Debugging = ON
3. The server can auto-launch Silk/Firefox when started with `--firetv <IP>`.

---

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

---

## Performance

| Metric | Target |
|--------|--------|
| Video latency (P95) | <150ms |
| Input latency (P95) | <50ms |
| Frame rate | 24-30 fps |
| Resolution | Up to 1920×1080 |
| Server CPU | <25% |

---

## Documentation

- **[Usage Modes](docs/MODES.md)** — Mirror, Extended, or Solo TV: which one to choose
- [Setup Guide](docs/SETUP.md) — Installation and configuration
- [FireTV Config](docs/FIRETV.md) — FireTV app build & D-Pad mapping
- [Windows Config](docs/WINDOWS.md) — Windows deployment & Parsec VDD setup
- [NAS Config](docs/NAS.md) — Headless NAS / OpenMediaVault setup
- [Architecture](docs/ARCHITECTURE.md) — Component diagram and data flow
- [Development](docs/DEVELOPMENT.md) — Contributing and debugging
- [API Reference](docs/API.md) — HTTP endpoints and WebSocket protocol

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | Python 3.10+, aiohttp |
| WebRTC | aiortc (pure Python) |
| Capture | FFmpeg (x11grab / gdigrab) → rawvideo YUV420P |
| Input | xdotool (Linux), SendInput/ctypes (Windows) |
| Fire TV App | Kotlin, Android WebView |
| Web Client | Vanilla HTML/JS/CSS |
| Container | Docker + docker-compose |

---

## License

Apache 2.0 — See [LICENSE](LICENSE)

---

## Support

If Emiscreen has been useful to you, consider supporting the project. Every contribution helps keep development active!

<p align="center">
  <a href="https://www.paypal.com/donate/?hosted_button_id=UMBEQY4YL27LU">
    <img src="https://img.shields.io/badge/Donate-PayPal-blue.svg?style=for-the-badge&logo=paypal" alt="Donate with PayPal" />
  </a>
</p>

---

**by Cleyvin** © 2026
