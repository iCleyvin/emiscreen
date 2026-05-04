#Requires -Version 5.1
<#
.SYNOPSIS
    Build Emiscreen Fire TV APK (Release)
    
.DESCRIPTION
    Builds a release APK with auto-versioning from git tags.
    
    Output: emiscreen-firetv-release.apk
#>
param(
    [string]$OutputPath = ".\emiscreen-firetv-release.apk"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Join-Path $PSScriptRoot ".."
$AppDir = Join-Path $ProjectRoot "firetv-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Emiscreen Fire TV APK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get version from git
try {
    $VersionName = git describe --tags --always 2>$null
    if (-not $VersionName) { $VersionName = "1.0.0" }
} catch {
    $VersionName = "1.0.0"
}

$VersionCode = (git rev-list --count HEAD 2>$null)
if (-not $VersionCode) { $VersionCode = 1 }

Write-Host "Version: $VersionName (code: $VersionCode)" -ForegroundColor Yellow

# Update version in build.gradle
$GradlePath = Join-Path $AppDir "app\build.gradle.kts"
if (Test-Path $GradlePath) {
    $Content = Get-Content $GradlePath -Raw
    $Content = $Content -replace 'versionName = "[^"]*"', "versionName = `"$VersionName`""
    $Content = $Content -replace 'versionCode = \d+', "versionCode = $VersionCode"
    Set-Content -Path $GradlePath -Value $Content -Encoding UTF8
    Write-Host "Updated version in build.gradle.kts" -ForegroundColor Green
}

# Build release APK
Write-Host "`nBuilding release APK..." -ForegroundColor Yellow
$GradleWrapper = Join-Path $AppDir "gradlew.bat"
if (-not (Test-Path $GradleWrapper)) {
    Write-Error "Gradle wrapper not found at $GradleWrapper"
    exit 1
}

& $GradleWrapper -p $AppDir assembleRelease
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    exit 1
}

# Copy output
$ApkSource = Join-Path $AppDir "app\build\outputs\apk\release\app-release-unsigned.apk"
if (-not (Test-Path $ApkSource)) {
    # Try alternative name
    $ApkSource = Join-Path $AppDir "app\build\outputs\apk\release\app-release.apk"
}

if (Test-Path $ApkSource) {
    Copy-Item -Path $ApkSource -Destination $OutputPath -Force
    $Size = (Get-Item $OutputPath).Length / 1MB
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  APK built successfully!" -ForegroundColor Green
    Write-Host "  $OutputPath ($([Math]::Round($Size,1)) MB)" -ForegroundColor Green
    Write-Host "  Version: $VersionName" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Error "APK not found at expected path"
    exit 1
}
