# Emiscreen - Fase 0 Orchestrator
# Ejecuta toda la validación end-to-end automáticamente.
# Uso: .\scripts\phase0-orchestrator.ps1 -FireTvIp 192.168.1.100

param(
    [Parameter(Mandatory=$true)]
    [string]$FireTvIp,

    [string]$Server = "cleyvinserv",
    [string]$RemotePath = "/mnt/datos/dev/emiscreen",
    [string]$ApkOutput = "./emiscreen-firetv.apk",
    [string]$Source = "ubuntu-desktop"
)

$ErrorActionPreference = "Stop"
$host.ui.RawUI.WindowTitle = "Emiscreen - Fase 0 Orchestrator"

function Banner($text, $color = "Cyan") {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $color
    Write-Host "  $text" -ForegroundColor $color
    Write-Host "============================================" -ForegroundColor $color
    Write-Host ""
}

function Step($num, $total, $text) {
    Write-Host ""
    Write-Host "[$num/$total] $text" -ForegroundColor Yellow
    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
}

$TotalSteps = 6
$StartTime = Get-Date

Banner "FASE 0: VALIDACION END-TO-END" "Cyan"
Write-Host "Fire TV IP:  $FireTvIp" -ForegroundColor Gray
Write-Host "Server:      $Server" -ForegroundColor Gray
Write-Host "Source:      $Source" -ForegroundColor Gray
Write-Host ""
Read-Host "Presiona ENTER para comenzar..."

# ========================================================================
# STEP 1: Validación local
# ========================================================================
Step 1 $TotalSteps "Validando código local..."
$LocalResults = .venv\Scripts\python.exe scripts\validate-local.py | ConvertFrom-Json
$Passed = $LocalResults.passed
$Failed = $LocalResults.failed
Write-Host "  Local checks: $Passed passed, $Failed failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
if ($Failed -gt 0) {
    Write-Host "  Fallos:" -ForegroundColor Red
    $LocalResults.checks | Where-Object { $_.status -eq "FAIL" } | ForEach-Object {
        Write-Host "    - $($_.name): $($_.output)" -ForegroundColor Red
    }
    exit 1
}

# ========================================================================
# STEP 2: Sync a cleyvinserv
# ========================================================================
Step 2 $TotalSteps "Sync código a cleyvinserv + tests..."
& $PSScriptRoot\sync-to-server.ps1 -Server $Server -RemotePath $RemotePath -NoTests:$false
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sync falló. Abortando." -ForegroundColor Red
    exit 1
}

# ========================================================================
# STEP 3: Compilar APK remotamente
# ========================================================================
Step 3 $TotalSteps "Compilando APK de Fire TV en servidor..."
& $PSScriptRoot\build-apk-remote.ps1 -Server $Server -RemotePath $RemotePath -OutputPath $ApkOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build APK falló. Abortando." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $ApkOutput)) {
    Write-Host "APK no encontrado en $ApkOutput. Abortando." -ForegroundColor Red
    exit 1
}
Write-Host "  APK listo: $ApkOutput" -ForegroundColor Green

# ========================================================================
# STEP 4: Conectar ADB e instalar
# ========================================================================
Step 4 $TotalSteps "Conectando ADB al Fire TV..."
$adbConnect = adb connect "${FireTvIp}:5555" 2>&1
Write-Host "  $adbConnect" -ForegroundColor Gray

