# Geplant, aber noch nicht umgesetzt (Stand v0.2.2, 2026-09-29)

Abgleich von `docs/PLAN_V2.md` und `docs/ENTWICKLUNG.md` („Empfohlene nächste Schritte“) mit `TEST_REPORT.md` und
`KNOWN_ISSUES.md`. Jeder Punkt nennt seine Quelle. Punkte, die in den Quellen als *bewusst ausgelassen* markiert sind,
stehen gesondert.

## 1. Aus Plan v2 offen (Meilenstein W11 „teilweise“)
| Punkt | Geplant in | Ist-Stand (Beleg) |
|---|---|---|
| Spurwechsel auf mehrspurigen Straßen (Überholen/Abbiegen) | PLAN_V2 W11, ENTWICKLUNG Nr. 5 | fehlt (TEST_REPORT W11, KNOWN_ISSUES „KI“) |
| Kreuzungsreservierung statt vereinfachtem „rechts vor links“ | PLAN_V2 W11 | fehlt (dito) |
| Abbiegen mit Prüfung des Gegenverkehrs | ENTWICKLUNG Nr. 5 | nicht belegt → als offen geführt |
| Polizei: Verfolgung mit Abschneiden von Fluchtwegen, koordinierte Suchmuster | PLAN_V2 W7/W11, ENTWICKLUNG Nr. 4 | fehlt; Suche nur am letzten bekannten Ort (KNOWN_ISSUES) |
| Autopilot-NPCs in Aufträgen weichen Hindernissen aus | PLAN_V2 W11 (Umfahren) | Verkehr umfährt, Auftrags-NPCs bremsen nur (KNOWN_ISSUES) |

## 2. Aus „Empfohlene nächste Schritte“ offen
| Punkt | Quelle | Ist-Stand |
|---|---|---|
| Test auf echtem Windows 10/11 (Start, 30 min, FPS mit F3) | ENTWICKLUNG Nr. 1 | **ungetestet** – wichtigster offener Punkt (TEST_REPORT §6) |
| Spielgefühl mit Testpersonen, Fahrzeugwerte/Kamera nachjustieren | ENTWICKLUNG Nr. 2 | ungetestet → Forenpost `docs/community/` |
| Leistungsmessung auf echter GPU, Qualitätsvoreinstellungen danach | ENTWICKLUNG Nr. 3, PLAN_V2 §6 | ungemessen |
| Gamepad-Unterstützung | ENTWICKLUNG Nr. 7 | fehlt (KNOWN_ISSUES „nur Tastatur + Maus“) |
| Code-Signierung des Windows-Builds | ENTWICKLUNG Nr. 8 | fehlt (SmartScreen-Warnung) |
| Weitere Aufträge / Nebenaktivitäten | ENTWICKLUNG Nr. 6 | 15 Aufträge + 3 Jobtypen vorhanden; Erweiterung offen |

## 3. Kleinere offene Punkte aus Testbericht und Known Issues
- Kartenbeschriftung „Hauptbahnhof“ überlappt am unteren Rand die Legende (TEST_REPORT §4).
- U-Strab-Zugänge sind schlichte Blöcke; Rampen schneiden die Straße nicht aus (KNOWN_ISSUES „ÖPNV“).
- Stadtbahn/Busse beachten keine Ampeln; Ein-/Aussteigen der Fahrgäste nur kosmetisch.
- Zwei Wagen können sich an der Tunnel-Endhaltestelle Marktplatz kurz überlappen.
- Fahrzeuge werden nicht gespeichert; laufende Aufträge starten nach dem Laden neu.
- Einige Grafikoptionen wirken erst nach Neuladen der Umgebung.
- Symbolzeichen (◆ ✔ 🔒 ✚) unter Windows nicht geprüft.
- Straßentunnel ausgelassen, Brücken/Unterführungen vereinfacht; Hafenkräne an Näherungsposition.

## 4. Bewusst nicht geplant (keine Lücke, sondern Entscheidung)
- Waffensystem (Cheat „AUSRUESTUNG“ ist Platzhalter) – PLAN_V2 W7.
- Innenräume, individuelle Modelle für alle Gebäude – PLAN_V2 §3 (nur Prioritäts-Landmarken einzeln modelliert).
- Weitere Sprachen: nicht geplant, nur Deutsch (KNOWN_ISSUES).

## 5. Empfohlene Reihenfolge
1. Windows-Start + FPS durch Tester (Forenpost) → Qualitätsvoreinstellungen anpassen.
2. Rückmeldungen zum Fahrgefühl einarbeiten.
3. Verkehrs-KI: Kreuzungsreservierung, dann Spurwechsel.
4. Polizei: Abschneiden/Suchmuster.
5. Gamepad, kleine Schönheitsfehler (Kartenlegende, U-Strab-Zugänge).
