$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

function Resolve-IsccPath {
  $cmd = Get-Command iscc -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Path
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\ISCC.EXE"),
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  return $null
}

Write-Host "Building Windows app..."
flutter build windows

$isccPath = Resolve-IsccPath
if (-not $isccPath) {
  throw "Inno Setup Compiler (iscc) not found in PATH. Install Inno Setup first."
}

Write-Host "Building installer..."
& $isccPath (Join-Path $PSScriptRoot "PassGuardSetup.iss")

Write-Host "Done. Installer is in build\installer"
