# Assets und Lizenzen (v0.2)

Alle Spielinhalte wurden **für dieses Projekt selbst erstellt** (prozedural aus Code bzw. mit eigenen Generatoren).
Es werden **keine** fremden Modelle, Texturen, Sounds, Musikstücke, Logos oder Schriften aus anderen Spielen verwendet –
insbesondere keine Inhalte, Namen, Menüs oder Cheat-Codes der GTA-Reihe. Keine kostenpflichtigen Assets, Plugins oder Dienste.

| Asset | Ort | Herkunft | Lizenz |
|---|---|---|---|
| Weltdaten Karlsruhe (Straßengraph, Sektoren, LOD, Übersichtskarte, ÖPNV) | `data/world/ka/` | erzeugt mit `tools/worldgen/` aus **OpenStreetMap** (siehe unten); Rückfall: eigene 1:1-Näherung (`ka_authored.py`) | **ODbL 1.0** (aktueller Stand, OSM-Quelle); MIT nur bei Näherung |
| 3D-Stadt (Straßen, Gebäude, Flächen, Landmarken, Bäume, Laternen, Möblierung, Gleise, Tunnel) | zur Laufzeit erzeugt durch `src/world/*`, `src/transit/*` | eigener Code | MIT |
| Figuren (Spieler, Passanten, Auftraggeber, Ereignis-Beteiligte) | `src/player/humanoid_rig.gd` | eigener prozeduraler Entwurf | MIT |
| Tiere (Zoo, Parks, Stadt) | `src/animals/*`, `data/animals/species.json` | eigener prozeduraler Entwurf | MIT |
| Fahrzeuge (fiktive Modelle), Stadtbahn, Bus | `src/vehicles/vehicle_model_builder.gd`, `data/vehicles/vehicles.json`, `src/transit/transit_models.gd` | eigene Entwürfe; Namen erfunden; Linienfarben nur zur Orientierung | MIT |
| Shader (Fassade, Dach, Pflaster, Asphalt mit Nässe, Rasen, Wasser, Laub mit Wind, Farbfehlsicht-Filter) | `assets/shaders/*.gdshader` | eigene Werke | MIT |
| Soundeffekte, Umgebungsklang, Tierstimmen, Regen, Menümusik | `assets/audio/*.wav` | deterministisch erzeugt mit `tools/generate_audio.py` (nur Python-Standardbibliothek) | MIT |
| Missionen, Dialoge, fiktive Gruppen | `data/missions/*.json`, `data/world/gangs.json` | eigene Texte | MIT |
| Programmsymbol | `assets/icons/faecherstadt.ico`, `faecherstadt_256.png`, `icon.svg` | erzeugt mit `tools/generate_icon.py` bzw. eigenes SVG | MIT |
| Menühintergrund | `src/ui/menu_background.gd` | eigene Zeichnung zur Laufzeit | MIT |
| Oberflächenschrift | in der Godot-Engine eingebaut (Standardschrift „Open Sans“) | Godot 4.7.2, `thirdparty/fonts/OpenSans*.woff2` | SIL OFL 1.1 (laut Godot `COPYRIGHT.txt`) |
| Engine | Godot Engine 4.7.2-stable | godotengine.org | MIT bzw. Drittlizenzen laut Godot `COPYRIGHT.txt` |

## OpenStreetMap
Die ausgelieferte Welt ist mit `build_world.py --source osm` erzeugt (Abruf 2026-09-29). Für die Kartendaten gilt:
**© OpenStreetMap-Mitwirkende**, verfügbar unter der **Open Database License 1.0** (https://www.openstreetmap.org/copyright).
Die abgeleiteten Weltdaten in `data/world/ka/` stehen ebenfalls unter ODbL (Weitergabe unter gleicher Lizenz, Namensnennung;
Erzeugung reproduzierbar mit `tools/worldgen/fetch_osm.py` + `build_world.py`); der Programmcode bleibt MIT.
Die Namensnennung erscheint im Hauptmenü (Quelle der Weltdaten). Welche Quelle aktuell verwendet wird, steht in
`docs/KARTE_KARLSRUHE.md` und im Feld `source` von `data/world/ka/world.json.gz`.

Hinweis zu Symbolzeichen (◆ ✔ 🔒 ✚ ♥): Diese Zeichen werden aus der Standardschrift oder per Font-Fallback aus einer
Systemschrift dargestellt. Es werden keine Schriftdateien mitgeliefert.

## Reale Orte, Namen, Firmen
- Straßen-, Platz- und Stadtteilnamen sowie reale Bauwerke (Schloss, Hauptbahnhof, Zoo, Stadion, Rathaus, Stadtkirche, Pyramide,
  Tore, Turmberg) werden als geografische Orte verwendet und vereinfacht, ohne fremdes Bildmaterial, nachgebildet.
- Alle Personen, Geschäfte, Firmen, Gruppen und Institutionen im Spiel (z. B. „Fächerblitz-Kurier“, „Hafenkolonne“,
  „Ringbande“, „Nordlichter“, „Turmberg-Clique“) sind **erfunden**. Reale Unternehmen, Vereine oder Personen werden nicht
  dargestellt; reale Institutionen erscheinen nur als Orte und nie in negativem Zusammenhang.
- Liniennummern des ÖPNV dienen der Orientierung; Takt und Fahrzeiten sind spielerisch und kein realer Fahrplan.
