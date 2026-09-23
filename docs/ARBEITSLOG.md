# Arbeitslog – Fächer-City: Asphalt & Schatten

Fortlaufender Planstand und Umsetzungsnachweis. Jeder Meilenstein endet mit einem Commit (= Restore-Punkt).

## Restore-Punkte

| Datum | Commit | Stand |
|---|---|---|
| 2026-09-23 | `75fe4ae` | Ausgangsstand (nur LICENSE + README) |

## 2026-09-23 – Meilenstein 0: Absicherung, Struktur, Toolchain

- **Ziel:** Arbeitsumgebung, Ablagestruktur und Dokumentation vor der Umsetzung herstellen.
- **Änderungsklasse:** groß (neues Projekt, neue Toolchain) → Restore-Punkt = Commit `75fe4ae` + Dateibackup `backups/2026-09-23_README.orig.md`.
- **Annahmen:** Container ist ephemer; Systempakete (mesa-vulkan-drivers) betreffen nur den Container.
- **Durchgeführt:**
  - Godot 4.7.2-stable Editor + Export-Templates geladen, SHA512 gegen offizielle Liste: **OK**.
  - Nur Windows-x64-Templates installiert (Platz sparen).
  - `mesa-vulkan-drivers` (lavapipe) installiert → Vulkan-Softwarerendering unter Xvfb für Screenshots.
  - Top-Level-Struktur mit `.gdignore` in Nicht-Spiel-Ordnern angelegt; Ordner-READMEs.
- **Abweichung Zielstruktur:** Godot-Projekt im Repo-Root statt `projects/active/…` (Nutzerentscheidung vom 2026-09-23).
- **Zugangsdaten:** keine benötigt → keine Passbolt-/passwords.xlsx-Einträge.

## 2026-09-23 – Meilenstein A: Projektgerüst, Spielfigur, Kamera, Testrunner

- **Ziel:** startfähiges Godot-4.7.2-Projekt mit Spielfigur, Kamera, Testgelände und automatisierten Tests.
- **Änderungsklasse:** mittel (nur neue Dateien) → Restore-Punkt: Commit von Meilenstein 0 (`1be5ddd`).
- **Umgesetzt:** `project.godot` (Jolt, Forward+ mit GL-Fallback, eigener user-Ordner `Faecherstadt`), Autoloads
  (EventBus, Settings inkl. Tastenbelegung, GameState, SaveManager + SaveCodec, AudioManager, App),
  Kernhilfen (MeshKit, PolyUtil, MatLib, DetRng, Layers), prozedurale Figur (HumanoidRig), Player (Stufensteigen,
  Sprung, Sturzschaden, Lebenspunkte, Regeneration, Interaktions-/Fahrzeug-Hinweise), PlayerCamera (SpringArm,
  weicher Moduswechsel), Testgelände, Mini-Testrunner, Screenshot-Tour, eigenes Icon (SVG/ICO, generiert).
- **Prüfung:** `scripts/linux/run_tests.sh` → 23/23 Tests bestanden (Unit: GameState, SaveCodec, PolyUtil;
  Integration: Bodenhaftung, Gehen/Sprinten, Bordstein, Sprung, Schaden, Kamera-Kollision).
  Screenshot-Tour (Xvfb, lavapipe) visuell geprüft → `artifacts/screenshots/A/`.
- **Gefundene und behobene Fehler:** falsch dimensionierter Bordstein-Test (Laufzeit zu kurz), Kamera-Wand-Test
  prüfte falsche Seite, Jackengeometrie wirkte wie Rucksack.
- **Erkenntnis:** Nach neuen `class_name`-Dateien ist ein `--import` nötig (Skripte machen das automatisch).

## 2026-09-23 – Meilenstein B: Fahrzeuge, Ein-/Ausstieg, Audio

