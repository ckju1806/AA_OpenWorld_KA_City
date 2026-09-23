# Inhaltsverzeichnis – Fächer-City: Asphalt & Schatten

Das Repository ist zugleich das Godot-Projekt (Nutzerentscheidung 2026-09-23, dokumentierte Ausnahme von `projects/active/…`).

## Einstieg
| Datei | Inhalt |
|---|---|
| [ANLEITUNG.md](ANLEITUNG.md) | Download, Installation nach `C:\GTA_KA`, Start, Fehlerbehebung (für Spieler) |
| [release/](release/) | Versionierte Auslieferung: Windows-ZIP, Installer-.bat, SHA256SUMS |
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
| `src/` | GDScript-Quellcode, getrennt nach Systemen (autoload, core, game, player, vehicles, world, traffic, npc, police, missions, ui, save, debug) |
| `scenes/` | Einstiegsszenen (Hauptmenü, Spiel); Inhalte entstehen zur Laufzeit aus Daten |
| `data/` | Datengetriebene Inhalte: Karte (`world/`), Fahrzeuge (`vehicles/`), Missionen (`missions/`) |
| `assets/` | Shader, Audio, Icons (selbst erzeugt) |
| `tests/` | Automatisierte Unit- und Integrationstests |

## Werkzeuge & Betrieb
| Ordner | Inhalt |
|---|---|
| `scripts/` | Start-, Build-, Test- und Setup-Skripte (Windows/Linux) |
| `tools/` | Generatoren (Audio, Icon) – nicht Teil des Spiels |
| `config/` | Toolchain-Versionen, keine Secrets |
| `artifacts/` | Screenshots je Meilenstein (`screenshots/A`–`G`, `H_export_pck` = aus dem exportierten Paket) und Test-/Exportlogs |
| `backups/` | Dateisicherungen vor Änderungen |
| `logs/`, `tmp/` | lokal, nicht versioniert |
| `sensitive/` | leer – Projekt benötigt keine Zugangsdaten |
| `_inventory/` | Werkzeug-Inventar |
| `_quarantine/` | ungeprüfte Dateien (leer) |
| `build/` | lokale Build-Ausgabe `build/windows/Faecherstadt.exe` + `.pck`, ZIP (nicht versioniert) |
| `release/` | freigegebene Auslieferung (versioniert, Nutzerentscheidung 2026-09-23), `.gdignore` |
