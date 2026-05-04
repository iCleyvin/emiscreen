# Story 1-1: Auto-reconexión inteligente

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 2 días

## Description
La app Fire TV debe detectar desconexiones del servidor WebRTC y reconectarse automáticamente sin intervención del usuario. El usuario solo ve un overlay breve de "Reconnecting..." y luego el video vuelve.

## Acceptance Criteria
- [ ] Detectar desconexión WebRTC en ≤2s (ping/pong timeout o connectionstatechange failed)
- [ ] Reintentar conexión con backoff exponencial: 1s, 2s, 4s, 8s, max 30s
- [ ] Mostrar overlay "Reconnecting..." con contador de intento
- [ ] En reconexión exitosa, el overlay desaparece automáticamente
- [ ] Si después de 5 intentos no conecta, mostrar error: "Servidor no disponible"
- [ ] La reconexión preserva la configuración (IP, puerto, contraseña si aplica)

## Technical Notes
- Usar el WebSocket de signaling para ping/pong cada 2s
- En `viewer.js` (y app Fire TV), manejar `pc.onconnectionstatechange`
- Estados a monitorear: `failed`, `disconnected`, `closed`
- Separar la lógica de reconexión en una clase `ConnectionManager`

## Files to Touch
- `emiscreen/static/viewer.js` — lógica de reconexión
- `emiscreen/server.py` — mantener WebSocket alive con ping/pong
- `firetv-app/.../MainActivity.kt` — propagar mensajes de estado a la UI

## Test Evidence Path
- `tests/test_reconnection.py` — simular desconexión y verificar reconexión
- Prueba manual: matar servidor 5s, verificar reconexión automática