- **Ziel:** vollständig fahrbares Fahrzeug inkl. Ein-/Ausstieg, danach weitere Typen.
- **Änderungsklasse:** mittel (neue Dateien, keine bestehende Logik ersetzt) → Restore-Punkt: Commit `b619ed7`.
- **Umgesetzt:** `VehicleSpec` + `data/vehicles/vehicles.json` (Kompakt, Limousine, Sport, Transporter, Polizei –
  eigene fiktive Modelle), `VehicleModelBuilder` (Seitenprofil-Extrusion, gecachte Geometrie, Lack per Override),
  `Vehicle` (RigidBody3D mit 4 Raycast-Federbeinen, Quergrip, Handbremse, geschwindigkeitsabhängiger Lenkung,
  Aufrichthilfe, Schaden mit Rauch/Totalschaden, Licht/Bremslicht/Blaulicht, Hupe, Ausstiegsprüfung mit
  Boden-, Wand- und Platztest, Bergung mit Abklingzeit), `Autopilot` (Pure Pursuit).
  Audio-Generator `tools/generate_audio.py` (20 eigene Synthese-Klänge, deterministisch).
- **Prüfung:** 41/41 Tests (u. a. Beschleunigen/Bremsen/Rückwärts, Rechtskurve, Handbremse, 2× Wechsel zwischen
  drei Fahrzeugen, Ausstieg bei Fahrt verweigert, Ausstieg bei Einkesselung verweigert, Crash-Schaden ohne
  Durchdringen der Wand, Bergung nach Überschlag, Autopilot mit Wende). Screenshots: `artifacts/screenshots/B/`.
- **Behobene Testfehler:** Startpositionen im Test (Auffahren auf geparktes Fahrzeug, fehlender Anlauf).
- **Offen:** Fahrgefühl subjektiv nicht beurteilbar (nur messbare Kriterien getestet).

## 2026-09-23 – Meilenstein C: Innenstadt, Landmarken, Ausstattung

- **Ziel:** zusammenhängende, wiedererkennbare Innenstadt mit Landmarken als gemeinsame Datenbasis.
- **Änderungsklasse:** groß (viele neue Dateien, zentrale Datenstruktur) → Restore-Punkt: Commit `ce29572`.
- **Umgesetzt:** `data/world/karlsruhe_layout.json` (27 Straßen, Plätze, Höfe, Landmarken, POIs, Parkplätze),
  `CityGraph`/`CityGraphBuilder` (Planarisierung, Knoten-Snapping, Face-Extraktion, A*), `GroundBuilder`
  (Asphalt, Blockplatten mit Bordstein, erhöhte Fußgängerzonen, Markierungen, Zebrastreifen, Gleise),
  `BuildingBuilder` (1 429 Parzellen, Blockrand mit Innenhöfen, Hofeinfahrten per Korridor, Baulücken, Baustelle),
  `LandmarkBuilder` (Schloss, Pyramide, Rathaus, Stadtkirche, Säule, Brunnen, U-Strab, Torbogen, Pavillon,
  Haltestelle), `PropsBuilder` (557 Laternen, Bäume, Bänke, Fahrräder, Poller, Litfaßsäulen, Kioske, Schilder),
  `EnvironmentSetup` (Abendsonne, Nebel, Glow, Laternen-Lichtpool), eigene Shader (Fassade, Dach, Pflaster, Asphalt, Rasen).
- **Recherche:** Lagebeziehungen per Websuche, dokumentiert in `docs/KARTE_KARLSRUHE.md`.
- **Prüfung:** 54/54 Tests (u. a. keine Kanten-Kreuzung ohne Knoten, zusammenhängendes Netz, keine Sackgassen,
  alle POIs frei/erreichbar, 4 440 Fahrspurproben ohne Hindernis, geparkte Fahrzeuge stabil, Landmarken vorhanden).
  Aufbauzeit der Stadt headless ca. 1,2 s. Screenshots: `artifacts/screenshots/C/`.
- **Behobene Befunde:** Möblierung auf der Schloss-Sichtachse, violetter Farbstich, zu helle Schaufenster,
  fensterlose freiliegende Brandwände, Hofeinfahrt traf falsche Parzelle (Auftraggeber stand auf Dach).

