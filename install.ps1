# Emiscreen - One-Line Installer for Windows (PowerShell)
# Usage: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
# Or: irm https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex

param(
    [string]$FireTV = "",
    [string]$Source = "windows-pc",
    [string]$Resolution = "1920x1080",
    [int]$FPS = 30,
    [int]$Port = 8445,
    [switch]$Update,
    [switch]$Help
)

$InstallerVersion = "3.0.0"

if ($Help) {
    Write-Host @"
Emiscreen Installer v$InstallerVersion

Usage:
    irm https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex

Options:
    -FireTV     FireTV IP address
    -Source     Capture source (windows-pc, ubuntu-desktop, nas-omv)
    -Resolution Resolution (default: 1920x1080)
    -FPS        Frame rate (default: 30)
    -Port       Server port (default: 8445)
    -Update     Force update even if already installed

After install, run from any terminal:
    emiscreen

"@
    exit 0
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Repo = "iCleyvin/emiscreen"
$InstallDir = "$env:LOCALAPPDATA\emiscreen"
$LauncherDir = "$env:LOCALAPPDATA\emiscreen\bin"
$ExePath = "$LauncherDir\emiscreen.exe"

Write-Host ""
Write-Host "=== Emiscreen v$InstallerVersion ===" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# CLEANUP: Remove old installations and artifacts
# =============================================================================
Write-Host "[Cleanup] Checking for old installations..." -ForegroundColor Yellow

$OldDirs = @(
    "$env:USERPROFILE\emiscreen",
    "$env:LOCALAPPDATA\emiscreen"
)

$OldPathEntries = @(
    "$env:USERPROFILE\emiscreen",
    "$env:LOCALAPPDATA\emiscreen\bin"
)

# Also clean up if running from inside an old emiscreen folder
if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\emiscreen\server.py")) {
    $OldDirs += $PSScriptRoot
}

foreach ($dir in $OldDirs) {
    if (Test-Path $dir) {
        Write-Host "  Removing old installation: $dir" -ForegroundColor Gray
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean PATH of old entries
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ -and $_ -notlike "*emiscreen*" }
[Environment]::SetEnvironmentVariable("Path", ($CurrentPath -join ";"), "User")
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + ($CurrentPath -join ";")

Write-Host "  Old artifacts cleaned" -ForegroundColor Gray

# =============================================================================
# INSTALL: Fresh installation
# =============================================================================
Write-Host ""
Write-Host "[Install] Downloading Emiscreen..." -ForegroundColor Yellow

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $LauncherDir | Out-Null

# Download latest release
try {
    $ZipUrl = "https://github.com/$Repo/archive/refs/heads/main.zip"
    $ZipPath = "$env:TEMP\emiscreen_main.zip"

    Write-Host "  Downloading from GitHub..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 120

    Write-Host "  Extracting..." -ForegroundColor Gray
    Expand-Archive -Path $ZipPath -DestinationPath $env:TEMP -Force
    Move-Item -Path "$env:TEMP\emiscreen-main\*" -Destination $InstallDir -Force
    Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:TEMP\emiscreen-main" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "  Installed to: $InstallDir" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Download failed: $_" -ForegroundColor Red
    exit 1
}

# =============================================================================
# PYTHON SETUP
# =============================================================================
Write-Host ""
Write-Host "[Python] Setting up environment..." -ForegroundColor Yellow

$VenvDir = "$InstallDir\.venv"
$VenvPython = "$VenvDir\Scripts\python.exe"

# Find or install Python
$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    $result = & $cmd --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $PythonCmd = $cmd
        break
    }
}

if (-not $PythonCmd) {
    Write-Host "  Python not found. Installing..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Write-Host "  Python installed! Restart PowerShell and run installer again." -ForegroundColor Green
        exit 0
    }
    Write-Host "  ERROR: Cannot install Python. Install manually from python.org" -ForegroundColor Red
    exit 1
}

Write-Host "  Python: $PythonCmd" -ForegroundColor Gray

# Create venv
if (-not (Test-Path $VenvDir)) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Gray
    & $PythonCmd -m venv $VenvDir 2>&1 | Out-Null
}

# Install dependencies
Write-Host "  Installing dependencies..." -ForegroundColor Gray
& $VenvPython -m pip install --upgrade pip -q 2>&1 | Out-Null
& $VenvPython -m pip install -r "$InstallDir\requirements.txt" -q 2>&1 | Out-Null

# Install the package normally (non-editable) so it's importable
Write-Host "  Installing package..." -ForegroundColor Gray
& $VenvPython -m pip install "$InstallDir" --quiet 2>&1 | Out-Null

Write-Host "  Dependencies installed" -ForegroundColor Green

# =============================================================================
# SSL CERTIFICATES - Generate using Python cryptography (no external deps)
# =============================================================================
Write-Host ""
Write-Host "[SSL] Generating certificates..." -ForegroundColor Yellow

$CertDir = "$InstallDir\certs"
$CertFile = "$CertDir\cert.pem"
$KeyFile = "$CertDir\key.pem"

New-Item -ItemType Directory -Force -Path $CertDir | Out-Null

