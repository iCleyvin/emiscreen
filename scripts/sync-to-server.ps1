# Emiscreen - Sync to cleyvinserv (PowerShell)
# Usage: .\scripts\sync-to-server.ps1
# Syncs local code to cleyvinserv, installs deps, and runs tests remotely.

param(
    [string]$Server = "cleyvinserv",
    [string]$RemotePath = "/mnt/datos/dev/emiscreen",
    [switch]$NoTests
)

$ErrorActionPreference = "Stop"

Write-Host "=== Emiscreen Sync to cleyvinserv ===" -ForegroundColor Cyan
Write-Host "Server: $Server" -ForegroundColor Gray
Write-Host "Remote path: $RemotePath" -ForegroundColor Gray
Write-Host ""

# 1. Sync code via rsync (if available) or fallback to scp
$UseRsync = $false
if (Get-Command rsync -ErrorAction SilentlyContinue) {
    $UseRsync = $true
}

Write-Host "[1/4] Syncing code to server..." -ForegroundColor Yellow

$ExcludeList = @(
    ".venv", "__pycache__", ".git", ".gitignore",
    "*.pyc", "*.pyo", ".pytest_cache", 
    "firetv-app/.gradle", "firetv-app/app/build",
    "firetv-app/app/.cxx", "*.apk", "*.keystore"
)

if ($UseRsync) {
    $ExcludeArgs = $ExcludeList | ForEach-Object { "--exclude=$_" }
    $cmd = @("rsync", "-avz", "--delete") + $ExcludeArgs + @("./", "${Server}:${RemotePath}/")
    Write-Host "  Using rsync..." -ForegroundColor Gray
    & $cmd[0] $cmd[1..($cmd.Length-1)]
} else {
    # Fallback: use scp + ssh rm for a clean sync-like behavior
    Write-Host "  rsync not found, using ssh + scp fallback..." -ForegroundColor Yellow
    ssh $Server "mkdir -p $RemotePath && rm -rf $RemotePath/emiscreen $RemotePath/scripts $RemotePath/tests $RemotePath/docs $RemotePath/firetv-app $RemotePath/*.md $RemotePath/*.txt $RemotePath/*.toml $RemotePath/*.yml $RemotePath/*.py $RemotePath/*.sh $RemotePath/*.ps1"
    scp -r -C ./emiscreen ./scripts ./tests ./docs ./firetv-app ./*.md ./*.txt ./*.toml ./*.yml ./*.py ./*.sh ./*.ps1 "${Server}:${RemotePath}/"
}

Write-Host "  Sync complete." -ForegroundColor Green

# 2. Ensure venv and deps on server
Write-Host ""
Write-Host "[2/4] Ensuring Python environment on server..." -ForegroundColor Yellow
ssh $Server @"
cd $RemotePath
if [ ! -d .venv ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install -q -r requirements.txt
echo "Deps OK"
"@

Write-Host "  Environment ready." -ForegroundColor Green

# 3. Run tests remotely
if (-not $NoTests) {
    Write-Host ""
    Write-Host "[3/4] Running tests on server..." -ForegroundColor Yellow
    ssh $Server "cd $RemotePath && source .venv/bin/activate && python -m pytest tests/ -v"
} else {
    Write-Host ""
    Write-Host "[3/4] Skipping tests (--NoTests)." -ForegroundColor Yellow
}

# 4. Verify server can import cleanly
Write-Host ""
Write-Host "[4/4] Verifying server imports..." -ForegroundColor Yellow
ssh $Server "cd $RemotePath && source .venv/bin/activate && python -c 'from emiscreen.server import EmiscreenServer; from emiscreen.capture.base import CaptureSource; print(\"Imports OK\")'"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Sync complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  Build APK:   .\scripts\build-apk-remote.ps1" -ForegroundColor Cyan
Write-Host "  Run server:  ssh $Server 'cd $RemotePath && source .venv/bin/activate && python -m emiscreen.server --source ubuntu-desktop'" -ForegroundColor Cyan
