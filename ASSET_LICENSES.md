# Assets und Lizenzen

Alle Spielinhalte wurden **für dieses Projekt selbst erstellt** (prozedural aus Code bzw. mit eigenen Generatoren).
Es werden **keine** fremden Modelle, Texturen, Sounds, Musikstücke, Logos oder Schriften aus anderen Spielen verwendet.
Keine kostenpflichtigen Assets, Plugins oder Dienste.

| Asset | Ort | Herkunft | Lizenz |
|---|---|---|---|
| 3D-Stadt (Straßen, Plätze, Gebäude, Landmarken, Bäume, Laternen, Möblierung) | zur Laufzeit erzeugt aus `data/world/karlsruhe_layout.json` durch `src/world/*` | eigener Code, eigene Daten | MIT (Projektlizenz) |
| Figuren (Spieler, Passanten, Auftraggeber) | `src/player/humanoid_rig.gd` | eigener prozeduraler Entwurf | MIT |
| Fahrzeuge (5 fiktive Modelle) | `src/vehicles/vehicle_model_builder.gd`, `data/vehicles/vehicles.json` | eigener prozeduraler Entwurf; Namen erfunden | MIT |
| Shader (Fassade, Dach, Pflaster, Asphalt, Rasen) | `assets/shaders/*.gdshader` | eigene Werke | MIT |
| Soundeffekte, Umgebungsklang, Menümusik (20 WAV) | `assets/audio/*.wav` | deterministisch erzeugt mit `tools/generate_audio.py` (nur Python-Standardbibliothek) | MIT |
| Programmsymbol | `assets/icons/faecherstadt.ico`, `faecherstadt_256.png`, `icon.svg` | erzeugt mit `tools/generate_icon.py` bzw. eigenes SVG | MIT |
| Menühintergrund | `src/ui/menu_background.gd` | eigene Zeichnung zur Laufzeit | MIT |
| Oberflächenschrift | in der Godot-Engine eingebaut (Standardschrift „Open Sans“) | Godot 4.7.2, `thirdparty/fonts/OpenSans*.woff2` | SIL OFL 1.1 (laut Godot `COPYRIGHT.txt`, geprüft 2026-09-23) |
| Engine | Godot Engine 4.7.2-stable | godotengine.org | MIT (Engine) bzw. Drittlizenzen laut Godot `COPYRIGHT.txt` |

Hinweis zu Symbolzeichen (◆ ● ▲ ♥): Diese Zeichen werden aus der Standardschrift oder – falls dort nicht enthalten – aus einer
Systemschrift des Betriebssystems dargestellt (Font-Fallback). Es werden keine Schriftdateien mitgeliefert.

## Reale Orte, Namen, Firmen

- Straßen- und Platznamen der Karlsruher Innenstadt werden als geografische Bezeichnungen verwendet; die Stadt ist künstlerisch
  verdichtet und kein digitaler Zwilling (siehe `docs/KARTE_KARLSRUHE.md`).
- Alle Personen, Geschäfte, Firmen und Institutionen im Spiel (z. B. „Fächerblitz-Kurier“, „Bäckerei Brezelglück“,
  „Kanzlei Dr. Hagedorn“, „Antiquitäten Riegel“, „Schrauberei Mäule“, „St.-Fächer-Klinik“, „Polizeirevier Innenstadt“)
  sind **erfunden**. Reale lokale Unternehmen werden nicht dargestellt und nicht als kriminell gezeigt.
- Rathaus, Stadtkirche, Pyramide, Schloss und Tore sind vereinfachte, eigene Nachbildungen ohne fremdes Bildmaterial.
