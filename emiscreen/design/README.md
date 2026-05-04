# Emiscreen Desktop UI — Design Handoff

**Proyecto:** Emiscreen — Remote Display via WebRTC  
**Repo fuente:** https://github.com/iCleyvin/emiscreen  
**Fecha:** Mayo 2026  
**Variante de diseño elegida:** B — Top Tabs

---

## Contenido del paquete

```
design_handoff_emiscreen/
├── README.md                            ← este archivo (guía maestra)
├── design-tokens.json                   ← todos los valores de diseño (colores, tipografía, espaciado, componentes)
├── navigation-flows.md                  ← flujos de navegación y estados de la app
├── Emiscreen Wireframes Standalone.html ← wireframes interactivos (abrir en navegador)
└── screenshots/
    ├── 01-onboarding.png
    ├── 02-dashboard.png
    ├── 03-source-config.png
    ├── 04-firetv-connect.png            ← pantalla más importante ★
    ├── 05-stream-viewer.png
    ├── 06-settings.png
    └── 07-system-tray.png
```

---

## Sobre los archivos de diseño

Los archivos `.html` y `.png` son **referencias de diseño** — wireframes que muestran estructura, jerarquía y flujo. **No son código de producción para copiar directamente.**

La tarea es **implementar estas pantallas en el framework elegido para la app desktop**, usando los valores exactos de `design-tokens.json` para colores, tipografía y espaciado.

---

## Qué es Emiscreen

App de escritorio (Windows + Linux) que:
1. Captura la pantalla del PC con FFmpeg (x11grab / gdigrab)
2. La transmite vía WebRTC a un FireTV o cualquier navegador en la LAN
3. Retransmite eventos de input del FireTV al PC vía xdotool/ADB
4. Gestiona la conexión ADB con el FireTV (wake, launch browser, D-pad mapping)

**Backend existente:** Python 3.11 + aiortc + aiohttp (puerto 8445)  
**La UI desktop es nueva** — no existe aún, hay que crearla.

---

## Framework recomendado

| Opción | Pros | Contras |
|---|---|---|
| **Tauri v2** (recomendado) | Ligero, nativo, web frontend | Requiere Rust |
| **Electron** | Familiar, web frontend | Pesado (~100MB) |
| **PyQt6** | Puro Python, mismo repo | Más trabajo de UI |
| **CustomTkinter** | Puro Python, simple | Limitado en diseño |

**Tauri v2** es la mejor opción: el frontend web reproduce el diseño exactamente, y el backend Rust puede lanzar el proceso Python como subprocess y comunicarse via HTTP/WebSocket local.

---

## Comunicación UI ↔ Servidor Python

El servidor Python ya existe en el repo. La UI desktop lo comunica así:

```
UI Desktop (Tauri/Electron)
    │
    ├── lanza: python -m emiscreen --source windows-pc --firetv 192.168.1.42
    │          (captura stdout para el Activity Log)
    │
    ├── HTTP GET  http://localhost:8445/stats     → métricas en vivo (cada 2s)
    ├── HTTP POST http://localhost:8445/offer     → iniciar WebRTC
    ├── HTTP POST http://localhost:8445/control   → pause/stop/start
    └── WebSocket ws://localhost:8444/input       → relay de input
```

---

## Pantallas — Descripción y Especificaciones

### 01 — Onboarding (First Run Wizard)
**Screenshot:** `screenshots/01-onboarding.png`

Wizard de 4 pasos mostrado solo en el primer arranque. Guarda `firstRun: false` en config al completar.

**Layout:** Ventana centrada 600×400px. Contenido centrado con flex-column. Progress indicator horizontal de 4 pasos arriba, card de contenido central (max-width 420px, border-radius 12px), botones de navegación abajo.

**Paso 2 — Selector de fuente (pantalla mostrada):**
- 3 opciones en grid horizontal: Windows / Linux / NAS
- Seleccionado: `border: 1.5px solid #44aaff`, `background: rgba(68,170,255,0.08)`, texto `#44aaff` bold
- Normal: `border: 1.5px solid #333`, `background: #1a1a1a`, texto `#bbbbbb`
- Sub-etiqueta técnica: `font-family: JetBrains Mono, 10px, color: #555`

**Progress steps:**
- Done: `border: 2px solid #44cc44`, color `#44cc44`, texto `✓`
- Active: `border: 2px solid #44aaff`, `background: rgba(68,170,255,0.1)`, color `#44aaff`
- Pending: `border: 2px solid #444`, color `#777`
- Línea entre pasos: `height: 1.5px`, done=`#44aaff`, pending=`#333`

---

### 02 — Dashboard
**Screenshot:** `screenshots/02-dashboard.png`

Hub principal. **Acción más importante: botón Start Stream.**

**Layout:** Tab bar arriba → 2 columnas con gap 10px, padding 12px.

