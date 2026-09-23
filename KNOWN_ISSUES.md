# Bekannte Probleme und Einschränkungen (v0.1.0)

## Nicht verifiziert
- **Windows-Start ungetestet:** Der Windows-x64-Build wurde erzeugt und formal geprüft (PE-Header x86_64, PCK-Kennung,
  Bootstest und Screenshot-Tour der PCK unter Linux – siehe TEST_REPORT.md), aber **nicht auf echtem Windows gestartet**.
  Ein Rauchtest unter Wine war blockiert (Wine 9.0 startet bereits das unveränderte offizielle Godot-Template nicht).
- **Leistung auf echter Hardware unbekannt:** Alle grafischen Prüfungen liefen mit Software-Rendering (Xvfb + Mesa lavapipe,
  ca. 4 FPS). Diese Werte sind nicht aussagekräftig. Ziel 60 FPS auf Mittelklasse-Hardware ist **nicht gemessen**.
- **Fahrgefühl** ist nur über messbare Kriterien getestet (Beschleunigung, Lenkung, Bremsen, kein Überschlag), nicht subjektiv.
- **Echte Flucht vor der Polizei-KI** ist nicht automatisiert getestet; der Test „Fahndung abschütteln“ versetzt das Fahrzeug
  außer Sicht und prüft dann die echte Such- und Abbaulogik.
- **Windows-Skripte** (`scripts/windows/*.bat`, `*.ps1`) wurden mangels Windows nicht ausgeführt.

## Spielerische Einschränkungen
- Nur Tastatur + Maus, nur Deutsch, kein Gamepad.
- KI-Verkehr: vereinfachte Vorfahrt an ungeregelten Kreuzungen, keine Spurwechsel, keine Überholmanöver. Festgefahrene
  Fahrzeuge setzen zurück und werden außer Sicht entfernt.
- Passanten: einfache Zustandsmaschine (Gehen, Warten, Ausweichen, Flucht, Umgestoßen), keine Ragdoll-Physik.
- Polizei fährt über das Straßennetz (A*) und bei Sichtkontakt direkt auf den Spieler zu; keine Straßensperren, keine Fußstreifen.
- Fahrzeuge werden nicht gespeichert; nach dem Laden steht die Spielfigur zu Fuß am gespeicherten sicheren Punkt.
- Laufende Aufträge werden nicht mitten im Ablauf gespeichert, sondern beginnen nach dem Laden beim Auftraggeber neu.
- Änderungen an „Qualität“ und „Verkehrsdichte“ wirken vollständig erst beim nächsten Spielstart.
- Symbolzeichen auf Karte/HUD (◆ ● ▲ ♥) hängen vom Font-Fallback des Systems ab und könnten auf manchen Systemen
  als Kästchen erscheinen (unter Linux korrekt dargestellt; unter Windows nicht geprüft).
- Die Stadt ist verdichtet und vereinfacht (Straßenverläufe gerade/als Bögen, fiktive Nebenstraßen, Gebäude generisch).

## Technik
- Das Programm ist nicht code-signiert; Windows SmartScreen kann warnen.
- In Testläufen erscheinen beim Beenden Hinweise „ObjectDB instances were leaked at exit“ bzw. „resources still in use“ –
  sie betreffen das Herunterfahren des Test-Runners, nicht den Spielablauf (Ursache nicht weiter untersucht).
- Screenshots der Dokumentation stammen aus Software-Rendering; Farben/Schatten können auf echter GPU leicht abweichen.
