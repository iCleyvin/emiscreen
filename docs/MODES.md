# Emiscreen — Usage Modes Guide

Emiscreen supports three distinct ways to use your Fire TV as a display. Choose the one that fits your workflow.

| Mode | Use Case | Windows Setup | Input Relay |
|------|----------|---------------|-------------|
| **Mirror** (Duplicar) | Show the same screen on both PC and TV | `Win + P` → **Duplicate** | Full support |
| **Extended** (Extendido) | Use TV as a *real* second monitor | Virtual Display Driver (Parsec VDD) | Full support |
| **Solo TV** | TV becomes your only screen | Close laptop lid / disable internal display | Full support |

---

## Mode 1: Mirror (Duplicar) — Easiest

The same image appears on your PC monitor **and** your Fire TV simultaneously.

### When to use
- Presentations
- Watching movies with others
- Quick sharing without setup

### Setup
1. On your PC, press `Win + P`
2. Select **Duplicate**
3. Start Emiscreen:
   ```powershell
   emiscreen --source windows-pc
   ```
4. Open the Emiscreen app on your Fire TV and enter your PC's IP.

### Behavior
- Everything you do on the PC is visible on the TV
- Good latency, zero configuration
- Audio stays on the PC (or use Bluetooth to TV if desired)

---

## Mode 2: Extended Desktop (Extendido) — Most Powerful

Use your Fire TV as a **real extended monitor**. You can drag windows to the TV, work on the PC, and keep apps separate.

> **Why this mode needs a driver:** Windows cannot create a virtual monitor without a kernel-mode display driver. Emiscreen integrates with **Parsec VDD** (open-source, trusted) to add a software display that Windows treats as a real monitor.

### Prerequisites
- Windows 10/11 64-bit
- [Parsec VDD](https://github.com/nomi-san/parsec-vdd) installed

### Step 1: Install Parsec VDD

1. Download `ParsecVDisplay-v0.45-setup.exe` from the [releases page](https://github.com/nomi-san/parsec-vdd/releases)
2. Run the installer as Administrator
3. Open **ParsecVDisplay** from the Start Menu
4. Click **Add display** — a virtual monitor appears in Windows

### Step 2: Set Windows to Extend mode

1. Press `Win + P`
2. Select **Extend**
3. (Optional) Open Display Settings and arrange the virtual monitor to match your physical layout

### Step 3: Detect monitors in Emiscreen

```powershell
.\scripts\list-monitors.ps1
```

Expected output:
```
Connected monitors:
  1: Monitor1 (1920x1080 @ 60Hz)
  2: Monitor2 (1920x1080 @ 60Hz)
```

### Step 4: Capture only the virtual monitor

```powershell
# Capture ONLY the virtual display (monitor 2)
emiscreen --source windows-pc --display 2
```

### Step 5: Use it

- Drag any window past the edge of your PC screen → it appears on the Fire TV
- Shortcuts:
  - `Win + Shift + Left/Right` — Move active window between monitors
  - `Win + P` — Quickly switch projection modes

### Recommended settings for Extended mode

```powershell
# Balanced quality (good for WiFi)
emiscreen --source windows-pc --display 2 --quality balanced

# Maximum quality (if wired or very strong WiFi)
emiscreen --source windows-pc --display 2 --quality quality

# Low latency mode (gaming)
emiscreen --source windows-pc --display 2 --quality fast --fps 30
```

---

## Mode 3: Solo TV (Solo pantalla)

Turn off your PC's built-in display and use **only** the Fire TV as your monitor.

### When to use
- Your laptop screen is broken
- You want a large-screen-only workspace
- Saving power by disabling the internal panel

### Setup

**Option A: Close the laptop lid**
1. Connect power adapter (so the PC doesn't sleep)
2. Go to **Control Panel → Power Options → Choose what closing the lid does**
3. Set **When I close the lid** → **Do nothing**
4. Close the lid — output switches to the external (virtual) display
5. Start Emiscreen capturing that display:
   ```powershell
   emiscreen --source windows-pc --display 2
   ```

**Option B: Disable internal display via Settings**
1. `Win + P` → **Second screen only**
2. Start Emiscreen:
   ```powershell
   emiscreen --source windows-pc --display 2
   ```

> **Note:** If you only have one physical monitor and want Solo TV mode, you need Parsec VDD (same as Extended mode) so Windows still has a "display" to capture.

---

## Quick Reference: Choosing a Mode

| I want to... | Choose | Needs Parsec VDD? |
|--------------|--------|-------------------|
| Show my screen on the TV | **Mirror** | No |
| Use TV as a second monitor with separate windows | **Extended** | Yes |
| Turn off my laptop screen and use only the TV | **Solo TV** | Yes (if no other display) |
| Play games on the TV while browsing on the PC | **Extended** | Yes |
| Give a presentation | **Mirror** | No |

---

## Multi-Monitor Commands

| Command | What it does |
|---------|--------------|
| `emiscreen --source windows-pc` | Capture entire desktop (all monitors) |
| `emiscreen --source windows-pc --display 1` | Capture only primary monitor |
| `emiscreen --source windows-pc --display 2` | Capture only secondary monitor |
| `.\scripts\list-monitors.ps1` | List detected monitors with IDs |

---

## Troubleshooting by Mode

### Mirror: "I see the same thing but it's cropped"
- The PC and TV have different aspect ratios. Emiscreen uses `object-fit: contain` to preserve aspect ratio. This is normal.

### Extended: "Windows doesn't see a second monitor"
- Make sure Parsec VDD is installed and you clicked **Add display**
- Run `list-monitors.ps1` to verify Windows detects it
- Restart ParsecVDisplay if needed

### Extended: "FFmpeg says capture area extends outside window"
- This means the detected monitor coordinates don't match the real desktop. Update Emiscreen to the latest version — it uses `GetMonitorInfo` to read the exact Windows virtual-desktop coordinates.

### Solo TV: "Screen goes black when I close the laptop"
- Go to Power Options and set lid close action to **Do nothing**
- Make sure the PC is plugged in

### All modes: "High latency or stuttering"
- Lower resolution: `--resolution 1280x720`
- Lower FPS: `--fps 24`
- Use `--quality fast` preset
- Ensure both devices are on the same 5GHz WiFi band or use Ethernet

---

## See Also

- [Windows Setup](WINDOWS.md) — Windows-specific installation
- [Fire TV Setup](FIRETV.md) — Building and installing the native app
- [Setup Guide](SETUP.md) — General server setup
