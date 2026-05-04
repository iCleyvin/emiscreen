# Emiscreen Roadmap — Deja de prototipo a producto terminado

> **Regla de oro:** Tu PC local (Windows) es solo para **diseño y código**. Todo lo que implique compilar, empaquetar, o ejecutar el servidor backend se hace en **`cleyvinserv`** (Ubuntu server vía SSH).

---

## Fase 0: Validación End-to-End (Esta semana)

**Objetivo:** Confirmar que todo lo que escribimos funciona en hardware real antes de seguir puliendo.

- [ ] **0.1 Sincronizar código a `cleyvinserv`**
  - Opción A: `git push` + `git pull` en el servidor
  - Opción B: `rsync -avz --exclude='.venv' --exclude='__pycache__' ./ cleyvinserv:/mnt/datos/dev/emiscreen/`
  - *Recomendado:* Crear un script `scripts/sync-to-server.sh` que haga esto en un comando.

- [ ] **0.2 Probar servidor Python en `cleyvinserv` (Linux)**
  ```bash
  ssh cleyvinserv
  cd /mnt/datos/dev/emiscreen
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
  python -m emiscreen.server --source ubuntu-desktop
  ```
  - Verificar que FFmpeg capture sin errores (`x11grab` necesita un display X11 real o Xvfb).
  - Verificar que WebRTC responda en `https://<IP>:8445`.

- [ ] **0.3 Compilar APK de Fire TV en `cleyvinserv`**
  ```bash
  ssh cleyvinserv
  cd /mnt/datos/dev/emiscreen/firetv-app
  ./gradlew assembleDebug
  ```
  - Descargar el APK a tu PC local:
    ```bash
    scp cleyvinserv:/mnt/datos/dev/emiscreen/firetv-app/app/build/outputs/apk/debug/app-debug.apk ./emiscreen-firetv.apk
    ```

- [ ] **0.4 Instalar y probar en Fire TV real**
  ```bash
  adb connect <FIRETV_IP>:5555
  adb install emiscreen-firetv.apk
  ```
  - Abrir app, ingresar IP del servidor, confirmar stream + D-Pad + input relay.
  - Documentar cualquier lag, crash o comportamiento raro.

---

## Fase 1: Endurecimiento (Hardening) — Crítico

**Objetivo:** Que el servidor no se caiga nunca y que los errores sean comprensibles.

- [ ] **1.1 Validación de pre-requisitos al arrancar**
  - Detectar si `ffmpeg` existe en PATH; si no, mostrar mensaje claro y salir con código útil.
  - Detectar si el puerto 8445 está ocupado; si lo está, sugerir `--port`.
  - En Linux, detectar si `$DISPLAY` existe antes de lanzar `x11grab`.

- [ ] **1.2 Manejo de errores en captura**
  - Si FFmpeg muere inesperadamente, reiniciarlo automáticamente (watchdog) con backoff.
  - Si el pipe se rompe, cerrar gracefulmente la conexión WebRTC en lugar de dejarla colgada.

- [ ] **1.3 Logging profesional**
  - Escribir logs a archivo rotativo (`logs/emiscreen.log`) además de stdout.
  - Niveles: INFO para startup, DEBUG para FFmpeg verbose, ERROR para fallos.
  - Incluir timestamp con zona horaria.

- [ ] **1.4 Mejorar mensajes de error en el cliente web**
  - `"FFmpeg not found"` en lugar de `"Connection failed"`.
  - `"No display found"` cuando X11 no está disponible.
  - Overlay visual con instrucciones específicas según el error.

- [ ] **1.5 Actualizar installers (`install.sh` / `install.ps1`)**
  - El installer actual está desactualizado respecto a la nueva arquitectura (no menciona FFmpeg, no configura cert trust).
  - `install.ps1` debería verificar que FFmpeg esté instalado (`winget install ffmpeg` si falta).
  - `install.sh` debería instalar `xdotool` en Debian/Ubuntu si falta.

---

## Fase 2: Flujo de Trabajo Profesional (DX)

**Objetivo:** Que iterar sea tan fácil como `guardar → sync → probar`.

- [ ] **2.1 Script de sync inteligente**
  - Crear `scripts/dev-sync.sh`:
    ```bash
    #!/bin/bash
    rsync -avz --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
      ./ cleyvinserv:/mnt/datos/dev/emiscreen/
    ssh cleyvinserv 'cd /mnt/datos/dev/emiscreen && source .venv/bin/activate && python -m pytest tests/ -q'
    ```

- [ ] **2.2 Script de build remoto**
  - Crear `scripts/build-apk-remote.sh`:
    ```bash
    ssh cleyvinserv 'cd /mnt/datos/dev/emiscreen/firetv-app && ./gradlew assembleDebug'
    scp cleyvinserv:/mnt/datos/dev/emiscreen/firetv-app/app/build/outputs/apk/debug/app-debug.apk ./emiscreen-firetv.apk
    ```

- [ ] **2.3 Script de deploy servidor**
  - Crear `scripts/deploy-server.sh`:
    ```bash
    rsync -avz --exclude='.venv' ./ cleyvinserv:/mnt/datos/dev/emiscreen/
    ssh cleyvinserv 'sudo systemctl restart emiscreen'  # o el comando que uses
    ```

