# Emiscreen

**Remote Display via WebRTC** - Usa cualquier TV/monitor con FireTV (o cualquier browser) como pantalla remota.

## Características

- **WebRTC custom** - Latencia ~50-150ms, calidad hasta 1080p@30fps
- **Multi-source** - Ubuntu, Windows, NAS headless (Xvfb)
- **Input relay** - Control remoto via WebSocket + xdotool/ADB
- **FireTV ready** - ADB auto-connect, D-Pad mapping, auto-launch
- **Zero dependencies on target** - Solo un browser en el dispositivo destino
- **Open source** - Apache 2.0 License

## Arquitectura

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  SOURCE      │────▶│  EMISCREEN       │────▶│  TARGET      │
│  (Ubuntu/    │     │  SERVER          │     │  (FireTV/    │
│   Win/NAS)   │     │  (aiortc+aiohttp)│     │   Browser)   │
──────────────┘     └──────────────────┘     └──────────────┘
```

## Quick Start

### Servidor (Ubuntu)

```bash
# 1. Instalar dependencias
./scripts/setup.sh

# 2. Configurar FireTV (primera vez)
./scripts/connect-firetv.sh <FIRETV_IP>

# 3. Iniciar Emiscreen
./scripts/start.sh --source ubuntu-desktop --firetv <FIRETV_IP>
```

### Servidor (Windows)

```powershell
# 1. Instalar dependencias
.\scripts\setup.ps1

# 2. Iniciar Emiscreen
.\scripts\start.ps1 -Source windows-pc
```

## Documentación

- [Arquitectura](docs/ARCHITECTURE.md)
- [Instalación](docs/SETUP.md)
- [Config FireTV](docs/FIRETV.md)
- [Config Windows](docs/WINDOWS.md)
- [Config NAS](docs/NAS.md)
- [Desarrollo](docs/DEVELOPMENT.md)
- [API](docs/API.md)

## Licencia

Apache 2.0 - Ver [LICENSE](LICENSE)
