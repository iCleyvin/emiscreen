# Emiscreen - NAS / OpenMediaVault Configuration

## Overview

For headless NAS environments (OpenMediaVault, TrueNAS, etc.), Emiscreen uses a virtual Xvfb display to capture and stream content.

## Setup on OMV/NAS

### 1. Install Dependencies

```bash
# On Debian/Ubuntu-based NAS
sudo apt install ffmpeg xdotool xvfb x11-utils python3 python3-pip python3-venv

# On OMV via SSH
# Enable SSH in OMV web interface, then SSH in
```

### 2. Install Emiscreen

```bash
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
./scripts/setup.sh
```

### 3. Start with Virtual Display

```bash
./scripts/start.sh --source nas-omv
```

This will:
1. Start Xvfb on display :99 (1920x1080)
2. Start FFmpeg capturing the virtual display
3. Stream via WebRTC to FireTV

### 4. Run Applications on Virtual Display

To run apps on the virtual display:

```bash
# Set DISPLAY to the virtual display
export DISPLAY=:99

# Run any X application
firefox &
chromium-browser &
vlc &
```

### Docker (Headless Mode)

```bash
docker compose --profile headless up -d
```

This starts both the Emiscreen server and Xvfb container.

## Use Cases

- **Dashboard display**: Show Grafana, Home Assistant, etc. on TV
- **Media center**: Run VLC/Kodi on virtual display
- **Monitoring**: Display system stats, logs, cameras
- **Kiosk mode**: Run a web browser in fullscreen
