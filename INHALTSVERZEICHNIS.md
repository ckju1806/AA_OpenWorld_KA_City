# Inhaltsverzeichnis – Fächer-City: Asphalt & Schatten

Das Repository ist zugleich das Godot-Projekt (Nutzerentscheidung 2026-09-23, dokumentierte Ausnahme von `projects/active/…`).

## Einstieg
| Datei | Inhalt |
|---|---|
| [ANLEITUNG.md](ANLEITUNG.md) | Download (GitHub-Release), Installation nach `C:\GTA_KA`, erste Schritte, Fehlerbehebung (für Spieler) |
| [release/](release/) | Release-Notizen (`RELEASE_NOTES.md`) und Altstand v0.1.0; neue Builds nur als GitHub-Release-Anhang |
| [README.md](README.md) | Überblick, Voraussetzungen, Start, Build, Spielstände, Fehlerbehebung |
| [CONTROLS.md](CONTROLS.md) | Steuerung |
| [TEST_REPORT.md](TEST_REPORT.md) | Durchgeführte / nicht durchgeführte / blockierte Prüfungen |
| [KNOWN_ISSUES.md](KNOWN_ISSUES.md) | Bekannte Probleme |
| [ASSET_LICENSES.md](ASSET_LICENSES.md) | Herkunft und Lizenz aller Assets |
| [LICENSE](LICENSE) | MIT-Lizenz des Projekts |

## Dokumentation (`docs/`)
| Datei | Inhalt |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Plan v0.1 (Prototyp, abgeschlossen) |
| [docs/PLAN_V2.md](docs/PLAN_V2.md) | Plan v2: Großausbau Karlsruhe 1:1 (Meilensteine W1–W12, Status) |
| [docs/ARBEITSLOG.md](docs/ARBEITSLOG.md) | Fortlaufender Arbeitsstand, Restore-Punkte |
| [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) | Module, Datenfluss, Welt-Pipeline, ÖPNV, Physik-Layer, Speicherformat, Tests |
| [docs/KARTE_KARLSRUHE.md](docs/KARTE_KARLSRUHE.md) | Kartengrundlage 1:1: Näherung vs. OpenStreetMap, Koordinaten, Prioritätsorte, ÖPNV, Abweichungen |
| [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md) | Entwicklungsübersicht und nächste Schritte |

## Spielprojekt
| Ordner | Inhalt |
|---|---|
| `project.godot`, `export_presets.cfg` | Godot-Projekt- und Exportkonfiguration |
| `src/` | GDScript-Quellcode, getrennt nach Systemen (autoload, core, game, player, vehicles, world, traffic, npc, animals, events, police, transit, missions, ui, save, debug) |
| `scenes/` | Einstiegsszenen (Hauptmenü, Spiel); Inhalte entstehen zur Laufzeit aus Daten |
| `data/` | Datengetriebene Inhalte: Weltdaten Karlsruhe 1:1 (`world/ka/`: `world.json.gz` Straßengraph/POIs/Landmarken/ÖPNV, `sectors/` 256-m-Sektoren, `lod/` Fernsicht-Kacheln, `map.webp` Übersichtskarte – erzeugt von `tools/worldgen/`), Zoo-Gehege und fiktive Gruppen (`world/`), Tierarten (`animals/`), Fahrzeuge (`vehicles/`), Missionen M1–M15 (`missions/`) |
| `assets/` | Shader, Audio, Icons (selbst erzeugt) |
| `tests/` | Automatisierte Unit- und Integrationstests |

## Werkzeuge & Betrieb
| Ordner | Inhalt |
|---|---|
| `scripts/` | Start-, Build-, Test- und Setup-Skripte (Windows/Linux) |
| `tools/` | Generatoren (Audio, Icon) – nicht Teil des Spiels |
| `tools/worldgen/` | Welt-Pipeline (Python: shapely/numpy/pillow): Quellen `ka_authored.py` (1:1-Näherung) und `source_osm.py` (OpenStreetMap, Abruf `fetch_osm.py`), `network.py`, `blocks.py`, `transit.py`, `export.py`, `validate_world.py`, Aufruf `build_world.py` |
| `tools/release/` | Vorlage des Installers (`installer_template.bat`, Name/Prüfsumme werden beim Paketieren eingesetzt) |
| `.github/workflows/` | `windows-release.yml`: Windows-Build + GitHub-Release (manuell oder Commit mit `[release]`) |
| `tools/check_repo_budget.py` | Prüft das GitHub-Speicherbudget (Repo < 300 MB, Weltdaten ≤ 40 MB, Dateien ≤ 5 MB) vor Commits |
| `config/` | Toolchain-Versionen, keine Secrets |
| `artifacts/` | Screenshots je Meilenstein (`screenshots/A`–`G`, `H_export_pck` = aus dem exportierten Paket); Test-Logs entstehen lokal unter `artifacts/test-logs/` (seit Phase 2 nicht mehr versioniert) |
| `backups/` | Dateisicherungen vor Änderungen |
| `logs/`, `tmp/` | lokal, nicht versioniert |
| `sensitive/` | leer – Projekt benötigt keine Zugangsdaten |
| `_inventory/` | Werkzeug-Inventar |
| `_quarantine/` | ungeprüfte Dateien (leer) |
| `build/` | lokale Build-Ausgabe `build/windows/Faecherstadt.exe` + `.pck`, ZIP (nicht versioniert) |
| `release/` | Release-Notizen und Altstand v0.1.0 (`.gdignore`); v0.2+ als GitHub-Release (Speicherbudget) |