**Columna izquierda:**
- Card FireTV Target *(borde azul, bg rgba(68,170,255,0.04))*
  - Label `FIRETV TARGET` — JetBrains Mono 13px `#888`, uppercase
  - Ícono 📺 centrado (32px, border 2px azul, border-radius 6px)
  - IP: `192.168.1.42` — 16px, `#44aaff`, bold
  - StatusDot (punto animado + "Connected")
  - **Botón `⏵ Start Stream`** — ancho total, 16px, verde (`#44cc44`), `border: 1.5px solid #44cc44`, `background: rgba(60,200,60,0.12)`, padding 10px
  - En streaming: cambia a `⏹ Stop Stream`, color `#ff6644`
- Card Source — ícono + nombre + specs + toggle ON/OFF

**Columna derecha:**
- Grid 3×2 de métricas (Latency, FPS, Bitrate, Resolution, CPU, P2P)
  - Cada celda: `background: #1a1a1a`, `border: 1px solid #2a2a2a`, `border-radius: 5px`, `padding: 6px 8px`
  - Label: JetBrains Mono 9px `#555`
  - Valor: JetBrains Mono 16px (verde si bueno, ámbar si advertencia, rojo si crítico)
- Activity Log (ver especificación de componente Log abajo)

---

### 03 — Source Configuration
**Screenshot:** `screenshots/03-source-config.png`

**Layout:** 2 columnas, gap 10px.

**Columna izquierda:**
- Lista radio de 3 fuentes (ubuntu-desktop, windows-pc, nas-omv)
- 3 sliders: Resolution / Frame Rate / Bitrate
  - Track: `height: 4px`, `background: #333`, `border-radius: 2px`
  - Fill: `background: #44aaff`
  - Thumb: `width/height: 12px`, circular, `background: #44aaff`, `border: 2px solid #1a1a1a`

**Columna derecha:**
- Selector codec H.264 / VP8 (botones tipo option)
- Preview placeholder (`repeating-linear-gradient` de rayas diagonales, `border: 1.5px dashed #444`)
- Botones Test Capture + Apply & Save
- 3 toggles de opciones

---

### 04 — FireTV Connect ★ (PANTALLA MÁS IMPORTANTE)
**Screenshot:** `screenshots/04-firetv-connect.png`

**Layout:** 2 columnas — izquierda flex:1.4, derecha flex:1.

**Columna izquierda:**
- Card con `border: 1.5px solid #44aaff`
  - Input IP: `font-size: 15px`, `border: 1.5px solid #44aaff`, `box-shadow: 0 0 0 2px rgba(68,170,255,0.2)`
  - Botón `Connect ADB` — primario azul
  - 4 status dots en fila: ADB · Browser · Display · Input
    - Cada uno: `background: #1a1a1a`, `border: 1px solid #2d2d2d`, `border-radius: 5px`
    - Dot verde con glow cuando conectado
  - 3 botones: Wake TV · Launch Browser · Pair (first run)
- Card Advanced — 3 toggles

**Columna derecha:**
- Setup Guide — 4 pasos con checkmarks
- ADB Log — componente log (ver abajo)

**Estados del botón Connect ADB:**
- Idle: `border: 1.5px solid #44aaff`, `background: rgba(68,170,255,0.15)`, texto `#44aaff`
- Connecting: spinner + texto "Connecting..." 
- Connected: deshabilitado / texto "Connected ✓"
- Error: `border-color: #ff6644`, texto "Retry"

---

### 05 — Stream Viewer (Active)
**Screenshot:** `screenshots/05-stream-viewer.png`

Ocupa el 100% del área de contenido. `background: #000`.

**Overlays:**
- Top-left: badge LIVE (`color: #ff6644`) + badge uptime
  - `background: rgba(0,0,0,0.7)`, `border: 1px solid #333`, `border-radius: 5px`, JetBrains Mono 11px
- Top-right: toolbar `[⏸][⏹][⚙][⛶]`
  - `background: rgba(0,0,0,0.7)`, `border: 1px solid #2d2d2d`, iconos separados por `border-right: 1px solid #2d2d2d`
  - Se ocultan tras 3s de inactividad del mouse (`opacity: 0, transition: opacity 0.3s`)
- Bottom-right: stats overlay
  - `background: rgba(0,0,0,0.7)`, `border: 1px solid #333`, `border-radius: 6px`, flex-column, gap 3px
  - Latencia en verde/ámbar/rojo según valor
- Bottom-left: badge FireTV IP + ADB status

---

### 06 — Settings
**Screenshot:** `screenshots/06-settings.png`

**Layout:** 2 columnas.

**Columna izquierda:**
- Card Server: Port (input), SSL cert (input + Browse), SSL key (input + Browse)
- Card Auth: toggle + token input (enmascarado)

**Columna derecha:**
- Card System: 5 toggles (Launch at startup, Start minimized to tray, Auto-reconnect FireTV, Show stats overlay, Dark mode)
- Card About: info en JetBrains Mono 11px, link al repo en `#44aaff`

---

### 07 — System Tray
**Screenshot:** `screenshots/07-system-tray.png`

Popup flotante al hacer clic en el ícono de la bandeja del sistema.