## 2026-09-23 – Meilenstein D: Missionssystem + Mission 1 „Erste Schicht“

- **Ziel:** datengetriebenes Missionssystem und erste vollständig abschließbare Mission.
- **Änderungsklasse:** mittel (neue Module, kleine Erweiterungen an Game/CityGraph) → Restore-Punkt: `2c1f623`.
- **Umgesetzt:** `MissionDefinition` (JSON + Validierung gegen Kartendaten), `MissionSystem` (Schritte talk,
  spawn_vehicle, enter_vehicle, goto, wait_zone, exit_vehicle, interact, countdown, checkpoints, trigger_wanted,
  lose_wanted; Fehlschlag bei Tod/Festnahme/Fahrzeugverlust/Zurücklassen/Zeitablauf; Wiederholung ohne Einleitungsdialog;
  Aufräumen; einmalige Belohnung), `MissionGiver`, `MissionMarker` (eigenes Design), `MissionInteractPoint`,
  HUD (`Hud`, `UiStyle`), Spieler-Tod mit Wiederbelebung an der Klinik (Gebühr), `CityGraph.lane_path` (Rechtsverkehr).
  Mission 1 in `data/missions/m01_erste_schicht.json`.
- **Prüfung:** automatischer Durchlauf (Auftrag per E, Lieferwagen, Fahrt per Autopilot über das Straßennetz zur Bäckerei,
  Haltezone, Fahrt zur Kanzlei, Aussteigen, zu Fuß zur Tür, Abgabe) → Mission erfüllt, +250 € genau einmal;
  3× Fehlschlag + Wiederholung ohne wachsende Fahrzeugzahl. Screenshots `artifacts/screenshots/D/`.
- **Korrektur nach Commit `f92eacd`:** Der Commit enthielt einen fehlschlagenden Test (Befehlskette prüfte den
  Testausgang nicht). Ursache: Auftraggeber-Kollision auf Welt-Ebene verfälschte die Bodenhöhe am POI.
  Behoben durch NPC-Ebene für Figuren (Spieler/Fahrzeuge kollidieren weiter). Seitdem wird vor jedem Commit
  der Exit-Code der Testsuite explizit geprüft. Ergebnis: 57/57 Tests grün.

## 2026-09-23 – Meilenstein E: Verkehr, Ampeln, Passanten, Polizei/Fahndung

- **Ziel:** belebte Stadt (Verkehr, Passanten) und nachvollziehbares Fahndungssystem Stufe 0–3 mit Festnahme/Respawn.
- **Änderungsklasse:** groß (drei neue Module, Änderungen an Physik-Ebenen, Spieler, Fahrzeug, HUD) → Restore-Punkt: `ece86ef`.
- **Umgesetzt:**
  - `src/traffic/`: `TrafficLights` (zwei Phasengruppen, fester Zyklus mit Versatz je Kreuzung, Masten neben der Fahrbahn,
    Haltelinien), `LaneDriver` (Pure Pursuit mit vorwärtslaufendem Segment-Cursor, Kurven-/Ampel-/Vorfahrtslogik,
    Hindernis-Box-Abfrage, Festfahr-Behandlung mit Rückwärtsmanöver), `TrafficDriver`, `TrafficManager`
    (Obergrenze aus Einstellungen, Spawn 75–230 m außer Sicht, Despawn > 270 m bzw. festgefahren und unsichtbar).
  - `src/npc/`: `SidewalkNetwork`, `Pedestrian` (Gehen/Warten/Ausweichen/Flucht/Umgestoßen, Wand-Raycast, Animations-LOD),
    `PedestrianManager` (Pool, Zeugenzählung, Meldung „Fußgänger angefahren“).
  - `src/police/`: `WantedLogic` (reine Logik: nur beobachtete Taten, zuletzt bekannte Position, Sichtverlust-Verzögerung,
    Suchdauer je Stufe), `PoliceDriver` (A*-Neuplanung, direkte Verfolgung bei Sicht, Sirene), `PoliceManager`
    (Einheiten je Stufe, Spawn außer Sicht, Festnahme bei langsamem Spieler < 7 m für 2,8 s, Streife bei Stufe 0).
  - Game: Festnahme → Revier (150 €), Tod → Klinik (100 €), Missionsfehlschlag; HUD-Fahndungsanzeige (3 Segmente,
    Zustandstext, Festnahmebalken); Treffer-Zone des Spielers (Umfahren durch Fahrzeuge).
