# Emiscreen - Build Fire TV APK remotely on cleyvinserv
# Usage: .\scripts\build-apk-remote.ps1
# Builds the debug APK on the server and downloads it to ./emiscreen-firetv.apk

param(
    [string]$Server = "cleyvinserv",
    [string]$RemotePath = "/mnt/datos/dev/emiscreen",
    [string]$OutputPath = "./emiscreen-firetv.apk"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Emiscreen Fire TV APK Build ===" -ForegroundColor Cyan
Write-Host "Server: $Server" -ForegroundColor Gray
Write-Host "Output: $OutputPath" -ForegroundColor Gray
Write-Host ""

# Ensure code is synced first
Write-Host "[1/3] Syncing code..." -ForegroundColor Yellow
& $PSScriptRoot\sync-to-server.ps1 -Server $Server -RemotePath $RemotePath -NoTests

# Build APK on server
Write-Host ""
Write-Host "[2/3] Building APK on server..." -ForegroundColor Yellow
Write-Host "  This may take 2-5 minutes on first run..." -ForegroundColor Gray

ssh $Server @"
set -e
cd ${RemotePath}/firetv-app
if [ ! -x ./gradlew ]; then
    echo 'Gradle wrapper not found. Trying system gradle...'
    gradle assembleDebug
else
    ./gradlew assembleDebug
fi
echo "BUILD_OK"
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed! Check output above." -ForegroundColor Red
    exit 1
}

# Download APK
Write-Host ""
Write-Host "[3/3] Downloading APK..." -ForegroundColor Yellow

$RemoteApkPath = "${RemotePath}/firetv-app/app/build/outputs/apk/debug/app-debug.apk"
scp "${Server}:${RemoteApkPath}" "$OutputPath"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  APK ready!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Location: $OutputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Install on Fire TV:" -ForegroundColor White
Write-Host "  adb connect <FIRETV_IP>:5555" -ForegroundColor Gray
Write-Host "  adb install $OutputPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Or run directly:" -ForegroundColor White
Write-Host "  adb connect <FIRETV_IP>:5555 && adb install $OutputPath && adb shell am start -n com.icleyvin.emiscreen/.MainActivity" -ForegroundColor Cyan
