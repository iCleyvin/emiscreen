# Story 1-12: Amazon Appstore ready

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Nice to Have
Estimate: 2 días

## Description
Preparar la app Fire TV para distribución en Amazon Appstore.

## Acceptance Criteria
- [ ] APK firmado con keystore de release (no debug)
- [ ] Íconos en todos los tamaños requeridos (48px, 72px, 96px, 144px, 192px, 512px)
- [ ] Screenshots de la app (mínimo 3) en resolución Fire TV
- [ ] Descripción corta (<120 chars) y larga (<4000 chars) en español e inglés
- [ ] Categoría correcta en manifest: `Apps & Games` → `Utilities` o `Productivity`
- [ ] `AndroidManifest.xml` sin permisos innecesarios
- [ ] App pasa validación de Amazon Appstore (test con `apk-validator` si existe)

## Technical Notes
- Amazon tiene requisitos específicos para Fire TV: navegación D-Pad, icono de banner (1280x720)
- El manifest debe declarar `android.intent.category.LEANBACK_LAUNCHER` para aparecer en Fire TV
- Considerar si el nombre del paquete debe cambiar para producción

## Files to Touch
- `firetv-app/app/src/main/AndroidManifest.xml` — categorías, permisos
- `firetv-app/app/src/main/res/mipmap-*/` — iconos
- `firetv-app/app/build.gradle.kts` — config release
- `assets/screenshots/` — screenshots
- `docs/AMAZON_APPSTORE.md` — guía de publicación

## Test Evidence Path
- Subir APK a Amazon Appstore Developer Console y verificar validación
- O usar herramienta de validación local si existe
