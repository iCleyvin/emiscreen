# Story 1-10: Empaquetado APK release

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Should Have
Estimate: 1 día

## Description
Configurar Gradle para compilar APK release con firma y versionado automático.

## Acceptance Criteria
- [ ] Gradle task `assembleRelease` funciona sin errores
- [ ] APK firmado con keystore de debug (configurable para release)
- [ ] Version name basado en `git describe --tags --always`
- [ ] Version code auto-incremental (basado en número de commits)
- [ ] Script `scripts/build-apk-release.ps1` que:
  1. Actualiza version en `build.gradle`
  2. Ejecuta `./gradlew assembleRelease`
  3. Copia APK a `./emiscreen-firetv-release.apk`
- [ ] APK release es más pequeño que debug (ProGuard/R8 opcional)

## Technical Notes
- Keystore de release debe estar en `.gitignore` (no subir a GitHub)
- `buildConfigField` puede incluir versión de Git para debugging
- ProGuard puede romper WebView/JS — probar exhaustivamente si se activa

## Files to Touch
- `firetv-app/app/build.gradle.kts` — config release, versionado
- `scripts/build-apk-release.ps1` — nuevo
- `.gitignore` — agregar keystore

## Test Evidence Path
- Ejecutar script y verificar APK generado
- Instalar APK release en Fire TV y verificar funciona igual que debug
