# Emiscreen Setup Guide

## Prerequisites

### Server (Ubuntu/Debian)

- Python 3.10+
- FFmpeg
- xdotool (for input relay)
- ADB (for FireTV control)
- OpenSSL (for HTTPS)

### Server (Windows)

- Python 3.10+
- FFmpeg
- ADB (optional, for FireTV control)

### Target (FireTV)

- Fire TV Stick or Fire TV Edition
- Developer Options enabled
- ADB Debugging enabled

## Quick Start (Ubuntu)

### 1. Clone and Setup

```bash
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
./scripts/setup.sh
```

### 2. Connect FireTV

```bash
# Find your FireTV IP: Settings > My Fire TV > About > Network
./scripts/connect-firetv.sh 192.168.1.100
```

### 3. Start Server

```bash
./scripts/start.sh --source ubuntu-desktop --firetv 192.168.1.100
```

### 4. Done!

The FireTV browser will automatically open and display your Ubuntu desktop.

## Quick Start (Docker)

```bash
# With FireTV
FIRETV_IP=192.168.1.100 docker compose up -d

# Headless mode (NAS)
docker compose --profile headless up -d
```

## Quick Start (Windows)

```powershell
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
.\scripts\setup.ps1
.\scripts\start.ps1 -Source windows-desktop
```

Then manually open `https://<SERVER_IP>:8443` on the FireTV browser.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EMISCREEN_HOST` | Server bind address | `0.0.0.0` |
| `EMISCREEN_PORT` | Server port | `8443` |
| `EMISCREEN_SOURCE` | Capture source name | `ubuntu-desktop` |
| `EMISCREEN_RESOLUTION` | Capture resolution | `1920x1080` |
| `EMISCREEN_FPS` | Capture frame rate | `30` |
| `EMISCREEN_FIRETV_IP` | FireTV IP address | - |
| `EMISCREEN_TOKEN` | Auth token (optional) | - |

### Available Sources

| Source | Description | Platform |
|--------|-------------|----------|
| `ubuntu-desktop` | Physical Ubuntu display (:0) | Linux |
| `windows-pc` | Windows desktop via gdigrab | Windows |
| `nas-omv` | Virtual Xvfb display (:99) | Linux (headless) |

## Troubleshooting

### "Connection refused" on FireTV

- Check server is running: `curl -k https://localhost:8443/health`
- Check firewall: `sudo ufw allow 8443/tcp`
- Verify same network: `ping <SERVER_IP>` from FireTV

### "ADB device unauthorized"

- Check FireTV screen for authorization prompt
- Accept the ADB debugging request
- Re-run: `./scripts/connect-firetv.sh <IP>`

### Black screen on FireTV

- Check FFmpeg is capturing: `ffmpeg -f x11grab -i :0 -frames:v 1 test.png`
- Check browser console for WebRTC errors
- Try different codec: edit `config.py` to use `vp8`

### High latency

- Reduce resolution: `--resolution 1280x720`
- Reduce FPS: `--fps 24`
- Check network bandwidth
- Use wired connection instead of WiFi
