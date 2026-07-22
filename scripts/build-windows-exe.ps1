# Build setup.exe from the WPF wizard. Needs ps2exe (Install-Module ps2exe -Scope CurrentUser).
# Output: dist\setup.exe  (no console, requests admin, custom icon if present).
param([string]$OutDir = "$PSScriptRoot\..\dist")
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -ListAvailable ps2exe)) { throw "缺 ps2exe。先跑: Install-Module ps2exe -Scope CurrentUser" }
$src = Join-Path $PSScriptRoot '..\installer\gui\setup-wizard.ps1'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$exe = Join-Path $OutDir 'setup.exe'
$ico = Join-Path $PSScriptRoot '..\installer\gui\setup.ico'
$args = @{ inputFile = $src; outputFile = $exe; noConsole = $true; requireAdmin = $true;
           title = 'remote-LAN-service Setup'; description = 'Self-hosted remote access installer' }
if (Test-Path $ico) { $args.iconFile = $ico }
Invoke-ps2exe @args
Write-Host "built: $exe"
