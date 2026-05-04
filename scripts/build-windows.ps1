#Requires -Version 5.1
<#
.SYNOPSIS
    Build Emiscreen Windows Portable Package
    
.DESCRIPTION
    Creates a .zip package that can run on any Windows 10/11 machine
    without requiring Python installation.
    
    Output: emiscreen-windows.zip
#>
param(
    [string]$OutputDir = ".",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Join-Path $PSScriptRoot ".."
$BuildDir = Join-Path $env:TEMP "emiscreen-build-$(Get-Random)"
$PackageDir = Join-Path $BuildDir "emiscreen"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Emiscreen Windows Package" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Clean and create dirs
Remove-Item -Path $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

# Step 1: Install dependencies to local .venv
Write-Host "`nStep 1: Installing dependencies..." -ForegroundColor Yellow
& $PythonExe -m venv (Join-Path $BuildDir ".venv")
$VenvPip = Join-Path $BuildDir ".venv\Scripts\pip.exe"
$VenvPython = Join-Path $BuildDir ".venv\Scripts\python.exe"

& $VenvPip install --upgrade pip | Out-Null
& $VenvPip install -r (Join-Path $ProjectRoot "requirements.txt") | Out-Null

# Step 2: Copy source code
Write-Host "Step 2: Copying source code..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $ProjectRoot "emiscreen") -Destination $PackageDir -Recurse
Copy-Item -Path (Join-Path $ProjectRoot "requirements.txt") -Destination $PackageDir
Copy-Item -Path (Join-Path $ProjectRoot "LICENSE") -Destination $PackageDir -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $ProjectRoot "README.md") -Destination $PackageDir -ErrorAction SilentlyContinue

# Step 3: Create launcher
Write-Host "Step 3: Creating launcher..." -ForegroundColor Yellow
$Launcher = @'
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PYTHON=%SCRIPT_DIR%..\.venv\Scripts\python.exe"
set "EMISCREEN=%SCRIPT_DIR%..\emiscreen"

if not exist "%PYTHON%" (
    echo ERROR: Python not found. Please run setup first.
    pause
    exit /b 1
)

echo Starting Emiscreen...
echo.
"%PYTHON%" -m emiscreen.server %*
'@

$LauncherPath = Join-Path $PackageDir "emiscreen.bat"
Set-Content -Path $LauncherPath -Value $Launcher -Encoding ASCII

# Step 4: Create README
$Readme = @'
# Emiscreen - Windows Portable

## Quick Start

1. Double-click `emiscreen.bat`
2. Open the Emiscreen app on your Fire TV
3. Enter your PC's IP address

## Command Line Options

```
emiscreen.bat --source windows-pc --display 2 --quality balanced
```

## Available Options

| Option | Description |
|--------|-------------|
| `--source windows-pc` | Capture Windows desktop |
| `--display 1\|2\|desktop` | Select monitor to capture |
| `--quality fast\|balanced\|quality\|native` | Quality preset |
| `--fps 24` | Frame rate |
| `--resolution 1920x1080` | Capture resolution |
| `--firetv 192.168.1.100` | Auto-launch Fire TV browser |

## Requirements

- Windows 10/11 64-bit
- FFmpeg installed and in PATH

## Support

- GitHub: https://github.com/iCleyvin/emiscreen
- PayPal: https://www.paypal.com/donate/?hosted_button_id=UMBEQY4YL27LU
'@

$ReadmePath = Join-Path $PackageDir "README-WINDOWS.txt"
Set-Content -Path $ReadmePath -Value $Readme -Encoding UTF8

# Step 5: Copy .venv
Write-Host "Step 4: Packaging virtual environment..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $BuildDir ".venv") -Destination (Join-Path $PackageDir "..\.venv") -Recurse

# Step 6: Create zip
Write-Host "Step 5: Creating zip..." -ForegroundColor Yellow
$ZipPath = Join-Path $OutputDir "emiscreen-windows.zip"
Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

# Cleanup
Remove-Item -Path $BuildDir -Recurse -Force -ErrorAction SilentlyContinue

$Size = (Get-Item $ZipPath).Length / 1MB
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Package created!" -ForegroundColor Green
Write-Host "  $ZipPath ($([Math]::Round($Size,1)) MB)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
