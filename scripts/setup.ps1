# Emiscreen - Setup Script for Windows
# Installs Python dependencies for running the Emiscreen server

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Emiscreen - Windows Setup Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectDir = Split-Path -Parent $PSScriptRoot

# 1. Check Python
Write-Host "[1/4] Checking Python..." -ForegroundColor Yellow
try {
    $PythonVersion = python --version 2>&1
    Write-Host "  Python: $PythonVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Python not found. Install Python 3.10+ from python.org" -ForegroundColor Red
    exit 1
}

# 2. Check FFmpeg
Write-Host "[2/4] Checking FFmpeg..." -ForegroundColor Yellow
try {
    $FfmpegVersion = ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  FFmpeg: $FfmpegVersion" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: FFmpeg not found. Screen capture will not work." -ForegroundColor Yellow
    Write-Host "  Install FFmpeg: winget install ffmpeg" -ForegroundColor Yellow
}

# 3. Create virtual environment
Write-Host "[3/4] Creating virtual environment..." -ForegroundColor Yellow
$VenvDir = Join-Path $ProjectDir ".venv"
if (-not (Test-Path $VenvDir)) {
    python -m venv $VenvDir
    Write-Host "  Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "  Virtual environment already exists" -ForegroundColor Green
}

# 4. Install Python dependencies
Write-Host "[4/4] Installing Python dependencies..." -ForegroundColor Yellow
& "$VenvDir\Scripts\Activate.ps1"
pip install --upgrade pip -q
pip install -r (Join-Path $ProjectDir "requirements.txt") -q
Write-Host "  Dependencies installed" -ForegroundColor Green

# 5. Generate SSL certificates
$CertDir = Join-Path $ProjectDir "certs"
$CertFile = Join-Path $CertDir "cert.pem"
$KeyFile = Join-Path $CertDir "key.pem"

if (-not (Test-Path $CertFile) -or -not (Test-Path $KeyFile)) {
    Write-Host "Generating SSL certificates..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
    openssl req -new -x509 -keyout $KeyFile -out $CertFile -days 3650 -nodes `
        -subj "/CN=emiscreen.local" `
        -addext "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1" 2>$null
    Write-Host "  SSL certificates generated" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  Start server: .\scripts\start.ps1 -Source windows-desktop"
Write-Host ""
