# Emiscreen API Reference

## HTTP Endpoints

### GET /
Serves the main viewer page (`viewer.html`).

### POST /offer
WebRTC signaling - receives SDP offer from client.

**Request:**
```json
{
    "sdp": "v=0\r\no=- ..."
}
```

**Response:**
```json
{
    "sdp": "v=0\r\no=- ...",
    "type": "answer"
}
```

### GET /answer
WebRTC signaling - receives ICE candidates (kept for compatibility).

**Request:**
```json
{
    "candidate": {
        "candidate": "candidate:...",
        "sdpMid": "0",
        "sdpMLineIndex": 0
    }
}
```

**Response:**
```json
{
    "status": "ok"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
    "status": "healthy",
    "webrtc": true,
    "adb": true,
    "relay": true
}
```

### GET /status
Detailed server status.

**Response:**
```json
{
    "server": {
        "host": "0.0.0.0",
        "port": 8443,
        "uptime": "running"
    },
    "capture": {
        "type": "linux",
        "resolution": "1920x1080",
        "fps": 30,
        "codec": "h264"
    },
    "webrtc": {
        "connected": true,
        "peers": 1
    },
    "adb": {
        "enabled": true,
        "connected": true,
        "host": "192.168.1.100"
    }
}
```

## WebSocket Input Protocol

Endpoint: `ws://<host>:8443/input` (or `wss://` for HTTPS)

### Event Types

#### Mouse Move
```json
{"type": "mousemove", "x": 960, "y": 540}
```

#### Mouse Down/Up
```json
{"type": "mousedown", "button": 0, "x": 500, "y": 300}
{"type": "mouseup", "button": 0, "x": 500, "y": 300}
```

#### Key Down/Up
```json
{"type": "keydown", "key": "dpad_up", "keyCode": 38}
{"type": "keyup", "key": "dpad_up", "keyCode": 38}
```

#### Wheel
```json
{"type": "wheel", "deltaX": 0, "deltaY": -100}
```

#### Touch
```json
{"type": "touchstart", "x": 500, "y": 300}
{"type": "touchmove", "x": 510, "y": 305}
{"type": "touchend"}
```

### Key Names

| Key Name | Description |
|----------|-------------|
| `dpad_up` | D-Pad Up |
| `dpad_down` | D-Pad Down |
| `dpad_left` | D-Pad Left |
| `dpad_right` | D-Pad Right |
| `dpad_center` | D-Pad Select |
| `back` | Back button |
| `home` | Home button |
| `enter` | Enter/Return |
| `space` | Space bar |
| `tab` | Tab |
| `escape` | Escape |

## Python API

### Server

```python
from emiscreen.server import EmiscreenServer
from emiscreen.config import ServerConfig, CaptureConfig, ADBConfig, RelayConfig

server = EmiscreenServer(
    server_config=ServerConfig(host="0.0.0.0", port=8443),
    capture_config=CaptureConfig(type="linux", resolution="1920x1080", fps=30),
    adb_config=ADBConfig(enabled=True, host="192.168.1.100"),
    relay_config=RelayConfig(enabled=True),
)

await server.start()
```

### ADB Controller

```python
from emiscreen.relay.adb import ADBController

adb = ADBController(host="192.168.1.100")
await adb.connect()
await adb.wake()
await adb.launch_browser("https://192.168.1.50:8443")
await adb.send_keyevent("dpad_up")
await adb.tap(500, 300)
```
