@echo off
rem Fuehrt alle automatisierten Tests headless aus. Aufruf: run_tests.bat [filter]
setlocal
set "ROOT=%~dp0..\.."
if "%GODOT%"=="" set "GODOT=godot"
echo [tests] Import ...
"%GODOT%" --headless --path "%ROOT%" --import >nul 2>nul
echo [tests] Tests ...
if "%~1"=="" (
  "%GODOT%" --headless --path "%ROOT%" --fixed-fps 60 res://tests/test_runner.tscn
) else (
  "%GODOT%" --headless --path "%ROOT%" --fixed-fps 60 res://tests/test_runner.tscn -- --filter=%~1
)
set RC=%ERRORLEVEL%
echo [tests] Exit-Code: %RC%
exit /b %RC%
