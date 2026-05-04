# Story 1-5: Tests unitarios core

## Context
Sprint: Sprint 1 — Fase 1: Endurecimiento
Priority: Must Have
Estimate: 2 días

## Description
Escribir tests unitarios para los módulos críticos del proyecto. Establecer una base de tests que se ejecuten en CI.

## Acceptance Criteria
- [ ] Tests para `emiscreen/config.py` — parsing de argumentos CLI, variables de entorno
- [ ] Tests para `emiscreen/capture/windows.py` — `_get_monitors()` devuelve lista válida, maneja fallback
- [ ] Tests para `emiscreen/relay/windows_input.py` — `send_key()`, `send_click()` con mock de Windows API
- [ ] Tests para `emiscreen/relay/linux_input.py` — `send_key()`, `send_click()` con mock de xdotool
- [ ] Tests para generación de certificados SSL — cert contiene LAN IP en SAN
- [ ] Cobertura ≥70% en los módulos testeado
- [ ] Todos los tests pasan con `pytest`
- [ ] `pytest.ini` configurado con paths y markers

## Technical Notes
- Usar `pytest` + `pytest-asyncio` para tests async
- Para tests de Windows API: usar `unittest.mock.patch` sobre `ctypes.windll.user32`
- Para tests de input relay Linux: mock `subprocess.run` que llama xdotool
- Para tests de certificados: usar `cryptography` para parsear el cert generado

## Files to Touch
- `tests/test_config.py` — nuevo
- `tests/test_capture_windows.py` — nuevo
- `tests/test_relay_windows.py` — nuevo
- `tests/test_relay_linux.py` — nuevo
- `tests/test_certs.py` — nuevo
- `pytest.ini` — nuevo o actualizar
- `.github/workflows/ci.yml` — opcional para CI

## Test Evidence Path
- `pytest tests/ --cov=emiscreen --cov-report=term-missing`
- Cobertura reportada en terminal
