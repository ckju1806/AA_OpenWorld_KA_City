# Inhaltsverzeichnis – Fächer-City: Asphalt & Schatten

Das Repository ist zugleich das Godot-Projekt (Nutzerentscheidung 2026-09-23, dokumentierte Ausnahme von `projects/active/…`).

## Einstieg
| Datei | Inhalt |
|---|---|
| [README.md](README.md) | Überblick, Voraussetzungen, Start, Build, Spielstände, Fehlerbehebung |
| [CONTROLS.md](CONTROLS.md) | Steuerung |
| [TEST_REPORT.md](TEST_REPORT.md) | Durchgeführte / nicht durchgeführte / blockierte Prüfungen |
| [KNOWN_ISSUES.md](KNOWN_ISSUES.md) | Bekannte Probleme |
| [ASSET_LICENSES.md](ASSET_LICENSES.md) | Herkunft und Lizenz aller Assets |
| [LICENSE](LICENSE) | MIT-Lizenz des Projekts |

## Dokumentation (`docs/`)
| Datei | Inhalt |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Freigegebener Umsetzungsplan |
| [docs/ARBEITSLOG.md](docs/ARBEITSLOG.md) | Fortlaufender Arbeitsstand, Restore-Punkte |
| [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) | Module, Datenfluss, Physik-Layer |
| [docs/KARTE_KARLSRUHE.md](docs/KARTE_KARLSRUHE.md) | Kartengrundlage, Quellen, künstlerische Interpretation |
| [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md) | Entwicklungsübersicht und nächste Schritte |

## Spielprojekt
| Ordner | Inhalt |
|---|---|
| `project.godot`, `export_presets.cfg` | Godot-Projekt- und Exportkonfiguration |
| `src/` | GDScript-Quellcode, getrennt nach Systemen (autoload, core, player, vehicles, world, traffic, npc, police, missions, ui, audio, save) |
| `scenes/` | Szenen (Boot, Hauptmenü, Spiel) |
| `data/` | Datengetriebene Inhalte: Karte (`world/`), Fahrzeuge (`vehicles/`), Missionen (`missions/`) |
| `assets/` | Shader, Audio, Icons (selbst erzeugt) |
| `tests/` | Automatisierte Unit- und Integrationstests |

## Werkzeuge & Betrieb
| Ordner | Inhalt |
|---|---|
| `scripts/` | Start-, Build-, Test- und Setup-Skripte (Windows/Linux) |
| `tools/` | Generatoren (Audio, Icon) – nicht Teil des Spiels |
| `config/` | Toolchain-Versionen, keine Secrets |
| `artifacts/` | Screenshots und Testlogs |
| `backups/` | Dateisicherungen vor Änderungen |
| `logs/`, `tmp/` | lokal, nicht versioniert |
| `sensitive/` | leer – Projekt benötigt keine Zugangsdaten |
| `_inventory/` | Werkzeug-Inventar |
| `_quarantine/` | ungeprüfte Dateien (leer) |
| `build/` | Windows-Build (nicht versioniert) |
