# Plan: „Fächer-City: Asphalt & Schatten“ – spielbarer Open-World-Prototyp (Godot 4.7.2)

Stand: 2026-09-23 · Änderungsklasse: **groß** (neues Projekt, >80 Dateien, neue Toolchain, Build-Pipeline)

## 1. Kontext

Das Repository `ckju1806/AA_OpenWorld_KA_City` (Branch `claude/confident-volta-6a71kc`) enthält nur `LICENSE` (MIT) und eine einzeilige `README.md`. Ziel ist ein vollständig spielbarer 3D-Open-World-Prototyp (Third-Person, Fahren, Verkehr, Passanten, Polizei, 3 Missionen, UI, Speichern) in einer künstlerisch verdichteten Karlsruher Innenstadt, inkl. Tests, Doku und echtem Windows-x64-Export.

## 2. Umgebungsbefund (Beweiskette)

| Beobachtung | Folgerung |
|---|---|
| Kein Godot installiert; `godotengine.org`, `tuxfamily` → 403 (Policy) | Offizielle Seiten blockiert |
| `git ls-remote` godotengine/godot: neuester Stable-Tag **4.7.2-stable** | Zielversion 4.7.2 |
| `github.com/godotengine/godot/releases/download/4.7.2-stable/…linux.x86_64.zip`, `SHA512-SUMS.txt` → 206 OK | Editor + Prüfsummen ladbar |
| `…/godot/…export_templates.tpz` → HTTP 500 (GitHub-seitig); `godotengine/godot-builds/…4.7.2…tpz` → 206 OK | Templates über offizielles Spiegel-Repo `godot-builds`, SHA512-Prüfung gegen offizielle Liste |
| Ubuntu 24.04, 4 CPU, 15 GB RAM, ~30 GB frei; Xvfb, Mesa-GL (llvmpipe) vorhanden; `mesa-vulkan-drivers`, `wine64` per apt installierbar | Headless-Tests, Screenshots unter Xvfb (Vulkan via lavapipe oder GL-Fallback), optional Wine-Rauchtest |
| Wikipedia/OSM/Asset-Portale blockiert; WebSearch funktioniert | Lagebeziehungen per Websuche verifiziert (s. §5), keine Geodaten/Fremdassets → alle Assets selbst erzeugt |
| Kein echtes Windows verfügbar | Windows-Start **nicht** prüfbar → wird als „ungetestet unter Windows“ dokumentiert |

Konfidenz Umgebungsbefund: 9/10 (direkt gemessen; Template-Download-Größe/-Dauer noch unbekannt).

## 3. Grundsatzentscheidungen (selbst getroffen, dokumentiert)

