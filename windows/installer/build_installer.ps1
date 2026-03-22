$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

Write-Host "Building Windows app..."
flutter build windows

$iscc = Get-Command iscc -ErrorAction SilentlyContinue
if (-not $iscc) {
  throw "Inno Setup Compiler (iscc) not found in PATH. Install Inno Setup first."
}

Write-Host "Building installer..."
& $iscc.Path (Join-Path $PSScriptRoot "PassGuardSetup.iss")

Write-Host "Done. Installer is in build\installer"
