# Emiscreen - FireTV Configuration Guide

## Enable Developer Options on FireTV

1. Go to **Settings** > **My Fire TV** > **About**
2. Click on your Fire TV device name **7 times** until you see "You are now a developer"
3. Go back to **Settings** > **My Fire TV** > **Developer Options**
4. Enable **ADB Debugging**
5. (Optional) Enable **Install Unknown Apps** for your browser

## Find FireTV IP Address

1. **Settings** > **My Fire TV** > **About** > **Network**
2. Note the IP address (e.g., `192.168.1.100`)

## Connect via ADB

```bash
./scripts/connect-firetv.sh 192.168.1.100
```

This will:
- Connect ADB over TCP/IP
- Enable screen stay-awake
- Disable screensaver
- Set screen timeout to 30 minutes

## Supported Browsers

| Browser | Support | Notes |
|---------|---------|-------|
| Silk Browser | Full | Default on FireTV |
| Firefox for Fire TV | Full | Better WebRTC support |
| Chrome (sideloaded) | Partial | May have codec issues |

## D-Pad Mapping

The FireTV remote D-Pad is mapped to mouse movement:

| Button | Action |
|--------|--------|
| D-Pad Up | Mouse up (20px) |
| D-Pad Down | Mouse down (20px) |
| D-Pad Left | Mouse left (20px) |
| D-Pad Right | Mouse right (20px) |
| Select/Center | Left click |
| Back | Right click / Escape |
| Menu | Context menu |
| Play/Pause | Space bar |

## Auto-Launch

When you start the Emiscreen server with `--firetv <IP>`, it will:
1. Wake the FireTV
2. Launch the Silk browser
3. Navigate to the stream URL

## Static IP Recommendation

For reliable operation, set a static IP for your FireTV in your router's DHCP settings.
