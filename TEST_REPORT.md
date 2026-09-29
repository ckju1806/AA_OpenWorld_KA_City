# Testbericht – Fächer-City: Asphalt & Schatten v0.2.0

Stand: 2026-09-29 · Umgebung: Linux-Container (Ubuntu 24.04, 4 CPU, keine GPU, keine Soundkarte),
Godot 4.7.2.stable.official.ed1daf0bf, Weltdaten aus OpenStreetMap (Abruf 2026-09-29).
Alle Angaben sind tatsächlich ausgeführt und beobachtet, sofern nicht anders markiert. Der Bericht zu v0.1.0 liegt in der
Git-Historie (`git show 46db3d1:TEST_REPORT.md`).

Status-Begriffe: **implementiert** (Code vorhanden), **getestet** (automatisiert und/oder visuell geprüft), **teilweise**
(Kern vorhanden, Umfang eingeschränkt), **ungetestet** (nicht ausführbar in dieser Umgebung), **blockiert** (äußerer Grund).

## Kurzfassung

| Bereich | Status |
|---|---|
| Automatisierte Tests (Unit + Integration, headless) | **getestet – 138 Tests, 0 fehlgeschlagen, Exit-Code 0** (Gesamtlauf auf der OSM-Welt, 2 072 s) |
| Weltdaten-Validierung (Gebäude, Autos, Objekte, Landmarken gegen Fahrbahnen) | **getestet** – 5 Prüfungen, 0 Verstöße |
| Visuelle Kontrolle (Screenshot-Tour, Software-Rendering) | **getestet** – 46 Bilder + Hauptmenü visuell geprüft, Auswahl in `artifacts/screenshots/v0.2/` |
| Windows-Export + Starttest der PCK (`--boot-check`) | **getestet** (unter Linux): PCK-Inhalt geprüft, Starttest „OK“ |
| GitHub-Release (Workflow) | siehe Abschnitt 5 |
| Start unter echtem Windows 10/11 | **ungetestet** – kein Windows verfügbar |
| Leistung (FPS) auf echter Hardware | **ungetestet** – keine GPU |
| Subjektives Spielgefühl, Balance | **ungetestet** (nur messbare Kriterien) |
| Windows-Skripte (`scripts/windows/*`) | **ungetestet** (kein Windows) |

## 1. Funktionsumfang nach Meilenstein (Plan v2)

| Meilenstein | Status | Beleg |
|---|---|---|
| W1 Weltsystem & Streaming (256-m-Sektoren, LOD, Zeitbudget) | implementiert, getestet | test_traffic (Objektzahl nach Teleports), test_city_world, Screenshot-Tour |
| W2 Karte 1:1 (OSM, ≈ 17,5 × 10,4 km) | implementiert, getestet | Validierung, test_city_graph, test_city_world, alle Auftragstests auf OSM-Geometrie |
| W3 Landmarken & Prioritätsorte | implementiert, visuell geprüft | test_city_world (Landmarken, Schlossturm), Tour-Stationen je Ort |
| W4 Grafik (Tag/Nacht, Wetter, Shader, Wind, Qualitätsstufen) | implementiert, visuell geprüft | test_world_clock, test_settings_v2, Tour Mittag/Nacht/Regen/Nebel |
| W5 ÖPNV (Stadtbahn, U-Strab, Bus, Mitfahren) | implementiert, getestet | test_transit (4), Tour ÖPNV-Stationen |
| W6 Tiere | implementiert, getestet | test_animals (3) |
| W7 Banden/Ereignisse/Polizei | implementiert, getestet | test_events (5), test_police (5) |
| W8 Kampagne (15 Aufträge) + Jobs | implementiert, getestet | test_mission_m01–m03, test_campaign (M4–M15), test_jobs |
| W9 Cheats (40 deutsche Codes) | implementiert, getestet | test_cheats (6) |
| W10 Optionen A–E, Tastenbelegung | implementiert, getestet | test_settings_v2 (5), Tour Optionen |
| W11 KI (Umfahren, Hindernisbremsung, Fahrgäste) | teilweise (keine Spurwechsel, keine Kreuzungsreservierung) | test_traffic (Umfahren, Abstand, Rot) |
| W12 Tests, Doku, Build, Release | implementiert, getestet (Windows-Start ungetestet) | dieser Bericht |

