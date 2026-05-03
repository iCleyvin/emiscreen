# Emiscreen Architecture

## Overview

Emiscreen is a WebRTC-based remote display system that streams a source screen (Ubuntu, Windows, or NAS) to a target display (FireTV browser or any modern browser) with low latency (~50-150ms).

## Component Diagram

```
┌─────────────────┐     ┌──────────────────────────────────┐     ┌──────────────────┐
│  SOURCE         │     │  EMISCREEN SERVER                │     │  TARGET          │
│  (Desktop)      │     │  (Python 3.11 + aiortc)          │     │  (FireTV Browser)│
│                 │     │                                  │     │                  │
│  ┌───────────┐  │     │  ┌────────────┐  ┌────────────  │     │  ────────────┐  │
│  │ FFmpeg    │──┼────▶│  │ Capture    │  │ WebRTC     │  │     │  │ WebRTC     │  │
│  │ x11grab/  │  │     │  │ Module     │──▶│ Engine     │──┼────▶│  │ Receiver   │  │
│  │ gdigrab   │  │     │  │            │  │            │  │     │  │            │  │
│  └───────────┘  │     │  └────────────┘  └──────┬─────┘  │     │  └──────┬─────┘  │
│                 │     │                         │        │     │         │        │
│                 │     │  ┌────────────┐  ┌──────▼─────┐  │     │  ┌──────▼─────┐  │
│                 │     │  │ Input      │  │ HTTP/WS    │  │     │  │ Input      │  │
│                 │     │  │ Relay      │◀─┤ Server     │◀─┼─────┼──│ Capture    │  │
│                 │     │  │ (xdotool)  │  │ (aiohttp)  │  │     │  │ (JS)       │  │
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

1. **Capture**: FFmpeg captures the desktop as raw YUV420P frames
2. **Encoding**: Frames are wrapped in aiortc VideoStreamTrack (H.264 codec)
3. **WebRTC**: aiortc handles RTP/RTCP, SRTP encryption, and ICE connectivity
4. **Transport**: Video flows directly peer-to-peer (no server relay needed)
5. **Decode**: Browser's native WebRTC stack decodes and displays

### Input Stream (Target → Source)

1. **Capture**: Browser JS captures keyboard/mouse/touch events
2. **Transport**: Events sent via WebSocket to the server
3. **Relay**: InputRelay translates events to xdotool commands
4. **Execution**: xdotool simulates input on the source desktop

### Control Flow (Server → FireTV)

1. **ADB Connect**: Server connects to FireTV via ADB over TCP/IP
2. **Wake**: Server wakes FireTV and configures display settings
3. **Launch**: Server launches FireTV browser with the stream URL
4. **Monitor**: Background task auto-reconnects if ADB drops

## Protocol Details

### WebRTC Signaling

- **Offer**: Client POSTs SDP offer to `/offer`
- **Answer**: Server responds with SDP answer + ICE candidates
- **ICE**: Uses Google STUN servers for NAT traversal
- **Codec**: H.264 (hardware decoded on FireTV)

### WebSocket Input Protocol

```json
// Mouse move
{"type": "mousemove", "x": 960, "y": 540}

// Key press
{"type": "keydown", "key": "dpad_up", "keyCode": 38}

// Click
{"type": "mousedown", "button": 0, "x": 500, "y": 300}
```

## Security Model

- **HTTPS required**: WebRTC needs secure context
- **Self-signed certs**: Generated locally, trusted on LAN
- **No internet exposure**: Server binds to local network only
- **ADB auth**: First-time pairing requires physical confirmation on FireTV
- **No authentication by default**: LAN-only, add token auth via `EMISCREEN_TOKEN` env var

## Performance Characteristics

| Metric | Target | Notes |
|--------|--------|-------|
| Video latency | <150ms P95 | WebRTC direct peer-to-peer |
| Input latency | <50ms P95 | WebSocket + xdotool |
| Frame rate | 24-30 fps | Configurable |
| Resolution | Up to 1920x1080 | Configurable |
| Bandwidth | 2-8 Mbps | H.264, depends on content |
| CPU (server) | <25% | On Raspberry Pi 4 |
| CPU (FireTV) | <20% | Hardware decode |
