# Anleitung: Fächer-City herunterladen, installieren und spielen

Für Windows 10/11 (64 Bit). Keine Installation von Zusatzsoftware nötig, kein Konto, keine Internetverbindung beim Spielen.

> **Wichtig:** Der Windows-Build wurde erstellt und technisch geprüft, aber noch **nicht auf einem echten Windows-PC gestartet**
> (siehe [TEST_REPORT.md](TEST_REPORT.md)). Rückmeldungen sind ausdrücklich erwünscht – siehe Abschnitt 8.

## 1. Herunterladen (GitHub)

Benötigt werden zwei Dateien aus dem Ordner [`release/`](release/):

| Datei | Zweck |
|---|---|
| `Faecherstadt_Windows_x64_v0.1.0.zip` (ca. 37 MB) | das Spiel |
| `GTA_KA_installieren_und_starten.bat` | Installation nach `C:\GTA_KA` mit Prüfung und Start |

So lädt man eine einzelne Datei herunter:
1. Im Repository den Ordner `release` öffnen und auf die Datei klicken.
2. Rechts oben auf das Download-Symbol („Download raw file“) klicken.
3. Beide Dateien landen typischerweise im Ordner **Downloads** – sie müssen im **selben Ordner** liegen.

Alternativ: grüner Knopf „Code“ → „Download ZIP“ lädt das ganze Repository; darin liegt der Ordner `release`.

## 2. Installieren und starten – Variante A (empfohlen, automatisch)

1. `GTA_KA_installieren_und_starten.bat` doppelklicken.
2. Falls Windows warnt („Der Computer wurde durch Windows geschützt“): **Weitere Informationen → Trotzdem ausführen**.
   (Die Dateien sind nicht digital signiert; das ist bei Hobbyprojekten üblich.)
3. Das Skript
   - legt `C:\GTA_KA` an,
   - kopiert das ZIP dorthin und **prüft die SHA256-Prüfsumme** (erkennt unvollständige Downloads),
   - entpackt nach `C:\GTA_KA\Faecherstadt\`,
   - startet `Faecherstadt.exe`.

Später startest du das Spiel direkt über `C:\GTA_KA\Faecherstadt\Faecherstadt.exe`
(Tipp: Rechtsklick → „Senden an“ → „Desktop (Verknüpfung erstellen)“).

## 3. Installieren – Variante B (von Hand)

1. Ordner `C:\GTA_KA` anlegen.
2. `Faecherstadt_Windows_x64_v0.1.0.zip` dorthin kopieren, Rechtsklick → **Alle extrahieren…** → `C:\GTA_KA`.
3. `C:\GTA_KA\Faecherstadt\Faecherstadt.exe` starten.
   **`Faecherstadt.pck` muss immer im selben Ordner wie die `.exe` liegen.**

Prüfsumme selbst kontrollieren (optional, Eingabeaufforderung):
```
certutil -hashfile C:\GTA_KA\Faecherstadt_Windows_x64_v0.1.0.zip SHA256
```
Erwartet: `794122ba28611caf96e3a35afa35e835990a551589a1e82097bcd21a38013010` (auch in `release/SHA256SUMS.txt`).

## 4. Systemvoraussetzungen (Annahme, nicht gemessen)

- Windows 10 oder 11, 64 Bit
- Grafikkarte mit Vulkan 1.2 oder Direct3D 12 (neuere Intel-/AMD-/NVIDIA-Treiber); sonst versucht das Spiel automatisch OpenGL 3.3
- ca. 250 MB freier Speicher, 4 GB RAM
- Tastatur und Maus (Gamepad wird nicht unterstützt)

## 5. Erste Schritte im Spiel

1. Hauptmenü → **Neues Spiel**. Du startest am Marktplatz mit Blick auf das Schloss.
2. Orange Rauten (◆) auf der Minikarte bzw. Karte (**M**) markieren Auftraggeber. Der erste Auftrag kommt von
   **Hanne** im Kurierhof südwestlich des Marktplatzes – hingehen und **E** drücken.
3. **Esc** öffnet das Pausenmenü (Speichern, Einstellungen, Steuerung). **F3** zeigt Bildrate und Technikdaten.

Wichtigste Tasten (vollständig in [CONTROLS.md](CONTROLS.md)):

| Zu Fuß | | Im Fahrzeug | |
|---|---|---|---|
| W A S D | bewegen | W / S | Gas / Bremse, rückwärts |
| Maus | umsehen | A / D | lenken |
| Umschalt | rennen | Leertaste | Handbremse |
| Leertaste | springen | H / L | Hupe / Licht |
| E | sprechen, interagieren | R | Fahrzeug bergen |
| F | einsteigen | F | aussteigen (langsam) |

## 6. Spielstände, Einstellungen, Deinstallation

- Spielstände und Einstellungen: `%APPDATA%\Faecherstadt\` (in die Adresszeile des Explorers eingeben).
- Gespeichert wird über das Pausenmenü und automatisch nach jedem erledigten Auftrag.
- **Deinstallieren:** Ordner `C:\GTA_KA` löschen; wer auch Spielstände entfernen will, zusätzlich `%APPDATA%\Faecherstadt`.
  Es gibt keine Registry-Einträge und keinen Hintergrunddienst.

## 7. Fehlerbehebung

| Problem | Lösung |
|---|---|
| Die `.bat` meldet „Prüfsumme stimmt NICHT“ | ZIP erneut herunterladen (Download war unvollständig) |
| Die `.bat` findet das ZIP nicht | ZIP und `.bat` in denselben Ordner legen |
| Schwarzes Fenster / Absturz beim Start | Grafiktreiber aktualisieren; Eingabeaufforderung in `C:\GTA_KA\Faecherstadt` öffnen und `Faecherstadt.exe --rendering-driver opengl3` starten |
| „PCK nicht gefunden“ | `Faecherstadt.pck` liegt nicht neben der `.exe` – ZIP vollständig entpacken |
| Ruckeln | Esc → Einstellungen → Qualität „Niedrig“, Verkehrsdichte senken (wirkt ab nächstem Start vollständig) |
| Maus „gefangen“ | Esc drücken |
| Virenscanner schlägt an | unsignierte Programme werden teils vorsorglich gemeldet; Prüfsumme wie oben kontrollieren |

## 8. Rückmeldung

Hilfreich sind: Startet das Spiel? Welche Bildrate zeigt **F3** am Marktplatz und beim Fahren? Grafikkarte/Windows-Version?
Bei Fehlern ein Screenshot oder der Text der Fehlermeldung. Bekannte Einschränkungen: [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## 9. Optional: als GitHub-Release veröffentlichen

Ein „Release“ macht den Download auf der Startseite des Repositorys sichtbarer:
1. Im Repository rechts auf **Releases → Create a new release**.
2. **Choose a tag** → `v0.1.0` eintippen → „Create new tag“.
3. Titel: `Fächer-City v0.1.0 (Prototyp)`.
4. Die Dateien aus `release/` (ZIP, `.bat`, `SHA256SUMS.txt`) in das Feld „Attach binaries“ ziehen.
5. Häkchen **Set as a pre-release** (noch ungetestet unter Windows) → **Publish release**.

## 10. Selbst bauen (für Entwickler)

Siehe [README.md](README.md), Abschnitt „Entwicklung“ (Godot 4.7.2, `scripts/windows/build_windows.bat`).