## 2. Automatisierte Tests

Aufruf: `scripts/linux/run_tests.sh` (Import, dann `godot --headless --fixed-fps 60 res://tests/test_runner.tscn`).
Ein Test gilt nur als bestanden, wenn alle Prüfungen erfüllt sind **und** kein Engine-/Skriptfehler protokolliert wurde.
Alle Integrationstests laufen auf der ausgelieferten OSM-Welt (Streaming synchron, 3 × 3 Sektoren).

- **Gesamtlauf:** 138 Tests, 0 fehlgeschlagen, 0 Skriptfehler, 2 072 s, Exit-Code 0 (Welt-Stand v7, Commit `43686ab`).
- **Nachtest nach der letzten Änderung** (Laufzeit-Vegetation spart Gebäude/Gewässer/Landmarken aus, Landmarken-Grundrisse in
  `world.json.gz`): Unit 52/52 sowie test_city_world 6/6, test_animals 3/3, test_player 6/6, test_traffic 5/5,
  test_transit 4/4, test_save_load 6/6 – alle grün, keine Skriptfehler.
- Vorheriger Gesamtlauf auf der ersten OSM-Welt: 137/138 (m01: Fußweg zur Kanzleitür blockiert → Testhilfe `walk_to` geht über
  das Wegenetz; danach grün). Testlogs liegen lokal in `artifacts/test-logs/` (nicht versioniert, Speicherbudget).

| Testdatei | Tests | Inhalt (Auszug) |
|---|---|---|
| unit/test_city_graph | 9 | Graph baut, keine Kreuzung ohne Knoten, Rasterindex = Brute Force, Fahrnetz zu > 97 % zusammenhängend, wenige Sackgassen, Fächerstraßen münden in den Zirkel, Landmarken im realen Maßstab (Schloss–Hbf 2–2,5 km), Wege zwischen POIs, Weltdaten-Budget |
| unit/test_save_codec | 8 | Rundreise, beschädigt/leer/falsches Format, neuere Version abgelehnt, fehlende Felder, **ferne Positionen der großen Karte**, ungültige Position, Auftragsfeld |
| unit/test_settings_v2 | 5 | Voreinstellungen, Migration v1→v2, Speichern/Laden, Werte begrenzt, Tastenkonflikte |
| unit/test_world_clock | 6 | Zeitfortschritt/Tageswechsel, Pause, Tag-Nacht-Faktor, Wetterübergang + Nässe, erzwungenes Wetter, Spielstand |
| unit/test_game_state, test_wanted_logic, test_poly_util, test_vehicle_spec, test_audio_assets | 24 | wie v0.1 |
| integration/test_player | 6 | Boden, Gehen/Rennen, Bordstein, Springen, Schaden/Wiederbelebung, Kamera |
| integration/test_vehicle | 12 | Fahren/Bremsen/Lenken, Ein-/Ausstieg, Schaden, Bergung, Licht/Hupe, Autopilot, alle 5 Typen |
| integration/test_city_world | 6 | Aufbau + Spawn, POIs auf freiem Boden, **5 522 Fahrspurproben ohne Gebäude**, geparkte Autos stabil, Landmarken + Schlossturm, Bergungspunkt |
| integration/test_traffic | 5 | Verkehr fährt, Halt an Rot, Abstand, **Umfahren eines abgestellten Fahrzeugs**, Objektzahl begrenzt |
| integration/test_pedestrians | 3 | nicht in Wänden, Ausweichen, Anfahren gemeldet |
| integration/test_police | 5 | Diebstahl mit/ohne Zeugen, Spawn außer Sicht, Suche/Abbau, Festnahme, Rammen |
| integration/test_transit | 4 | Linien/Haltestellen/Tunnel geladen, Fahrt mit Halt und Wende, **Mitfahrt durch den U-Strab-Tunnel mit Ausstieg**, Bremsen vor Hindernis |
| integration/test_animals | 3 | Zootiere bleiben im Gehege, Vögel fliegen bei Hupe auf, Dichte 0 |
| integration/test_events | 5 | jede Ereignisart startet und räumt auf, abschaltbar, Chaos-Modus, Dieb fangen, Unbeteiligte anfahren = Tat |
| integration/test_cheats | 6 | unbekannt/gesperrt, Geld/Gesundheit, Schalter + Zurücksetzen, Tippen im Spiel, Zeit/Wetter/Dichte, Auto + Teleport |
| integration/test_mission_m01–m03 | 10 | M1 per Autopilot über echte Straßen (Bäckerei → Kanzlei), **M2 reale Fächer-Runde 13,9 km in < 18 min**, M3 mit Fahndung |
| integration/test_campaign | 13 | M4–M15 per Löser (Verfolgen, Begleiten, Beobachten, Sammeln, Taxi, ÖPNV-Fahrt …), Belohnung/Ruf einmalig, Aufräumen |
| integration/test_jobs | 2 | Jobs zahlen jedes Mal, Auftragsliste + Wegpunkt |
| integration/test_save_load | 6 | Speichern/Fortsetzen, Auftrag neu beim Auftraggeber, Fahndung → sicherer Punkt, Autosave, Pause/Karte |

