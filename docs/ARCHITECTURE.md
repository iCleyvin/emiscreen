# Emiscreen Architecture

## Overview

Emiscreen is a WebRTC-based remote display system that streams a source screen (Ubuntu, Windows, or NAS) to a target display (Fire TV native app or browser) with low latency (~50-150ms).

## Component Diagram

```
┌─────────────────┐     ┌──────────────────────────────────┐     ┌──────────────────┐
│  SOURCE         │     │  EMISCREEN SERVER                │     │  TARGET          │
│  (Desktop)      │     │  (Python 3.11 + aiortc)          │     │  (Fire TV /      │
│                 │     │                                  │     │   Browser)       │
│  ┌───────────┐  │     │  ┌────────────┐  ┌────────────  │     │  ────────────┐  │
│  │ FFmpeg    │──┼────▶│  │ Capture    │  │ WebRTC     │  │     │  │ Native App │  │
│  │ x11grab/  │  │     │  │ Module     │──▶│ Engine     │──┼────▶│  │ or Browser │  │
│  │ gdigrab   │  │     │  │            │  │            │  │     │  │            │  │
│  └───────────┘  │     │  └────────────┘  └──────┬─────┘  │     │  └──────┬─────┘  │
│                 │     │                         │        │     │         │        │
│                 │     │  ┌────────────┐  ┌──────▼─────┐  │     │  ┌──────▼─────┐  │
│                 │     │  │ Input      │  │ HTTP/WS    │  │     │  │ Input      │  │
│                 │     │  │ Relay      │◀─┤ Server     │◀─┼─────┼──│ Capture    │  │
│                 │     │  │ (xdotool/  │  │ (aiohttp)  │  │     │  │ (JS)       │  │
│                 │     │  │  SendInput)│  │            │  │     │  │            │  │
│                 │     │  └────────────┘  └────────────┘  │     │  └────────────┘  │
│                 │     │                                  │     │                  │
│                 │     │  ┌────────────┐                  │     │                  │
│                 │     │  │ ADB        │                  │     │                  │
│                 │     │  │ Controller │                  │     │                  │
│                 │     │  │ (FireTV)   │                  │     │                  │
│                 │     │  └────────────┘                  │     │                  │
└─────────────────┘     └──────────────────────────────────┘     └──────────────────┘
```

## Data Flow

### Video Stream (Source → Target)

1. **Capture**: FFmpeg captures the desktop (`x11grab` on Linux, `gdigrab` on Windows) and outputs raw YUV420P frames.
2. **WebRTC Track**: `FFmpegRawVideoTrack` reads raw frames from FFmpeg's stdout and wraps them in `av.VideoFrame` objects for aiortc.
3. **WebRTC**: aiortc handles encoding (H.264), RTP/RTCP, SRTP encryption, and ICE connectivity.
4. **Transport**: Video flows directly peer-to-peer (no server relay needed for media).
5. **Decode**: Fire TV app (WebView) or browser decodes via native WebRTC stack and displays.

> **Note:** The capture pipeline intentionally uses **rawvideo YUV420P** from FFmpeg rather than H.264 passthrough. This eliminates platform-specific H.264 parser bugs and keeps the Python code simple and robust.

### Input Stream (Target → Source)

1. **Capture**: Browser JS or native app captures keyboard/mouse/touch/remote events.
2. **Transport**: Events sent via WebSocket to the server.
3. **Relay**: `InputRelay` translates events via an OS-specific backend:
   - **Linux**: `xdotool`
   - **Windows**: `SendInput` via `ctypes` (zero dependencies)
4. **Execution**: The backend simulates input on the source desktop.

### Control Flow (Server → Fire TV)

1. **ADB Connect**: Server connects to Fire TV via ADB over TCP/IP.
2. **Wake**: Server wakes Fire TV and configures display settings.
3. **Launch** (browser only): Server launches Fire TV browser with the stream URL.
4. **Monitor**: Background task auto-reconnects if ADB drops.

## Protocol Details

### WebRTC Signaling

- **Offer**: Client POSTs SDP offer to `/offer`
- **Answer**: Server responds with SDP answer + ICE candidates
- **ICE**: Uses Google STUN servers for NAT traversal
- **Codec**: H.264 (hardware decoded on Fire TV)

### WebSocket Input Protocol

```json
// Mouse move
{"type": "mousemove", "x": 960, "y": 540}

// Key press
{"type": "keydown", "key": "dpad_up", "code": "ArrowUp", "keyCode": 38}

// Click
{"type": "mousedown", "button": 0, "x": 500, "y": 300}

// Ping / Pong (connection health)
{"type": "ping"}
{"type": "pong"}
```

## Security Model

- **HTTPS required**: WebRTC needs secure context.
- **Self-signed certs**: Generated locally on first run. Now include the server's LAN IP in the SAN.
- **No internet exposure**: Server binds to local network only.
- **ADB auth**: First-time pairing requires physical confirmation on Fire TV.
- **Native app trust**: The Fire TV Android app ignores SSL errors via `onReceivedSslError → proceed()`.
- **No authentication by default**: LAN-only; add token auth via `EMISCREEN_TOKEN` env var.

## Performance Characteristics

| Metric | Target | Notes |
|--------|--------|-------|
| Video latency | <150ms P95 | WebRTC direct peer-to-peer |
| Input latency | <50ms P95 | WebSocket + native input API |
| Frame rate | 24-30 fps | Configurable |
| Resolution | Up to 1920x1080 | Configurable |
| Bandwidth | 2-8 Mbps | H.264, depends on content |
| CPU (server) | <25% | On modern hardware |
| CPU (Fire TV) | <20% | Hardware decode |
