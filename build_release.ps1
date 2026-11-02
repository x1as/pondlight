# Reproducible release build for PONDLIGHT.
#   powershell -ExecutionPolicy Bypass -File build_release.ps1 [-Linux] [-Web] [-Pages] [-SkipTests]
# Requires Godot 4.7.2 + export templates 4.7.2. Set $env:GODOT to override the editor path.
param([switch]$Linux, [switch]$Web, [switch]$Pages, [switch]$SkipTests)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $root "pondlight"
$godot = $env:GODOT
if (-not $godot) {
    $cands = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe",
        "C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe"
    )
    $godot = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $godot) { throw "Godot 4.7.2 not found. Set `$env:GODOT to Godot_v4.7.2-stable_win64_console.exe" }
Write-Host "Using $godot"
& $godot --headless --path $proj --import | Out-Null
if (-not $SkipTests) {
    & $godot --headless --path $proj res://tests/test_runner.tscn
    if ($LASTEXITCODE -ne 0) { throw "Tests failed ($LASTEXITCODE failures) - release aborted" }
}
$out = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --headless --path $proj --export-release "Windows Desktop" (Join-Path $out "Pondlight.exe")
if (-not (Test-Path (Join-Path $out "Pondlight.exe"))) { throw "Windows export failed" }
Write-Host "Windows build: $out\Pondlight.exe"
if ($Web) {
    $wout = Join-Path $root "build\web"
    if (Test-Path $wout) { Remove-Item -Recurse -Force $wout }
    New-Item -ItemType Directory -Force $wout | Out-Null
    & $godot --headless --path $proj --export-release "Web" (Join-Path $wout "index.html")
    Copy-Item (Join-Path $proj "web\pl_bridge.js") $wout
    if (-not (Test-Path (Join-Path $wout "index.pck"))) { throw "Web export failed" }
    $zip = Join-Path $root "build\PONDLIGHT_web.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path (Join-Path $wout "*") -DestinationPath $zip
    Write-Host "Web build: $wout (upload archive: $zip)"
}
if ($Pages) {
    # GitHub Pages: docs/ in the repository root, served from the main branch
    $pout = Join-Path $root "docs"
    if (Test-Path $pout) { Remove-Item -Recurse -Force $pout }
    New-Item -ItemType Directory -Force $pout | Out-Null
    & $godot --headless --path $proj --export-release "Web Pages" (Join-Path $pout "index.html")
    if (-not (Test-Path (Join-Path $pout "index.pck"))) { throw "Pages export failed" }
    New-Item -ItemType File -Force (Join-Path $pout ".nojekyll") | Out-Null
    Write-Host "GitHub Pages build: $pout"
}
if ($Linux) {
    $lout = Join-Path $root "build\linux"
    New-Item -ItemType Directory -Force $lout | Out-Null
    & $godot --headless --path $proj --export-release "Linux" (Join-Path $lout "Pondlight.x86_64")
    Write-Host "Linux build: $lout\Pondlight.x86_64"
}
