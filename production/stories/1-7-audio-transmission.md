# Story 1-7: Audio del PC a Fire TV

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Should Have
Estimate: 3 días

## Description
Transmitir audio del desktop del PC a la Fire TV sincronizado con el video. El usuario puede silenciar desde la app.

## Acceptance Criteria
- [ ] Servidor captura audio del sistema con FFmpeg
  - Windows: `-f dshow -i audio="virtual-audio-capturer"` o loopback
  - Linux: `-f pulse -i default` o ALSA
- [ ] Audio se transmite vía WebRTC en el mismo peer connection (track de audio)
- [ ] Fire TV reproduce audio automáticamente
- [ ] Drift audio/video < 100ms
- [ ] Toggle mute/unmute en la app (botón o tecla)
- [ ] Si el sistema no tiene audio, el servidor continúa sin error

## Technical Notes
- FFmpeg puede capturar audio de loopback en Windows con `dshow` y Virtual Audio Cable, o mejor con WASAPI loopback (`-f dshow -i audio="Stereo Mix"` si está disponible)
- Alternativa: usar `ffmpeg -f lavfi -i anullsrc` como fallback si no hay audio
- En aiortc, agregar un `AudioStreamTrack` además del `VideoStreamTrack`
- El audio puede causar que la app Fire TV mute automáticamente — verificar que se reproduzca

## Files to Touch
- `emiscreen/capture/base.py` — agregar AudioStreamTrack
- `emiscreen/capture/windows.py` — captura de audio FFmpeg
- `emiscreen/capture/linux.py` — captura de audio FFmpeg
- `emiscreen/webrtc.py` — agregar audio track al peer connection
- `emiscreen/static/viewer.js` — habilitar audio track, toggle mute
- `firetv-app/.../MainActivity.kt` — controles de volumen/mute

## Test Evidence Path
- Prueba manual: reproducir video con audio en PC, verificar que suena en TV
- Medir drift con herramienta de sync
