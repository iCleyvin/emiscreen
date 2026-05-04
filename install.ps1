# Emiscreen - One-Line Installer for Windows (PowerShell)
# Usage: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
# Or with parameters: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex -FireTV "192.168.1.100" -Source "windows-pc"

param(
    [string]$FireTV = "",
    [string]$Source = "windows-pc",
    [string]$Resolution = "1920x1080",
    [int]$FPS = 30,
    [int]$Port = 8445,
    [switch]$SkipADBCheck,
    [switch]$Help
)

$InstallerVersion = "1.1.0"

if ($Help) {
    Write-Host @"
Emiscreen One-Line Windows Installer v$InstallerVersion

Usage:
    iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex

With parameters:
    iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex -FireTV "192.168.1.100"

Parameters:
    -FireTV        FireTV IP address for ADB control
    -Source        Capture source (windows-pc, ubuntu-desktop, nas-omv)
    -Resolution    Capture resolution (default: 1920x1080)
    -FPS           Frame rate (default: 30)
    -Port          Server port (default: 8445)
    -SkipADBCheck  Skip ADB connection test
    -Help          Show this help

Examples:
    iwr ... | iex
    iwr ... | iex -FireTV "192.168.1.100"
    iwr ... | iex -FireTV "192.168.1.100" -Source windows-pc -Resolution 1280x720

"@
    exit 0
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Emiscreen Installer v$InstallerVersion" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectDir = "$env:USERPROFILE\emiscreen"

Write-Host "[1/5] Checking environment..." -ForegroundColor Yellow

$OSVersion = [System.Environment]::OSVersion.Version
Write-Host "  OS: Windows $($OSVersion.Major).$($OSVersion.Minor)" -ForegroundColor Gray
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

Write-Host ""
Write-Host "[2/5] Downloading Emiscreen..." -ForegroundColor Yellow

if (Test-Path $ProjectDir) {
    Write-Host "  Found existing installation at $ProjectDir" -ForegroundColor Yellow
    Write-Host "  Updating from git..." -ForegroundColor Cyan
    Set-Location $ProjectDir
    git pull 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  Git pull failed, keeping existing files" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Downloading Emiscreen..." -ForegroundColor Cyan

    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            git clone --depth 1 https://github.com/iCleyvin/emiscreen.git $ProjectDir 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git clone failed" }
        } else {
            # Fallback: download as zip
            $ZipUrl = "https://github.com/iCleyvin/emiscreen/archive/refs/heads/main.zip"
            $ZipPath = "$env:TEMP\emiscreen_main.zip"

            Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
            Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP" -Force
            Move-Item -Path "$env:TEMP\emiscreen-main\*" -Destination $ProjectDir -Force
            Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:TEMP\emiscreen-main" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  Downloaded to $ProjectDir" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to download: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "[3/5] Setting up Python..." -ForegroundColor Yellow

$PythonCmd = $null
$PythonPath = $null

foreach ($cmd in @("python", "python3", "py")) {
    $result = & $cmd --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $PythonCmd = $cmd
        Write-Host "  Found: $result" -ForegroundColor Green
        break
    }
}

if (-not $PythonCmd) {
    Write-Host "  Python not found. Installing..." -ForegroundColor Yellow

    # Try winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Python via winget..." -ForegroundColor Cyan
        $installResult = winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $installResult -match "installed") {
            Write-Host "  Python installed. RESTART POWERSHELL AND RUN INSTALLER AGAIN." -ForegroundColor Green
            Write-Host "  Then run: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex" -ForegroundColor Cyan
            exit 0
        }
    }

    # Try chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Python via Chocolatey..." -ForegroundColor Cyan
        choco install python --yes 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Python installed. Restart PowerShell and run installer again." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "  ERROR: Cannot install Python automatically." -ForegroundColor Red
    Write-Host "  Please install Python 3.10+ from: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

# Create virtual environment
$VenvDir = "$ProjectDir\.venv"
if (-not (Test-Path $VenvDir)) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Cyan
    & $PythonCmd -m venv $VenvDir 2>&1 | Out-Null
    if (-not (Test-Path $VenvDir)) {
        Write-Host "  ERROR: Failed to create venv" -ForegroundColor Red
        exit 1
    }
}

$PythonPath = "$VenvDir\Scripts\python.exe"
if (-not (Test-Path $PythonPath)) {
    $PythonPath = "$VenvDir\bin\python.exe"
}

