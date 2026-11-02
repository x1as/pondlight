@echo off
rem Launch PONDLIGHT from source (Godot 4.7.2). Set GODOT to override the editor path.
setlocal
if "%GODOT%"=="" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 not found. Install with: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0pondlight"
