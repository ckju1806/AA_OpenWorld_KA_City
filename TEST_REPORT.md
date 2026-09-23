# Testbericht – Fächer-City v0.1.0

Stand: 2026-09-23 · Umgebung: Linux-Container (Ubuntu 24.04, 4 CPU, keine GPU, keine Soundkarte),
Godot 4.7.2.stable.official.ed1daf0bf. Alle Angaben unten sind tatsächlich ausgeführt und beobachtet, sofern nicht anders markiert.

## Kurzfassung

| Bereich | Status |
|---|---|
| Automatisierte Tests (Unit + Integration, headless) | **durchgeführt – 90 Tests, 0 fehlgeschlagen, Exit-Code 0** |
| Visuelle Kontrolle (Screenshot-Tour, Software-Rendering) | durchgeführt (Meilensteine A–G + exportiertes Paket) |
| Windows-Export (`build/windows/Faecherstadt.exe` + `.pck`) | **durchgeführt**, formal geprüft |
| Start des exportierten Pakets | durchgeführt **unter Linux** (gleiche Engine-Version, `--main-pack`) |
| Rauchtest unter Wine | **blockiert** (siehe unten) |
| Start unter echtem Windows 10/11 | **nicht durchgeführt** – kein Windows verfügbar |
| Leistung (FPS) auf echter Hardware | **nicht durchgeführt** |
| Subjektives Spielgefühl (Fahren, Kamera, Balance) | **nicht durchgeführt** (nur messbare Kriterien) |
| Windows-Skripte (`scripts/windows/*`) | **nicht ausgeführt** (kein Windows) |

## 1. Automatisierte Tests

Aufruf: `scripts/linux/run_tests.sh` (Import, dann `godot --headless --fixed-fps 60 res://tests/test_runner.tscn`).
Ein Test gilt nur als bestanden, wenn alle Prüfungen erfüllt sind **und** während des Tests kein Engine-/Skriptfehler
protokolliert wurde. Letzter vollständiger Lauf: `artifacts/test-logs/tests_20260923_194040.log` – **90 Tests, 0 fehlgeschlagen, Laufzeit 121,5 s, Exit-Code 0**.

| Testdatei | Tests | Inhalt (Auszug) |
|---|---|---|
| unit/test_game_state | 6 | Startgeld, Belohnung nur einmal, Geld nie negativ, Bestzeit nur Verbesserung, Rundreise, fehlerhafte Daten toleriert |
| unit/test_save_codec | 7 | Rundreise, beschädigtes JSON, leer/falsches Format, neuere Version abgelehnt, fehlende Felder → Standard, ungültige Position verworfen, Feld `mission` |
| unit/test_poly_util | 5 | Fläche/Orientierung, gleichmäßiger und kantenweiser Inset, kollabierender Inset, Polarkoordinaten |
| unit/test_vehicle_spec | 4 | Katalog (5 Typen), Plausibilität, Fahrverhalten unterscheidet sich, Rückfall |
| unit/test_audio_assets | 3 | Pflichtklänge vorhanden, Schleifenpunkte, fehlender Klang ohne Absturz |
| unit/test_city_graph | 7 | Graph baut, keine Kantenkreuzung ohne Knoten, Fahrnetz zusammenhängend, keine Sackgassen im Verkehrsnetz, Blöcke + Park, Fächerstraßen beginnen am Zirkel, Wege zwischen POIs |
| unit/test_wanted_logic | 6 | unbeobachtete Tat ohne Wirkung, beobachtete Tat → Stufe + Position, Obergrenze 3, Suchphase + Abbau auf 0, erneuter Sichtkontakt, konfigurierbare Suchdauer |
| integration/test_player | 6 | steht auf dem Boden, Gehen/Rennen, Bordsteinstufe, Springen, Schaden/Wiederbelebung, Kamera folgt und weicht Wänden aus |
| integration/test_vehicle | 12 | Beschleunigen/Bremsen/Rückwärts, Lenkung, Handbremse, 5× Ein-/Aussteigen und Wechsel, Ausstieg verweigert (schnell/eingekeilt), Crash-Schaden, Bergung, Licht/Hupe, Autopilot 200 m, **alle 5 Fahrzeugtypen** |
| integration/test_city_world | 6 | Stadtaufbau + Spawn, POIs auf freiem begehbarem Boden, Fahrbahnen frei von Gebäuden, geparkte Fahrzeuge stabil, Landmarken vorhanden, Bergungspunkt auf Fahrbahn |
| integration/test_traffic | 4 | Sollanzahl, kein Überschlag, ≥ 90 % auf Fahrbahnen, Halt an Rot, Abstand ohne Auffahrunfall, begrenzte Objektzahl |
| integration/test_pedestrians | 3 | nicht in Wänden, bewegen sich, Ausweichen, Anfahren gemeldet |
| integration/test_police | 5 | beobachteter/unbeobachteter Diebstahl, Spawn außer Sicht, Suche an zuletzt bekannter Position, Abbau, Festnahme → Revier (150 €) + Missionsfehlschlag, Rammen |
| integration/test_mission_m01 | 3 | kompletter Durchlauf per Autopilot, 250 € genau einmal, 3× Fehlschlag + Wiederholung ohne Objektwachstum, Missionsdaten gültig |
| integration/test_mission_m02 | 3 | gesperrt ohne M1, **komplette Runde über 12 Kontrollpunkte per Autopilot (142,6 s simuliert)**, Bestzeit, Wiederholung ohne Doppelbelohnung, Zeitlimit-Fehlschlag + Wiederholung |
| integration/test_mission_m03 | 4 | gesperrt ohne M1, kompletter Durchlauf (Lager, Fahndung 2, Polizei rückt an, Abschütteln, Werkstatt, 800 € einmal), **kein Abschluss mit Fahndung bzw. Streifenwagen < 60 m**, Festnahme → Wiederholung |
| integration/test_save_load | 6 | Speichern → Fortsetzen (Geld, Aufträge, Bestzeit, Position), Auftrag beginnt beim Auftraggeber neu, Fahndung → sicherer Punkt, blockierte Position → Start, Autosave, Pause/Karte |

