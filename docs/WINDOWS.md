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

## Notes

- **Input relay**: Fully supported on Windows via native `SendInput` API (`ctypes`). No extra dependencies required.
- **Capture**: Uses FFmpeg `gdigrab` which captures the entire desktop, outputting raw YUV420P frames.
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
