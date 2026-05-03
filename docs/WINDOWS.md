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

## Notes

- **Input relay**: xdotool is Linux-only. On Windows, input relay is not available.
- **Capture**: Uses FFmpeg gdigrab which captures the entire desktop.
- **FireTV control**: If ADB is installed, FireTV auto-launch works on Windows too.

## Running as a Service

To run Emiscreen as a Windows service, use NSSM:

```powershell
# Download NSSM from nssm.cc
nssm install Emiscreen "C:\path\to\emiscreen\.venv\Scripts\python.exe" "-m emiscreen.server --source windows-pc"
nssm start Emiscreen
```
