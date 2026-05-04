# Emiscreen — Navigation Flows & State Diagram

## App Launch Flow

```
App Starts
    │
    ├─── First run? ──YES──► Onboarding Wizard (01)
    │                              │
    │                         4 Steps:
    │                         1. Detect platform (auto)
    │                         2. Select source
    │                         3. Enter FireTV IP + Connect ADB
    │                         4. Done ──────────────────────► Dashboard (02)
    │
    └─── Not first run ──────────────────────────────────────► Dashboard (02)
              │
              └─── "Start minimized" ON ──► System Tray (07) only
```

---

## Main Navigation (Tab Bar)

```
┌─────────────────────────────────────────────────────────┐
│  [Dashboard]  [Source]  [🔥 FireTV]  [Stream]  [Settings] │
└─────────────────────────────────────────────────────────┘
      02           03         04          05         06
```

All tabs are always accessible. Tab `Stream` auto-activates when streaming starts.

---

## Dashboard (02) Actions

```
Dashboard (02)
    │
    ├─── Click "⏵ Start Stream"
    │         │
    │         ├─── FireTV connected? ──NO──► Toast: "Connect FireTV first" ──► FireTV tab (04)
    │         │
    │         └─── YES ──► Start FFmpeg + WebRTC ──► Tab changes to Stream (05)
    │                           │
    │                      Button becomes "⏹ Stop Stream" (red)
    │
    ├─── Click Source card ──────────────────────────────────► Source tab (03)
    │
    └─── Click FireTV card ──────────────────────────────────► FireTV tab (04)
```

---

## Source Configuration (03) Actions

```
Source (03)
    │
    ├─── Select device (Linux/Windows/NAS) ──► Updates capture params
    │
    ├─── Adjust sliders (Resolution/FPS/Bitrate) ──► Live preview updates
    │
    ├─── Select codec (H.264 / VP8)
    │
    ├─── Click "Test Capture" ──► Shows 3s preview in preview box
    │
    └─── Click "Apply & Save" ──► Saves config ──► Toast: "Source saved"
```

---

## FireTV Connect (04) — PRIMARY FLOW ★

```
FireTV (04)
    │
    ├─── User types IP address
    │
    ├─── Click "Connect ADB"
    │         │
    │         ├─── Connecting state:
    │         │    ADB dot ──► amber (pulsing)
    │         │
    │         ├─── SUCCESS:
    │         │    ADB ──► green ●
    │         │    Browser ──► green ●  (if auto-launch ON)
    │         │    Display ──► green ●  (if stay-awake ON)
    │         │    Input ──► green ●
    │         │    Log: "connected to IP:5555 ✓"
    │         │
    │         └─── FAILURE:
    │              ADB ──► red ●
    │              Log: error message
    │              Button resets
    │
    ├─── Click "Wake TV" ──► ADB command: input keyevent WAKEUP
    │
    ├─── Click "Launch Browser" ──► ADB am start → opens stream URL
    │
    ├─── Click "Pair (first run)" ──► Opens pairing dialog (enter code)
    │
    └─── Toggle "Auto-launch browser" ON ──► Browser auto-opens on ADB connect
```

---

## Stream Viewer (05) Controls

```
Stream Viewer (05)  [LIVE ●] [02:14:38]              [⏸][⏹][⚙][⛶]
    │
    ├─── ⏸ Pause ──► Pauses FFmpeg capture ──► Badge changes to [⏸ PAUSED]
    │         └─── Click again / ▶ Resume ──► Resumes stream
    │
    ├─── ⏹ Stop ──► Stops FFmpeg + closes WebRTC ──► Back to Dashboard (02)
    │         └─── Button "Start Stream" reappears
    │
    ├─── ⚙ Settings ──► Opens Settings tab (06)
    │
    ├─── ⛶ Fullscreen ──► Native OS fullscreen (F11 equivalent)
    │
    ├─── Mouse inactive 3s ──► Controls fade out (opacity: 0)
    │         └─── Mouse move ──► Controls reappear
    │
    └─── Stats overlay (bottom-right):
         Updates every 2s
         Latency < 100ms ──► green
         Latency 100-200ms ──► amber
         Latency > 200ms ──► red
```

---

## Settings (06) Actions

```
Settings (06)
    │
    ├─── Change Port ──► Requires restart to take effect ──► Toast warning
    │
    ├─── Browse SSL cert/key ──► OS file picker
    │
    ├─── Toggle "Enable token auth" ON ──► Shows token input field
    │
    ├─── Toggle "Launch at startup"
    │    ├─── Windows: adds to HKCU\Software\Microsoft\Windows\CurrentVersion\Run
    │    └─── Linux: creates ~/.config/autostart/emiscreen.desktop
    │
    ├─── Toggle "Start minimized to tray" ──► On next launch, goes to tray
    │
    └─── Click version link ──► Opens github.com/iCleyvin/emiscreen in browser
```

---

## System Tray (07) Flow

```
Taskbar tray icon [● EMISCREEN]
    │
    └─── Left/Right click ──► Opens tray popup
              │
              ├─── 📺 192.168.1.42 — FireTV ──► Brings window to front ──► FireTV tab (04)
              │
              ├─── ⏸ Pause Stream ──► Pauses (same as Stream viewer ⏸)
              │
              ├─── ⏹ Stop & Disconnect ──► Stops stream + disconnects ADB
              │
              ├─── ⛶ Open Window ──► Brings main window to front ──► Dashboard (02)
              │
              ├─── ⚙ Preferences ──► Brings window to front ──► Settings (06)
              │
              └─── Quit Emiscreen ──► Stops all processes + exits app
```

---

## Error States

| Situation | UI Response |
|---|---|
| ADB connection fails | ADB dot → red, log shows error, button resets |
| WebRTC ICE fails | Log: "ICE failed", toast error, retry button |
| FFmpeg capture error | Stream stops, log error, back to Dashboard |
| FireTV disconnects mid-stream | Log: "ADB lost", auto-reconnect if toggle ON |
| Latency > 200ms | Latency value turns red in stats |
| CPU > 80% | CPU value turns red in stats |
| Bitrate drops > 50% | Log: "Bitrate drop → Xmbps" in amber |

---

## Keyboard Shortcuts (suggested)

| Shortcut | Action |
|---|---|
| `Ctrl+S` | Start/Stop stream |
| `Ctrl+F` | Focus FireTV tab |
| `Ctrl+,` | Open Settings |
| `F11` | Toggle fullscreen (stream viewer) |
| `Escape` | Exit fullscreen |
| `Ctrl+Q` | Quit app |

---

## Window States

```
Normal window ──► User minimizes ──► Goes to taskbar
                        │
                        └─── "Start minimized" ON ──► Goes to tray icon instead

Tray icon only ──► Double-click ──► Restores window

App closes (X button) ──► Goes to tray (does NOT quit)
                              │
                              └─── Tray "Quit" ──► Actually quits
```
