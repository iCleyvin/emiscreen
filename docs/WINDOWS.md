# Windows-specific configuration for Emiscreen

## Prerequisites

1. **Python 3.10+**: Download from [python.org](https://python.org)
2. **FFmpeg**: Install via winget or download from [ffmpeg.org](https://ffmpeg.org)
   ```powershell
   winget install ffmpeg
   ```
3. **ADB (optional)**: For FireTV control
   ```powershell
   winget install AndroidSDKPlatformTools
   ```

## Setup

```powershell
cd emiscreen
.\scripts\setup.ps1
```

## Run

```powershell
.\scripts\start.ps1 -Source windows-pc
```

Or directly after installation:
```powershell
emiscreen --source windows-pc
```

## Using a Virtual Display (Extended Desktop Mode)

To use your Fire TV as a **real extended monitor** (separate from your main screen), Windows needs a virtual display driver. Emiscreen integrates seamlessly with **Parsec VDD**.

### 1. Install Parsec VDD

1. Download `ParsecVDisplay-v0.45-setup.exe` from the [Parsec VDD releases](https://github.com/nomi-san/parsec-vdd/releases)
2. Run the installer as Administrator
3. Open **ParsecVDisplay** from the Start Menu
4. Click **Add display** — a virtual monitor appears

### 2. Verify Windows sees it

```powershell
.\scripts\list-monitors.ps1
```

You should see 2 monitors:
```
Connected monitors:
  1: Monitor1 (1920x1080 @ 60Hz)
  2: Monitor2 (1920x1080 @ 60Hz)
```

### 3. Start Emiscreen on the virtual monitor

```powershell
# Capture only the virtual display (monitor 2)
emiscreen --source windows-pc --display 2
```

Now drag any window past the edge of your PC screen and it will appear on the Fire TV.

### Quick mode switching

| Mode | Windows shortcut | Emiscreen command |
|------|------------------|-------------------|
| Mirror | `Win + P` → Duplicate | `emiscreen --source windows-pc` |
| Extended | `Win + P` → Extend | `emiscreen --source windows-pc --display 2` |
| Solo TV | `Win + P` → Second screen only | `emiscreen --source windows-pc --display 2` |

## Notes

- **Input relay**: Fully supported on Windows via native `SendInput` API (`ctypes`). No extra dependencies required.
- **Capture**: Uses FFmpeg `gdigrab` which captures the desktop framebuffer directly. Works even when the server runs as a background service.
- **Fire TV control**: If ADB is installed, Fire TV auto-launch works on Windows too.
- **Certificates**: The first time you run Emiscreen, it will generate a self-signed certificate. To avoid browser warnings on your PC, run:
  ```powershell
  .\scripts\trust-cert.ps1
  ```

## Running as a Service

To run Emiscreen as a Windows service, use NSSM:

```powershell
# Download NSSM from nssm.cc
nssm install Emiscreen "C:\path\to\emiscreen\.venv\Scripts\python.exe" "-m emiscreen.server --source windows-pc"
nssm start Emiscreen
```

## Troubleshooting

### "Parsec VDD monitor not detected"
- Ensure ParsecVDisplay is running and you clicked **Add display**
- Try restarting ParsecVDisplay after adding the display
- Run `list-monitors.ps1` to confirm Windows sees it

### "Black screen on Fire TV but connection works"
- Verify which monitor you're capturing: `--display 1` vs `--display 2`
- If the virtual monitor is off-screen or has no content, the capture will be black. Move a window to it first.

### "High CPU usage"
- Lower resolution: `--resolution 1280x720`
- Lower FPS: `--fps 20`
- Use `--quality fast` preset
