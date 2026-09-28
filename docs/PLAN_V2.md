# Plan v2: „Fächerstadt: Asphalt & Schatten“ – Großausbau Karlsruhe 1:1 (Godot 4.7.2)

Stand: 2026-09-28 · Änderungsklasse: **groß** (Weltsystem-Umbau, neue Datenpipeline, viele neue Systeme)
Vorgänger-Plan (v0.1-Prototyp, Meilensteine M0/A–H): erledigt, dokumentiert in `docs/PLAN.md` und `docs/ARBEITSLOG.md`.

## 1. Kontext

v0.1.0 (PR #1, gemergt → `main` = `46db3d1`) ist ein spielbarer Prototyp: ~1,1×1,2 km verdichtete Innenstadt, 3 Missionen,
Verkehr/Passanten/Polizei, Menüs, Speichern, 90 Tests, Windows-Build. Neuer Auftrag: **massive Erweiterung auf Basis des
bestehenden Codes** – gesamter Kartenausschnitt des Nutzer-Screenshots (Neureut bis Rheinstetten, Rheinhafen bis Durlach,
≈ 17 × 11 km) **1:1 und in voller Detailtiefe**, bessere Grafik, ÖPNV inkl. U-Strab, Tiere/Zoo, Cheats, viele Missionen,
Banden/Unruhen/Polizei, umfangreiche Optionen, Streaming. Nutzerentscheidungen: **gesamte Karte 1:1** und **„erst Breite, dann Tiefe“**.

## 2. Befund / Beweiskette

| Beobachtung | Folgerung |
|---|---|
| `CityWorld.build()` baut alles auf einmal (1,2 s für 1 429 Parzellen) | Für ~150–200 km² ist Sektor-Streaming zwingend |
| Karte heute handgeschrieben (`karlsruhe_layout.json`, 27 Straßen, Faktor 0,55) | 1:1 „wie auf der Karte“ braucht echte Geodaten |
| overpass-api.de, download.geofabrik.de, tile/planet.openstreetmap.org, geoportal/transparenz.karlsruhe.de → `connect_rejected` durch die **Egress-Richtlinie der Cloud-Umgebung** (nicht Pi-hole des Nutzers) | Freischaltung nur in den Umgebungseinstellungen möglich; bis dahin datenunabhängig arbeiten, Fallback von Hand |
| raw.githubusercontent.com, pypi.org erreichbar | Python-Werkzeuge installierbar; keine OSM-Daten darüber |
| Kein Windows, keine GPU | Grafik nur per Software-Rendering sichtbar prüfbar; FPS auf Hardware weiterhin ungetestet |

## 3. Grundsatzentscheidungen

- **Kein Neuanfang:** vorhandene Systeme (CityGraph, LaneDriver, Pedestrian, Police/WantedLogic, MissionSystem, UI, Save,
  Tests) werden erweitert; Koordinatenkonvention bleibt (1 m, Ursprung Schlossturm, Nord = −Z).
- **Geodaten:** OSM-Extrakt (ODbL) → Offline-Konverter `tools/osm_import.py` → kompakte Sektordateien `data/world/ka/`.
  Pflichten: Namensnennung „© OpenStreetMap-Mitwirkende“ (Credits im Hauptmenü, ASSET_LICENSES), abgeleitete Kartendaten
  unter ODbL (Code bleibt MIT). **Fallback** ohne Freigabe: handgezeichnetes 1:1-Gerüst (Hauptachsen, Ringe, Viertel mit
  typischem Raster, Landmarken an realer Position) nach Screenshot und Wissen – als Näherung gekennzeichnet.
- **Detailtiefe realistisch:** „volle Detailtiefe“ = jedes Gebäude aus Grundriss + Höhe mit Fassadenshader, Straßen mit Breite/Spuren,
  Grünflächen, Gleise, Wasser. Individuell modelliert werden die Prioritäts-Landmarken (§14 des Auftrags); übrige Gebäude prozedural.
- **Streaming:** Sektoren 256 m; Aufbau im Hintergrund-Thread (Mesh-Daten), Anhängen im Hauptthread in Zeitscheiben; drei Stufen:
  Nah (voll inkl. Kollision/Props), Mittel (Gebäude vereinfacht), Fern (Silhouetten-LOD pro Viertel). Globale leichte Daten
  (Straßengraph, A*, Karte) bleiben komplett geladen.
- **Kontrollierbarkeit:** alle neuen Systeme hinter Optionen/Schaltern; Ereignis-Direktor mit Budget und Abkühlzeiten.
- **Fiktion:** alle Figuren, Banden, Firmen fiktiv; reale Institutionen (Zoo, Hbf, KIT, Schloss) nur als Orte, nie negativ.
  Keine GTA-Codes/-Namen/-Menüs.
- **Restore-Punkt:** `main` = `46db3d1`; Arbeitsbranch `claude/confident-volta-6a71kc` wird (da PR #1 gemergt) neu von `main`
  gestartet; je Meilenstein Commit + Push; Draft-PR früh, final PR nach `main`.

## 4. Meilensteine (Breite zuerst; jeder endet startbar, getestet, committet)

**W1 – Weltsystem & Streaming (datenunabhängig)**
- `src/world/streaming/`: `WorldStreamer` (Sektorgitter, Lade-/Entladeradius je Qualität, Zeitbudget pro Frame), `SectorData`
  (Straßen, Gebäude, Flächen, Props je Sektor), `SectorBuilder` (nutzt vorhandene `MeshKit`, `BuildingBuilder`-Fassadenlogik,
  `GroundBuilder`, `PropsBuilder` pro Sektor), `LodBuilder` (Fern-Silhouetten).
- `CityGraph` für große Netze: räumlicher Index (Gitter) für `nearest_*`, A* unverändert.
- Traffic/Passanten/Polizei/Missionen fragen „Sektor geladen?“ (kein Spawn in ungeladenen Sektoren).
- Tests: Objektzahl bleibt beim Abfahren von 10 km begrenzt; Sektor-Laden/Entladen ohne Lecks; alte Tests grün.

**W2 – Karte 1:1** (mit OSM, sonst Fallback)
- `tools/osm_import.py` (Projektion, Klassifizierung highway/railway/building/landuse/water/leisure, Sektorierung, Vereinfachung,
  Gebäudehöhe aus `height`/`building:levels`/Typ), Ergebnis versioniert in `data/world/ka/`.
- Gebiete lt. Auftrag §2 inkl. Autobahn A5/B10/B36 angedeutet; Kartenränder als Wald/Felder mit Sperrgrenze.
- Missionen/POIs/Respawns auf echte Koordinaten umziehen; M1–M3 bleiben spielbar (Tests anpassen).
- Minikarte/Vollkarte zoombar, Stadtteilnamen.

**W3 – Landmarken & Prioritätsorte**: Schloss (Flügel + Turm), Schlossgarten, Zirkel, Marktplatz (Pyramide, Rathaus, Stadtkirche),
Kaiserstraße (Geschäfte, Arkaden), Europaplatz, Kronenplatz, Durlacher Tor, **Hbf** (Empfangsgebäude mit Bogenhallen, Vorplatz,
Bahnsteige), **Zoo** (Gehege, Stadtgartensee, Wege), Botanischer Garten (Gewächshäuser), Citypark, Günther-Klotz-Anlage, Rheinhafen
(Becken, Kräne), Durlach (Altstadt, Turmberg angedeutet), Ettlinger Tor, Staatstheater-Umfeld.

**W4 – Grafik**: Tag-/Nachtzyklus mit Himmel, bessere Sonne/Schatten (Kaskaden je Qualität), SSAO/SSIL/Glow/Nebel je Stufe,
TAA/FXAA/MSAA-Auswahl, Fassadenshader v2 (Stockwerksgesimse, Fensterlaibungen, Ladenzonen, Varianten nach Epoche/Viertel),
Straßen-/Gehwegmaterial v2 (Fugen, Markierungen, Nässe), Vegetation (MultiMesh-Bäume mit Windshader, Hecken, Rasen), Wassershader,
Wetter (Regen/Nebel, nasse Straßen), Fahrzeugmodelle v2, UI-Feinschliff. Qualitätsstufen Niedrig/Mittel/Hoch/Ultra.

**W5 – ÖPNV**: `TransitNetwork` (Linien aus OSM `route=tram/bus` oder definierten Linien), Stadtbahnen als geführte Fahrzeuge auf
Gleispfaden mit Fahrplan/Taktzyklus, **U-Strab-Tunnel Kaiserstraße** (Rampen, unterirdische Haltestellen), Busse auf dem Straßengraph
(LaneDriver + Haltebuchten), Haltestellen mit Wartehäuschen/Anzeigen, Passanten steigen ein/aus, Spieler kann mitfahren
(Einsteigen an Haltestelle, Mitfahrkamera, Aussteigen an nächster Station). Kollisionen: Bahnen haben Vorrang, bremsen vor Hindernissen.

**W6 – Tiere**: `AnimalAgent` + Artdaten (JSON): Zoo-Gehege (Elefant, Giraffe, Zebra, Pinguin, Robbe, Flamingo, Bär, Affen, Löwe),
Stadtgartensee-Enten, Tauben-Schwärme (auffliegen bei Nähe/Lärm), Hunde mit Haltern, Katzen, Vögel in Parks. Zustände Idle/Wander/
Flee/React; Aufenthaltsbereiche; Zoo-Besucher; Umgebungsgeräusche (generiert).

**W7 – Banden, Unruhen, Polizei**: `ZoneMap` (Risikoprofil je Viertel), 3–4 fiktive Gruppen mit Revieren, `EventDirector`
(Budget, Abstand zum Spieler, Abkühlzeit; Ereignisse: Rangelei, Revierstreit, Straßenrennen, Diebstahl mit Flucht, Kundgebung/Unruhe,
Polizeikontrolle), Polizei-Einsätze auf Ereignisse, Straßensperren ab Stufe 3, verbesserte Suche (Suchgebiet statt Punkt).
Kein Waffen-System (Nahkampf nur als Umstoßen/Rangelei-Animation) – als Einschränkung dokumentiert.

**W8 – Missionen**: neue Schritttypen (follow_target, escape_area, observe_stealth, deliver_item, collect, protect_vehicle,
ride_transit, destroy/sabotage_object, timed_multi_drop), Kampagne mit 5 fiktiven Auftraggebern (Kurierdienst, Kontaktmann,
Informantin, Fahrzeughändler, zwei Gruppen) ≈ 15 Story-Missionen + wiederholbare Jobs (Kurier, Taxi, Lieferung); Missionsliste im
Pausenmenü; alle datengetrieben, restartbar, getestet per Autopilot.

**W9 – Cheats**: `CheatManager` (Autoload, Registry, erweiterbar), Eingabe per Tippen im Spiel + Konsole (Taste `^`/Eingabefeld),
eigene deutsche Codes, Rückmeldung, einzeln an/aus/zurücksetzen, in Optionen erlaubbar; Liste gemäß Auftrag §8 (Teleport-Ziele,
Tageszeit, Wetter, Chaos-Modus, Dichten usw.; „Ausrüstung“ als Platzhalter).

**W10 – Optionen**: `Settings` v2 mit Kategorien A–E + Tastenbelegung (Neubelegung, Konflikterkennung), Optionsmenü mit Tabs,
Speicherung in `settings.cfg` (Migration v1→v2), Live-Anwendung wo möglich; Busse Fahrzeuge/Sprache ergänzt; Untertitel,
Schriftgröße, Kamera-Autozentrierung, Hilfsmarkierungen, vereinfachte Missionen.

**W11 – KI-Feinschliff**: Verkehr (Einbahnstraßen/Spuren aus Daten, Spurwechsel für Überholen/Abbiegen, Kreuzungsreservierung),
Passanten (Haltestellen, Zebrastreifen, Parks), Polizei (Verfolgung mit Abschneiden, Sperren), Tiere/Banden wie oben.

**W12 – Optimierung, Tests, Doku, Build**: Profiling (Software-Rendering nur relativ), Objektbudgets, vollständiger Testlauf,
Screenshot-Touren aller Prioritätsorte, README/ANLEITUNG/TEST_REPORT/KNOWN_ISSUES/ARCHITEKTUR/KARTE aktualisieren,
Windows-Build + `release/` + PR.

## 5. Validierung (je Meilenstein)
- `scripts/linux/run_tests.sh` → Exit-Code 0 vor jedem Commit; neue Tests je System (Unit + Integration + Autopilot-Durchläufe).
- Streaming-Test: Fahrt/Teleport über die ganze Karte, Knoten-/Objekt-/Speicherzähler begrenzt.
- Screenshot-Tour je Meilenstein, visuell geprüft; Export-Bootstest am Ende.
- Doku fortlaufend: ARBEITSLOG je Meilenstein, TEST_REPORT mit implementiert / teilweise / getestet / ungetestet / blockiert.

## 6. Risiken
| Risiko | Maßnahme |
|---|---|
| OSM bleibt gesperrt | W1/W4–W10 unabhängig davon; W2 als handgezeichnetes 1:1-Gerüst, klar als Näherung markiert |
| Datenmenge/Leistung (Hunderttausende Gebäude) | Streaming, LOD, Vereinfachung im Konverter, Qualitätsstufen, Budgets |
| Leistung auf echter Hardware unbekannt | konservative Standardwerte „Mittel“, F3-Messanzeige, Rückmeldung einholen |
| Umfang übersteigt eine Sitzung | Breite zuerst; jeder Meilenstein lauffähig committet; Offenes sauber markiert |
| Repo-Größe | Sektordaten komprimiert (binär/gzip), `build/` weiter ignoriert |
## 7. Addendum 2026-09-28: GitHub-Speicherbudget (Nutzervorgabe)
Zweck: Projekt muss vollständig in GitHub bleiben, ohne Kontingente zu überschreiten; Qualität ist daran gedeckelt.
- Repo gesamt inkl. Historie **< 300 MB** (GitHub-Empfehlung < 1 GB; Dateilimit 100 MB, Warnung ab 50 MB). Stand 28.09.: 63 MB.
- **Keine weiteren Builds im Repo**: neue Windows-Builds nur als GitHub-Release-Anhang (zählt nicht zum Repo); `release/` wird
  bei v0.2 durch einen Verweis ersetzt (vorhandenes ZIP bleibt nur in der Historie).
- Generierte Weltdaten (`data/world/ka/`) **≤ 40 MB** je Stand, kompakt (quantisierte Ganzzahlen, gzip), Einzeldatei ≤ 5 MB;
  nur an Meilensteinen neu committen (Historie wächst sonst je Neugenerierung).
- Kein Git LFS (Kontingent 1 GB inkl. Bandbreite). Screenshots nur verkleinert/JPEG (≤ 200 KB), Test-Logs nicht mehr versionieren.
- `tools/check_repo_budget.py` prüft Budgets vor jedem Commit (Exit-Code ≠ 0 bei Überschreitung).
