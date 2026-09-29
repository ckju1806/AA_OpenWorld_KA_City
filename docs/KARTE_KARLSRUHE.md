# Kartengrundlage Karlsruhe (v0.2) – Maßstab 1:1

> **Hinweis:** Die Spielwelt bildet Karlsruhe im Maßstab 1:1 über den Ausschnitt des Referenz-Screenshots ab
> (≈ 17,5 × 10,4 km: Neureut/Knielingen bis Rheinstetten/Rüppurr, Rheinhafen bis Durlach/Turmberg). Sie ist ein **Spiel**,
> kein digitaler Zwilling: Gebäude sind prozedural, Innenräume fehlen, alle Figuren, Firmen und Gruppen sind erfunden.
> Der Spielstart benötigt keinen Kartendienst; alle Kartendaten liegen kompakt im Projekt (`data/world/ka/`).

## 1. Zwei Datenquellen, ein Format

| Quelle | Datei | Inhalt | Genauigkeit | Status |
|---|---|---|---|---|
| **OpenStreetMap** (im Build verwendet) | `tools/worldgen/fetch_osm.py` → `~/osm_cache` → `source_osm.py` | echte Straßen (Breite, Einbahn, Brücken), 96 513 Gebäudegrundrisse mit Höhen/Dachform, 17 500 Flächen, Gewässer, Gleise, 559 Ampelkreuzungen, 30 000 Einzelbäume, 573 Haltestellen, 177 ÖPNV-Linienverläufe (63 Bahn, 87 Bus, Rest Zug) mit U-Strab-Tunnel | Geodaten (ODbL), Stand des Abrufs 2026-09-29 | **implementiert, getestet** |
| Handgezeichnete 1:1-Näherung (Rückfall) | `tools/worldgen/ka_authored.py` | Hauptachsen, Ringe, Fächer, Viertel mit typischem Raster, Landmarken, POIs, ÖPNV-Näherung | typ. ± 50–150 m | implementiert, getestet (nicht mehr im Build) |

Beide Quellen liefern dasselbe Zwischenformat; `tools/worldgen/build_world.py` erzeugt daraus Straßengraph, 256-m-Sektoren,
LOD-Kacheln, Übersichtskarte und ÖPNV-Daten (OSM: ≈ 11,5 MB, ≈ 6 min). Welche Quelle im Build steckt, zeigen `world.json.gz`
(`source`, `note`), das Startprotokoll („Quelle: osm“) und das Hauptmenü (Namensnennung).

**Lizenz:** Kartendaten © OpenStreetMap-Mitwirkende, Open Database License 1.0. Die abgeleiteten Weltdaten in
`data/world/ka/` stehen unter ODbL; der Programmcode bleibt MIT. Rohdaten (≈ 460 MB Overpass-Kacheln) werden nicht versioniert.

### Aufbereitung der OSM-Daten für ein befahrbares Spiel (Regeln in `source_osm.py`, `blocks.py`, `export.py`)
- **Mindestbreiten** je Straßenklasse (OSM-`width` beschreibt teils nur einen Fahrstreifen), z. B. zweispurige Tertiärstraße
  ≥ 7 m, Wohnstraße ≥ 5,5 m, Einbahnstraße ≥ 4 m.
- **Gebäude** werden an Fahrbahnen (halbe Breite + 0,2 m, runde Kappen) zugeschnitten und morphologisch geöffnet (keine Nadeln).
- **Sackgassen-Stummel**, die an Gebäuden enden (Ladehof-/Garageneinfahrten), werden entfernt (278); Straßentunnel ausgelassen.
- **Landmarken** werden an realen OSM-Objekten verankert (Name/Tags, Ausrichtung aus dem Grundriss); Nebenstraßen unter
  Landmarken-Grundrissen entfallen. Das Schloss sitzt am realen Schlossturm (Mittelpunkt des Fächers); Schloss, Pyramide,
  Rathaus und Stadtkirche folgen der realen Stadtachse (Schlossturm → Pyramide, ≈ 4° gegen Nord gedreht). Rathaus
  (≈ 62 × 76 m) und Stadtkirche (≈ 61 × 31 m, Portikus nach Westen) haben die Maße ihrer OSM-Grundrisse.
