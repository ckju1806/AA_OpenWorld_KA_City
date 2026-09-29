# Architektur (v0.2)

Godot 4.7.2, typisiertes GDScript, Jolt Physics, Forward+ (Fallback OpenGL 3). Keine Plugins, keine kostenpflichtigen Assets.
Nahezu alle Inhalte entstehen zur Laufzeit aus Daten und Code; `scenes/main_menu.tscn` und `scenes/game.tscn` sind nur
Einstiegspunkte.

## Ablauf

```
main_menu.tscn (MainMenu) ──Neues Spiel / Fortsetzen──▶ game.tscn (Game)
   ├─ CityWorld  ← data/world/ka/world.json.gz (Graph, POIs, Landmarken, Signale, ÖPNV, Sektorindex)
   │    ├─ CityGraph (Knoten/Kanten mit Breite/Einbahn/Brücke, Rasterindex, A* je Modus, Spurpfade)
   │    ├─ WorldStreamer → SectorBuilder (256-m-Sektoren: Boden, Straßen, Gebäude, Flächen, Props, Gleise)
   │    │                  + LOD-Kacheln (1 024 m, Fernsilhouetten) · Aufbau in Zeitscheiben
   │    ├─ LandmarkBuilder / LandmarksExtra (Schloss, Pyramide, Hbf, Zoo, Stadion, Gewächshäuser, Kräne, Turmberg …)
   │    └─ EnvironmentSetup (Sonne/Mond nach WorldClock, Himmel, Nebel, Regen, Laternen-Lichtpool, Tunnel-Abdunklung)
   ├─ Player + PlayerCamera (SpringArm, Kollisionsschutz, Rückblick, Kamerawackeln, Mitfahrkamera)
   ├─ Fahrzeuge (Vehicle, Specs aus data/vehicles/vehicles.json), ParkedCarManager (sektorweise)
   ├─ TrafficLights (Ampeln aus Daten), TrafficManager (LaneDriver), PedestrianManager, AnimalManager
   ├─ PoliceManager (Streife, Fahndung, Einsätze, Sperren), EventDirector (Ereignisse, fiktive Gruppen)
   ├─ TransitSystem (Stadtbahn/Bus, U-Strab-Tunnel, Haltestellen, Mitfahren)
   ├─ MissionSystem ← data/missions/*.json (+ MissionStepsExt), JobSystem (wiederholbare Jobs)
   └─ UI: Hud, MapView/MapOverlay, MissionList (J), CheatConsole (^), PauseMenu/SettingsPanel, DevOverlay (F3)
```

## Autoloads (`src/autoload/`)
| Name | Aufgabe |
|---|---|
| `EventBus` | Signale zwischen Systemen (Spieler, Fahrzeuge, Missionen, Fahndung, Meldungen, Zurufe) |
| `Settings` | Einstellungen v2 (Kategorien A–E, Voreinstellungen, Tastenbelegung mit Konfliktprüfung), `user://settings.cfg`, Migration v1→v2 |
| `GameState` | Geld, erledigte Aufträge, Bestzeiten, Tageszeit/Tag/Wetter, Flags, Statistik, Ruf je Gruppe |
| `WorldClock` | Tageszeit, Zeitraffer, Wetter (klar/bewölkt/Regen/Nebel) mit Übergängen, Nässe, Sonnenstand |
| `CheatManager` | Registry eigener Codes (erweiterbar), Tipp-Erkennung, Schalt-Cheats, Zurücksetzen |
| `SaveManager` | atomisches Schreiben, Sicherungskopie `.bak`, Laden mit Rückfall |
| `AudioManager` | Busse Musik/Effekte/Umgebung/UI, Stream-Cache, 2D/3D-Stimmen |
| `App` | Szenenwechsel, Maus, Farbfehlsicht-Filter, Übergabe geladener Daten |

## Module (`src/`)
| Ordner | Inhalt |
|---|---|
| `core/` | Physik-Ebenen, deterministischer Zufall, MeshKit, Polygon-Werkzeuge, Materialcache, Eingabebelegung |
| `world/` | CityWorld, CityGraph, WorldData, Materialien/Shader-Parameter, Umgebung, Props, `streaming/`, `landmarks/` |
| `player/` | Spielfigur (inkl. Mitfahrt im ÖPNV), Figuren-Rig, Kamera, Interaktionsregister |
| `vehicles/` | Arcade-Fahrzeug (RigidBody3D + Raycast-Federbeine), Specs, Modellbau, Autopilot (optional mit Hindernisbremsung), geparkte Autos |
| `traffic/` | Ampeln (Phasen je Kreuzung), LaneDriver (Spurfolge, Einbahn, Ampel, Vorfahrt, Hindernisse, Umfahren), Verkehrsmanager |
| `npc/` | Gehwegnetz, Passanten (Zustandsmaschine, Einsteigen in Bahn/Bus), Passantenmanager (Zeugen) |
| `animals/` | Artdaten (`data/animals/species.json`), AnimalAgent (Idle/Wandern/Flucht/Fliegen/Folgen), Modelle, Manager (Zoo, Parks, Stadt) |
| `events/` | EventDirector (Budget, Abkühlzeit, Zonen-Risiko, Schalter), Ereignisse (Rangelei, Diebstahl, Rennen, Kundgebung, Kontrolle), EventActor |
| `police/` | WantedLogic, PoliceDriver, PoliceManager (Sicht, Spawn außer Sicht, Festnahme, Einsätze, Straßensperren) |
| `transit/` | TransitSystem (virtuelle Fahrzeuge, Pendelbetrieb, Haltestellen, Tunnel/Stationen/Portale), Modelle, Einstiegspunkt |
| `missions/` | MissionDefinition (Validierung), MissionSystem, MissionStepsExt (neue Schritttypen), JobSystem, Auftraggeber, Marker |
| `save/` | SaveCodec (Format, Version, Migration, Validierung) |
| `ui/` | Hud, Karten, Auftragsliste, Cheat-Konsole, Pausenmenü, Optionsmenü (Tabs, Tastenerfassung), Entwickleranzeige |
| `game/` | Game: verbindet alles, Respawn, Speichern/Laden, Teleport, Schnittstellen für Missionen/Cheats |
| `debug/` | Screenshot-Tour (Filter `--tour-only=`) |

