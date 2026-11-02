@echo off
rem Run the PONDLIGHT headless test suite. Exit code = number of failed checks.
setlocal
if "%GODOT%"=="" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT%" --headless --path "%~dp0pondlight" res://tests/test_runner.tscn
exit /b %ERRORLEVEL%
