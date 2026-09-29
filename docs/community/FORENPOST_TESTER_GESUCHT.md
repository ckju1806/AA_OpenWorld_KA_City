# Forenpost: Tester und Ideen gesucht

Vorlagen zum Einladen von Testern in Karlsruhe- und Gamer-Foren. Stand: v0.2.2 (2026-09-29).
Vor dem Posten die Platzhalter in `[eckigen Klammern]` ersetzen und die Regeln des jeweiligen Forums prüfen
(Eigenwerbung ist oft nur in bestimmten Unterforen erlaubt).

Hinweise:
- Ab v0.2.2 heißt der Installer `Faecherstadt_installieren_und_starten.bat` (vorher mit Fremdmarken-Kürzel). Keine Vergleiche
  mit bekannten Spielreihen im Titel – das kann als Markenbezug gelesen werden; der Post stellt das Projekt eigenständig vor.
- Alle Aussagen unten stützen sich auf README.md, KNOWN_ISSUES.md und TEST_REPORT.md. Nicht behaupten, dass es flüssig läuft –
  die Leistung auf echter Hardware ist nicht gemessen, der Windows-Start ist nicht auf echtem Windows geprüft.

---

## Variante A – Karlsruhe-Foren (Stadtbezug im Vordergrund)

**Titel:** Karlsruhe 1:1 als Open-World-Spiel – wer hat Lust zu testen?

Hallo zusammen,

ich baue in meiner Freizeit ein kostenloses Open-World-Spiel, das in **Karlsruhe im Maßstab 1:1** spielt: „Fächer-City:
Asphalt & Schatten“. Die Karte ist aus OpenStreetMap erzeugt und reicht von Neureut bis Rüppurr und vom Rheinhafen bis
Durlach – rund 94.000 Gebäude und 45.000 Straßenabschnitte.

Was es schon gibt:
- Schloss, Fächer und Zirkel, Marktplatz mit Pyramide, Kaiserstraße, Europaplatz, Hauptbahnhof, Zoo, Stadion,
  Rheinhafen mit Kränen, Durlach mit Turmberg, Staatstheater
- **Stadtbahn und Busse im Takt – inklusive U-Strab-Tunnel** mit unterirdischen Haltestellen; man kann einsteigen und
  mitfahren (Fahrschein 3 €, Haltewunsch drücken nicht vergessen 😉)
- Autofahren mit Verkehr, Ampeln und Einbahnstraßen, Passanten, Zoo-Tiere, Enten und Tauben
- Tag/Nacht, Regen mit nassen Straßen, Nebel
- 15 Aufträge mit erfundenen Figuren und Gruppen, dazu Nebenjobs als Kurier oder Taxi

Warum ich schreibe: **Ihr kennt die Stadt besser als jede Karte.** Mich interessiert vor allem:
- Wo erkennt ihr euer Viertel wieder – und wo sieht es völlig falsch aus?
- Welche Orte fehlen euch? (Welche Gebäude, Plätze, Kneipen-Ecken, Abkürzungen …)
- Fährt die Bahn da, wo sie fahren soll?
- Was sollte man in Karlsruhe unbedingt *machen* können?

Ehrlich gesagt: Das ist eine **Vorabversion**. Gebäude sind überwiegend automatisch aus Grundrissen erzeugt, es gibt keine
Innenräume, und wie gut es auf normalen Rechnern läuft, weiß ich noch nicht. Genau dafür brauche ich euch.

