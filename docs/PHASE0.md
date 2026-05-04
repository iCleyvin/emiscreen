# Fase 0: Validación End-to-End

> **Regla:** Todo el código se edita en tu PC local (Windows). Todo lo que compila o ejecuta el servidor se hace en **`cleyvinserv`** vía SSH.

---

## Requisitos previos

### En tu PC local (Windows)
- **OpenSSH client** (viene con Windows 10/11; verifica con `ssh -V` en PowerShell).
- **ADB** instalado si vas a instalar el APK directamente desde tu PC:
  ```powershell
  winget install AndroidSDKPlatformTools
  ```
- Acceso SSH configurado a `cleyvinserv` (asegúrate de que `ssh cleyvinserv` funcione).

### En cleyvinserv (Ubuntu Server)
- Python 3.10+ y `python3-venv`.
- FFmpeg instalado:
  ```bash
  sudo apt update && sudo apt install -y ffmpeg
  ```
- Si vas a capturar display físico (no Xvfb): un entorno X11 activo o `xvfb`.
- Android SDK + Gradle (para compilar el APK):
  ```bash
  # Verificar
  gradle --version
  # o
  ./gradlew --version   # dentro de firetv-app/
  ```

---

## Paso 1: Sincronizar código al servidor

Desde tu PC, en la carpeta del proyecto:

```powershell
# PowerShell (recomendado en Windows)
.\scripts\sync-to-server.ps1

# O si tienes Git Bash / WSL
bash ./scripts/sync-to-server.sh
```

Esto hará:
1. Subir todo el código a `/mnt/datos/dev/emiscreen/` en `cleyvinserv`.
2. Crear/actualizar el virtualenv `.venv`.
3. Instalar dependencias de `requirements.txt`.
4. Ejecutar tests automáticos (`pytest`).

**Resultado esperado:**
```
============================== 8 passed in 0.03s ==============================
  Sync complete!
```

---

## Paso 2: Probar el servidor en cleyvinserv

### Opción A: Script automatizado desde tu PC
```powershell
.\scripts\run-server-remote.ps1 --source ubuntu-desktop
```

Esto sincroniza, conecta por SSH y arranca el servidor. Verás los logs en tu terminal.

### Opción B: Manual por SSH
```bash
ssh cleyvinserv
cd /mnt/datos/dev/emiscreen
source .venv/bin/activate
python -m emiscreen.server --source ubuntu-desktop
```

**Qué verificar:**
- [ ] El servidor arranca sin errores de import.
- [ ] Aparece: `Server running at https://0.0.0.0:8445`.
- [ ] FFmpeg arranca: `Starting Linux capture: ffmpeg -f x11grab ...`
- [ ] Si no tienes display X11, usa `--source nas-omv` (Xvfb virtual).

**Probar desde tu PC:**
Abre en tu navegador: `https://<IP_DE_CLEYVINSERV>:8445`
> Verás una advertencia de certificado (es normal, es autofirmado). Haz clic en **Advanced → Proceed**.

Deberías ver:
- Overlay "Connecting..." → desaparece.
- Video de la pantalla del servidor (o negro si es Xvfb sin nada corriendo).
- Stats overlay si mueves el mouse sobre el cliente web.

---

## Paso 3: Compilar el APK de Fire TV

Desde tu PC:

```powershell
.\scripts\build-apk-remote.ps1
```

Esto hará:
1. Sincronizar código.
2. Compilar `assembleDebug` en `cleyvinserv`.
3. Descargar el APK a `./emiscreen-firetv.apk` en tu PC.

**Resultado esperado:**
```
============================================
  APK ready!
============================================
Location: .\emiscreen-firetv.apk
```

> **Nota:** La primera compilación puede tardar 3-5 minutos porque Gradle descarga dependencias.

---

## Paso 4: Instalar y probar en Fire TV real

### 4.1 Conectar ADB al Fire TV
```powershell
adb connect <IP_DEL_FIRETV>:5555
adb devices   # Debe listar tu dispositivo
```

Si no aparece, asegúrate de haber habilitado **ADB Debugging** en:
`Settings → My Fire TV → Developer Options → ADB Debugging = ON`

### 4.2 Instalar APK
```powershell
adb install emiscreen-firetv.apk
```

### 4.3 Abrir la app
Desde el Fire TV, ve a **Aplicaciones** y abre **Emiscreen**.

La primera vez te pedirá la IP del servidor. Ingresa la IP de `cleyvinserv` (ej. `192.168.1.50`).

### 4.4 Verificar funcionamiento
- [ ] El stream de video aparece en pantalla completa.
- [ ] D-Pad del remoto mueve el cursor del mouse en el servidor.
- [ ] Botón **Select** (centro) hace clic.
- [ ] Botón **Back** envía Escape.
- [ ] Menú (≡) abre el diálogo de cambiar IP.

---

## Troubleshooting Fase 0

### "ffmpeg not found" en el servidor
```bash
ssh cleyvinserv
sudo apt install -y ffmpeg
```

### "No module named aiortc" o similar
El script `sync-to-server.ps1` debería instalar dependencias automáticamente. Si falla:
```bash
ssh cleyvinserv
cd /mnt/datos/dev/emiscreen
source .venv/bin/activate
pip install -r requirements.txt
```

### "Cannot open display :0" (x11grab)
Significa que no hay sesión X11 activa en el servidor. Soluciones:
- Usa `--source nas-omv` para capturar un display virtual Xvfb.
- O inicia una sesión X11 en el servidor.

### Certificado SSL bloquea el navegador
Esperado. El servidor genera un cert autofirmado en primer arranque. Puedes:
- Ignorar la advertencia en navegador (Advanced → Proceed).
- Confiar el cert en tu PC: ejecuta `scripts/trust-cert.ps1` (como Admin).
- Usar la app nativa de Fire TV, que ignora el error automáticamente.

### Gradle no encontrado en cleyvinserv
```bash
ssh cleyvinserv
sudo apt install -y gradle
# o instalar Android SDK + command line tools
```

### APK no instala en Fire TV
- Verifica que ADB esté conectado: `adb devices`
- Asegúrate de haber habilitado **Install Unknown Apps** en el Fire TV.
- Si ya existe una versión anterior, desinstálala:
  ```powershell
  adb uninstall com.icleyvin.emiscreen
  adb install emiscreen-firetv.apk
  ```

---

## Checklist de Fase 0

- [ ] `sync-to-server.ps1` ejecuta sin errores y pasa tests.
- [ ] Servidor arranca en `cleyvinserv` y responde en puerto 8445.
- [ ] Cliente web (desde tu PC) muestra el stream del servidor.
- [ ] `build-apk-remote.ps1` genera `emiscreen-firetv.apk`.
- [ ] APK se instala correctamente en Fire TV.
- [ ] App nativa muestra el stream y el D-Pad controla el mouse.

**Cuando completes esta checklist, avísame y pasamos a Fase 1 (Endurecimiento).**