- **Behobene Befunde:** Lookahead suchte nur die ersten 8 Segmente (Ziel hinter dem Fahrzeug → Abkommen von der Straße)
  → Segment-Cursor + Bézier-Abbiegespuren; Spawn-Anschub zählte als Aufprall (jedes Verkehrsauto 144 Schaden)
  → Aufprall-Schonzeit; Ampelmast auf Fahrspur an spitzwinkliger Kreuzung → Rücksetzung per Fahrbahnprüfung;
  Hindernisabstand zur Objektmitte gemessen → Front-zu-Heck-Abstand.
- **Prüfung:** 75/75 Tests grün, Exit-Code 0 (u. a. Verkehr erreicht Sollzahl, kein Überschlag, ≥ 90 % auf Fahrbahnen,
  Halt an roter Ampel, Abstand zu Hindernis ohne Auffahrunfall, begrenzte Objektzahl nach Teleports, Passanten nicht in Wänden,
  Ausweichen/Anfahren gemeldet, beobachteter vs. unbeobachteter Diebstahl, Spawn außer Sicht, Suche an zuletzt bekannter
  Position, Abbau auf 0, Festnahme am Revier mit Gebühr und Missionsfehlschlag, Rammen eines Streifenwagens).
  Screenshots `artifacts/screenshots/E/` (u. a. 14 Kreuzung mit Ampel, 15 Passanten Kaiserstraße, 16 Verfolgung) visuell geprüft.

## 2026-09-23 – Meilenstein F: Mission 2 „Die Fächer-Runde“, Mission 3 „Die falsche Lieferung“, Fahrzeugtypen

- **Ziel:** zwei weitere vollständig abschließbare Missionen; alle Fahrzeugtypen fahrdynamisch geprüft.
- **Änderungsklasse:** mittel (neue Datendateien und Tests, zwei kleine Code-Korrekturen) → Restore-Punkt: `985f0e0`.
- **Umgesetzt:**
  - `data/missions/m02_faecher_runde.json`: Toni „Turbo“ Kessler (fiktiv), Sportwagen „Fächer GT“, Countdown,
    12 Kontrollpunkte (Ostring → Schlossallee Ost → Zirkel → Adlerstraße → Kanzleistraße → Herrenstraße → Kriegsstraße →
    Ostring → Durlacher Tor), Zeitlimit 3:30, Bestzeit (`faecher_runde`), wiederholbar, 400 € nur beim ersten Abschluss.
  - `data/missions/m03_falsche_lieferung.json`: Ewald Riegel (fiktiv), dunkle Limousine, Abholung Lagerhof Westring,
    geskriptete Fahndung Stufe 2, Abschütteln, Abgabe Schrauberei Mäule nur bei Fahndung 0 und ohne Streifenwagen < 60 m, 800 €.
    Handlung: Verwechslung einer Kiste – keine realen Firmen, niemand Reales wird als kriminell dargestellt.
  - `MissionDefinition.validate`: Kontrollpunkte müssen auf befahrbarer Fahrbahn liegen.
  - Testhilfen `route_through` / `follow_until` (Route über das Straßennetz durch Punktfolgen).
  - Screenshot-Stationen `m2_zeitfahren_kontrollpunkt`, `m3_auftraggeber_ewald`.
