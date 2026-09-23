# Arbeitslog – Fächer-City: Asphalt & Schatten

Fortlaufender Planstand und Umsetzungsnachweis. Jeder Meilenstein endet mit einem Commit (= Restore-Punkt).

## Restore-Punkte

| Datum | Commit | Stand |
|---|---|---|
| 2026-09-23 | `75fe4ae` | Ausgangsstand (nur LICENSE + README) |

## 2026-09-23 – Meilenstein 0: Absicherung, Struktur, Toolchain

- **Ziel:** Arbeitsumgebung, Ablagestruktur und Dokumentation vor der Umsetzung herstellen.
- **Änderungsklasse:** groß (neues Projekt, neue Toolchain) → Restore-Punkt = Commit `75fe4ae` + Dateibackup `backups/2026-09-23_README.orig.md`.
- **Annahmen:** Container ist ephemer; Systempakete (mesa-vulkan-drivers) betreffen nur den Container.
- **Durchgeführt:**
  - Godot 4.7.2-stable Editor + Export-Templates geladen, SHA512 gegen offizielle Liste: **OK**.
  - Nur Windows-x64-Templates installiert (Platz sparen).
  - `mesa-vulkan-drivers` (lavapipe) installiert → Vulkan-Softwarerendering unter Xvfb für Screenshots.
  - Top-Level-Struktur mit `.gdignore` in Nicht-Spiel-Ordnern angelegt; Ordner-READMEs.
- **Abweichung Zielstruktur:** Godot-Projekt im Repo-Root statt `projects/active/…` (Nutzerentscheidung vom 2026-09-23).
- **Zugangsdaten:** keine benötigt → keine Passbolt-/passwords.xlsx-Einträge.

## 2026-09-23 – Meilenstein A: Projektgerüst, Spielfigur, Kamera, Testrunner

- **Ziel:** startfähiges Godot-4.7.2-Projekt mit Spielfigur, Kamera, Testgelände und automatisierten Tests.
- **Änderungsklasse:** mittel (nur neue Dateien) → Restore-Punkt: Commit von Meilenstein 0 (`1be5ddd`).
- **Umgesetzt:** `project.godot` (Jolt, Forward+ mit GL-Fallback, eigener user-Ordner `Faecherstadt`), Autoloads
  (EventBus, Settings inkl. Tastenbelegung, GameState, SaveManager + SaveCodec, AudioManager, App),
  Kernhilfen (MeshKit, PolyUtil, MatLib, DetRng, Layers), prozedurale Figur (HumanoidRig), Player (Stufensteigen,
  Sprung, Sturzschaden, Lebenspunkte, Regeneration, Interaktions-/Fahrzeug-Hinweise), PlayerCamera (SpringArm,
  weicher Moduswechsel), Testgelände, Mini-Testrunner, Screenshot-Tour, eigenes Icon (SVG/ICO, generiert).
- **Prüfung:** `scripts/linux/run_tests.sh` → 23/23 Tests bestanden (Unit: GameState, SaveCodec, PolyUtil;
  Integration: Bodenhaftung, Gehen/Sprinten, Bordstein, Sprung, Schaden, Kamera-Kollision).
  Screenshot-Tour (Xvfb, lavapipe) visuell geprüft → `artifacts/screenshots/A/`.
- **Gefundene und behobene Fehler:** falsch dimensionierter Bordstein-Test (Laufzeit zu kurz), Kamera-Wand-Test
  prüfte falsche Seite, Jackengeometrie wirkte wie Rucksack.
- **Erkenntnis:** Nach neuen `class_name`-Dateien ist ein `--import` nötig (Skripte machen das automatisch).
