# Sprint 1 — Fase 1: Endurecimiento
**Del 2026-05-05 al 2026-05-26** (15 días hábiles)

## Sprint Goal
Transformar Emiscreen de "prototipo funcional" a "producto usable diariamente": robustez, performance, audio, packaging y tests automatizados.

## Capacity
- Total días: 15
- Buffer (20%): 3 días (imprevistos, bugfixes)
- Disponibles: **12 días de trabajo**

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Días | Dependencias | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-1 | Auto-reconexión inteligente | 2 | — | App detecta desconexión y reconecta automáticamente en ≤5s con backoff exponencial (1s→2s→4s→8s→max 30s). Muestra "Reconnecting..." claramente. |
| 1-2 | Indicador de estado en app | 1 | 1-1 | Overlay en la app muestra: estado de conexión (Connecting/Streaming/Reconnecting), bitrate actual, ping ms, resolución. Se oculta automáticamente tras 3s, reaparece con menú. |
| 1-3 | Manejo de errores visibles | 1 | — | Si el servidor no responde, certificado inválido, o red caída: la app muestra mensaje útil en español ("Servidor no encontrado", "Error de certificado") en lugar de pantalla negra. |
| 1-4 | Adaptación dinámica de bitrate | 2 | — | Servidor monitorea RTT y pérdida de paquetes WebRTC. Si la red se degrada, baja bitrate automáticamente (8M→4M→2M). Si mejora, sube de nuevo. Sin reconexión. |
| 1-5 | Tests unitarios core | 2 | — | Tests para: config parsing, monitor enumeration (Windows), input relay (Windows/Linux), cert generation. Cobertura ≥70% en módulos core. |
| 1-6 | Smoke check automatizado | 1 | 1-5 | Script que arranca servidor, verifica HTTPS responde, verifica WebSocket conecta, y captura un frame válido. Falla en <60s si algo está roto. |

### Should Have

| ID | Task | Est. Días | Dependencias | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-7 | Audio del PC a Fire TV | 3 | — | Servidor captura audio del desktop con FFmpeg (`-f dshow` Windows, `pulse`/ALSA Linux) y lo transmite vía WebRTC. Fire TV reproduce audio sincronizado (drift <100ms). Toggle on/off. |
| 1-8 | Optimización de latencia | 2 | 1-4 | Buffer de jitter reducido a mínimo funcional. Codec H.264 tuneado para low-latency (`-tune zerolatency`). Latencia end-to-end medida y documentada: target <100ms en LAN. |
| 1-9 | Empaquetado Windows | 1 | — | Script `build-windows.ps1` que genera: `.zip` portable + `.bat` de inicio rápido con ícono. README explica uso. |
| 1-10 | Empaquetado APK release | 1 | — | Gradle config para `assembleRelease`. Script `build-apk-release.ps1` con firma de debug. Versionado automático basado en `git describe`. |

### Nice to Have

| ID | Task | Est. Días | Dependencias | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-11 | Multi-cliente simultáneo | 3 | — | Servidor acepta 2+ conexiones WebRTC. Cada cliente recibe el mismo stream. Sin degradación >20% en CPU. |
| 1-12 | Amazon Appstore ready | 2 | — | APK firma release, assets (iconos 512px, screenshots), manifest con categoría `Apps & Games`. |
| 1-13 | Benchmark de latencia | 1 | 1-8 | Script que mide latencia frame-to-display automáticamente y genera reporte CSV. |

---

## Risks

| Risk | Probabilidad | Impacto | Mitigación |
|------|------------|--------|------------|
| Audio sync complejo en WebRTC | Media | Alto | Si se complica, mover a Fase 2 (Nice-to-have) |
| Parsec VDD no estable en algunos PCs | Baja | Medio | Documentar alternativas (spacedesk) |
| Fire TV WebView limita audio WebRTC | Media | Alto | Probar early, si falla → investigar ExoPlayer |
| Tiempo insuficiente (15 días) | Media | Alto | Priorizar Must-Have, deferir Nice-to-Have |

---

## Dependencies on External Factors
- Parsec VDD releases page (para docs de instalación)
- Amazon Appstore guidelines (si se llega a 1-12)

---

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
