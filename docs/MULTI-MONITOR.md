# Multi-Monitor Guide

> This page has been superseded by **[Usage Modes](MODES.md)** which covers Mirror, Extended, and Solo TV modes in detail.

This document remains as a quick Windows-specific cheat sheet.

---

## Quick Commands

```powershell
# List detected monitors
.\scripts\list-monitors.ps1

# Capture all monitors (mirror / desktop)
emiscreen --source windows-pc

# Capture only monitor 1 (primary)
emiscreen --source windows-pc --display 1

# Capture only monitor 2 (secondary / virtual)
emiscreen --source windows-pc --display 2
```

## Mode Switching with Win + P

| Key combo | Mode | Emiscreen command |
|-----------|------|-------------------|
| `Win + P` → PC screen only | Solo PC | `emiscreen --source windows-pc --display 1` |
| `Win + P` → Duplicate | Mirror | `emiscreen --source windows-pc` |
| `Win + P` → Extend | Extended | `emiscreen --source windows-pc --display 2` |
| `Win + P` → Second screen only | Solo TV | `emiscreen --source windows-pc --display 2` |

## Moving Windows Between Monitors

- **Mouse**: Drag window past screen edge
- **Keyboard**: `Win + Shift + Left/Right`

## Extended Mode with Virtual Display

For a *real* extended desktop (separate windows, drag-and-drop), you need a virtual display driver. See:

- **[Usage Modes: Extended](MODES.md#mode-2-extended-desktop-extendido--most-powerful)**
- **[Windows Config](WINDOWS.md#using-a-virtual-display-extended-desktop-mode)**

---

For full setup instructions, see [MODES.md](MODES.md).