- **Engine:** Godot **4.7.2-stable**, typisiertes GDScript, **Jolt Physics**, Renderer **Forward+** mit aktiviertem OpenGL-Fallback (`rendering_device/fallback_to_opengl3`). Tests headless mit `--fixed-fps 60` (deterministisch).
- **Keine externen Plugins/Assets.** Eigener Mini-Testrunner statt GUT. Alle Modelle prozedural/modular aus Code (SurfaceTool/ArrayMesh, MultiMesh), Texturen per Shader, Audio per Python-Stdlib-Generator (deterministisch, eigene Werke).
- **Fahrzeuge:** eigener Arcade-Ansatz `RigidBody3D` + 4 Raycast-Federbeine (Feder/Dämpfer, Quergrip, Handbremse = reduzierter Hinterachsgrip, tiefer Schwerpunkt, Anti-Roll) – kontrollierbarer als `VehicleBody3D`.
- **Figur:** prozedurales Gliederpuppen-Rig (Hüfte/Torso/Kopf/Arme/Beine als Mesh-Knoten) mit code-basierten Animationen (Idle, Gehen, Rennen, Springen, Fallen) – für Spieler und Passanten (Farb-/Größenvarianten).
- **Welt:** eine gemeinsame Datenbasis `data/world/karlsruhe_layout.json` (Straßen-Polylinien, Typ, Spuren, Fußgängerzonen, Plätze, POIs, Spawnpunkte, Missionsziele). `CityGraphBuilder` planarisiert (Schnittpunkte → Knoten), extrahiert Häuserblöcke (Face-Walk) und insettet sie (`Geometry2D.offset_polygon`) → Blockrandbebauung mit Innenhöfen; daraus Straßen-, Verkehrs-, Gehweg-, Minikarten- und Missionsdaten. Deterministisch (fester Seed) – Landmarken/Hauptstraßen fix.
- **Save:** `user://` mit eigenem Verzeichnis `Faecherstadt` (Windows: `%APPDATA%\Faecherstadt\`), JSON mit Format-Version, atomisches Schreiben + `.bak`, Validierung/Migration; aktive Missionen starten nach Laden am Missionsanfang (kommuniziert).
- **Secrets:** Projekt benötigt keine Zugangsdaten → keine Einträge für Passbolt/doku.md/passwords.xlsx (wird so dokumentiert). Termix/Grafana: nicht betroffen.

## 4. Ablagestruktur (Nutzerentscheidung: Godot-Projekt im Repo-Root)

Dokumentierte Ausnahme von der Standardablage (`projects/active/…` entfällt, da das Repo selbst das Projekt ist). Die übrigen Top-Level-Ordner bleiben erhalten; Nicht-Spiel-Ordner bekommen `.gdignore`, damit Godot sie weder importiert noch exportiert.

```
/ (Repo-Root = Godot-Projekt)
├─ project.godot  export_presets.cfg  icon.svg  .gitignore  .gitattributes
├─ INHALTSVERZEICHNIS.md  README.md  CONTROLS.md  ASSET_LICENSES.md  TEST_REPORT.md  KNOWN_ISSUES.md
├─ src/{autoload,core,player,vehicles,world,traffic,npc,police,missions,ui,audio,save}/
├─ scenes/  data/{world,vehicles,missions}/  assets/{audio,shaders,icons}/
├─ tests/{unit,integration}/   tools/ (Audio-/Icon-Generator, Screenshot-Tour)
├─ scripts/{windows,linux}/    (start/build/test/setup)
├─ docs/ (PLAN, ARBEITSLOG, ARCHITEKTUR, KARTE_KARLSRUHE, ENTWICKLUNG)   config/ (Hinweise, keine Secrets)
├─ artifacts/{screenshots,test-logs}/  backups/  logs/  tmp/  sensitive/  _inventory/  _quarantine/   ← .gdignore, je README
└─ build/windows/Faecherstadt.exe (+ Faecherstadt.pck, ZIP)   ← .gitignore (Nutzerentscheidung)
```

Build-Auslieferung (Nutzerentscheidung): `build/` wird nicht committet; das ZIP wird in dieser Sitzung per Datei übergeben, Prüfsumme (SHA256) in `TEST_REPORT.md`.

## 5. Karte – künstlerische Interpretation (1 m = 1 Einheit, Ursprung = Schlossturm, Nord = −Z, Ost = +X, Verdichtung ≈ 0,55)

Per Websuche verifiziert: 32 Strahlen, 11,25°-Abstand, **9 Fächerstraßen W→O: Waldstraße, Herrenstraße, Ritterstraße, Lammstraße, Karl-Friedrich-Straße, Kreuzstraße, Adlerstraße, Kronenstraße, Waldhornstraße**; Zirkel = Halbkreis um den Schlossturm; Karl-Friedrich-Straße = Nord-Süd-Achse Zirkel → Marktplatz → Rondellplatz → Ettlinger Tor/Kriegsstraße; Marktplatz: Pyramide zwischen Rathaus (West, Portikus) und Ev. Stadtkirche (Ost, korinthischer Portikus), Kaiserstraße an der Nordseite, trifft dort rechtwinklig die K.-F.-Straße; Kaiserstraße gerade O-W ≈ 2 km: Durlacher Tor → Kronenplatz → Marktplatz → Europaplatz; Fußgängerzone Europaplatz–Kronenplatz.

Spielgeometrie (Entwurf): Schloss mit Turm (~45 m) und abgewinkelten Flügeln · Schlossplatz bis Zirkel r≈190 m · 9 Strahlen −45°…+45° bis Kaiserstraße z≈+330 · Marktplatz z≈+340…+420 · Rondellplatz z≈+520 · Kriegsstraße z≈+640 (Ettlinger Tor) · Europaplatz x≈−470, Kronenplatz x≈+250, Durlacher Tor x≈+560 · äußerer Rundkurs: Westachse x≈−560, Ostachse x≈+560, Nordbogen (Adenauerring-Interpretation) um den Schlossgarten, Süd = Kriegsstraße. Südlich der Kaiserstraße gehen ausgewählte Strahlen in N-S-Straßen über; Nebenstraßen erhalten fiktive Namen. Fläche ≈ 1,1 × 1,2 km (Nordhälfte Park). Straßenbahn nur als dekorative Haltestelle/Gleise an der Kriegsstraße und U-Strab-Zugänge als Kulisse – ohne Behauptung realer Linienführung. Quellen + Hinweis „kein digitaler Zwilling“ in `docs/KARTE_KARLSRUHE.md`.

## 6. Architektur (Module, Kern-Dateien)

- `src/autoload/`: `event_bus.gd` (Signale), `game_state.gd` (Geld, abgeschlossene Missionen, idempotente Belohnung), `settings.gd`, `save_manager.gd`, `audio_manager.gd`.
- `src/world/`: `city_layout.gd` (JSON-Laden/Validierung), `city_graph_builder.gd` (reine Logik, testbar), `road_mesh_builder.gd`, `block_builder.gd` (Gebäude aus Block-Polygonen, Fassaden-Shader mit Instanz-Uniforms, Satteldächer), `landmarks/{schloss,pyramide,rathaus,stadtkirche,tor,…}.gd`, `props_builder.gd` (MultiMesh: Bäume, Laternen, Bänke, Fahrräder, Litfaßsäulen, Poller, Baustelle, Haltestelle), `world_root.gd`, `environment_setup.gd` (warme Abendstimmung, Schatten, Glow, Nebel, Qualitätsstufen).
- `src/player/`: `player.gd` (CharacterBody3D, Gehen/Rennen/Springen, HP, Interaktion), `humanoid_rig.gd`, `player_camera.gd` (SpringArm3D, Kollisionsschutz, weicher Wechsel Fuß↔Fahrzeug).
- `src/vehicles/`: `vehicle_spec.gd` (Resource) + `data/vehicles/{kompakt,sport,transporter,polizei}.tres`, `vehicle.gd` (Arcade-Physik, Schaden, Licht, Hupe, Räder), `vehicle_model_builder.gd`, `vehicle_audio.gd`, `exit_validator.gd`, `vehicle_recovery.gd` (Bergung: nur langsam/umgekippt, Cooldown, nächster geprüfter Straßenpunkt ≤25 m, Fahndung bleibt).
- `src/traffic/`: `lane_graph.gd` (rechtsverkehr-Spuren aus Straßengraph), `traffic_lights.gd`, `ai_driver.gd` (Pure-Pursuit, Abstand, Ampel, Festfahr-Behandlung), `traffic_manager.gd` (Pool, Spawn außerhalb Frustum, Obergrenzen).
- `src/npc/`: `sidewalk_graph.gd`, `pedestrian.gd` (Gehen/Warten/Ausweichen/Flucht/Umgestoßen), `pedestrian_manager.gd` (Pool, Anim-LOD).
- `src/police/`: `wanted_logic.gd` (reine Logik 0–3, Sicht, zuletzt bekannte Position, Suchphase konfigurierbar), `police_manager.gd`, `police_driver.gd` (A* über Straßengraph, Sichtprüfung per Raycast gestaffelt), Festnahme-Logik.
- `src/missions/`: `mission_definition.gd`, `mission_runner.gd` (Schritt-Zustandsmaschine: talk, spawn_vehicle, enter_vehicle, go_to, interact, exit_vehicle, countdown, checkpoints, trigger_wanted, lose_wanted, Fehlschlagbedingungen), `mission_system.gd` (Start, Retry, Cleanup aller Missions-Entitäten, Belohnung einmalig) + `data/missions/m01_erste_schicht.json`, `m02_faecher_runde.json`, `m03_falsche_lieferung.json`.
- `src/ui/`: Hauptmenü, Pause, Einstellungen, HUD (Missionsziel, HP, Geld, Fahndungsanzeige mit 3 Blaulicht-Segmenten, Tacho + Zustand, Kontexthinweise nur bei möglicher Aktion), Minikarte + Vollkarte (gleiche Graphdaten, Landmarken benannt), Dialogbox, Missions-Ergebnis/Retry, F3-Dev-Overlay.
- Physik-Layer: 1 Welt-statisch, 2 Spieler, 3 Fahrzeuge, 4 NPC, 5 Trigger.

## 7. Missionen (eigene Figuren/Firmen, fiktiv)

1. **„Erste Schicht“** – Hanne Brettschneider, Kurierdienst „Fächerblitz“: Auftrag → Lieferwagen → Abholung (fiktive Bäckerei) → Ziel nahe Marktplatz (Ladezone) → aussteigen → Sendung abgeben (E) → 250 €.
2. **„Die Fächer-Runde“** – Toni „Turbo“ Kessler: Start am Rundkurs, Countdown, ~10 Kontrollpunkte auf befahrbaren Kanten in Reihenfolge, Zeitlimit, Fortschritt, Bestzeit gespeichert, Wiederholung; Belohnung nur beim ersten Abschluss.
3. **„Die falsche Lieferung“** – Ewald Riegel (Antiquitäten im Hinterhof): Fahrzeug abholen → Lagerbereich nahe Kriegsstraße → geskriptete Fahndung Stufe 2 → abschütteln → Werkstatt „Schrauberei Mäule“; Abschluss nur bei Fahndung 0 **und** keinem Polizeifahrzeug < 60 m.

Fehlschlag (Fahrzeug zerstört, Spieler ausgeschaltet/festgenommen, Zeit abgelaufen, Fahrzeug verlassen >150 m) → Ergebnisdialog mit „Erneut versuchen“; Cleanup verhindert wachsende Objektmengen; nach Abschluss freie Erkundung.

## 8. Umsetzung in Meilensteinen (je Commit + Push = Restore-Punkt)

0. **Absicherung & Doku-Start:** Restore-Punkt = Commit `75fe4ae` (Ausgangsstand); Original-`README.md` nach `backups/2026-09-23_README.orig.md`; Zielstruktur + `INHALTSVERZEICHNIS.md` + `docs/PLAN.md` (dieser Plan) + `docs/ARBEITSLOG.md`. Godot 4.7.2 Editor + Templates nach `~/godot` laden, SHA512 verifizieren; `apt install mesa-vulkan-drivers` (+ optional `wine64`) im Wegwerf-Container.
A. Projektgerüst, Autoloads, Testrunner, Spielfigur + Kamera + Teststraße → Import-/Parse-/Boot-Prüfung, Unit-Tests.
B. Fahrzeug (Kompakt) inkl. Ein-/Ausstieg, Ausstiegsprüfung, Schaden, Licht, Hupe, Räder, Bergung → Integrationstest Fahren/Mehrfachwechsel.
C. Straßengraph + Innenstadt + Landmarken (Schloss, Schlossplatz, Fächer, Marktplatz mit Pyramide/Rathaus/Stadtkirche, Kaiserstraße, Europaplatz, Kronenplatz, Durlacher Tor, Rondellplatz, Ettlinger Tor) + Props → Graph-Tests (Planarität, Zusammenhang, keine Gebäude auf Straßen), Screenshots.
D. Missionssystem + Mission 1 → automatischer Durchlauf (Autopilot fährt Spielerfahrzeug).
E. Verkehr, Passanten, Ampeln, Fahndung/Polizei, Festnahme/Ausschalten/Respawn → Tests Fahndungsabbau, Spawnregeln, Pool-Größen.
F. Mission 2 + 3, weitere Fahrzeugtypen (Sport, Transporter, Polizei) → automatische Durchläufe, Wiederholungs-/Doppelbelohnungstests.
G. Hauptmenü, Pause, Einstellungen, Speichern/Laden, Audio (generiert), Minikarte/Karte, grafische Überarbeitung → Save-Tests, Screenshot-Kontrolle.
H. Gesamt-Testlauf, Windows-Export `build/windows/Faecherstadt.exe` + `.pck` + ZIP, Exportprüfung, Doku-Abschluss.

## 9. Tests & Validierung

- **Statisch:** `godot --headless --import` (Import/Parse), Skript-Fehlerprüfung im Log (keine `SCRIPT ERROR`/`Parse Error`).
- **Unit (headless):** Graph-Builder, Spurgraph/A*, Ampelphasen, WantedLogic (Eskalation, Sichtverlust, Suchphase → 0), MissionRunner (Zustände, Fail/Retry), GameState (einmalige Belohnung), SaveCodec (Roundtrip, beschädigt, fehlende Felder, zukünftige Version, ungültige Position), Lenkkurve, Fahrzeug-Specs.
- **Integration (headless, `--fixed-fps 60`):** Weltaufbau fehlerfrei; alle Spawnpunkte mit Boden + frei (Physik-Queries); Spieler fällt nicht durch; Fahrzeug fährt 200 m ohne Überschlag; 5× Ein-/Aussteigen und Fahrzeugwechsel; M1/M2/M3 per Autopilot vollständig; Missionswiederholung ohne Objektwachstum; Festnahme → Respawn/Retry; Speichern → Szene neu laden → Zustand gleich.
- **Grafisch (Xvfb + lavapipe/GL):** Screenshot-Tour (Spieler, Kamera, Fahrzeug, Landmarken, HUD, Karte, Verfolgung) nach `artifacts/screenshots/`, visuell geprüft; Performance-Werte aus Software-Rendering werden **nicht** als Spielperformance ausgegeben.
- **Export:** Log ohne Fehler, PE-Header (MZ/PE, Maschine x64 0x8664), `.pck`-Header `GDPC`, Boot-Test des exportierten `.pck` mit Linux-Editor (`--main-pack`), optional Wine-Rauchtest (als „Wine, nicht Windows“ gekennzeichnet).
- `TEST_REPORT.md` trennt strikt: durchgeführt / nicht durchgeführt / blockiert.

## 10. Lieferumfang

Godot-Projekt, Export-Profil `export_presets.cfg` (Windows Desktop x86_64), Skripte `scripts/windows/{start_game.bat,build_windows.ps1,build_windows.bat,run_tests.bat}` und `scripts/linux/{setup_godot.sh,build_windows.sh,run_tests.sh,screenshot_tour.sh}`, README.md (DE), CONTROLS.md, ASSET_LICENSES.md, TEST_REPORT.md, KNOWN_ISSUES.md, docs/ENTWICKLUNG.md (nächste Schritte), docs/KARTE_KARLSRUHE.md, docs/ARCHITEKTUR.md.

## 11. Risiken & Gegenmaßnahmen

| Risiko | Maßnahme |
|---|---|
| Template-Download (≈1 GB) bricht ab | Resume (`curl -C -`), SHA512; sonst Export blockiert dokumentieren, Build-Skripte trotzdem liefern |
| Fahrgefühl nicht headless beurteilbar | konfigurierbare Specs, messbare Fahrtests, Screenshots; als „subjektiv ungetestet“ markieren |
| Software-Rendering sehr langsam | Screenshots mit reduzierter Auflösung; GL-Fallback |
| KI-Fahrzeuge verkeilen | Festfahr-Behandlung, Respawn außer Sicht, Obergrenzen |
| Windows-Start nicht verifizierbar | klar als ungetestet dokumentieren; Wine nur als Indiz |
| Große Binärdateien im Git | `build/` in `.gitignore`; ZIP per Datei-Übergabe (Nutzerentscheidung) |
| Godot importiert Doku-/Backup-Ordner mit | `.gdignore` in Nicht-Spiel-Ordnern, Export-Ausschlussfilter für `tests/`, `tools/`, `docs/` |

## 12. Pflicht-Abschluss

Abschlussbericht (Ausgangslage, Vorgehen, Änderungen, Restore-Punkte, Tests, Risiken, Empfehlungen) mit Einteilung **implementiert / getestet / ungetestet / blockiert** und Konfidenzwert.
