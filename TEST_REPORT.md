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
| Automatisierte Tests (Unit + Integration, headless) | ⟨SUITE⟩ |
| Weltdaten-Validierung (Gebäude, Autos, Objekte, Landmarken gegen Fahrbahnen) | **getestet** – ⟨VALID⟩ |
| Visuelle Kontrolle (Screenshot-Tour, Software-Rendering) | ⟨TOUR⟩ |
| Windows-Export + Starttest der PCK (`--boot-check`) | ⟨EXPORT⟩ |
| GitHub-Release (Workflow) | ⟨RELEASE⟩ |
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
| W12 Tests, Doku, Build, Release | ⟨W12⟩ | dieser Bericht |

## 2. Automatisierte Tests

Aufruf: `scripts/linux/run_tests.sh` (Import, dann `godot --headless --fixed-fps 60 res://tests/test_runner.tscn`).
Ein Test gilt nur als bestanden, wenn alle Prüfungen erfüllt sind **und** kein Engine-/Skriptfehler protokolliert wurde.
Alle Integrationstests laufen auf der ausgelieferten OSM-Welt (Streaming synchron, 3 × 3 Sektoren).

⟨SUITE_DETAIL⟩

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

⟨WORLD⟩

## 4. Visuelle Kontrolle

`scripts/linux/screenshot_tour.sh` unter Xvfb mit Vulkan (Mesa lavapipe, **Software-Rendering**), 1280×720.
Die angezeigte Bildrate ist **nicht** aussagekräftig für echte Hardware.

⟨TOUR_DETAIL⟩

## 5. Windows-Export und Release

⟨EXPORT_DETAIL⟩

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
