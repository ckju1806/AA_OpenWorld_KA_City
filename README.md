# Fächer-City: Asphalt & Schatten

3D-Open-World-Spiel (Third-Person, Fahren, Verkehr, ÖPNV, Passanten, Tiere, Polizei, Aufträge) in **Karlsruhe im Maßstab
1:1**. Eigenständiges Projekt mit eigener Identität – keine Inhalte, Namen, Logos, Figuren, Musik, Menüs oder Cheat-Codes aus
anderen Spielen. Alle Figuren, Firmen und Gruppen sind erfunden.

> Stand: Version **0.2.0** (Vorabversion). Was getestet ist und was nicht, steht in [TEST_REPORT.md](TEST_REPORT.md);
> Einschränkungen in [KNOWN_ISSUES.md](KNOWN_ISSUES.md). **Der Windows-Build wurde nicht auf echtem Windows gestartet.**

## Inhalt

- **Karte 1:1** über den gesamten Ausschnitt (≈ 17 × 10 km: Neureut bis Rüppurr, Rheinhafen bis Durlach), gestreamt in
  256-m-Sektoren mit Fernsicht-LOD. Kartengrundlage und Quellen: [docs/KARTE_KARLSRUHE.md](docs/KARTE_KARLSRUHE.md).
- **Prioritätsorte:** Schloss, Zirkel/Fächer, Marktplatz mit Pyramide, Kaiserstraße, Europaplatz, Kronenplatz, Durlacher und
  Ettlinger Tor, Hauptbahnhof, Zoo, Botanischer Garten, Stadion, Rheinhafen mit Kränen, Durlach mit Turmberg, Staatstheater.
- **Grafik:** Tag/Nacht mit Sonne und Mond, Wetter (klar, bewölkt, Regen mit nassen Straßen, Nebel), Fassaden-/Asphalt-/
  Wasser-/Laub-Shader, Qualitätsstufen Niedrig–Ultra und benutzerdefiniert.
- **ÖPNV:** Stadtbahn und Busse im Takt, **U-Strab-Tunnel** mit U-Stationen und Rampen, Haltestellen mit Fahrgästen;
  selbst mitfahren (Fahrschein 3 €, Haltewunsch).
- **Leben in der Stadt:** Verkehr mit Ampeln und Einbahnstraßen, Passanten, Zoo-Tiere, Enten, Tauben, Hunde, Katzen.
- **Ereignisse:** fiktive Gruppen mit Revieren, Rangeleien, Diebstähle, Straßenrennen, Kundgebungen, Polizeikontrollen;
  Polizei mit Fahndungsstufen, Einsätzen und Sperren – alles einzeln abschaltbar.
- **Aufträge:** Kampagne mit 15 Aufträgen bei fünf fiktiven Auftraggebern (Verfolgen, Beschützen, Beobachten, Sammeln,
  Liefern, Sabotage, Taxi, ÖPNV …) und wiederholbare Jobs (Kurier, Taxi, Lieferrunde); Auftragsliste (J), Ruf je Gruppe.
- **Cheats:** 40 eigene deutsche Codes (Konsole `^` oder direkt tippen, `HILFE` listet alle), abschaltbar.
- **Optionen:** Grafik, Audio, Steuerung mit freier Tastenbelegung, Gameplay (Dichten, Polizei, Ereignisse, Zeit, Wetter),
  Barrierefreiheit (Untertitel, Schriftgröße, HUD-Deckkraft, Farbfehlsicht-Filter, vereinfachte Aufträge).

## Spielen (Windows 10/11, 64 Bit)

**Download:** GitHub-Seite des Projekts → **Releases** → neueste Version: `Faecherstadt_Windows_x64_v0.2.0.zip` und
`GTA_KA_installieren_und_starten.bat`. Schritt-für-Schritt: [ANLEITUNG.md](ANLEITUNG.md).

1. Beide Dateien in denselben Ordner laden, die `.bat` doppelklicken → Installation nach `C:\GTA_KA` (mit Prüfsumme) und Start.
2. Von Hand: ZIP entpacken, `Faecherstadt\Faecherstadt.exe` starten – **`Faecherstadt.pck` muss daneben liegen**.
3. Windows SmartScreen kann warnen („Weitere Informationen“ → „Trotzdem ausführen“); das Programm ist nicht code-signiert.

Mindestvoraussetzung (Annahme, nicht gemessen): Grafikkarte mit Vulkan 1.2 oder Direct3D 12; sonst versucht Godot
automatisch OpenGL 3.3. Bei Leistungsproblemen Einstellungen → Grafik → „Niedrig“, Sichtweite und Dichten verringern.

