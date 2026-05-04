# Story 1-2: Indicador de estado en app

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 1 día
Depends on: 1-1

## Description
Mostrar un overlay en la app Fire TV con información del estado del stream: conectado, reconectando, bitrate, ping, resolución. Se oculta automáticamente y aparece con tecla Menú.

## Acceptance Criteria
- [ ] Overlay visible al conectar (3s), luego auto-hide
- [ ] Tecla Menú (≡) del Fire TV muestra/oculta overlay
- [ ] Campos mostrados: estado (Connecting/Streaming/Reconnecting/Error), bitrate, ping ms, resolución
- [ ] Overlay no interfiere con el video (fondo semi-transparente, texto pequeño)
- [ ] En estado "Error", muestra mensaje específico (no genérico)

## Technical Notes
- Agregar un `<div id="stats-overlay">` en `viewer.html`
- Estilos en `viewer.css`: posición absoluta arriba-derecha, fondo rgba(0,0,0,0.6)
- Actualizar desde `viewer.js` en eventos WebRTC (bitrate via `getStats()`)
- Para Fire TV: D-Pad no debe interactuar con el overlay (solo Menú)

## Files to Touch
- `emiscreen/static/viewer.html` — div overlay
- `emiscreen/static/viewer.css` — estilos del overlay
- `emiscreen/static/viewer.js` — actualizar stats y toggle con tecla Menú

## Test Evidence Path
- Prueba manual: verificar overlay aparece, se oculta, y se togglea con Menú