if (-not (Test-Path $CertFile)) {
    $GenCertScript = @"
import os, ipaddress
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
import datetime

cert_dir = r'$CertDir'
cert_path = os.path.join(cert_dir, 'cert.pem')
key_path = os.path.join(cert_dir, 'key.pem')

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

subject = issuer = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'emiscreen.local')])
cert = (
    x509.CertificateBuilder()
    .subject_name(subject)
    .issuer_name(issuer)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(datetime.datetime.utcnow())
    .not_valid_after(datetime.datetime.utcnow() + datetime.timedelta(days=3650))
    .add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName('emiscreen.local'),
            x509.DNSName('localhost'),
            x509.IPAddress(ipaddress.IPv4Address('127.0.0.1')),
        ]),
        critical=False,
    )
    .sign(key, hashes.SHA256())
)

cert_pem = cert.public_bytes(serialization.Encoding.PEM)
key_pem = key.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.TraditionalOpenSSL,
    serialization.NoEncryption(),
)

with open(cert_path, 'wb') as f: f.write(cert_pem)
with open(key_path, 'wb') as f: f.write(key_pem)
print('OK')
"@

    $GenCertScript | Out-File -FilePath "$InstallDir\gen_certs.py" -Encoding UTF8
    & $VenvPython "$InstallDir\gen_certs.py" 2>&1 | Out-Null
    Remove-Item "$InstallDir\gen_certs.py" -Force -ErrorAction SilentlyContinue
}

Write-Host "  Certificates ready" -ForegroundColor Green

# =============================================================================
# CREATE LAUNCHER
# =============================================================================
Write-Host ""
Write-Host "[Launcher] Creating executable..." -ForegroundColor Yellow

# Create a proper Windows executable wrapper using Python
$LaunchScript = @"
import sys, os, subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_PYTHON = os.path.join(SCRIPT_DIR, ".venv", "Scripts", "python.exe")

HELP_TEXT = '''Emiscreen - Remote Display via WebRTC

Usage: emiscreen [options]
  --source, -s NAME    Capture source (ubuntu-desktop, windows-pc, nas-omv)
  --firetv, -f IP      FireTV IP for auto-launch
  --resolution, -r RES  Resolution (default: 1920x1080)
  --fps N              Frame rate (default: 30)
  --port, -p N         Server port (default: 8445)
  --verbose, -v        Enable debug logging
  --help               Show this help

Examples:
  emiscreen
  emiscreen --firetv 192.168.1.100

Open: https://localhost:8445
'''

if "--help" in sys.argv or "-h" in sys.argv:
    print(HELP_TEXT)
    sys.exit(0)

result = subprocess.run([VENV_PYTHON, "-m", "emiscreen.server"] + sys.argv[1:])
sys.exit(result.returncode)
"@

$LaunchScript | Out-File -FilePath "$InstallDir\emiscreen_launcher.py" -Encoding UTF8

# Create batch file wrapper
$BatchContent = '@echo off
setlocal
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"
call .venv\Scripts\activate.bat >nul 2>&1
python emiscreen_launcher.py %*'
$BatchContent | Out-File -FilePath "$LauncherDir\emiscreen.bat" -Encoding ASCII

# Create PowerShell launcher
$PsLauncher = @"
if ("`$args" -eq "--help" -or "`$args" -eq "-h") {
    Write-Host "Emiscreen - Remote Display via WebRTC`nUsage: emiscreen [options]`nRun 'emiscreen --help' for options."
    exit 0
}
& "$env:LOCALAPPDATA\emiscreen\.venv\Scripts\python.exe" "$env:LOCALAPPDATA\emiscreen\emiscreen_launcher.py" `$args
exit `$LASTEXITCODE
"@

$PsLauncherPath = "$LauncherDir\emiscreen.ps1"
$PsLauncher | Out-File -FilePath $PsLauncherPath -Encoding UTF8

# Add to PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$NewPathEntry = "$LauncherDir"
if ($UserPath -notlike "*$NewPathEntry*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$NewPathEntry", "User")
    $env:Path = "$env:Path;$NewPathEntry"
}

Write-Host "  Launcher: $LauncherDir\emiscreen.bat" -ForegroundColor Green

# =============================================================================
# ENVIRONMENT CONFIG
# =============================================================================
Write-Host ""
Write-Host "[Config] Writing environment..." -ForegroundColor Yellow

$envContent = @"
EMISCREEN_PORT=$Port
EMISCREEN_SOURCE=$Source
EMISCREEN_RESOLUTION=$Resolution
EMISCREEN_FPS=$FPS
EMISCREEN_FIRETV_IP=$FireTV
"@
$envContent | Out-File -FilePath "$InstallDir\.env" -Encoding UTF8

# Test FireTV if provided
if ($FireTV) {
    Write-Host ""
    Write-Host "[FireTV] Testing connection..." -ForegroundColor Yellow
    $ADB = Get-Command adb -ErrorAction SilentlyContinue
    if ($ADB) {
        $addr = if ($FireTV -match ":\d+$") { $FireTV } else { "$FireTV`:5555" }
        $conn = & adb connect $addr 2>&1
        if ($conn -match "connected") {
            Write-Host "  Connected!" -ForegroundColor Green
        } else {
            Write-Host "  Could not connect - enable ADB debugging on FireTV" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# DONE
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Emiscreen installed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Location: $InstallDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Open a NEW terminal and run:" -ForegroundColor White
Write-Host "    emiscreen" -ForegroundColor Green
if ($FireTV) {
    Write-Host "    emiscreen --firetv $FireTV" -ForegroundColor Green
}
Write-Host ""
Write-Host "  Then open: https://localhost:$Port in your browser" -ForegroundColor White
Write-Host ""