Steuerung: [CONTROLS.md](CONTROLS.md).

## Spielstände und Einstellungen

- Windows: `%APPDATA%\Faecherstadt\` (`savegame.json`, Sicherungskopie `savegame.bak.json`, `settings.cfg`).
- Linux: `~/.local/share/Faecherstadt/`.
- Speichern: Pausenmenü → „Spiel speichern“; automatisch nach abgeschlossenen Aufträgen (abschaltbar) und beim Verlassen.
- Gespeichert wird ein **sicherer Fortsetzungspunkt** inkl. Tageszeit, Wetter, Ruf; laufende Aufträge beginnen nach dem Laden
  beim Auftraggeber neu, bei aktiver Fahndung gilt der letzte sichere Punkt.
- Beschädigter Spielstand → automatisch die Sicherungskopie; beide unlesbar → Meldung im Hauptmenü.
- Spielstände aus v0.1 werden geladen (fehlende Felder erhalten Standardwerte; Positionen der alten Karte liegen ggf. anders).

## Entwicklung

Voraussetzung: **Godot 4.7.2-stable** (Standard, nicht .NET), für die Welt-Pipeline Python 3.11 mit `shapely`, `numpy`,
`pillow`. Keine Plugins, keine kostenpflichtigen Dienste.

| Aufgabe | Linux | Windows |
|---|---|---|
| Godot + Templates einrichten (SHA512-geprüft) | `scripts/linux/setup_godot.sh` | Godot 4.7.2 manuell; Templates über den Editor |
| Spiel aus dem Projekt starten | `godot --path .` | `scripts\windows\start_game.bat` |
| Alle Tests / gefiltert | `scripts/linux/run_tests.sh [datei[::test_präfix]]` | `scripts\windows\run_tests.bat` |
| Windows-Build + ZIP | `scripts/linux/build_windows.sh` | `scripts\windows\build_windows.bat` |
| Release-Dateien (ZIP, Installer mit Prüfsumme, SHA256SUMS) | `scripts/linux/package_release.sh` | – |
| Screenshot-Tour | `scripts/linux/screenshot_tour.sh <Ordner> [city] [B] [H] [nur=teil1,teil2]` | – |
| Weltdaten erzeugen | `python3 tools/worldgen/build_world.py --source authored` bzw. `--source osm` (nach `fetch_osm.py`) | – |
| Speicherbudget prüfen | `python3 tools/check_repo_budget.py --staged` | – |

**Releases:** Builds liegen nie im Repository (Speicherbudget), sondern als Anhang eines GitHub-Releases. Der Workflow
`.github/workflows/windows-release.yml` baut unter Linux, führt die Unit-Tests aus und veröffentlicht ZIP, Installer und
Prüfsummen (Auslöser: manuell oder Commit-Nachricht mit `[release]`).

Kommandozeilen-Optionen nach `--`: `--autostart`, `--world=test`, `--no-ambient` (ohne Verkehr/Passanten/ÖPNV),
`--screenshot-tour --shot-dir=<Pfad> [--tour-only=a,b]`.

Weiterführend: [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md), [docs/PLAN_V2.md](docs/PLAN_V2.md), [docs/ARBEITSLOG.md](docs/ARBEITSLOG.md),
[INHALTSVERZEICHNIS.md](INHALTSVERZEICHNIS.md), [ASSET_LICENSES.md](ASSET_LICENSES.md).

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| Start bricht sofort ab / schwarzes Fenster | Grafiktreiber aktualisieren; `Faecherstadt.exe --rendering-driver opengl3` testen |
| „Faecherstadt.pck nicht gefunden“ | `.pck` neben die `.exe` legen |
| Maus „gefangen“ | Esc öffnet das Pausenmenü und gibt die Maus frei |
| Ruckeln | Grafik „Niedrig“, Sichtweite/Verkehr/Passanten/Tiere verringern, V-Sync prüfen |
| Taste belegt/Konflikt | Einstellungen → Tastenbelegung → „Standard wiederherstellen“ |
| Spielstand defekt | Sicherungskopie wird automatisch geladen; sonst Dateien in `%APPDATA%\Faecherstadt\` löschen |

## Zugangsdaten

Das Projekt benötigt **keine** Zugangsdaten, Tokens oder Online-Dienste. Es gibt daher keine Einträge für Passbolt,
`doku.md` oder `passwords.xlsx`.

## Lizenz

Code: MIT ([LICENSE](LICENSE)). Assets selbst erstellt – siehe [ASSET_LICENSES.md](ASSET_LICENSES.md). Bei Weltdaten aus
OpenStreetMap: © OpenStreetMap-Mitwirkende, ODbL 1.0.
