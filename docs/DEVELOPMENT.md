# Emiscreen - Development Guide

## Project Structure

```
emiscreen/
├── emiscreen/           # Main package
│   ├── server.py        # aiohttp server + signaling
│   ├── webrtc.py        # WebRTC peer connection handler
│   ├── config.py        # Configuration
│   ├── capture/         # Screen capture modules
│   │   ├── base.py      # Abstract base class
│   │   ├── linux.py     # FFmpeg x11grab + Xvfb
│   │   └── windows.py   # FFmpeg gdigrab
│   ├── relay/           # Input relay modules
│   │   ├── input.py     # WebSocket → xdotool
│   │   └── adb.py       # ADB FireTV control
│   └── static/          # Browser client files
│       ├── viewer.html
│       ├── viewer.js
│       └── viewer.css
├── scripts/             # Setup and launch scripts
├── docs/                # Documentation
└── tests/               # Test suite
```

## Development Setup

```bash
# Clone and setup dev environment
git clone https://github.com/iCleyvin/emiscreen.git
cd emiscreen
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Running Tests

```bash
pytest tests/ -v
```

## Code Style

```bash
# Format
black emiscreen/

# Lint
ruff check emiscreen/

# Type check
mypy emiscreen/
```

## Adding a New Capture Source

1. Create a new file in `emiscreen/capture/` (e.g., `macos.py`)
2. Inherit from `CaptureSource` base class
3. Implement `start()` and `stop()` methods
4. Create a `FFmpegVideoTrack` or custom `VideoStreamTrack`
5. Register in `CaptureSource.create()` factory method

## Adding a New Platform

1. Add platform detection in `capture/base.py`
2. Create platform-specific capture module
3. Add platform-specific setup script
4. Update documentation

## WebRTC Debugging

Enable verbose logging:

```bash
./scripts/start.sh --verbose
```

Check WebRTC stats in browser console:

```javascript
// In FireTV browser console
pc.getStats().then(stats => {
    stats.forEach(report => {
        if (report.type === 'inbound-rtp') {
            console.log('FPS:', report.framesPerSecond);
            console.log('Resolution:', report.frameWidth, 'x', report.frameHeight);
        }
    });
});
```

## Performance Tuning

### Reduce Latency

- Lower resolution: `--resolution 1280x720`
- Lower FPS: `--fps 24`
- Use H.264 codec (hardware decode on FireTV)
- Wired network connection

### Reduce CPU Usage

- Use hardware encoding if available:
  ```python
  # In capture module, add FFmpeg hardware encoder
  "-vcodec", "h264_vaapi",  # Intel VAAPI
  # or
  "-vcodec", "h264_nvenc",  # NVIDIA NVENC
  ```