Einschränkungen der Tests (ehrlich):
- Fahrten steuert ein Autopilot über das Straßennetz – Beleg für Erreichbarkeit/Abschließbarkeit, nicht für Spielgefühl.
- Kampagnen-Löser versetzen das Fahrzeug zu Zielen; Verfolgen/Begleiten nutzt die echte NPC-Fahrt.
- „Fahndung abschütteln“ versetzt das Fahrzeug außer Sicht (geprüft wird die Such-/Abbaulogik, keine Fluchtfahrt).
- Tests laufen deterministisch mit fester Bildrate; schwankende Bildraten sind nicht gesondert getestet.

## 3. Weltdaten

`python3 tools/worldgen/build_world.py --source osm` → `validate_world.py` (bricht den Build bei Verstößen ab).

| Kennzahl | Wert |
|---|---|
| Quelle | OpenStreetMap, Abruf 2026-09-29 (Overpass, 240 Kacheln + ÖPNV-Relationen) |
| Straßengraph | 42 238 Knoten, 45 612 Kanten |
| Gebäude | 94 052 Grundrisse im Kartenausschnitt (96 522 aufbereitet; Gebäude mit Mittelpunkt außerhalb des Ausschnitts entfallen) |
| Sektoren / LOD-Kacheln | 2 988 / 204 |
| Größe | 11,5 MB (Budget ≤ 40 MB, größte Datei `map.webp` 2,0 MB) |
| ÖPNV | 177 Linienverläufe (Starttest) |
| Bauzeit | ≈ 7,5 min (4 CPU) |

Validierung (`validate_world.py`, bricht den Build ab): Gebäude in Fahrspuren **0**, parkende Autos auf Fahrspuren **0**,
Objekte auf Fahrbahnen **0**, Landmarken auf Fahrbahnen **0**, Objekte in Landmarken **0**. Zusätzlich geprüft (Skript im
Arbeitslog beschrieben): 0 m² Überlappung von OSM-Gebäuden mit Landmarken-Grundrissen; Zoo-Gehege 0 m² Wasser/Gebäude.

## 4. Visuelle Kontrolle

`scripts/linux/screenshot_tour.sh` unter Xvfb mit Vulkan (Mesa lavapipe, **Software-Rendering**), 1280×720.
Die angezeigte Bildrate ist **nicht** aussagekräftig für echte Hardware.

Abschluss-Tour: 46 Stationen, 0 Skriptfehler, alle Standpunkte aus Weltdaten (Landmarken, Straßennamen). Visuell geprüft und
für gut befunden: Schlossplatz mit Schloss in der Achse, Marktplatz (Pyramide, Rathaus mit Portikus, Stadtkirche), Kaiserstraße,
Europaplatz mit Brunnen, Durlacher Tor, Hauptbahnhof mit Uhrturm und Bogenhalle, Zoo (Gehege, Robbenbecken, Flamingos), Stadion,
Gewächshäuser, Hafenkräne, Turmberg, Durlach (Pfinztalstraße), ÖPNV (Haltestelle mit Einsteigehinweis, Rampenportal, Mitfahrt in
U-Station und Tunnel mit HUD), Tag/Nacht/Regen/Nebel, HUD-Fahrt, Ampelkreuzung, Vollkarte (reales Straßennetz), Optionen,
Cheat-Konsole, Luftbild (Zirkel und Fächerblöcke), Hauptmenü mit Namensnennung „© OpenStreetMap-Mitwirkende … (ODbL)“.
Während der Prüfung gefundene und behobene Mängel: siehe Arbeitslog (Zoo-Gehege im See, Bäume in Landmarken, Turmberg-Terrasse
auf der Straße, verdeckte Standpunkte). Kleinere offene Schönheitsfehler: Kartenbeschriftung „Hauptbahnhof“ überlappt am unteren
Rand die Legende; U-Strab-Zugänge sind schlichte Blöcke.

