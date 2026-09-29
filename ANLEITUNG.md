# Anleitung: Fächer-City herunterladen, installieren und spielen (v0.2)

Für Windows 10/11 (64 Bit). Keine Zusatzsoftware, kein Konto, keine Internetverbindung beim Spielen.

> **Wichtig:** Der Windows-Build wird automatisiert erstellt und technisch geprüft, aber wurde **noch nicht auf einem echten
> Windows-PC gestartet** (siehe [TEST_REPORT.md](TEST_REPORT.md)). Rückmeldungen sind ausdrücklich erwünscht – Abschnitt 8.

## 1. Herunterladen (GitHub-Release)

Die Spieldateien liegen **nicht** im Quellcode-Ordner, sondern als Anhang eines Releases (spart Speicherplatz im Repository):

1. Auf der GitHub-Seite des Repositorys rechts auf **Releases** klicken (oder `…/releases` an die Adresse anhängen).
2. Beim neuesten Eintrag (z. B. **v0.2.0**, als „Pre-release“ markiert) unter **Assets** herunterladen:

| Datei | Zweck |
|---|---|
| `Faecherstadt_Windows_x64_v0.2.0.zip` | das Spiel |
| `GTA_KA_installieren_und_starten.bat` | Installation nach `C:\GTA_KA` mit Prüfsummenkontrolle und Start |
| `SHA256SUMS.txt` | Prüfsummen (optional) |

Beide Hauptdateien müssen im **selben Ordner** liegen (typisch: **Downloads**).

Die ältere Version 0.1.0 (kleiner Innenstadt-Prototyp) liegt in der Git-Historie (siehe [`release/README.md`](release/README.md)).

## 2. Installieren und starten – Variante A (empfohlen, automatisch)

1. `GTA_KA_installieren_und_starten.bat` doppelklicken.
2. Falls Windows warnt („Der Computer wurde durch Windows geschützt“): **Weitere Informationen → Trotzdem ausführen**
   (nicht digital signiert – bei Hobbyprojekten üblich).
3. Das Skript legt `C:\GTA_KA` an, kopiert das ZIP dorthin, **prüft die SHA256-Prüfsumme**, entpackt nach
   `C:\GTA_KA\Faecherstadt\` und startet `Faecherstadt.exe`.

Später direkt starten: `C:\GTA_KA\Faecherstadt\Faecherstadt.exe` (Rechtsklick → „Senden an“ → „Desktop“).

## 3. Installieren – Variante B (von Hand)

1. Ordner `C:\GTA_KA` anlegen, das ZIP dorthin kopieren, Rechtsklick → **Alle extrahieren…** → `C:\GTA_KA`.
2. `C:\GTA_KA\Faecherstadt\Faecherstadt.exe` starten. **`Faecherstadt.pck` muss im selben Ordner wie die `.exe` liegen.**

Prüfsumme selbst kontrollieren (Eingabeaufforderung), Ergebnis mit `SHA256SUMS.txt` vergleichen:
```
certutil -hashfile C:\GTA_KA\Faecherstadt_Windows_x64_v0.2.0.zip SHA256
```

## 4. Systemvoraussetzungen (Annahme, nicht gemessen)

- Windows 10 oder 11, 64 Bit; Grafikkarte mit Vulkan 1.2 oder Direct3D 12 (sonst automatisch OpenGL 3.3)
- ca. 300 MB freier Speicher, 8 GB RAM empfohlen (große, gestreamte Stadt)
- Tastatur und Maus (kein Gamepad)

## 5. Erste Schritte im Spiel

1. Hauptmenü → **Neues Spiel**. Du startest am **Marktplatz** mit Blick auf das Schloss.
2. **J** öffnet die **Auftragsliste**: Dort siehst du alle Aufträge und kannst einen **Wegpunkt** zum Auftraggeber setzen.
   Der erste Auftrag kommt von **Hanne** (Fächerblitz-Kurier) in der Südendstraße (Südweststadt). Auf Minikarte und Karte (**M**)
   markieren orange Rauten (◆) die Auftraggeber. Hingehen und **E** drücken.
3. Unterwegs: Autos mit **F** nehmen (markierte fremde Fahrzeuge interessieren die Polizei), oder an einer **Haltestelle** mit **E**
   in Stadtbahn/Bus einsteigen (3 €); **E** während der Fahrt = Ausstieg an der nächsten Haltestelle.
4. **Esc** öffnet das Pausenmenü (Speichern, Einstellungen inkl. Tastenbelegung, Steuerung). **F3** zeigt Bildrate und Technikdaten.
5. **^** öffnet die Cheat-Konsole (`HILFE` listet die eigenen Codes; in den Einstellungen abschaltbar).

Wichtigste Tasten (vollständig in [CONTROLS.md](CONTROLS.md)):

| Zu Fuß | | Im Fahrzeug | |
|---|---|---|---|
| W A S D | bewegen | W / S | Gas / Bremse, rückwärts |
| Maus | umsehen | A / D | lenken |
| Umschalt | rennen | Leertaste | Handbremse |
| Leertaste | springen | H / L / C | Hupe / Licht / Rückblick |
| E | sprechen, interagieren, einsteigen (ÖPNV) | R | Fahrzeug bergen |
| F | ins Auto einsteigen | F | aussteigen (langsam) |

## 6. Spielstände, Einstellungen, Deinstallation

- Spielstände und Einstellungen: `%APPDATA%\Faecherstadt\` (in die Adresszeile des Explorers eingeben).
- Gespeichert wird über das Pausenmenü und automatisch nach erledigten Aufträgen (abschaltbar).
- **Deinstallieren:** Ordner `C:\GTA_KA` löschen; für Spielstände zusätzlich `%APPDATA%\Faecherstadt`.
  Keine Registry-Einträge, kein Hintergrunddienst.

## 7. Fehlerbehebung

| Problem | Lösung |
|---|---|
| Die `.bat` meldet „Prüfsumme stimmt NICHT“ | ZIP erneut herunterladen (Download unvollständig) |
| Die `.bat` findet das ZIP nicht | ZIP und `.bat` in denselben Ordner legen |
| Schwarzes Fenster / Absturz beim Start | Grafiktreiber aktualisieren; in `C:\GTA_KA\Faecherstadt` `Faecherstadt.exe --rendering-driver opengl3` starten |
| „PCK nicht gefunden“ | `Faecherstadt.pck` liegt nicht neben der `.exe` – ZIP vollständig entpacken |
| Ruckeln | Esc → Einstellungen → Grafik „Niedrig“, Sichtweite, Verkehr, Passanten und Tiere verringern |
| Tasten vertauscht | Einstellungen → Tastenbelegung → „Tastenbelegung zurücksetzen“ |
| Maus „gefangen“ | Esc drücken |
| Virenscanner schlägt an | unsignierte Programme werden teils vorsorglich gemeldet; Prüfsumme wie oben kontrollieren |

## 8. Rückmeldung

Hilfreich: Startet das Spiel? Welche Bildrate zeigt **F3** am Marktplatz, beim Fahren und in der U-Strab? Grafikkarte/Windows-
Version? Bei Fehlern ein Screenshot oder der Text der Fehlermeldung. Bekannte Einschränkungen: [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## 9. Selbst bauen (für Entwickler)

Siehe [README.md](README.md), Abschnitt „Entwicklung“ (Godot 4.7.2, `scripts/linux/build_windows.sh` bzw.
`scripts\windows\build_windows.bat`, Release-Workflow `.github/workflows/windows-release.yml`).
