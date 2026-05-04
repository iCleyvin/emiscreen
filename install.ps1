# Emiscreen - One-Line Installer for Windows (PowerShell)
# Usage: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex
# Or with parameters: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex -FireTV "192.168.1.100" -Source "windows-pc"

param(
    [string]$FireTV = "",
    [string]$Source = "windows-pc",
    [string]$Resolution = "1920x1080",
    [int]$FPS = 30,
    [string]$Port = "8445",
    [switch]$SkipADBCheck,
    [switch]$Help
)

$InstallerVersion = "1.0.0"
$Repo = "iCleyvin/emiscreen"
$RawBase = "https://raw.githubusercontent.com/$Repo/main"

if ($Help) {
    Write-Host @"
Emiscreen One-Line Windows Installer v$InstallerVersion

Usage:
    iwr https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex

With parameters:
    iwr https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex -FireTV "192.168.1.100" -Source "windows-pc"

Parameters:
    -FireTV     FireTV IP address for ADB control
    -Source     Capture source (windows-pc, ubuntu-desktop, nas-omv) [default: windows-pc]
    -Resolution Capture resolution [default: 1920x1080]
    -FPS        Frame rate [default: 30]
    -Port       Server port [default: 8445]
    -SkipADBCheck  Skip ADB connection test
    -Help       Show this help

Examples:
    # Local Windows PC
    iwr https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex

    # With FireTV
    iwr https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex -FireTV "192.168.1.100"

    # Custom resolution
    iwr https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex -FireTV "192.168.1.100" -Resolution "1280x720"

"@
    exit 0
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Emiscreen Installer v$InstallerVersion" -ForegroundColor Cyan
Write-Host "  https://github.com/$Repo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detect environment
Write-Host "[1/5] Detecting environment..." -ForegroundColor Yellow

$ProjectDir = "$env:USERPROFILE\emiscreen"

# Check Windows version
$WindowsVersion = [System.Environment]::OSVersion.Version
Write-Host "  OS: Windows $($WindowsVersion.Major).$($WindowsVersion.Minor)" -ForegroundColor Green

# Check PowerShell version
$PSVersion = $PSVersionTable.PSVersion
Write-Host "  PowerShell: $($PSVersion.Major).$($PSVersion.Minor)" -ForegroundColor Green

# 2. Clone repository
Write-Host "[2/5] Downloading Emiscreen..." -ForegroundColor Yellow

if (Test-Path $ProjectDir) {
    Write-Host "  Existing installation found at $ProjectDir" -ForegroundColor Yellow
    $response = Read-Host "  Remove and reinstall? [y/N]"
    if ($response -eq "y") {
        Remove-Item -Recurse -Force $ProjectDir -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Keeping existing installation" -ForegroundColor Green
        Set-Location $ProjectDir
        Write-Host "  Run 'git pull' to update or start server manually" -ForegroundColor Cyan
        exit 0
    }
}

# Clone or download
try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone --depth 1 https://github.com/$Repo $ProjectDir
    } else {
        # Fallback: download as zip
        $ZipPath = "$env:TEMP\emiscreen.zip"
        Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $ZipPath -UseBasicParsing
        Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP" -Force
        Move-Item "$env:TEMP\emiscreen-main\*" $ProjectDir -Force
        Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\emiscreen-main" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  Downloaded to $ProjectDir" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to download Emiscreen: $_" -ForegroundColor Red
    exit 1
}

# 3. Check Python
Write-Host "[3/5] Checking Python..." -ForegroundColor Yellow

$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $version = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $PythonCmd = $cmd
            Write-Host "  Python: $version" -ForegroundColor Green
            break
        }
    } catch {}
}

if (-not $PythonCmd) {
    Write-Host "  Python not found. Installing..." -ForegroundColor Yellow
    $PythonInstalled = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Python via winget..." -ForegroundColor Cyan
        winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
        $PythonCmd = "python"
        $PythonInstalled = $true
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Python via Chocolatey..." -ForegroundColor Cyan
        choco install python --yes
        $PythonCmd = "python"
        $PythonInstalled = $true
    } else {
        Write-Host @"
  ERROR: Python not found and no package manager available.
  Please install Python 3.10+ from: https://www.python.org/downloads/
"@ -ForegroundColor Red
        exit 1
    }

    if ($PythonInstalled) {
        Write-Host "  Python installed. Re-run installer to continue." -ForegroundColor Yellow
        Write-Host "  Or run: python -m venv $ProjectDir\.venv" -ForegroundColor Cyan
        exit 0
    }
}

# 4. Create virtual environment and install
Write-Host "[4/5] Installing Python dependencies..." -ForegroundColor Yellow

Set-Location $ProjectDir

