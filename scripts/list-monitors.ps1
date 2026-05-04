# List connected monitors on Windows
# Usage: .\scripts\list-monitors.ps1

Write-Host "Detecting monitors..." -ForegroundColor Cyan
$Output = .venv\Scripts\python.exe scripts\list-monitors.py
Write-Host $Output
