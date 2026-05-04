# Emiscreen - Trust Self-Signed Certificate (Windows)
# Run this as Administrator if you want the cert trusted system-wide.
# User-level trust does not require Admin on modern Windows.

$CertPath = "$PSScriptRoot\..\certs\cert.pem"
if (-not (Test-Path $CertPath)) {
    Write-Host "Certificate not found at $CertPath" -ForegroundColor Red
    Write-Host "Start Emiscreen once to generate it, then run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Importing Emiscreen certificate into Trusted Root store (CurrentUser)..." -ForegroundColor Cyan
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    Write-Host "Certificate trusted successfully." -ForegroundColor Green
    Write-Host "Restart your browser for changes to take effect." -ForegroundColor Yellow
} catch {
    Write-Host "Failed to import certificate: $_" -ForegroundColor Red
    exit 1
}
