# Entwicklungsübersicht

## Arbeitsweise
- Jede Änderung: Tests lokal (`scripts/linux/run_tests.sh` bzw. `scripts\windows\run_tests.bat`), **Exit-Code 0** vor dem Commit.
- Neue `class_name`-Dateien erfordern einen Import (`godot --headless --path . --import`); die Skripte erledigen das.
- Visuelle Kontrolle: `scripts/linux/screenshot_tour.sh artifacts/screenshots/<Ordner>` (Xvfb, Software-Rendering).
- Meilensteine und Restore-Punkte: `docs/ARBEITSLOG.md`.

## Inhalte erweitern

### Neuer Auftrag
1. `data/missions/mNN_name.json` anlegen (Vorlage: vorhandene Aufträge). Felder: `id`, `title`, `order`, `reward`,
   `repeatable`, `requires`, `giver` (POI, Name, Aussehen, Texte), `fail_vehicle`, optional `best_time_key`, `steps`.
2. Schritttypen: `talk`, `spawn_vehicle`, `enter_vehicle`, `goto` (optional `require_clean`, `clean_radius`), `wait_zone`,
   `exit_vehicle`, `interact`, `countdown`, `checkpoints` (Punkte als POI-ID oder `[x, z]`, `radius`, `time_limit`),
   `trigger_wanted`, `lose_wanted`.
3. Benötigte POIs in `data/world/karlsruhe_layout.json` ergänzen.
4. `test_mission_data_valid` prüft Datenkonsistenz automatisch; einen Durchlauftest nach dem Muster
   `tests/integration/test_mission_m02.gd` ergänzen.

### Neues Fahrzeug
Eintrag in `data/vehicles/vehicles.json` (Masse, Maße, Motor, Lenkung, Grip, Federung, Farben). Karosserieform über
`body_style` (vorhandene Formen in `vehicle_model_builder.gd`). `test_all_vehicle_types_drive_brake_and_steer` um die ID erweitern.

### Karte ändern
Straßen als Polylinie (`points`), Bogen (`arc`) oder Fächerstrahl (`ray`) in `karlsruhe_layout.json`. Der Graph wird planarisiert;
`test_city_graph` prüft Kreuzungen, Zusammenhang, Sackgassen und freie POIs.

## Empfohlene nächste Schritte
1. **Test auf echtem Windows 10/11** mit Mittelklasse-GPU: Start, Menü, 30 min Spielzeit, FPS mit F3 notieren
   (Grundlage für Qualitätsvoreinstellungen).
2. Spielgefühl mit Testpersonen: Fahrzeug-Specs (`vehicles.json`) und Kamera nachjustieren.
3. Leistung: Gebäude-Meshes je Block zusammenfassen/LOD, Schattendistanz je Qualitätsstufe prüfen.
4. Polizei: Straßensperren, koordinierte Suchmuster mehrerer Einheiten, bessere Umfahrung von Hindernissen.
5. Verkehr: Spurwechsel, Abbiegen mit Gegenverkehrsprüfung, Busse/Straßenbahn als Kulisse mit Bewegung.
6. Inhalte: weitere Aufträge, Nebenaktivitäten (Kurierfahrten als wiederholbare Jobs), Tageszeiten.
7. Barrierefreiheit/Komfort: Tastenbelegung ändern, Gamepad, Untertitelgröße.
8. Code-Signierung des Windows-Builds, falls verteilt wird.