## Welt-Pipeline (`tools/worldgen/`, Python)
```
Quelle: ka_authored.py (1:1-Näherung)  oder  OSM (fetch_osm.py → ~/osm_cache → source_osm.py)
   → network.py (Graph: Vereinfachung, Teilung ≤ 60 m, Kontakte, Inseln)   → blocks.py (Blöcke, Flächen, Gebäude-Füllung)
   → transit.py (Linien, Haltestellen, Tunnelbereiche)                      → export.py (Sektoren, LOD, Props, world.json.gz, map.webp)
   → validate_world.py (Gebäude/Autos nicht in Fahrspuren, Landmarken frei)
Aufruf: python3 tools/worldgen/build_world.py [--source osm|authored] [--cache ~/osm_cache] [--out data/world/ka]
```
Koordinaten: Ursprung Schlossturm (49.013480 N, 8.404440 E), x = Ost, z = Süd, 1 Einheit = 1 m; in Dateien als
Ganzzahlen in Dezimetern (q = 10), gzip-JSON. Kanten-Flags: Bit 0 Tunnel, Bit 1 Brücke, Bit 2 Einbahn, Bits 8–15 Breite (0,5 m).
Budget: Weltdaten ≤ 40 MB, Einzeldatei ≤ 5 MB (`tools/check_repo_budget.py`).

## ÖPNV
Linien sind Polylinien mit Haltestellen-Bogenlängen und Tunnelbereichen. Alle Fahrzeuge existieren virtuell (Position `s`
auf der Linie, Tempo, Haltezeit); nur in Spielernähe (< 480 m) werden Wagenteile als `AnimatableBody3D` erzeugt, die der Linie
folgen und vor Hindernissen bremsen. An der Endhaltestelle wechselt das Fahrzeug auf die Gegenrichtung. Tunnel: Röhre,
U-Stationen (Bahnsteige, Schilder, Leuchten) und Rampenbauwerke werden einmal gebaut; die Röhre hat eine reine
Kamera-Kollision (Layer 32), damit die Kamera beim Mitfahren im Tunnel bleibt.

## Physik-Ebenen (`src/core/layers.gd`)
| Bit | Name | Hinweis |
|---|---|---|
| 1 | WORLD (statische Welt) | Boden-Raycasts nutzen nur diese Ebene |
| 2 | PLAYER | Spieler-Maske: WORLD, VEHICLE, NPC |
| 4 | VEHICLE | Fahrzeuge inkl. ÖPNV-Wagen; Maske WORLD, VEHICLE, NPC |
| 8 | NPC | Passanten, Auftraggeber, Tiere, Ereignis-Beteiligte (nur Erkennung) |
| 16 | TRIGGER | Missions-/Interaktionsbereiche |
| 32 | CAMERA_ONLY | nur Kamera (Tunnelröhre) |
Kamera-Kollision: WORLD + VEHICLE + CAMERA_ONLY.

## Fahndung und Polizei
Nur **beobachtete** Taten (Zeugen oder Sichtlinie einer Streife) erhöhen die Stufe. Die Polizei kennt die zuletzt bekannte
Position; nach Sichtverlust beginnt eine Suchphase, danach sinkt die Stufe. Ereignisse können Einsätze auslösen;
ab Stufe 3 Straßensperren. Schwierigkeit über Einstellungen.

## Speicherformat (v1, erweitert)
```json
{ "format": "faecherstadt-save", "version": 1, "game_version": "0.2.0", "saved_at": "…",
  "state":  { "money": 0, "completed_missions": [], "best_times": {}, "mission_attempts": {}, "play_time": 0,
              "time_of_day": 9.0, "day": 1, "weather": "klar", "flags": {}, "stats": {}, "reputation": {} },
  "player": { "position": [x, y, z], "yaw": 0.0, "health": 100.0, "mission": "" } }
```
Neue Felder sind optional (ältere Stände laden mit Standardwerten). Positionen außerhalb ±12 km werden verworfen.

## Tests
Eigener Runner (`tests/test_runner.gd`, Filter `--filter=<datei>[::<test_präfix>]`): Klassen mit `test_*`-Methoden,
`before_each`/`after_each`, Awaits. Ein Logger zählt Engine-/Skriptfehler während jedes Tests und lässt ihn fehlschlagen.
Integrationstests starten die echte Spielszene headless mit `--fixed-fps 60`; Fahrten per Autopilot über das Straßennetz,
Kampagnenaufträge per generischem Test-Löser. Ohne „Umgebungsleben“ fahren weder Verkehr noch ÖPNV (reproduzierbar).
