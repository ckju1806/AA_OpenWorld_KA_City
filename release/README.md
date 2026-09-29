# Downloads

Spielversionen liegen **nicht mehr im Repository** (GitHub-Speicherbudget), sondern als Anhang von GitHub-Releases:

| Version | Wo | Inhalt |
|---|---|---|
| **v0.2.0** (aktuell, Vorabversion) | [Releases → v0.2.0](https://github.com/ckju1806/AA_OpenWorld_KA_City/releases/tag/v0.2.0) | `Faecherstadt_Windows_x64_v0.2.0.zip`, `GTA_KA_installieren_und_starten.bat`, `SHA256SUMS.txt` |
| v0.1.0 (Innenstadt-Prototyp) | Git-Historie: `git checkout b648134 -- release/` | ZIP, Installer, Prüfsumme (bis Commit `f6a9595` in diesem Ordner) |

Anleitung: [../ANLEITUNG.md](../ANLEITUNG.md) · Release-Notizen: [RELEASE_NOTES.md](RELEASE_NOTES.md) (werden vom Workflow
`.github/workflows/windows-release.yml` als Beschreibung verwendet).
Die `.gdignore` verhindert, dass Godot diesen Ordner importiert oder exportiert.