Write-Host "  Virtual environment ready" -ForegroundColor Green

Write-Host ""
Write-Host "[4/5] Installing Python dependencies..." -ForegroundColor Yellow

& $PythonPath -m pip install --upgrade pip -q 2>&1 | Out-Null
$pipResult = & $PythonPath -m pip install -r "$ProjectDir\requirements.txt" -q 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  WARNING: pip install had issues: $pipResult" -ForegroundColor Yellow
} else {
    Write-Host "  Dependencies installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "[5/5] Configuring Emiscreen..." -ForegroundColor Yellow

# Create certs directory
$CertDir = "$ProjectDir\certs"
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
}

# Try to install OpenSSL for certificate generation
$OpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $OpenSSL -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing OpenSSL for HTTPS certificates..." -ForegroundColor Cyan
    winget install IgorZinovievTools.OpenSSL.Light --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    $OpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
}

# Generate SSL certificates if OpenSSL is available
$CertFile = "$CertDir\cert.pem"
$KeyFile = "$CertDir\key.pem"

if ($OpenSSL -and (-not (Test-Path $CertFile) -or -not (Test-Path $KeyFile))) {
    Write-Host "  Generating SSL certificates..." -ForegroundColor Cyan
    $OpenSSLCmd = $OpenSSL.Source
    & $OpenSSLCmd req -new -x509 -keyout $KeyFile -out $CertFile -days 3650 -nodes -subj "/CN=emiscreen.local" 2>&1 | Out-Null
    if (Test-Path $CertFile) {
        Write-Host "  SSL certificates generated" -ForegroundColor Green
    }
} elseif (Test-Path $CertFile) {
    Write-Host "  SSL certificates already exist" -ForegroundColor Green
} else {
    Write-Host "  WARNING: OpenSSL not found. Server will auto-generate certs on first run." -ForegroundColor Yellow
    Write-Host "  Or install OpenSSL manually: winget install IgorZinovievTools.OpenSSL.Light" -ForegroundColor Cyan
}

# Create environment file
$envContent = @"
EMISCREEN_PORT=$Port
EMISCREEN_SOURCE=$Source
EMISCREEN_RESOLUTION=$Resolution
EMISCREEN_FPS=$FPS
EMISCREEN_FIRETV_IP=$FireTV
"@

$envContent | Out-File -FilePath "$ProjectDir\.env" -Encoding UTF8

# Make start script executable
$StartScript = "$ProjectDir\scripts\start.ps1"
if (Test-Path $StartScript) {
    Write-Host "  Configured: $StartScript" -ForegroundColor Gray
}

# Test FireTV connection
if ($FireTV -and -not $SkipADBCheck) {
    Write-Host ""
    Write-Host "Testing FireTV connection..." -ForegroundColor Yellow

    $ADB = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $ADB) {
        Write-Host "  ADB not found. Install Android SDK Platform Tools if needed." -ForegroundColor Yellow
        Write-Host "    winget install Google.AndroidSDKPlatformTools" -ForegroundColor Cyan
    } else {
        $FireTVAddr = if ($FireTV -match ":\d+$") { $FireTV } else { "$FireTV`:5555" }
        $connResult = & adb connect $FireTVAddr 2>&1

        if ($connResult -match "connected" -or $connResult -match "already connected") {
            Write-Host "  FireTV connected successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Could not connect to FireTV. Enable ADB debugging on your device." -ForegroundColor Yellow
        }
    }
}

# Results
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Location:   $ProjectDir" -ForegroundColor Cyan
Write-Host "  Source:     $Source" -ForegroundColor Cyan
Write-Host "  Resolution: $Resolution" -ForegroundColor Cyan
Write-Host "  FPS:        $FPS" -ForegroundColor Cyan
Write-Host "  Port:       $Port" -ForegroundColor Cyan
if ($FireTV) {
    Write-Host "  FireTV:     $FireTV" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  cd $ProjectDir" -ForegroundColor Gray
Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor Gray
Write-Host "  python -m emiscreen.server --source $Source" -ForegroundColor Gray
if ($FireTV) {
    Write-Host "  python -m emiscreen.server --source $Source --firetv $FireTV" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Then open: https://localhost:$Port in your browser" -ForegroundColor White
Write-Host ""