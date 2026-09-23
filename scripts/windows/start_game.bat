@echo off
rem Startet Faecher-City: bevorzugt den fertigen Build, sonst das Projekt mit einem installierten Godot 4.7.2.
setlocal
set "ROOT=%~dp0..\.."
if exist "%ROOT%\build\windows\Faecherstadt.exe" (
  start "" "%ROOT%\build\windows\Faecherstadt.exe"
  exit /b 0
)
if "%GODOT%"=="" set "GODOT=godot"
where "%GODOT%" >nul 2>nul
if errorlevel 1 (
  echo Kein Build gefunden und Godot nicht im PATH. Bitte zuerst scripts\windows\build_windows.bat ausfuehren
  echo oder die Umgebungsvariable GODOT auf Godot_v4.7.2-stable_win64.exe setzen.
  exit /b 1
)
start "" "%GODOT%" --path "%ROOT%"
