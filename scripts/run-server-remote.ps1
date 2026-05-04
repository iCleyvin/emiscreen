# Emiscreen - Run server remotely on cleyvinserv
# Usage: .\scripts\run-server-remote.ps1 [options...]
# All extra arguments are passed to emiscreen.server

param(
    [string]$Server = "cleyvinserv",
    [string]$RemotePath = "/mnt/datos/dev/emiscreen",
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ServerArgs
)

$ErrorActionPreference = "Stop"

Write-Host "=== Emiscreen Remote Server Start ===" -ForegroundColor Cyan
Write-Host "Server: $Server" -ForegroundColor Gray
Write-Host "Args: $($ServerArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

# Sync first
Write-Host "[1/2] Syncing code..." -ForegroundColor Yellow
& $PSScriptRoot\sync-to-server.ps1 -Server $Server -RemotePath $RemotePath -NoTests

# Build command string
$ArgString = $ServerArgs -join ' '
if ([string]::IsNullOrWhiteSpace($ArgString)) {
    $ArgString = "--source ubuntu-desktop"
}

Write-Host ""
Write-Host "[2/2] Starting server..." -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to stop (server will keep running in background)" -ForegroundColor Yellow
Write-Host ""

# Run server via SSH. Using nohup so it stays alive after SSH disconnect.
ssh -t $Server @"
cd ${RemotePath}
source .venv/bin/activate
export EMISCREEN_HOST=0.0.0.0
python -m emiscreen.server ${ArgString}
"@

Write-Host ""
Write-Host "Server session ended." -ForegroundColor Yellow
