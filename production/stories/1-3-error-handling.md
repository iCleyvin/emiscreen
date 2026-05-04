# Story 1-3: Manejo de errores visibles

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 1 día

## Description
La app debe mostrar mensajes de error claros en español en lugar de dejar al usuario frente a una pantalla negra. Cubrir los errores más comunes.

## Acceptance Criteria
- [ ] Servidor no responde (timeout de conexión): "No se pudo conectar al servidor. Verifica la IP y que el servidor esté corriendo."
- [ ] Certificado SSL inválido: "Error de certificado. Usa la app nativa o confía el certificado en tu navegador."
- [ ] Red caída (WiFi desconectado): "Conexión de red perdida. Revisa tu WiFi."
- [ ] Servidor cerró conexión inesperadamente: "El servidor cerró la conexión. Reiniciando..."
- [ ] Cada error muestra un ícono/icono representativo (⚠️, 🌐, 🔒, etc.)
- [ ] Botón "Reintentar" visible en todos los errores excepto reconexión automática

## Technical Notes
- Crear un componente/función `showError(type, message)` en `viewer.js`
- Tipos de error: `SERVER_TIMEOUT`, `CERT_INVALID`, `NETWORK_LOST`, `SERVER_CLOSED`
- Usar traducciones en español (idioma nativo del proyecto)
- El overlay de error debe estar por encima de todo y bloquear interacción hasta reintentar

## Files to Touch
- `emiscreen/static/viewer.html` — div de error
- `emiscreen/static/viewer.css` — estilos de error
- `emiscreen/static/viewer.js` — manejo de errores

## Test Evidence Path
- Prueba manual: simular cada error y verificar mensaje