Einschränkungen der Tests (ehrlich):
- „Fahndung abschütteln“ versetzt das Fahrzeug außer Sicht; geprüft wird die echte Such- und Abbaulogik, nicht eine Fluchtfahrt.
- Fahrten der Missionstests steuert ein Autopilot über das Straßennetz – Beleg für Erreichbarkeit/Abschließbarkeit, nicht für Spielgefühl.
- Tests laufen deterministisch mit fester Bildrate; Verhalten bei schwankender Bildrate ist nicht gesondert getestet.

## 2. Visuelle Kontrolle

`scripts/linux/screenshot_tour.sh` unter Xvfb mit Vulkan (Mesa lavapipe, **Software-Rendering**), 1280×720.
Bilder in `artifacts/screenshots/<Meilenstein>/`, jeweils von mir angesehen: Landmarken, Straßenzüge, HUD, Dialog, Missionsmarker,
Verkehr an Ampel, Passanten, Verfolgung, Zeitfahren, Hauptmenü, Vollkarte, Pausenmenü, F3-Anzeige mit Minikarte, Luftbild.
Die dabei angezeigte Bildrate (~4 FPS) ist **nicht** aussagekräftig für echte Hardware.

## 3. Windows-Export

| Prüfung | Ergebnis |
|---|---|
| Export `godot --headless --export-release "Windows Desktop"` | ok, Log ohne Fehler (`artifacts/test-logs/export_*.log`) |
| `Faecherstadt.exe` | MZ/PE-Header ok, **Maschine 0x8664 (x86_64)**, Subsystem GUI, 109 134 848 Bytes |
| Programmsymbol/Metadaten | alle 6 Bildgrößen aus `faecherstadt.ico` und Produktname in der EXE gefunden |
| `Faecherstadt.pck` | Kennung `GDPC`, 723 500 Bytes; enthält Skripte, Shader, Audio, alle JSON-Daten (Exportlog geprüft) |
| Bootstest der PCK (Linux-Editor-Binary 4.7.2, `--headless --main-pack … --quit-after 1200 -- --autostart`) | ok: Stadt aufgebaut, keine Skriptfehler |
| Screenshot-Tour aus der PCK (Xvfb/lavapipe) | ok: 22 Bilder, keine Skriptfehler; einzige ERROR-Zeile = fehlendes Audiogerät im Container (ALSA → Dummy-Treiber). Beispiele: `artifacts/screenshots/H_export_pck/` |
| ZIP `build/Faecherstadt_Windows_x64_v0.1.0.zip` | 38 488 702 Bytes, Integritätsprüfung ok; Inhalt: EXE, PCK, README, CONTROLS, ASSET_LICENSES, KNOWN_ISSUES, LICENSE |

