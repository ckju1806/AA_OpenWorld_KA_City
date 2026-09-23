# Reproduzierbarer Windows-x64-Export (Release) unter Windows.
# Aufruf:  powershell -ExecutionPolicy Bypass -File scripts\windows\build_windows.ps1 [-Godot C:\Pfad\Godot_v4.7.2-stable_win64_console.exe]
# Voraussetzung: Godot 4.7.2 und Export-Templates 4.7.2 unter %APPDATA%\Godot\export_templates\4.7.2.stable\
param([string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }))
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$OutDir = Join-Path $Root "build\windows"
$LogDir = Join-Path $Root "artifacts\test-logs"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Log = Join-Path $LogDir "export_$Stamp.log"
New-Item -ItemType Directory -Force -Path $OutDir, $LogDir | Out-Null

$ver = & $Godot --version
Write-Host "[build] Godot: $ver"
if ($ver -notmatch "^4\.7\.2\.stable") { Write-Warning "Erwartet wird Godot 4.7.2-stable (gefunden: $ver)." }
$tpl = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
if (-not (Test-Path $tpl)) { Write-Error "Export-Templates fehlen: $tpl" }

Write-Host "[build] Import ..."
& $Godot --headless --path $Root --import *> $Log
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $OutDir "Faecherstadt.exe"), (Join-Path $OutDir "Faecherstadt.pck")
Write-Host "[build] Export (Release) ... (Log: $Log)"
& $Godot --headless --path $Root --export-release "Windows Desktop" (Join-Path $OutDir "Faecherstadt.exe") *>> $Log
if (Select-String -Path $Log -Pattern "SCRIPT ERROR|Parse Error" -Quiet) { Write-Error "Fehler im Export-Log: $Log" }
foreach ($f in "Faecherstadt.exe", "Faecherstadt.pck") {
  if (-not (Test-Path (Join-Path $OutDir $f))) { Write-Error "Exportdatei fehlt: $f" }
}
$magic = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes((Join-Path $OutDir "Faecherstadt.pck"))[0..3])
if ($magic -ne "GDPC") { Write-Error "PCK-Kennung falsch: $magic" }

$version = (Select-String -Path (Join-Path $Root "project.godot") -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
$Zip = Join-Path $Root "build\Faecherstadt_Windows_x64_v$version.zip"
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ("faecherstadt_" + $Stamp)
$Pkg = Join-Path $Stage "Faecherstadt"
New-Item -ItemType Directory -Force -Path $Pkg | Out-Null
Copy-Item (Join-Path $OutDir "Faecherstadt.exe"), (Join-Path $OutDir "Faecherstadt.pck") $Pkg
foreach ($d in "README.md", "CONTROLS.md", "ASSET_LICENSES.md", "KNOWN_ISSUES.md", "LICENSE") { Copy-Item (Join-Path $Root $d) $Pkg }
if (Test-Path $Zip) { Remove-Item -Force $Zip }
Compress-Archive -Path $Pkg -DestinationPath $Zip
Remove-Item -Recurse -Force $Stage
Write-Host "[build] Ergebnis:"
Get-FileHash -Algorithm SHA256 (Join-Path $OutDir "Faecherstadt.exe"), (Join-Path $OutDir "Faecherstadt.pck"), $Zip | Format-Table -AutoSize
