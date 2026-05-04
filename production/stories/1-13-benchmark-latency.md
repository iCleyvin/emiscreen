# Story 1-13: Benchmark de latencia

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Nice to Have
Estimate: 1 día
Depends on: 1-8

## Description
Crear un benchmark automatizado que mida la latencia end-to-end y genere un reporte.

## Acceptance Criteria
- [ ] Script `scripts/benchmark-latency.py` que:
  1. Inyecta un timestamp visual en el frame capturado (ej: QR code o número grande)
  2. Captura la pantalla del cliente (Fire TV o navegador) vía screenshot
  3. Lee el timestamp del frame recibido
  4. Calcula diferencia = tiempo de render - tiempo de captura
  5. Repite 30 veces y calcula promedio, P50, P95, P99
- [ ] Genera reporte CSV con todos los datos
- [ ] Genera resumen en consola con conclusión
- [ ] Documentar metodología en `docs/PERFORMANCE.md`

## Technical Notes
- Para inyectar timestamp: usar FFmpeg `drawtext` filter (`-vf drawtext=text='%{pts}'`)
- Para capturar cliente: si es navegador, usar Selenium/Playwright screenshot. Si es Fire TV, usar ADB `screencap`
- La precisión depende de la sincronización de reloj entre PC y cliente (NTP)
- Alternativa simple: contar frames de delay visualmente

## Files to Touch
- `scripts/benchmark-latency.py` — nuevo
- `docs/PERFORMANCE.md` — nuevo

## Test Evidence Path
- Ejecutar benchmark y obtener reporte CSV
- Verificar que los números son razonables (<500ms en LAN)