SHA256 (Build vom 2026-09-23, 19:42 UTC):
```
3633ef34b4b5ad8dd70d3d33d7ff3e487a7252d0d817ce0a685071c48e02fc1d  Faecherstadt.exe
a6326d2eae5a35daf6e81b362f3173b5cc7ec9db70ac5125dc3daeee20ad2976  Faecherstadt.pck
794122ba28611caf96e3a35afa35e835990a551589a1e82097bcd21a38013010  Faecherstadt_Windows_x64_v0.1.0.zip
```
Reproduzierbarkeit: Zwei aufeinanderfolgende Exporte (19:40 und 19:42 UTC) ergaben bitgleiche EXE und PCK. Das ZIP unterscheidet sich,
weil zwischen den Läufen Doku-Dateien geändert wurden (und ZIP-Einträge Zeitstempel tragen).

## 4. Blockiert / nicht durchgeführt

- **Wine-Rauchtest – blockiert:** Wine 9.0 (Ubuntu-Paket) führt einfache Programme aus (`cmd /c echo` ok), aber bereits das
  **unveränderte offizielle** Godot-4.7.2-Template stürzt schon bei `--version` ab (Zugriffsverletzung, Adresse
  `0x6FFFFF4B0608` im Adressbereich der Wine-eigenen System-DLLs). Unser Build zeigt denselben Absturz an derselben Adresse.
  Beobachtung: Das Problem ist nicht durch unseren Export verursacht. Annahme (nicht verifiziert): Inkompatibilität dieser
  Wine-Version mit Godot 4.7. **Eine Aussage über das Verhalten unter Windows ist daraus nicht ableitbar.**
- **Start unter Windows 10/11 – nicht durchgeführt:** Kein Windows-System verfügbar. Der Build ist **ungetestet unter Windows**.
- **FPS-Messung auf echter Hardware, Speicherverbrauch über längere Spielzeit, Audioausgabe hörbar** – nicht durchgeführt
  (keine GPU, keine Soundkarte).
- **Windows-Skripte** (`start_game.bat`, `build_windows.ps1/.bat`, `run_tests.bat`) – nicht ausgeführt.

## 5. Empfohlene Abnahme auf Windows
1. ZIP entpacken, `Faecherstadt.exe` starten → Hauptmenü mit animiertem Fächer, Menümusik hörbar.
2. „Neues Spiel“ → Start am Marktplatz; F3 → FPS notieren; M → Karte; Esc → Pause.
3. Auftrag 1 bei Hanne (Kurierhof südwestlich des Marktplatzes, orange Raute auf der Karte) vollständig spielen.
4. Pausenmenü → Speichern → Hauptmenü → Fortsetzen: Geld/Fortschritt prüfen.
5. `%APPDATA%\Faecherstadt\savegame.json` vorhanden?

## 6. Auslieferung
Das ZIP (36,7 MiB) überschritt das Upload-Limit der Sitzung (30 MiB) und wurde daher binär in zwei Teile geteilt übergeben:
```
106befee5d4d7129d3d166bb362ce471d89f12ce8d5b67d4d34d3ff996b460fd  Faecherstadt_Windows_x64_v0.1.0.zip.part00
752e526b387d48455f30e5b8e4f870afd3b7f469692771fa8805f90de650ab7e  Faecherstadt_Windows_x64_v0.1.0.zip.part01
```
Zusammensetzen unter Windows: `copy /b Faecherstadt_Windows_x64_v0.1.0.zip.part00 + Faecherstadt_Windows_x64_v0.1.0.zip.part01 Faecherstadt_Windows_x64_v0.1.0.zip`,
Prüfung: `certutil -hashfile Faecherstadt_Windows_x64_v0.1.0.zip SHA256` → `794122ba…3010` (siehe oben). Zusammensetzen unter Linux geprüft (identische Prüfsumme).
