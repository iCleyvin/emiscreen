# Emiscreen - Fire TV Configuration Guide

## Recommended: Native Emiscreen App

The native Android app provides the best experience:
- **No SSL certificate warnings** — the app trusts the self-signed certificate automatically.
- **Proper D-Pad support** — remote keys are injected directly into the WebRTC client.
- **Fullscreen with no browser chrome** — pure leanback experience.
- **Easy configuration** — enter your PC's IP once, it remembers it.

### Build & Install

1. **Open the project** in Android Studio:
   ```
   firetv-app/
   ```

2. **Build the APK**:
   ```
   Build → Build Bundle(s) / APK(s) → Build APK(s)
   ```

3. **Sideload to your Fire TV**:
   ```bash
   adb connect 192.168.1.100:5555
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

4. **Launch** the Emiscreen app from your Fire TV home screen.

5. **Enter your PC's IP** when prompted (e.g., `192.168.1.50`).

### Changing Server IP

Press the **Menu** button (≡) on the Fire TV remote while the app is open to bring up the IP settings dialog again.

---

## Alternative: Browser

If you prefer not to install the native app, you can use Silk or Firefox.

### Enable Developer Options on Fire TV

1. Go to **Settings** > **My Fire TV** > **About**
2. Click on your Fire TV device name **7 times** until you see "You are now a developer"
3. Go back to **Settings** > **My Fire TV** > **Developer Options**
4. Enable **ADB Debugging**
5. (Optional) Enable **Install Unknown Apps** for your browser

### Find Fire TV IP Address

1. **Settings** > **My Fire TV** > **About** > **Network**
2. Note the IP address (e.g., `192.168.1.100`)

### Connect via ADB

```bash
./scripts/connect-firetv.sh 192.168.1.100
```

This will:
- Connect ADB over TCP/IP
- Enable screen stay-awake
- Disable screensaver
- Set screen timeout to 30 minutes

### Supported Browsers

| Browser | Support | Notes |
|---------|---------|-------|
| Silk Browser | Full | Default on FireTV; may show SSL warning |
| Firefox for Fire TV | Full | Better WebRTC support; may show SSL warning |
| Chrome (sideloaded) | Partial | May have codec issues |

> **Note:** When using a browser, you will see a certificate warning because Emiscreen uses a self-signed certificate. Choose **Advanced → Proceed** to continue. The native app avoids this entirely.

---

## D-Pad Mapping

Whether using the native app or browser, the Fire TV remote D-Pad is mapped as follows:

| Button | Action |
|--------|--------|
| D-Pad Up | Mouse up (20px) |
| D-Pad Down | Mouse down (20px) |
| D-Pad Left | Mouse left (20px) |
| D-Pad Right | Mouse right (20px) |
| Select/Center | Left click / Enter |
| Back | Escape key |
| Menu | Open settings (native app) |
| Play/Pause | Space bar |

---

## Auto-Launch (Browser Only)

When you start the Emiscreen server with `--firetv <IP>`, it will:
1. Wake the Fire TV via ADB
2. Launch the Silk browser
3. Navigate to the stream URL

This does not apply to the native app, which you launch manually from the Fire TV home screen.

---

## Static IP Recommendation

For reliable operation, set a static IP for your Fire TV (and your PC) in your router's DHCP settings.