**Download (Windows 10/11, 64 Bit, kostenlos, Open Source):**
[Link zur Release-Seite: https://github.com/ckju1806/AA_OpenWorld_KA_City/releases]
Windows zeigt beim Start eine SmartScreen-Warnung, weil das Programm nicht signiert ist („Weitere Informationen“ →
„Trotzdem ausführen“). Der Quellcode ist öffentlich einsehbar.

Rückmeldungen gern hier im Thread, per PN oder als Issue auf GitHub:
[Link: https://github.com/ckju1806/AA_OpenWorld_KA_City/issues]

Hinweis: Alle Personen, Firmen und Gruppen im Spiel sind frei erfunden. Kartendaten © OpenStreetMap-Mitwirkende (ODbL).

Danke und viele Grüße
[Name]

---

## Variante B – Gamer-Foren (Spiel und Technik im Vordergrund)

**Titel:** [Indie / Open Source] Open World in einer echten Stadt (Karlsruhe 1:1) – Tester & Feature-Ideen gesucht

Moin,

ich entwickle als Hobbyprojekt ein Third-Person-Open-World-Spiel in **Godot 4**, dessen Karte eine echte Stadt ist:
Karlsruhe im Maßstab 1:1, generiert aus OpenStreetMap (≈ 17,5 × 10,4 km, ≈ 94k Gebäude), gestreamt in 256-m-Sektoren mit
Fernsicht-LOD.

**Features (v0.2.2):**
- Zu Fuß und im Auto, KI-Verkehr mit Ampeln, Einbahnstraßen und Ausweichen
- ÖPNV-Simulation: Stadtbahnen und Busse nach Takt, U-Bahn-Tunnel, selbst mitfahren
- Polizei mit Fahndungsstufen, Einsätzen und Straßensperren
- Dynamische Ereignisse: Straßenrennen, Diebstähle, Rangeleien zwischen (fiktiven) Gruppen – alles einzeln abschaltbar
- Kampagne mit 15 Aufträgen (Verfolgen, Beschützen, Beobachten, Liefern, Sabotage …) plus wiederholbare Jobs
- Tag/Nacht, Wetter, Grafikstufen Niedrig–Ultra
- 40 eigene Cheat-Codes, freie Tastenbelegung, Barrierefreiheit-Optionen (Untertitel, Schriftgröße, Farbfehlsicht-Filter)

**Was ich suche:**
1. **Tester mit Windows 10/11** – ganz wichtig: Ich entwickle unter Linux, der Windows-Build ist **noch nie auf echtem
   Windows gestartet worden**. Startet es bei euch überhaupt?
2. **Leistungswerte:** Grafikkarte/CPU/RAM, Qualitätsstufe, grobe FPS (Innenstadt vs. Stadtrand)
3. **Fahrgefühl & Spaß:** Fühlt sich das Fahren gut an? Sind die Aufträge zu leicht, zu schwer, zu langweilig?
4. **Ideen für die Erweiterung:** Was würdet ihr als Nächstes sehen wollen? (Innenräume? Mehr Fahrzeuge? Multiplayer?
   Mehr Nebenbeschäftigungen?)
5. **Bugs** – gern mit Screenshot und kurzer Beschreibung, was ihr gerade gemacht habt

**Download:** [https://github.com/ckju1806/AA_OpenWorld_KA_City/releases]
Kostenlos, MIT-Lizenz, keine Werbung, keine Datensammlung. Nicht code-signiert → SmartScreen-Warnung beim ersten Start.

**Bekannte Baustellen** (damit ihr nicht umsonst meldet): keine Innenräume, prozedurale Gebäude, KI-Autos wechseln auf
mehrspurigen Straßen keine Spur, Performance ungemessen. Vollständige Liste: KNOWN_ISSUES.md im Repo.

Feedback bitte hier oder als GitHub-Issue: [https://github.com/ckju1806/AA_OpenWorld_KA_City/issues]

Danke fürs Reinschauen!
[Name]

---

## Variante C – Kurzfassung (Discord, Reddit-Kommentar, Social Media)

Ich baue ein kostenloses Open-World-Spiel in **Karlsruhe 1:1** (Godot 4, Karte aus OpenStreetMap): Autofahren,
Stadtbahn inkl. U-Strab zum Mitfahren, Polizei, 15 Aufträge, Tag/Nacht & Wetter. Suche **Windows-Tester** (Build noch
nie auf echtem Windows gestartet!) und Ideen, was als Nächstes rein soll. Download & Feedback:
[https://github.com/ckju1806/AA_OpenWorld_KA_City]

---

## Optional: Fragebogen für Tester (zum Anhängen)

```
System: Windows-Version / CPU / Grafikkarte / RAM
Startet das Spiel?  ja / nein (Fehlermeldung: …)
Qualitätsstufe:     Niedrig / Mittel / Hoch / Ultra
FPS ca.:            Innenstadt … / Stadtrand …
Was hat Spaß gemacht?
Was hat genervt?
Welcher Ort in Karlsruhe fehlt oder stimmt nicht?
Wunsch-Feature Nr. 1:
```
