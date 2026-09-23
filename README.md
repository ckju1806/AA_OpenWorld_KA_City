# Fächer-City: Asphalt & Schatten

Spielbarer 3D-Open-World-Prototyp (Third-Person, Fahren, Verkehr, Passanten, Polizei, drei Aufträge) in einer
**künstlerisch verdichteten Karlsruher Innenstadt**. Eigenständiges Projekt mit eigener Identität – keine Inhalte,
Namen, Logos, Figuren oder Musik aus anderen Spielen. Alle Figuren und Firmen sind erfunden.

> Stand: Version 0.1.0 (Prototyp). Was getestet ist und was nicht, steht in [TEST_REPORT.md](TEST_REPORT.md).
> **Der Windows-Build wurde nicht auf einem echten Windows-System gestartet** (in der Entwicklungsumgebung nicht verfügbar).

## Inhalt

- Innenstadt ca. 1,1 × 1,2 km: Schloss mit Schlossplatz und Schlossgarten, Zirkel, neun Fächerstraßen,
  Marktplatz mit Pyramide, Rathaus und Stadtkirche, Kaiserstraße (mit Fußgängerzone), Europaplatz, Kronenplatz,
  Durlacher Tor, Rondellplatz, Ettlinger Tor, Kriegsstraße und äußerer Ring. Details: [docs/KARTE_KARLSRUHE.md](docs/KARTE_KARLSRUHE.md).
- Spielfigur mit Kamera-Kollisionsschutz, Laufen/Rennen/Springen, Lebenspunkte.
- Fünf Fahrzeugtypen (Kompakt, Limousine, Sportwagen, Transporter, Streifenwagen) mit Arcade-Physik, Schaden,
  Licht, Hupe, Bergung; Übernahme markierter fremder Fahrzeuge.
- Straßenverkehr mit Ampeln, Passanten, Polizei mit Fahndungsstufen 0–3 (nur beobachtete Taten, Suchphase).
- Aufträge: „Erste Schicht“ (Kurier), „Die Fächer-Runde“ (Zeitfahren mit Bestzeit), „Die falsche Lieferung“ (Fahndung abschütteln).
- Hauptmenü, Pause, Einstellungen, Minikarte und Vollkarte, HUD, Speichern/Laden, Entwickleranzeige (F3).

## Spielen (Windows 10/11, 64 Bit)

1. ZIP `Faecherstadt_Windows_x64_v0.1.0.zip` entpacken (Ordner `Faecherstadt`).
2. `Faecherstadt.exe` starten. **`Faecherstadt.pck` muss im selben Ordner liegen.**
3. Windows SmartScreen kann bei unsignierten Programmen warnen („Weitere Informationen“ → „Trotzdem ausführen“).
   Das Programm ist nicht code-signiert.

Mindestvoraussetzung (Annahme, nicht gemessen): Grafikkarte mit Vulkan 1.2 oder Direct3D 12; ohne diese versucht Godot
automatisch OpenGL 3.3. Bei Leistungsproblemen im Menü „Einstellungen“ die Qualität auf „Niedrig“ stellen.

Steuerung: [CONTROLS.md](CONTROLS.md).

## Spielstände und Einstellungen

- Windows: `%APPDATA%\Faecherstadt\` (`savegame.json`, Sicherungskopie `savegame.bak.json`, `settings.cfg`).
- Linux: `~/.local/share/Faecherstadt/`.
- Speichern: Pausenmenü → „Spiel speichern“; automatisch nach jedem abgeschlossenen Auftrag und beim Verlassen über das Pausenmenü.
- Gespeichert wird immer ein **sicherer Fortsetzungspunkt**: Läuft ein Auftrag, beginnt er nach dem Laden beim Auftraggeber neu
  (mit Hinweis); bei aktiver Fahndung wird der letzte sichere Punkt zu Fuß gespeichert.
- Beschädigter Spielstand → automatisch die Sicherungskopie; beide unlesbar → Meldung im Hauptmenü, „Fortsetzen“ deaktiviert.
- Zurücksetzen: Spiel beenden und die Dateien im genannten Ordner löschen.

## Entwicklung

Voraussetzung: **Godot 4.7.2-stable** (Standard-Version, nicht .NET). Keine Plugins, keine kostenpflichtigen Dienste.

| Aufgabe | Linux | Windows |
|---|---|---|
| Godot + Templates einrichten (SHA512-geprüft) | `scripts/linux/setup_godot.sh` | Godot 4.7.2 manuell laden; Templates über den Editor installieren |
| Spiel aus dem Projekt starten | `godot --path .` | `scripts\windows\start_game.bat` |
| Alle Tests | `scripts/linux/run_tests.sh` | `scripts\windows\run_tests.bat` |
| Windows-Build + ZIP | `scripts/linux/build_windows.sh` | `scripts\windows\build_windows.bat` |
| Screenshot-Tour (visuelle Kontrolle) | `scripts/linux/screenshot_tour.sh <Ordner>` | – |

Build-Ergebnis: `build/windows/Faecherstadt.exe` + `build/windows/Faecherstadt.pck`, ZIP unter `build/`
(nicht versioniert). Kommandozeilen-Optionen nach `--`: `--autostart` (Menü überspringen), `--world=test` (Testgelände),
`--no-ambient` (ohne Verkehr/Passanten), `--screenshot-tour --shot-dir=<Pfad>`.

Weiterführend: [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md), [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md),
[INHALTSVERZEICHNIS.md](INHALTSVERZEICHNIS.md), [KNOWN_ISSUES.md](KNOWN_ISSUES.md), [ASSET_LICENSES.md](ASSET_LICENSES.md).

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| Start bricht sofort ab / schwarzes Fenster | Grafiktreiber aktualisieren; `Faecherstadt.exe --rendering-driver opengl3` testen |
| „Faecherstadt.pck nicht gefunden“ | `.pck` neben die `.exe` legen (nicht nur die `.exe` kopieren) |
| Maus „gefangen“ | Esc öffnet das Pausenmenü und gibt die Maus frei |
| Ruckeln | Einstellungen → Qualität „Niedrig“, Verkehrsdichte verringern, V-Sync prüfen |
| Spielstand defekt | Sicherungskopie wird automatisch geladen; sonst Dateien in `%APPDATA%\Faecherstadt\` löschen |

## Zugangsdaten

Das Projekt benötigt **keine** Zugangsdaten, Tokens oder Online-Dienste. Es gibt daher keine Einträge für Passbolt,
`doku.md` oder `passwords.xlsx`.

## Lizenz

Code: MIT ([LICENSE](LICENSE)). Alle Assets sind selbst erstellt – siehe [ASSET_LICENSES.md](ASSET_LICENSES.md).
