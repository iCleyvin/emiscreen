# Emiscreen - Start Server Script (Windows)
# Usage: .\scripts\start.ps1 [-Source SOURCE] [-Firetv IP]

$ProjectDir = Split-Path -Parent $PSScriptRoot
$VenvDir = Join-Path $ProjectDir ".venv"

# Parse parameters
param(
    [string]$Source = "windows-pc",
    [string]$Firetv = "",
    [string]$Resolution = "",
    [int]$Fps = 0,
    [switch]$Verbose
)

# Activate virtual environment
if (Test-Path (Join-Path $VenvDir "Scripts\Activate.ps1")) {
    & (Join-Path $VenvDir "Scripts\Activate.ps1")
} else {
    Write-Host "Virtual environment not found. Run .\scripts\setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Build command
$Cmd = "python -m emiscreen.server --source $Source"

if ($Firetv) {
    $Cmd += " --firetv $Firetv"
}

if ($Resolution) {
    $Cmd += " --resolution $Resolution"
}

if ($Fps -gt 0) {
    $Cmd += " --fps $Fps"
}

if ($Verbose) {
    $Cmd += " --verbose"
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Emiscreen - Starting Server" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Source:     $Source"
Write-Host "  FireTV:     $(if ($Firetv) { $Firetv } else { 'disabled' })"
Write-Host "  Resolution: $(if ($Resolution) { $Resolution } else { 'default' })"
Write-Host "  FPS:        $(if ($Fps -gt 0) { $Fps } else { 'default' })"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Run server
Invoke-Expression $Cmd
