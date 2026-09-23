@echo off
rem Faecher-City: Asphalt und Schatten - Installation nach C:\GTA_KA und Start.
rem Diese Datei in denselben Ordner legen wie Faecherstadt_Windows_x64_v0.1.0.zip
rem (oder die beiden Teile .zip.part00 und .zip.part01) und doppelklicken.
rem Aendert nichts ausser dem Ordner C:\GTA_KA. Hinweis: auf echtem Windows noch ungetestet.
setlocal
set "SRC=%~dp0"
set "DEST=C:\GTA_KA"
set "NAME=Faecherstadt_Windows_x64_v0.1.0.zip"
set "HASH=794122ba28611caf96e3a35afa35e835990a551589a1e82097bcd21a38013010"

echo [1/4] Ordner %DEST% anlegen ...
if not exist "%DEST%" mkdir "%DEST%"
if not exist "%DEST%" goto :fehler

echo [2/4] Archiv bereitstellen ...
if exist "%SRC%%NAME%" (
  copy /y /b "%SRC%%NAME%" "%DEST%\%NAME%" >nul
) else if exist "%SRC%%NAME%.part00" (
  if not exist "%SRC%%NAME%.part01" goto :fehlt
  copy /y /b "%SRC%%NAME%.part00" + "%SRC%%NAME%.part01" "%DEST%\%NAME%" >nul
) else (
  goto :fehlt
)
if errorlevel 1 goto :fehler

echo [3/4] Pruefsumme kontrollieren ...
certutil -hashfile "%DEST%\%NAME%" SHA256 | findstr /i "%HASH%" >nul
if errorlevel 1 (
  echo Pruefsumme stimmt NICHT - die Datei ist unvollstaendig oder beschaedigt.
  echo Bitte erneut von GitHub herunterladen.
  pause
  exit /b 1
)

echo [4/4] Entpacken ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force -LiteralPath '%DEST%\%NAME%' -DestinationPath '%DEST%'"
if errorlevel 1 goto :fehler

echo.
echo Fertig. Das Spiel liegt in %DEST%\Faecherstadt\ und wird jetzt gestartet.
echo Spaeter direkt starten mit: %DEST%\Faecherstadt\Faecherstadt.exe
start "" /d "%DEST%\Faecherstadt" "%DEST%\Faecherstadt\Faecherstadt.exe"
exit /b 0

:fehlt
echo %NAME% wurde neben dieser .bat nicht gefunden.
echo Bitte beide Dateien in denselben Ordner legen (z. B. Downloads).
pause
exit /b 1

:fehler
echo Es ist ein Fehler aufgetreten (siehe Meldungen oben).
pause
exit /b 1
