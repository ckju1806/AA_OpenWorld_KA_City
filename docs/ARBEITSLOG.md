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

## 2026-09-23 – Meilenstein B: Fahrzeuge, Ein-/Ausstieg, Audio

- **Ziel:** vollständig fahrbares Fahrzeug inkl. Ein-/Ausstieg, danach weitere Typen.
- **Änderungsklasse:** mittel (neue Dateien, keine bestehende Logik ersetzt) → Restore-Punkt: Commit `b619ed7`.
- **Umgesetzt:** `VehicleSpec` + `data/vehicles/vehicles.json` (Kompakt, Limousine, Sport, Transporter, Polizei –
  eigene fiktive Modelle), `VehicleModelBuilder` (Seitenprofil-Extrusion, gecachte Geometrie, Lack per Override),
  `Vehicle` (RigidBody3D mit 4 Raycast-Federbeinen, Quergrip, Handbremse, geschwindigkeitsabhängiger Lenkung,
  Aufrichthilfe, Schaden mit Rauch/Totalschaden, Licht/Bremslicht/Blaulicht, Hupe, Ausstiegsprüfung mit
  Boden-, Wand- und Platztest, Bergung mit Abklingzeit), `Autopilot` (Pure Pursuit).
  Audio-Generator `tools/generate_audio.py` (20 eigene Synthese-Klänge, deterministisch).
- **Prüfung:** 41/41 Tests (u. a. Beschleunigen/Bremsen/Rückwärts, Rechtskurve, Handbremse, 2× Wechsel zwischen
  drei Fahrzeugen, Ausstieg bei Fahrt verweigert, Ausstieg bei Einkesselung verweigert, Crash-Schaden ohne
  Durchdringen der Wand, Bergung nach Überschlag, Autopilot mit Wende). Screenshots: `artifacts/screenshots/B/`.
- **Behobene Testfehler:** Startpositionen im Test (Auffahren auf geparktes Fahrzeug, fehlender Anlauf).
- **Offen:** Fahrgefühl subjektiv nicht beurteilbar (nur messbare Kriterien getestet).
