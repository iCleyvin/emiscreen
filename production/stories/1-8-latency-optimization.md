# Story 1-8: Optimización de latencia

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Should Have
Estimate: 2 días
Depends on: 1-4

## Description
Reducir la latencia end-to-end al mínimo posible. Target: <100ms en LAN.

## Acceptance Criteria
- [ ] H.264 tuneado con `-tune zerolatency -profile:v baseline -level 3.0`
- [ ] Buffer de jitter mínimo en WebRTC (`jitterBufferTarget` bajo)
- [ ] Medir latencia real: capturar timestamp en frame, comparar con tiempo de render en cliente
- [ ] Documentar latencia medida en README
- [ ] Si la latencia es >150ms, identificar y documentar el cuello de botella

## Technical Notes
- `-tune zerolatency` en FFmpeg desactiva B-frames y reduce buffer
- `-profile:v baseline` evita características que aumentan delay
- `aiortc` permite configurar `RTCRtpCodecParameters` con `ptime` bajo
- Para medir: agregar timestamp al frame (como overlay invisible o en metadata), y leerlo en el cliente

## Files to Touch
- `emiscreen/capture/windows.py` / `linux.py` — flags de FFmpeg
- `emiscreen/webrtc.py` — configuración de codec low-latency
- `emiscreen/static/viewer.js` — medición de latencia
- `docs/PERFORMANCE.md` — documentar resultados

## Test Evidence Path
- Script de benchmark (1-13) si se alcanza
- Prueba manual: mover mouse y medir tiempo hasta ver movimiento en TV
