# Story 1-11: Multi-cliente simultáneo

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Nice to Have
Estimate: 3 días

## Description
Permitir que múltiples dispositivos (Fire TVs, navegadores) se conecten al mismo servidor simultáneamente y vean el mismo stream.

## Acceptance Criteria
- [ ] Servidor acepta 2+ conexiones WebRTC simultáneas
- [ ] Cada cliente recibe el mismo stream de video/audio
- [ ] Input relay va al servidor, no a un cliente específico
- [ ] CPU del servidor no sube >20% con 2 clientes vs 1
- [ ] Desconectar un cliente no afecta a los demás

## Technical Notes
- El `MediaRelay` de aiortc ya soporta múltiples suscriptores del mismo track
- El servidor necesita mantener una lista de peers y broadcastear el mismo track a todos
- El input relay debe funcionar independientemente de cuántos clientes hay conectados
- Considerar límite de clientes (ej: máximo 3) para no saturar CPU/red

## Files to Touch
- `emiscreen/webrtc.py` — mantener múltiples peers, broadcast track
- `emiscreen/server.py` — aceptar múltiples conexiones WebSocket
- `emiscreen/static/viewer.js` — sin cambios (el servidor maneja todo)

## Test Evidence Path
- Prueba manual: conectar Fire TV + navegador del PC al mismo tiempo
- Medir CPU con 1 vs 2 clientes