- **Auftragsorte (POIs)** rasten auf die benannte Straße ein; Fahrzeugziele an Fußgängerzonen auf die Fahrbahn daneben
  (z. B. Ladezone Kanzlei → Adlerstraße).
- **Objekte mit Kollision** (Laternen, Bäume, Poller, Bänke) und parkende Autos nie auf Fahrbahnen; Ampelmasten ≥ 1,2 m neben
  der Fahrbahnkante.
- **Zoo:** Die Gehege (9, eigene Anordnung) werden auf freie Stellen der realen Zoofläche gesetzt – ohne Stadtgartensee,
  Zoogebäude und Wege (`zoo_fit.py`, max. Versatz ≈ 83 m, Ergebnis im Landmarkeneintrag); Spiel und Tiere übernehmen es.
- **Objekte in Landmarken:** Bäume/Laternen/Bänke innerhalb von Landmarken-Grundrissen werden entfernt (Zoo-Gehege ausgenommen).
- **Validierung** (`validate_world.py`): Gebäude (Fläche und Eindringtiefe), parkende Autos, Objekte und die Grundrisse aller
  Landmarken (Detail- und Platzhaltermodelle) gegen alle Fahrbahnen, keine Objekte in Landmarken – der Build bricht bei
  Verstößen ab. Installation mit `install_world.py` (nur inhaltlich geänderte Dateien; gzip ohne Zeitstempel).

## 2. Koordinaten
Ursprung ≈ Schlossturm (49,013480 N, 8,404440 E; der reale Turm liegt laut OSM 54 m nördlich – dort ist die Schloss-Landmarke verankert), x = Osten, z = Süden (Norden = −Z), 1 Einheit = 1 m, lokale
äquirektanguläre Projektion. Kartenausschnitt (x, z): −9 500 … 8 000 × −4 100 … 6 300.

## 3. Prioritätsorte (einzeln modelliert, Position real)
Schloss mit Schlossplatz und Schlossgarten, Zirkel und Fächerstraßen, Marktplatz (Pyramide, Rathaus, Stadtkirche),
Kaiserstraße, Europaplatz, Kronenplatz, Durlacher Tor, Ettlinger Tor, Staatstheater-Umfeld, **Hauptbahnhof** (Empfangsgebäude,
Bahnsteighallen), **Zoo** (9 Gehege mit Tieren, Stadtgartensee), Botanischer Garten (Gewächshäuser), Stadion am Wildpark,
Rheinhafen (Becken, Kräne), Durlach mit Turmberg, U-Strab (Tunnel, U-Stationen, Rampen).

## 4. ÖPNV-Daten
Aus OSM: `route=tram|light_rail|bus|train`-Relationen (je Richtung eine Linie), Haltepositionen, Tunnelabschnitte aus
`tunnel=yes`-Gleisen (U-Strab Kaiserstraße und Südabzweig mit unterirdischen Haltestellen). Linien mit passender Gegenrichtung
pendeln, andere starten nach der Endhaltestelle neu. Liniennummern/-farben dienen der Orientierung; Takt und Fahrzeiten sind
spielerisch, **kein** realer Fahrplan. Rückfall ohne OSM: Linie 1, Linie 2, Bus 62 (Näherung).

## 5. Bewusste Abweichungen
| Abweichung | Grund |
|---|---|
| Mindestbreiten, entfernte Stummel, zugeschnittene Gebäude | Befahrbarkeit und Kollisionsfreiheit im Spiel |
| Straßentunnel (Kriegsstraße) ausgelassen | Spielbarkeit/Streaming; Oberfläche bleibt befahrbar |
| Rampen der U-Strab als überdachte Bauwerke | Straßenoberfläche wird nicht ausgeschnitten |
| Gebäude generisch (Fassaden-Shader nach Viertel/Epoche) | nur Landmarken sind individuell modelliert |
| Alle Firmen, Personen, Gruppen erfunden | keine Darstellung realer Unternehmen/Personen; reale Institutionen nur als Orte, nie negativ |
