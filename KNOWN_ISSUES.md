# Bekannte Probleme und Einschränkungen (v0.2.2)

Status-Begriffe wie in [TEST_REPORT.md](TEST_REPORT.md): **implementiert**, **teilweise**, **getestet**, **ungetestet**, **blockiert**.

## Nicht verifiziert
- **Windows-Start ungetestet:** Der Windows-x64-Build wird unter Linux erzeugt und formal geprüft (PE-Header, PCK-Kennung),
  aber **nicht auf echtem Windows gestartet** (kein Windows in der Entwicklungsumgebung). Windows-Skripte ebenfalls ungetestet.
- **Leistung auf echter Hardware unbekannt:** Grafikprüfungen laufen mit Software-Rendering (Xvfb + lavapipe, wenige FPS);
  diese Werte sind nicht aussagekräftig. Die Stadt ist ≈ 17 × 11 km groß und wird gestreamt – Ziel 60 FPS auf Mittelklasse-
  Hardware ist **nicht gemessen**. Bei Ruckeln: Qualität „Niedrig“, Sichtweite und Dichten verringern.
- **Fahrgefühl, Balance, Spaß** sind nicht subjektiv geprüft; Missionen werden per Autopilot/Test-Löser durchlaufen
  (Beleg für Abschließbarkeit, nicht für Schwierigkeit).
- Echte Flucht vor Polizei und echte Verfolgungsfahrten sind nicht automatisiert getestet (Tests versetzen das Fahrzeug).

## Karte und Welt
- **Kartengrundlage:** Die Welt wird aus **OpenStreetMap** erzeugt (Abruf 2026-09-29, ODbL): reale Straßen, Gebäudegrundrisse,
  Flächen, Gewässer, Gleise und ÖPNV-Linien. Für die Befahrbarkeit weicht sie bewusst ab (Mindestbreiten, entfernte
  Sackgassen-Stummel, an Fahrbahnen zugeschnittene Gebäude) – Details in `docs/KARTE_KARLSRUHE.md`. Die handgezeichnete
  Näherung (`ka_authored.py`) bleibt als Rückfall ohne Netzzugang erhalten.
- OSM-Daten spiegeln den Datenstand, nicht zwingend die Wirklichkeit (fehlende Gebäudehöhen → typische Höhe je Nutzung).
- Gebäude sind prozedural aus Grundrissen erzeugt (Fassaden-Shader); nur die Prioritäts-Landmarken sind einzeln modelliert.
- Zoo: Die 9 Gehege sind eine eigene, vereinfachte Anordnung, die der Generator auf freie Stellen der realen Zoofläche setzt
  (nicht die realen Gehegestandorte). Hafenkräne stehen an einer Näherungsposition (keine Kran-Objekte in den Kartendaten).
- Zugänge zu U-Strab-Haltestellen sind einfache Baukörper; Verfassungssäule und Durlacher-Tor-Skulptur sind Näherungen.
- Keine Innenräume; Brücken/Unterführungen vereinfacht; Straßentunnel sind ausgelassen.

## ÖPNV
- Fahrzeuge fern vom Spieler fahren „virtuell“ (ohne Physik); nur in Spielernähe gibt es Kollisionskörper.
- Bahnen und Busse beachten keine Ampeln (Vorrang), bremsen aber vor Hindernissen auf dem Gleis bzw. der Spur.
- Stadtbahn und Autos teilen sich teils die Fahrbahn (straßenbündige Gleise wie in der Innenstadt); Autos weichen
  haltenden Bahnen über die Gegenspur aus, sofern frei.
- Rampen zur U-Strab sind als überdachte Rampenbauwerke mit Portal dargestellt (die Straßenoberfläche wird nicht ausgeschnitten).
- An Endhaltestellen im Tunnel (Linie 2, Marktplatz) können sich zwei Wagen kurz überlappen.
- Ein-/Aussteigen der Fahrgäste ist kosmetisch (Figuren gehen zur Tür und werden ausgeblendet).
- Ohne „Umgebungsleben“ (Startoption `--no-ambient`) fahren keine ÖPNV-Fahrzeuge.

## KI
- Verkehr: Einbahnstraßen, Spurversatz je Straße, Ampeln aus Daten, Abstandhalten, **Umfahren stehender Hindernisse** über die
  Gegenspur; **keine** Spurwechsel auf mehrspurigen Straßen, keine Kreuzungsreservierung (vereinfachtes „rechts vor links“).
- Autopilot-Fahrzeuge in Missionen bremsen vor Hindernissen, weichen aber nicht aus.
- Passanten: einfache Zustandsmaschine, keine Ragdoll-Physik; Tiere: Wandern/Flucht/Auffliegen, keine Animationen mit Skelett.
- Polizei: Einsätze zu Ereignissen, Sperren ab Stufe 3, Suche am letzten bekannten Ort; kein Abschneiden von Fluchtwegen.
- Rangeleien sind Umstoßen/Schubsen – **kein Waffensystem** (bewusste Einschränkung).

## Spielerische Einschränkungen
- Nur Tastatur + Maus, nur Deutsch, kein Gamepad.
- Fahrzeuge werden nicht gespeichert; laufende Aufträge beginnen nach dem Laden beim Auftraggeber neu.
- Ein Auftraggeber zeigt zuerst seinen nächsten offenen Kampagnenauftrag; bereits abgeschlossene, wiederholbare Aufträge
  (z. B. „Die Fächer-Runde“) lassen sich jederzeit über die Auftragsliste (J → „Wiederholen“) starten.
- Einige Grafikoptionen (Qualitätsstufe, Dichten) wirken vollständig erst nach dem Neuladen der Umgebung/Spielstart.
- Symbolzeichen auf Karte/HUD (◆ ✔ 🔒 ✚) hängen vom Font-Fallback des Systems ab (unter Windows nicht geprüft).

## Technik
- Nicht code-signiert; Windows SmartScreen kann warnen.
- In Testläufen erscheinen beim Beenden gelegentlich „resources still in use at exit“ – betrifft das Herunterfahren des
  Test-Runners (noch laufende Timer), nicht den Spielablauf.
- Screenshots der Dokumentation stammen aus Software-Rendering; Farben/Schatten können auf echter GPU abweichen.
- Die OSM-Rohdaten werden nicht versioniert (Speicherbudget); nur die daraus erzeugten, kompakten Weltdaten liegen im Repo.