**Ícono de tray:** Punto verde animado `●` + texto `EMISCREEN` en JetBrains Mono

**Popup (width: 260px):**
- Header: `● STREAMING` en `#44cc44` + uptime alineado a la derecha
- Mini-stats: 3 celdas (48ms / 30fps / 3.8M) con valores en `#44aaff 14px bold`
- Lista de acciones con íconos
- Footer: "Quit Emiscreen" alineado a la derecha, `#555`

---

## Componentes reutilizables

### Tab Bar
```
height: 36px
background: #1e1e1e
border-bottom: 2px solid #2d2d2d
Tab padding: 8px 16px
Active: color #44aaff, border-bottom: 2px solid #44aaff
Inactive: color #666
```

### Card / Section
```
background: #222222
border: 1.5px solid #333333
border-radius: 8px
padding: 12px
Section title: JetBrains Mono 12px, uppercase, letter-spacing 1px, color #666
              border-bottom: 1px dashed #333, padding-bottom 6px, margin-bottom 8px
```

### Toggle
```
width: 34px, height: 18px, border-radius: 9px
OFF: background #333, border 1.5px solid #444, thumb left:2px background #666
ON:  background rgba(68,170,255,0.3), border #44aaff, thumb left:17px background #44aaff
Thumb: 12px circular, transition: left 0.15s
```

### Activity Log / ADB Log
```
background: #161616
font-family: JetBrains Mono
font-size: 10px, line-height: 1.6
padding: 8px, border-radius: 5px
Colors: ok=#44cc44  info=#44aaff  warn=#ffaa33  err=#ff6644
Format: "> [HH:MM:SS] mensaje"
Behavior: auto-scroll al fondo, max 100 líneas
```

### Status Dot
```
width/height: 8px, border-radius: 50%
Connected:   background #44cc44, box-shadow: 0 0 6px #44cc44
Connecting:  background #ffaa33, animation: pulse 1.2s infinite
Disconnected: background #cc4444
```

### Button Variants
```
Base:    border 1.5px solid #555, background #2a2a2a, color #ccc, border-radius 7px, padding 7px 14px
Primary: border #44aaff, background rgba(68,170,255,0.15), color #44aaff, font-weight 700
Success: border #44cc44, background rgba(60,200,60,0.12), color #44cc44, font-weight 700
Danger:  border #ff6644, background rgba(255,100,60,0.12), color #ff6644
```

### Input
```
background: #1a1a1a
border: 1.5px solid #444
border-radius: 6px
padding: 6px 10px
font-family: JetBrains Mono, 12px
color: #cccccc
Focus: border-color #44aaff, box-shadow: 0 0 0 2px rgba(68,170,255,0.2)
```

---

## State Management (variables sugeridas)

```typescript
interface AppState {
  isFirstRun: boolean
  currentTab: 'dashboard' | 'source' | 'firetv' | 'stream' | 'settings'
  
  server: {
    status: 'stopped' | 'starting' | 'streaming' | 'paused'
    uptime: number  // seconds
    pid: number | null
  }
  
  firetv: {
    ip: string
    adbConnected: boolean
    browserLaunched: boolean
    displayAwake: boolean
    inputReady: boolean
  }
  
  source: {
    selected: 'ubuntu-desktop' | 'windows-pc' | 'nas-omv'
    resolution: string   // "1920x1080"
    fps: number
    bitrate: string      // "4M"
    codec: 'h264' | 'vp8'
  }
  
  metrics: {
    latencyMs: number
    fps: number
    bitrateActual: string
    resolution: string
    cpuPercent: number
    p2p: boolean
  }
  
  log: Array<{
    time: string
    type: 'ok' | 'info' | 'warn' | 'err'
    text: string
  }>
  
  settings: {
    port: number          // 8445
    sslCert: string
    sslKey: string
    tokenAuth: boolean
    token: string
    launchAtStartup: boolean
    startMinimized: boolean
    autoReconnect: boolean
    showStats: boolean
  }
}
```

---

## Auto-start por OS

**Windows:**
```
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
"Emiscreen" = "C:\path\to\emiscreen.exe --minimized"
```

**Linux:**
```ini
# ~/.config/autostart/emiscreen.desktop
[Desktop Entry]
Type=Application
Name=Emiscreen
Exec=/usr/local/bin/emiscreen --minimized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
```

---

## Orden de implementación sugerido

1. **Shell de la app** — ventana, tab bar, tray icon básico
2. **Tab Dashboard** — layout, botón Start/Stop, cards Source + FireTV
3. **Tab FireTV Connect** ← más importante, empezar aquí
4. **Integración Python** — lanzar proceso, leer stdout para log, HTTP stats
5. **Tab Source Config** — sliders, selector, preview
6. **Stream Viewer** — fullscreen en ventana, overlays HUD
7. **Tab Settings** — toggles, inputs, auto-start
8. **System Tray** — popup completo, mini-stats
9. **Onboarding wizard** — solo al primer arranque

---

*Emiscreen Desktop UI Handoff · by Cleyvin © 2026*