$devices = adb devices 2>&1 | Select-String "${FireTvIp}:5555"
if (-not $devices) {
    Write-Host "  No se pudo conectar ADB. Verifica que el Fire TV tenga ADB Debugging activado." -ForegroundColor Red
    Write-Host "  Settings → My Fire TV → Developer Options → ADB Debugging = ON" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ADB conectado." -ForegroundColor Green

Step 4 $TotalSteps "Instalando APK en Fire TV..."
$installResult = adb install -r $ApkOutput 2>&1
Write-Host "  $installResult" -ForegroundColor Gray
if ($installResult -match "Success") {
    Write-Host "  Instalación exitosa." -ForegroundColor Green
} elseif ($installResult -match "INSTALL_FAILED_ALREADY_EXISTS") {
    Write-Host "  APK ya existe, forzando reinstall..." -ForegroundColor Yellow
    adb install -r $ApkOutput 2>&1 | Out-Null
} else {
    Write-Host "  Advertencia: resultado inesperado de instalación." -ForegroundColor Yellow
}

# ========================================================================
# STEP 5: Arrancar servidor remotamente (en background via nohup)
# ========================================================================
Step 5 $TotalSteps "Iniciando servidor Emiscreen en cleyvinserv..."
ssh $Server "cd $RemotePath && source .venv/bin/activate && pkill -f 'emiscreen.server' 2>/dev/null; nohup python -m emiscreen.server --source $Source --host 0.0.0.0 > logs/emiscreen.log 2>&1 &"
Start-Sleep -Seconds 3

# Verificar que el servidor responde
$serverIp = ssh $Server "hostname -I | awk '{print \$1}'" 2>$null
$serverIp = $serverIp.Trim()
Write-Host "  IP del servidor detectada: $serverIp" -ForegroundColor Gray

# Check health endpoint
$healthUrl = "https://${serverIp}:8445/health"
Write-Host "  Verificando health endpoint..." -ForegroundColor Gray
try {
    # Ignore cert validation for self-signed
    $health = Invoke-WebRequest -Uri $healthUrl -Method GET -UseBasicParsing -SkipCertificateCheck -TimeoutSec 10 | Select-Object -ExpandProperty Content
    Write-Host "  Health check: $health" -ForegroundColor Green
} catch {
    Write-Host "  No se pudo verificar health endpoint (puede ser normal si el certificado es nuevo)." -ForegroundColor Yellow
    Write-Host "  URL: $healthUrl" -ForegroundColor Gray
}

# ========================================================================
# STEP 6: Abrir app en Fire TV
# ========================================================================
Step 6 $TotalSteps "Abriendo Emiscreen en el Fire TV..."
adb shell am start -n com.icleyvin.emiscreen/.MainActivity 2>&1 | Out-Null
Write-Host "  App lanzada en Fire TV." -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "  Si es la primera vez, usa el MENU (≡) en el remoto para configurar la IP del servidor." -ForegroundColor Cyan
Write-Host "  IP a ingresar: $serverIp" -ForegroundColor Cyan

# ========================================================================
# DONE
# ========================================================================
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Banner "FASE 0 COMPLETADA" "Green"
Write-Host "Duración: $($Duration.ToString('mm\:ss'))" -ForegroundColor Gray
Write-Host ""
Write-Host "Resumen:" -ForegroundColor White
Write-Host "  Servidor:  https://${serverIp}:8445" -ForegroundColor Cyan
Write-Host "  APK:       $ApkOutput" -ForegroundColor Cyan
Write-Host "  Fire TV:   $FireTvIp (app instalada y abierta)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Comandos útiles:" -ForegroundColor White
Write-Host "  Ver logs servidor:  ssh $Server 'tail -f $RemotePath/logs/emiscreen.log'" -ForegroundColor Gray
Write-Host "  Detener servidor:   ssh $Server 'pkill -f emiscreen.server'" -ForegroundColor Gray
Write-Host "  Reinstalar APK:     adb install -r $ApkOutput" -ForegroundColor Gray
Write-Host ""
Write-Host "Para continuar con Fase 1 (Endurecimiento), avisame los resultados:" -ForegroundColor Yellow
Write-Host "  - ¿Se ve el stream en el Fire TV?" -ForegroundColor Yellow
Write-Host "  - ¿El D-Pad mueve el mouse?" -ForegroundColor Yellow
Write-Host "  - ¿Hay lag o se corta?" -ForegroundColor Yellow