## 5. Windows-Export und Release

| Prüfung | Ergebnis |
|---|---|
| Export `godot --headless --export-release "Windows Desktop"` (lokal) | ok |
| `Faecherstadt.exe` | 109 134 848 Bytes |
| `Faecherstadt.pck` | Kennung `GDPC`, 18 956 800 Bytes; enthält Weltdaten, Sektoren, Missionen, Gruppen (Skriptprüfung) |
| Starttest der PCK (Linux-Engine 4.7.2, `--headless --main-pack … -- --autostart --boot-check`) | `[boot] OK: Knoten 42238, Aufträge 15, ÖPNV-Linien 177, Quelle osm` |
| ZIP `Faecherstadt_Windows_x64_v0.2.0.zip` | 56 485 101 Bytes; EXE, PCK, README, CONTROLS, ASSET_LICENSES, KNOWN_ISSUES, LICENSE |
| Release-Paket (`package_release.sh`) | ZIP, Installer `GTA_KA_installieren_und_starten.bat`, `SHA256SUMS.txt` |

SHA256 des lokalen Builds (2026-09-29, 09:07 UTC):
```
d9cad95cb1ec54ab4ecc883df78fe6ce763caa646371c81e485da39a9d5dabfc  Faecherstadt.exe
532f9d74725ee4d4bbe30ab4d93d299ae2b08fa331d79f1731f0fd3a5abf0a35  Faecherstadt.pck
44d6725bf690359f9778d4410610c39fe255710196cdd578d63c17a00d37ee20  Faecherstadt_Windows_x64_v0.2.0.zip
```
**GitHub-Release:** Der Build liegt nicht im Repository (Speicherbudget). Der Workflow `.github/workflows/windows-release.yml`
baut unter Linux neu, führt die Unit-Tests aus und veröffentlicht ZIP, Installer und `SHA256SUMS.txt` als Release-Anhang
(eigene Prüfsummen des CI-Builds). Status: ausgelöst durch den Commit mit diesem Bericht (Tag `v0.2.0`, Vorabversion); das Ergebnis wird hier nachgetragen.

## 6. Blockiert / nicht durchgeführt
- **Start unter Windows 10/11 – ungetestet:** kein Windows verfügbar. Ein Wine-Rauchtest war schon in v0.1 blockiert
  (das unveränderte offizielle Godot-Template stürzt unter Wine 9.0 ab; keine Aussage über Windows ableitbar).
- **FPS, Speicherverbrauch über längere Spielzeit, hörbare Audioausgabe** – ungetestet (keine GPU, keine Soundkarte).
- **Windows-Skripte** (`start_game.bat`, `build_windows.ps1/.bat`, `run_tests.bat`, Installer-`.bat`) – nicht ausgeführt.
- **Kartendaten Hafenkräne:** Die abgerufenen OSM-Kacheln enthalten keine Kran-Objekte → Kräne an der Näherungsposition.

## 7. Empfohlene Abnahme auf Windows
1. Release-ZIP + Installer-`.bat` herunterladen, `.bat` starten (Prüfsummenkontrolle) oder ZIP entpacken und
   `Faecherstadt.exe` starten → Hauptmenü mit Namensnennung „© OpenStreetMap-Mitwirkende“.
2. „Neues Spiel“ → Start am Marktplatz; F3 → FPS notieren (Qualität „Mittel“); M → Karte; Esc → Pause.
3. Auftrag 1 bei Hanne (orange Raute) vollständig spielen; Stadtbahn an einer Haltestelle mit E besteigen.
4. Pausenmenü → Speichern → Hauptmenü → Fortsetzen: Geld/Fortschritt prüfen (`%APPDATA%\Faecherstadt\`).
5. Bei Ruckeln: Qualität „Niedrig“, Sichtweite und Dichten verringern; Ergebnis bitte zurückmelden.
