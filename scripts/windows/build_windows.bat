@echo off
rem Windows-Export per PowerShell-Skript (siehe build_windows.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1" %*
exit /b %ERRORLEVEL%