$VenvDir = "$ProjectDir\.venv"
if (-not (Test-Path $VenvDir)) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Cyan
    & python -m venv $VenvDir
}

$PythonPath = if (Test-Path "$VenvDir\Scripts\python.exe") { "$VenvDir\Scripts\python.exe" } else { "$VenvDir\bin\python.exe" }

Write-Host "  Upgrading pip..." -ForegroundColor Cyan
& $PythonPath -m pip install --upgrade pip -q

Write-Host "  Installing dependencies..." -ForegroundColor Cyan
& $PythonPath -m pip install -r "$ProjectDir\requirements.txt" -q 2>&1 | Out-Null

Write-Host "  Dependencies installed" -ForegroundColor Green

# 5. Generate SSL certificates
Write-Host "[5/5] Configuring SSL..." -ForegroundColor Yellow

$CertDir = "$ProjectDir\certs"
$CertFile = "$CertDir\cert.pem"
$KeyFile = "$CertDir\key.pem"

if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
}

if (-not (Test-Path $CertFile) -or -not (Test-Path $KeyFile)) {
    Write-Host "  Generating self-signed certificates..." -ForegroundColor Cyan

    $OpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $OpenSSL) {
        # Use PowerShell to generate self-signed certificate
        $CertSubject = "CN=emiscreen.local"
        $CertDnsNames = @("emiscreen.local", "localhost", "127.0.0.1")

        # Check PowerShell version for parameter compatibility
        $PSMajor = $PSVersionTable.PSVersion.Major

        if ($PSMajor -ge 7) {
            # PowerShell 7+ has -KeyExportable parameter
            $cert = New-SelfSignedCertificate -DnsName $CertDnsNames `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -NotAfter (Get-Date).AddYears(10) `
                -KeyAlgorithm RSA -KeyLength 2048 -KeyExportable
        } else {
            # Windows PowerShell 5.1 - no KeyExportable
            $cert = New-SelfSignedCertificate -DnsName $CertDnsNames `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -NotAfter (Get-Date).AddYears(10) `
                -KeyAlgorithm RSA -KeyLength 2048
        }

        $pwd = ConvertTo-SecureString -String "emiscreen" -Force -AsPlainText
        Export-PfxCertificate -Cert $cert -FilePath "$ProjectDir\certs\emiscreen.pfx" -Password $pwd | Out-Null

        Write-Host "  Self-signed certificate created (use HTTPS with --insecure flag on client)" -ForegroundColor Yellow
    } else {
        $Subject = "/CN=emiscreen.local"
        & openssl req -new -x509 -keyout $KeyFile -out $CertFile -days 3650 -nodes -subj $Subject 2>$null

        if (Test-Path $CertFile) {
            Write-Host "  SSL certificates generated" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  SSL certificates already exist" -ForegroundColor Green
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

# Test FireTV connection if provided
if ($FireTV -and -not $SkipADBCheck) {
    Write-Host ""
    Write-Host "Testing FireTV connection..." -ForegroundColor Yellow

    $ADB = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $ADB) {
        Write-Host "  ADB not found. Install Android SDK Platform Tools." -ForegroundColor Yellow
        Write-Host "  Or use winget: winget install Google.AndroidSDKPlatformTools" -ForegroundColor Cyan
    } else {
        $FireTVPort = if ($FireTV -match ":\d+$") { $FireTV } else { "$FireTV`:5555" }
        $connection = & adb connect $FireTVPort 2>&1

        if ($connection -match "connected" -or $connection -match "already connected") {
            Write-Host "  FireTV connected successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Could not connect to FireTV at $FireTVPort" -ForegroundColor Yellow
            Write-Host "  Make sure ADB debugging is enabled on your FireTV" -ForegroundColor Yellow
        }
    }
}

# Results
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Location:    $ProjectDir" -ForegroundColor Cyan
Write-Host "  Source:      $Source" -ForegroundColor Cyan
Write-Host "  Resolution:  $Resolution" -ForegroundColor Cyan
Write-Host "  FPS:         $FPS" -ForegroundColor Cyan
Write-Host "  Port:        $Port" -ForegroundColor Cyan
if ($FireTV) {
    Write-Host "  FireTV:     $FireTV" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "To start the server:" -ForegroundColor White
Write-Host "  cd $ProjectDir" -ForegroundColor White
Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "  python -m emiscreen.server --source $Source" -ForegroundColor White
if ($FireTV) {
    Write-Host "  python -m emiscreen.server --source $Source --firetv $FireTV" -ForegroundColor White
}
Write-Host ""
Write-Host "Then open: https://localhost:$Port in your browser" -ForegroundColor White
Write-Host "For FireTV: https://$env:COMPUTERNAME`:$Port" -ForegroundColor White
Write-Host ""