- **Behobene Befunde:**
  - Spielerposition blieb beim Fahren am Einstiegsort stehen → „Polizei in der Nähe“-Prüfung und andere Abstandsprüfungen
    nutzten eine falsche Position. Jetzt wird die Position mit dem Fahrzeug mitgeführt (`Player._physics_process`).
  - Auftraggeber Ewald stand 0,8 m neben der Ausfahrt der Limousine → POI auf [459, 255] verschoben.
- **Prüfung:** 83/83 Tests grün, Exit-Code 0. Neu u. a.: M2 gesperrt ohne M1; komplette Runde per Autopilot (142,6 s simuliert),
  Bestzeit gespeichert, zweite Runde ohne erneute Belohnung und mit besserer Bestzeit; Zeitlimit-Fehlschlag + 2× Wiederholung ohne
  Objektwachstum; M3 komplett (Fahrt zum Lager, Fahndung 2, Polizei rückt an, Abschütteln durch Sichtverlust und Ablauf der Suche,
  Fahrt zur Werkstatt, 800 € genau einmal); kein Abschluss mit Fahndung bzw. mit Streifenwagen in der Nähe, Abschluss danach;
  Festnahme → Fehlschlag → Wiederholung; alle 5 Fahrzeugtypen beschleunigen, lenken, bremsen ohne Überschlag.
  Screenshots `artifacts/screenshots/F/` visuell geprüft.
- **Einschränkung (ehrlich):** Das Abschütteln wird im Test durch Versetzen des Fahrzeugs außer Sicht simuliert (die Such- und
  Abbaulogik läuft echt); eine echte Fluchtfahrt gegen die Polizei-KI ist nicht automatisiert getestet.

## 2026-09-23 – Meilenstein G: Menüs, Speichern/Laden, Karte, Entwickleranzeige

- **Ziel:** vollständiger Spielrahmen: Hauptmenü, Pause, Einstellungen, Spielstand-Integration, Minikarte/Karte, F3.
- **Änderungsklasse:** mittel–groß (6 neue UI-Module, Integration in `game.gd`, Speicherformat erweitert) → Restore-Punkt: `9cde3ed`.
- **Umgesetzt:**
  - `MainMenu` (Neues Spiel mit Rückfrage bei vorhandenem Spielstand, Fortsetzen nur mit gültigem Spielstand inkl. Kurzinfo,
    Einstellungen, Beenden), eigener animierter Hintergrund `MenuBackground` (stilisierter Fächergrundriss), Menümusik.
  - `PauseMenu` (Esc; Fortsetzen, Speichern, Einstellungen, Steuerung, Hauptmenü/Beenden mit Speichern; pausiert, gibt Maus frei;
    öffnet auch bei Fokusverlust des Fensters).
  - `SettingsPanel` (Lautstärken, Mausempfindlichkeit, Y-Invertierung, Vollbild, V-Sync, Qualität, FPS-Anzeige, Verkehrsdichte).
  - `MapView` (Minikarte unten links, Vollkarte `MapOverlay` mit M): Blöcke, Park, Plätze, Straßen in Metern, Beschriftungen,
    Auftraggeber, Missionsziel (am Rand gehalten), Polizei bei Fahndung, Spielerpfeil, Legende. Datenquelle = Straßengraph.
  - `DevOverlay` (F3): FPS, Frame-/Physikzeit, Draw Calls, Objekte, Videospeicher, Position, Fahrzeug, Verkehr/Passanten/Polizei,
    Fahndung, Missionsschritt.
  - Speichern/Laden im Spiel: `Game.save_now`, `make_player_save` mit sicherem Fortsetzungspunkt (laufender Auftrag →
    Auftraggeber, Auftrag beginnt neu mit Hinweis; Fahndung → letzter sicherer Punkt zu Fuß), Autosave nach Missionsabschluss,
    Prüfung der geladenen Position (Boden + frei, sonst Startpunkt mit Hinweis). Speicherformat v1 um Feld `mission` ergänzt
    (abwärtskompatibel: fehlt es, gilt „kein Auftrag“).
