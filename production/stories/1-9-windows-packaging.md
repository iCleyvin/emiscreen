# Story 1-9: Empaquetado Windows

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Should Have
Estimate: 1 día

## Description
Crear un paquete portable de Windows que cualquier usuario pueda descargar y ejecutar sin instalar Python.

## Acceptance Criteria
- [ ] Script `scripts/build-windows.ps1` que genera:
  - Carpeta `emiscreen-windows/` con Python embebido o `.venv` portable
  - `emiscreen.bat` — doble clic para ejecutar
  - Icono `.ico` para el ejecutable
  - `README-WINDOWS.txt` con instrucciones
- [ ] El paquete funciona en Windows 10/11 sin Python preinstalado
- [ ] Incluye FFmpeg portable o detecta FFmpeg del sistema
- [ ] Tamaño del paquete <200MB

## Technical Notes
- Opción A: `pyinstaller` para crear `.exe` (puede ser pesado)
- Opción B: Empaquetar `.venv` + `python.exe` + script `.bat` (más ligero)
- FFmpeg puede empaquetarse como binario estático o pedirse al usuario que lo instale
- Incluir `certs/` generados o generarlos en primer run

## Files to Touch
- `scripts/build-windows.ps1` — nuevo
- `assets/icon.ico` — nuevo (icono del proyecto)
- `emiscreen.bat` — nuevo (launcher)

## Test Evidence Path
- Ejecutar en VM Windows limpia (sin Python) y verificar funciona
- Verificar tamaño del ZIP
