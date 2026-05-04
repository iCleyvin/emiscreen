# Story 1-6: Smoke check automatizado

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 1 día
Depends on: 1-5

## Description
Crear un script de smoke test que arranque el servidor, verifique que funcione correctamente, y valide que la captura y transmisión están operativas.

## Acceptance Criteria
- [ ] Script `scripts/smoke-check.ps1` (Windows) y `scripts/smoke-check.sh` (Linux)
- [ ] Arranca servidor en background con `--source windows-pc` (o `nas-omv` en CI)
- [ ] Espera a que HTTPS responda en `https://localhost:8445/health`
- [ ] Verifica que WebSocket de signaling responde
- [ ] Captura un frame y valida que no esté vacío (comprueba tamaño > 100KB)
- [ ] Mata el servidor al finalizar
- [ ] Tiempo total <60s
- [ ] Exit code 0 = PASS, 1 = FAIL
- [ ] Output claro: qué pasó y qué falló

## Technical Notes
- Usar `Start-Job` / `nohup` para arrancar servidor en background
- `Invoke-WebRequest` / `curl` para health check
- Para validar frame: arrancar FFmpeg manualmente por 1s y verificar que el output rawvideo tenga bytes
- En Linux headless: usar `--source nas-omv` con Xvfb

## Files to Touch
- `scripts/smoke-check.ps1` — nuevo
- `scripts/smoke-check.sh` — nuevo
- `emiscreen/server.py` — asegurar endpoint `/health` funcione

## Test Evidence Path
- Ejecutar `./scripts/smoke-check.ps1` y verificar PASS
- Ejecutar con servidor roto (puerto ocupado) y verificar FAIL
