# Story 1-4: Adaptación dinámica de bitrate

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 2 días

## Description
El servidor debe monitorear la calidad de la red (RTT, packet loss via WebRTC stats) y ajustar el bitrate del encoder FFmpeg en tiempo real sin cortar la conexión.

## Acceptance Criteria
- [ ] Leer stats WebRTC cada 2s: RTT, packetsLost, packetsReceived
- [ ] Si RTT > 150ms o packet loss > 2%: bajar bitrate (8M → 4M → 2M)
- [ ] Si RTT < 50ms y packet loss = 0 por 10s: subir bitrate (2M → 4M → 8M)
- [ ] Cambio de bitrate sin reconexión (usar `RTCRtpSender.setParameters()` o recrear encoder)
- [ ] Mostrar bitrate actual en el overlay de estado (1-2)
- [ ] Loguear cambios de bitrate en el servidor

## Technical Notes
- WebRTC `getStats()` devuelve `inbound-rtp` con `packetsLost`, `packetsReceived`
- Para cambiar bitrate sin reconectar, la forma más sencilla es pasar el bitrate como parámetro al encoder y reiniciar FFmpeg con el nuevo `-b:v`
- Alternativa: usar `RTCRtpSender.setParameters({ encodings: [{ maxBitrate }] })` si el codec lo soporta
- Inicialmente probar con reinicio controlado de FFmpeg (seamless si el buffer se maneja bien)

## Files to Touch
- `emiscreen/webrtc.py` — leer stats, decidir cambio
- `emiscreen/capture/base.py` — método para cambiar bitrate en caliente
- `emiscreen/capture/windows.py` / `linux.py` — reiniciar FFmpeg con nuevo bitrate
- `emiscreen/server.py` — loop de monitoreo de stats

## Test Evidence Path
- `tests/test_bitrate_adaptation.py` — simular alta latencia y verificar bajada de bitrate
- Prueba manual: saturar red y observar bitrate bajar
