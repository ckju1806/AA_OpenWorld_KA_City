# Architektur

Godot 4.7.2, typisiertes GDScript, Jolt Physics, Forward+ (Fallback OpenGL 3). Keine Plugins. Nahezu alle Inhalte werden
zur Laufzeit aus Daten und Code erzeugt; die Szenen `scenes/main_menu.tscn` und `scenes/game.tscn` sind nur Einstiegspunkte.

## Ablauf

```
main_menu.tscn (MainMenu) ──Neues Spiel / Fortsetzen──▶ game.tscn (Game)
                                                         ├─ CityWorld.build()  ← data/world/karlsruhe_layout.json
                                                         │    ├─ CityGraphBuilder → CityGraph (Knoten, Kanten, Blöcke, A*)
                                                         │    ├─ GroundBuilder, BuildingBuilder, LandmarkBuilder, PropsBuilder
                                                         │    └─ EnvironmentSetup (Licht, Nebel, Laternen-Lichtpool)
                                                         ├─ Player + PlayerCamera (SpringArm, Kollisionsschutz)
                                                         ├─ Fahrzeuge (Vehicle, Specs aus data/vehicles/vehicles.json)
                                                         ├─ TrafficLights, TrafficManager, PedestrianManager, PoliceManager
                                                         ├─ MissionSystem ← data/missions/*.json
                                                         └─ UI: Hud, MapView (Minikarte), MapOverlay (M), PauseMenu (Esc), DevOverlay (F3)
```

## Autoloads (`src/autoload/`)
| Name | Aufgabe |
|---|---|
| `EventBus` | Signale zwischen Systemen (Spieler, Fahrzeuge, Missionen, Fahndung, Meldungen) |
| `Settings` | Einstellungen, `user://settings.cfg`, qualitätsabhängige Werte |
| `GameState` | Geld, erledigte Aufträge, Bestzeiten, Versuche, Spielzeit; `complete_mission` ist idempotent |
| `SaveManager` | atomisches Schreiben (tmp → umbenennen), Sicherungskopie `.bak`, Laden mit Rückfall |
| `AudioManager` | Busse Musik/Effekte/Umgebung, Stream-Cache, 2D/3D-Stimmen-Pools |
| `App` | Szenenwechsel, Maus, Übergabe geladener Daten, Pause bei Fokusverlust |

## Module (`src/`)
| Ordner | Inhalt |
|---|---|
| `core/` | Physik-Ebenen, deterministischer Zufall, MeshKit (prozedurale Meshes), Polygon-Werkzeuge, Materialcache, Eingabebelegung |
| `world/` | Straßengraph und Stadtaufbau (s. o.), Testgelände |
| `player/` | Spielfigur, prozedurales Figuren-Rig (auch für Passanten/Auftraggeber), Kamera, Interaktionsregister |
| `vehicles/` | Arcade-Fahrzeug (RigidBody3D + 4 Raycast-Federbeine), Specs, Modellbau, Autopilot (Wegpunktfolger) |
| `traffic/` | Ampeln (2 Phasengruppen), LaneDriver (Spurfolge, Ampel, Vorfahrt, Hindernisse, Festfahren), Verkehrsmanager |
| `npc/` | Gehwegnetz, Passanten (Zustandsmaschine, Animations-LOD), Passantenmanager (Zeugen) |
| `police/` | WantedLogic (reine Logik), PoliceDriver, PoliceManager (Sicht, Spawn außer Sicht, Festnahme) |
| `missions/` | MissionDefinition (JSON + Validierung), MissionSystem (Schritt-Zustandsmaschine), Auftraggeber, Marker |
| `save/` | SaveCodec (Format, Version, Migration, Validierung) |
| `ui/` | UiStyle, Hud, MapView/MapOverlay, PauseMenu, SettingsPanel, DevOverlay, MainMenu, MenuBackground |
| `game/` | Game: verbindet alles, Respawn, Speichern/Laden, Schnittstellen für Missionen |
| `debug/` | Screenshot-Tour |

## Gemeinsame Datenbasis
`data/world/karlsruhe_layout.json` ist die **einzige** Quelle für Straßen, Plätze, Höfe, Landmarken, Kartenbeschriftungen,
POIs (Auftraggeber, Missionsziele, Respawn), Parkplätze und Baustellen. Daraus entstehen Geometrie, Verkehrs-/Polizei-Routen
(A* je Modus: drive, traffic, police), Gehwegnetz, Minikarte/Karte und Missionsziele. Missionen referenzieren POIs per ID
und werden beim Start gegen den Graphen validiert (POIs vorhanden, Kontrollpunkte auf Fahrbahn).

## Physik-Ebenen (`src/core/layers.gd`)
| Bit | Name | Kollidiert mit |
|---|---|---|
| 1 | WORLD (statische Welt) | – |
| 2 | PLAYER | Spieler-Maske: WORLD, VEHICLE, NPC |
| 4 | VEHICLE | Fahrzeug-Maske: WORLD, VEHICLE, NPC (Spieler wird über seine Trefferzone erkannt) |
| 8 | NPC (Passanten, Auftraggeber) | – |
| 16 | TRIGGER | – |
Kamera-Kollision: WORLD + VEHICLE.

## Fahndung
Nur **beobachtete** Taten (Zeugen im Umkreis oder Sichtlinie einer Streife) erhöhen die Stufe (0–3). Die Polizei kennt nur die
zuletzt bekannte Position; nach Sichtverlust (2,5 s) beginnt eine Suchphase (18/26/34 s je Stufe), danach sinkt die Stufe.
Einheiten erscheinen 110–240 m entfernt außerhalb der Kamerasicht. Festnahme: Streife < 7 m, Spieler langsam, 2,8 s.

## Speicherformat (v1)
```json
{ "format": "faecherstadt-save", "version": 1, "game_version": "0.1.0", "saved_at": "…",
  "state":  { "money": 0, "completed_missions": [], "best_times": {}, "mission_attempts": {}, "play_time": 0 },
  "player": { "position": [x, y, z], "yaw": 0.0, "health": 100.0, "mission": "" } }
```
Neuere Versionen werden abgelehnt, ältere über `SaveCodec.migrate` angehoben; ungültige Positionen fallen auf den Startpunkt.

## Tests
Eigener Mini-Runner (`tests/test_runner.gd`): Klassen mit `test_*`-Methoden, `before_each`/`after_each`, Awaits.
Ein `Logger` zählt Engine-/Skriptfehler während jedes Tests und lässt den Test fehlschlagen. Integrationstests starten die
echte Spielszene headless mit `--fixed-fps 60` (deterministisch) und fahren Fahrzeuge per Autopilot über das Straßennetz.
