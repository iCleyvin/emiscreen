# Emiscreen - One-Line Installer for Windows (PowerShell)
# Usage: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
# After install, just type: emiscreen

param(
    [string]$FireTV = "",
    [string]$Source = "windows-pc",
    [string]$Resolution = "1920x1080",
    [int]$FPS = 30,
    [int]$Port = 8445,
    [switch]$SkipADBCheck,
    [switch]$Help
)

$InstallerVersion = "2.0.0"

if ($Help) {
    Write-Host @"
Emiscreen One-Line Windows Installer v$InstallerVersion

Usage:
    iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex

After installation, run from ANY terminal:
    emiscreen
    emiscreen --firetv 192.168.1.100
    emiscreen --help

Parameters:
    -FireTV        FireTV IP address
    -Source        Capture source (windows-pc, ubuntu-desktop, nas-omv)
    -Resolution    Resolution (default: 1920x1080)
    -FPS           Frame rate (default: 30)
    -Port          Server port (default: 8445)
    -SkipADBCheck  Skip ADB connection test

"@
    exit 0
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Emiscreen Installer v$InstallerVersion" -ForegroundColor Cyan
Write-Host "  Remote Display via WebRTC" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectDir = "$env:USERPROFILE\emiscreen"
$OpenSSLInstalled = $false

Write-Host "[1/4] Environment check..." -ForegroundColor Yellow
Write-Host "  OS: Windows $([System.Environment]::OSVersion.Version)" -ForegroundColor Gray
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Install OpenSSL if needed
$OpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $OpenSSL) {
    Write-Host "  Installing OpenSSL..." -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install IgorZinovievTools.OpenSSL.Light --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        $OpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
    }
}
if ($OpenSSL) {
    $OpenSSLInstalled = $true
    Write-Host "  OpenSSL: available" -ForegroundColor Green
} else {
    Write-Host "  OpenSSL: not available (will use fallback)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/4] Downloading Emiscreen..." -ForegroundColor Yellow

if (Test-Path $ProjectDir) {
    Write-Host "  Updating existing installation..." -ForegroundColor Yellow
    Set-Location $ProjectDir
    git pull 2>&1 | Out-Null
} else {
    Write-Host "  Cloning repository..." -ForegroundColor Cyan
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone --depth 1 https://github.com/iCleyvin/emiscreen.git $ProjectDir 2>&1 | Out-Null
    } else {
        $ZipPath = "$env:TEMP\emiscreen_main.zip"
        Invoke-WebRequest -Uri "https://github.com/iCleyvin/emiscreen/archive/refs/heads/main.zip" -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP" -Force
        Move-Item -Path "$env:TEMP\emiscreen-main\*" -Destination $ProjectDir -Force
        Remove-Item -Path $ZipPath, "$env:TEMP\emiscreen-main" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "  Installed to $ProjectDir" -ForegroundColor Green

Write-Host ""
Write-Host "[3/4] Setting up Python..." -ForegroundColor Yellow

# Find Python
$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    $result = & $cmd --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $PythonCmd = $cmd
        break
    }
}

if (-not $PythonCmd) {
    Write-Host "  Python not found, installing..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Write-Host "  Python installed! RESTART POWERSHELL and run installer again." -ForegroundColor Green
        exit 0
    }
    Write-Host "  ERROR: Cannot install Python automatically" -ForegroundColor Red
    exit 1
}
Write-Host "  Python: $PythonCmd" -ForegroundColor Green

# Create venv
$VenvDir = "$ProjectDir\.venv"
if (-not (Test-Path $VenvDir)) {
    & $PythonCmd -m venv $VenvDir 2>&1 | Out-Null
}
$VenvPython = "$VenvDir\Scripts\python.exe"
Write-Host "  Virtual environment: ready" -ForegroundColor Green

# Install dependencies
& $VenvPython -m pip install --upgrade pip -q 2>&1 | Out-Null
& $VenvPython -m pip install -r "$ProjectDir\requirements.txt" -q 2>&1 | Out-Null
Write-Host "  Dependencies: installed" -ForegroundColor Green

Write-Host ""
Write-Host "[4/4] Configuring..." -ForegroundColor Yellow

# Create launcher script
$LauncherContent = '@echo off
setlocal
set SCRIPT_DIR=%~dp0
"%SCRIPT_DIR%.venv\Scripts\python.exe" "%SCRIPT_DIR%emiscreen.py" %*
'
$LauncherPath = "$ProjectDir\emiscreen.bat"
$LauncherContent | Out-File -FilePath $LauncherPath -Encoding ASCII

# Add to PATH for current session (persistent via Environment Variable)
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*emiscreen*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$ProjectDir", "User")
    $env:Path = "$env:Path;$ProjectDir"
}
Write-Host "  Launcher: $LauncherPath" -ForegroundColor Green
Write-Host "  PATH: updated (run 'emiscreen' from any terminal)" -ForegroundColor Gray

# SSL certificates
$CertDir = "$ProjectDir\certs"
if (-not (Test-Path $CertDir)) { New-Item -ItemType Directory -Force -Path $CertDir | Out-Null }

if ($OpenSSLInstalled -and (-not (Test-Path "$CertDir\cert.pem"))) {
    Write-Host "  Generating SSL certificates..." -ForegroundColor Cyan
    & openssl req -new -x509 -keyout "$CertDir\key.pem" -out "$CertDir\cert.pem" -days 3650 -nodes -subj "/CN=emiscreen.local" 2>&1 | Out-Null
    Write-Host "  SSL: generated" -ForegroundColor Green
} else {
    Write-Host "  SSL: will auto-generate on first run" -ForegroundColor Gray
}

# Environment file
$envContent = @"
EMISCREEN_PORT=$Port
EMISCREEN_SOURCE=$Source
EMISCREEN_RESOLUTION=$Resolution
EMISCREEN_FPS=$FPS
EMISCREEN_FIRETV_IP=$FireTV
"@
$envContent | Out-File -FilePath "$ProjectDir\.env" -Encoding UTF8

# Test ADB
if ($FireTV -and -not $SkipADBCheck) {
    $ADB = Get-Command adb -ErrorAction SilentlyContinue
    if ($ADB) {
        $addr = if ($FireTV -match ":\d+$") { $FireTV } else { "$FireTV`:5555" }
        $conn = & adb connect $addr 2>&1
        if ($conn -match "connected") { Write-Host "  FireTV: connected" -ForegroundColor Green }
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Location: $ProjectDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now open a NEW terminal and run:" -ForegroundColor White
Write-Host "    emiscreen" -ForegroundColor Green
Write-Host ""
if ($FireTV) {
    Write-Host "    emiscreen --firetv $FireTV" -ForegroundColor Green
}
Write-Host ""
Write-Host "Then open: https://localhost:$Port in your browser" -ForegroundColor White
Write-Host ""