- **Prüfung:** 90/90 Tests grün, Exit-Code 0. Neu: Speichern → Fortsetzen (Geld, Aufträge, Bestzeit, Position),
  Speichern während Auftrag → Fortsetzung beim Auftraggeber ohne altes Missionsfahrzeug, Fahndung → sicherer Punkt,
  blockierte Position → Startpunkt, Autosave, Pause/Karte pausieren und geben frei, Codec-Feld `mission`.
  Screenshots `artifacts/screenshots/G/` (Hauptmenü, Vollkarte, Pausenmenü, F3 + Minikarte) visuell geprüft.
- **Hinweis:** Die F3-Anzeige zeigt unter Software-Rendering (Xvfb/lavapipe) ca. 4 FPS – das ist **kein** Maß für echte Hardware.

## 2026-09-23 – Meilenstein H: Gesamttest, Windows-Export, Dokumentation

- **Ziel:** reproduzierbarer Windows-x64-Build mit Prüfung, vollständige Doku, ehrliche Testübersicht.
- **Änderungsklasse:** mittel (Export-Profil, Skripte, Doku; kein Spielcode) → Restore-Punkt: `866c482`.
- **Umgesetzt:** `export_presets.cfg` (Windows Desktop x86_64, Release, JSON-Daten eingeschlossen, Nicht-Spiel-Ordner ausgeschlossen,
  Symbol + Metadaten), `scripts/linux/{setup_godot.sh,build_windows.sh}`, `scripts/windows/{start_game.bat,build_windows.ps1,
  build_windows.bat,run_tests.bat}`, README.md, CONTROLS.md, ASSET_LICENSES.md, TEST_REPORT.md, KNOWN_ISSUES.md,
  docs/ARCHITEKTUR.md, docs/ENTWICKLUNG.md, Inhaltsverzeichnis aktualisiert.
- **Prüfung:** Gesamttestlauf (Ergebnis in TEST_REPORT.md); Export mit PE-Prüfung (x86_64, GUI), PCK-Kennung `GDPC`,
  Symbol/Metadaten in der EXE, Bootstest und 22-Bilder-Screenshot-Tour aus der exportierten PCK unter Linux, ZIP-Integrität,
  `setup_godot.sh` idempotent gegen vorhandene, SHA512-geprüfte Downloads.
- **Blockiert:** Wine-Rauchtest (Wine 9.0 startet bereits das unveränderte offizielle Template nicht). **Nicht durchgeführt:**
  Start unter echtem Windows, FPS-Messung auf Hardware, Windows-Skripte.
- **Auslieferung:** ZIP per Datei-Übergabe in der Sitzung (Nutzerentscheidung), `build/` bleibt unversioniert; SHA256 in TEST_REPORT.md.

## 2026-09-23 – Auslieferung über GitHub

- **Ziel:** Spiel, Installer und Anleitung direkt im Repository bereitstellen; Übernahme nach `main` per Pull Request.
- **Entscheidung (Nutzer):** ein ZIP im Repo + Pull Request. Damit wird „Build nicht versionieren“ **nur für das freigegebene
  Release-ZIP** aufgehoben (`release/`); `build/` bleibt ignoriert. GitHub-Releases kann ich mit meinen Werkzeugen nicht anlegen –
  Anleitung dafür in `ANLEITUNG.md` §9.
- **Änderungsklasse:** mittel (37-MB-Binärdatei, Doku) → Restore-Punkt: `97bb8ec`.
- **Umgesetzt:** `release/` (ZIP, `GTA_KA_installieren_und_starten.bat` für ZIP oder zwei Teile, `SHA256SUMS.txt`, `README.md`,
  `.gdignore`), `ANLEITUNG.md`, Verweise in README/Inhaltsverzeichnis/Testbericht, `.gitattributes`: `*.zip binary`.
- **Prüfung:** Hash der versionierten ZIP = dokumentierter Hash; `.bat` ASCII/CRLF; Godot-Import ignoriert `release/`.
  Nicht geprüft: Ausführung der `.bat` unter Windows.
