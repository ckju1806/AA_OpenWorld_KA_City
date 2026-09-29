# Kartengrundlage Karlsruhe (v0.2) – Maßstab 1:1

> **Hinweis:** Die Spielwelt bildet Karlsruhe im Maßstab 1:1 über den Ausschnitt des Referenz-Screenshots ab
> (≈ 17,5 × 10,4 km: Neureut/Knielingen bis Rheinstetten/Rüppurr, Rheinhafen bis Durlach/Turmberg). Sie ist ein **Spiel**,
> kein digitaler Zwilling: Gebäude sind prozedural, Innenräume fehlen, alle Figuren, Firmen und Gruppen sind erfunden.
> Der Spielstart benötigt keinen Kartendienst; alle Kartendaten liegen kompakt im Projekt (`data/world/ka/`).

## 1. Zwei Datenquellen, ein Format

| Quelle | Datei | Inhalt | Genauigkeit | Status |
|---|---|---|---|---|
| **Handgezeichnete 1:1-Näherung** | `tools/worldgen/ka_authored.py` | Hauptachsen, Ringe, Fächer, Kaiserstraße, Ausfallstraßen, Autobahn-/Bundesstraßen angedeutet, Rhein/Alb/Hafenbecken, Wälder/Parks/Zoo, Bahnstrecken, Viertel mit typischem Straßenraster, ÖPNV-Näherung (Linie 1/2, Bus 62, U-Strab Kaiserstraße + Südabzweig) | typ. ± 50–150 m; Nebenstraßen als plausibles Raster, nicht real | **implementiert, getestet** (aktueller Stand im Repo) |
| **OpenStreetMap** | `tools/worldgen/fetch_osm.py` → `~/osm_cache` → `source_osm.py` | echte Straßen (Breite, Einbahn, Brücken), Gebäudegrundrisse mit Höhen/Dachform, Flächen, Gewässer, Gleise, Ampeln, Bäume, Haltestellen, Linienverläufe | Geodaten (ODbL) | **teilweise** – Pipeline mit Teildaten erfolgreich getestet; vollständiger Abruf durch Auslastung der Overpass-API verzögert (siehe ARBEITSLOG) |

Beide Quellen liefern dasselbe Zwischenformat; `tools/worldgen/build_world.py` erzeugt daraus Straßengraph, 256-m-Sektoren,
LOD-Kacheln, Übersichtskarte und ÖPNV-Daten. Welche Quelle im Build steckt, zeigen `world.json.gz` (`source`, `note`),
das Startprotokoll („Quelle: authored|osm“) und das Hauptmenü.

**Lizenz bei OSM-Nutzung:** Kartendaten © OpenStreetMap-Mitwirkende, Open Database License 1.0. Die abgeleiteten Weltdaten
stehen dann unter ODbL; der Programmcode bleibt MIT. Die Namensnennung erscheint im Hauptmenü und in `ASSET_LICENSES.md`.
Rohdaten werden nicht versioniert (Speicherbudget).

## 2. Koordinaten
Ursprung = Schlossturm (49,013480 N, 8,404440 E), x = Osten, z = Süden (Norden = −Z), 1 Einheit = 1 m, lokale
äquirektanguläre Projektion. Kartenausschnitt (x, z): −9 500 … 8 000 × −4 100 … 6 300.

## 3. Prioritätsorte (einzeln modelliert, Position real)
Schloss mit Schlossplatz und Schlossgarten, Zirkel und Fächerstraßen, Marktplatz (Pyramide, Rathaus, Stadtkirche),
Kaiserstraße, Europaplatz, Kronenplatz, Durlacher Tor, Ettlinger Tor, Staatstheater-Umfeld, **Hauptbahnhof** (Empfangsgebäude,
Bahnsteighallen), **Zoo** (9 Gehege mit Tieren, Stadtgartensee), Botanischer Garten (Gewächshäuser), Stadion am Wildpark,
Rheinhafen (Becken, Kräne), Durlach mit Turmberg, U-Strab (Tunnel, U-Stationen, Rampen).

## 4. ÖPNV-Daten
Aus OSM: `route=tram|light_rail|bus|train`-Relationen (je Richtung eine Linie), Haltepositionen, Tunnelabschnitte aus
`tunnel=yes`-Gleisen. Näherung: Linie 1 (Mühlburger Tor – Kaiserstraße-Tunnel – Durlach), Linie 2 (Hauptbahnhof –
Südabzweig-Tunnel – Marktplatz), Bus 62 (Kaiserplatz – Hauptbahnhof). Liniennummern/-farben dienen der Orientierung;
Takt und Fahrzeiten sind spielerisch, **kein** realer Fahrplan.

## 5. Bewusste Abweichungen
| Abweichung | Grund |
|---|---|
| Nebenstraßen der Näherung als Raster | ohne Geodaten nicht exakt möglich; OSM ersetzt sie |
| Straßentunnel (Kriegsstraße) ausgelassen | Spielbarkeit/Streaming; Oberfläche bleibt befahrbar |
| Rampen der U-Strab als überdachte Bauwerke | Straßenoberfläche wird nicht ausgeschnitten |
| Gebäude generisch (Fassaden-Shader nach Viertel/Epoche) | nur Landmarken sind individuell modelliert |
| Alle Firmen, Personen, Gruppen erfunden | keine Darstellung realer Unternehmen/Personen; reale Institutionen nur als Orte, nie negativ |