- [ ] **2.4 Hot-reload básico en desarrollo**
  - Opcional: usar `watchdog` para reiniciar el servidor Python cuando cambien los archivos `.py` en `cleyvinserv`.

---

## Fase 3: Pulido y Confiabilidad

**Objetivo:** Que se sienta como un producto comercial, no un script.

- [ ] **3.1 Auto-descubrimiento del servidor (mDNS/Bonjour)**
  - En `cleyvinserv`: publicar servicio `_emiscreen._tcp` via `avahi` o `python-zeroconf`.
  - En la app Fire TV: escanear la red local y mostrar una lista de servidores Emiscreen encontrados, en lugar de pedir IP manual.
  - *Impacto:* El usuario abre la app y ve "PC-Sala (192.168.1.50) → Conectar".

- [ ] **3.2 Indicador de calidad de conexión**
  - Usar `pc.getStats()` en el cliente para mostrar:
    - Bitrate de video recibido
    - Paquetes perdidos
    - Jitter (latencia estimada)
  - Mostrar una barra de señal (🟢🟡🔴) en el overlay de stats.

- [ ] **3.3 Watchdog del servidor**
  - Si FFmpeg se cuelga o el peer WebRTC se desconecta, reiniciar solo ese componente sin matar todo el servidor.
  - Máximo 3 reintentos en 60 segundos antes de rendirse y notificar.

- [ ] **3.4 Mejorar reconexión**
  - Jitter en el backoff exponencial (evitar que 100 clientes reconecten al mismo tiempo).
  - Reconexión silenciosa (sin mostrar overlay de error si reconecta en <3s).

- [ ] **3.5 Servicio Windows / Systemd robusto**
  - Crear un script `scripts/install-service.ps1` que registre Emiscreen como servicio de Windows (usando NSSM o `pywin32`).
  - Mejorar `emiscreen.service` para Linux con `Restart=always` y `RestartSec=5`.

---

## Fase 4: Features que lo hacen "Perfecto"

**Objetivo:** Funcionalidades de monitor profesional.

- [ ] **4.1 Soporte multi-monitor**
  - En Windows: listar displays con `gdigrab` y permitir `--display 0`, `--display 1`, etc.
  - En Linux: soportar `:0.0`, `:0.1`, etc.
  - El cliente web podría tener un botón para cambiar de monitor (requiere renegociación WebRTC o múltiples tracks).

- [ ] **4.2 Audio forwarding**
  - Capturar audio del desktop con FFmpeg (`-f pulse` en Linux, `-f dshow` en Windows) y enviarlo como `AudioStreamTrack` por WebRTC.
  - En el Fire TV, el audio saldría por los altavoces de la TV. Game-changer.

- [ ] **4.3 Escalado inteligente de input**
  - Si el PC captura a 1920x1080 pero el Fire TV muestra a 1280x720, escalar las coordenadas del mouse/touch para que coincidan.
  - Fórmula: `scaled_x = raw_x * (capture_width / video_element_width)`.

- [ ] **4.4 Clipboard sync (opcional avanzado)**
  - Detectar cambios en el clipboard del servidor y enviarlos por WebSocket al cliente.
  - En Fire TV: Ctrl+C en PC → popup de "Texto copiado: ..." en la app (o integrar con teclado virtual).

- [ ] **4.5 Control remoto avanzado**
  - Soportar gestos multitouch (pinch-to-zoom simulado como Ctrl+scroll).
  - Soportar arrastrar-y-soltar desde el Fire TV (touchstart → mousemove → mouseup).

---

## Fase 5: Release Profesional

**Objetivo:** Distribuir sin vergüenza.

- [ ] **5.1 APK firmado (release)**
  - Generar keystore en `cleyvinserv`:
    ```bash
    keytool -genkey -v -keystore emiscreen.keystore -alias emiscreen -keyalg RSA -validity 10000
    ```
  - Configurar `build.gradle` para usar el keystore y generar `app-release.apk`.

- [ ] **5.2 Versionado automático**
  - `pyproject.toml` y `build.gradle` deben compartir el mismo número de versión.
  - Script `scripts/bump-version.sh 1.1.0` que actualice ambos archivos + tag de git.

- [ ] **5.3 Changelog automatizado**
  - Usar `git cliff` o similar para generar `CHANGELOG.md` desde conventional commits.

- [ ] **5.4 Pipeline de release en `cleyvinserv`**
  - Un solo comando que:
    1. Ejecute tests
    2. Compile APK release
    3. Empaquete el servidor como tarball + Dockerfile
    4. Genere GitHub Release (si usas GitHub CLI desde el server)

---

## Orden recomendado de ataque

**Esta semana:** Fase 0 (validar que funciona) + Fase 1.1 y 1.5 (instalers).  
**Semana 2:** Fase 1 completa + Fase 2 (scripts de sync/build).  
**Semana 3:** Fase 3 (polish + auto-descubrimiento).  
**Semana 4+:** Fase 4 y 5 según prioridad personal.

---

## Notas sobre `cleyvinserv`

- Compila siempre desde `/mnt/datos/dev/emiscreen`.
- Si Android SDK no está en PATH del servidor, agregar a `~/.bashrc`:
  ```bash
  export ANDROID_HOME=/opt/android-sdk
  export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
  ```
- Para probar el servidor en el puerto 8445 desde fuera, asegurar que `ufw` o el firewall del server lo permita:
  ```bash
  sudo ufw allow 8445/tcp
  ```
