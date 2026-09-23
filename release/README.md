# Download: Fächer-City v0.1.0 (Windows x64)

| Datei | Inhalt |
|---|---|
| `Faecherstadt_Windows_x64_v0.1.0.zip` | Spiel: `Faecherstadt/Faecherstadt.exe` + `Faecherstadt.pck` + README, Steuerung, Lizenzen |
| `GTA_KA_installieren_und_starten.bat` | entpackt nach `C:\GTA_KA`, prüft die Prüfsumme, startet das Spiel |
| `SHA256SUMS.txt` | SHA256-Prüfsumme des ZIP |

Schritt-für-Schritt-Anleitung: [../ANLEITUNG.md](../ANLEITUNG.md).

Build vom 2026-09-23 (Godot 4.7.2-stable, Release-Export), Quellstand Branch `claude/confident-volta-6a71kc`,
Build-Prüfung in [../TEST_REPORT.md](../TEST_REPORT.md). **Auf echtem Windows noch nicht gestartet** – Prototyp.

Hinweis für Entwickler: Dieser Ordner ist die bewusst versionierte Auslieferung (Nutzerentscheidung 2026-09-23);
`build/` bleibt unversioniert. Neue Versionen: `scripts/linux/build_windows.sh`, ZIP hierher kopieren, `SHA256SUMS.txt`
und Hash in der `.bat` aktualisieren. Die `.gdignore` verhindert, dass Godot den Ordner importiert oder exportiert.
