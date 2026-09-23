# Kartengrundlage „Fächer-City“ – künstlerische Interpretation von Karlsruhe

> **Hinweis:** Die Spielwelt ist eine **verdichtete, künstlerische Interpretation** der Karlsruher Innenstadt und
> **kein digitaler Zwilling**. Maßstab, Straßenverläufe, Gebäude und Nebenstraßen sind vereinfacht bzw. erfunden.
> Es wurden **keine** Geodaten, Kartenkacheln, Luftbilder oder fremden 3D-Stadtmodelle verwendet.
> Der Spielstart benötigt keinen Kartendienst.

## 1. Recherchierte Lagebeziehungen (Stand 2026-09-23)

Direkter Zugriff auf Wikipedia/OpenStreetMap war im Entwicklungscontainer durch die Netzwerkrichtlinie gesperrt.
Die folgenden Fakten wurden über eine Websuche (Suchmaschinen-Zusammenfassungen) ermittelt und sind **nicht**
gegen Primärkarten nachgemessen worden:

| Fakt | Quelle(n) | Umsetzung |
|---|---|---|
| Das Schloss ist Zentrum des „Karlsruher Fächers“; 32 Straßen/Alleen führen strahlenförmig zum Schlossturm, Winkelabstand 11,25°; neun davon führen in die Stadt, die übrigen durch Schlosspark/Hardtwald | [lokalmatador.de – Schloss Karlsruhe](https://www.lokalmatador.de/ausflugsziel/schloss-karlsruhe-zentrum-des-karlsruher-faechers-263/), [Stadtwiki Karlsruher Fächer](https://ka.stadtwiki.net/Karlsruher_F%C3%A4cher) | 9 Strahlen −45° … +45° in 11,25°-Schritten vom Turm (Ursprung) |
| Die neun Fächerstraßen von West nach Ost: Waldstraße, Herrenstraße, Ritterstraße, Lammstraße, Karl-Friedrich-Straße, Kreuzstraße, Adlerstraße, Kronenstraße, Waldhornstraße | [Stadtlexikon – Waldstraße](https://stadtlexikon.karlsruhe.de/index.php/De:Lexikon:top-2864), [Stadtlexikon – Waldhornstraße](https://stadtlexikon.karlsruhe.de/index.php/De:Lexikon:top-2854), [Wikipedia – Kaiserstraße](https://de.wikipedia.org/wiki/Kaiserstra%C3%9Fe_(Karlsruhe)) | Namen und Reihenfolge übernommen |
| Der Zirkel verläuft als Halbkreis um den Schlossturm | [Wikipedia – Zirkel](https://de.wikipedia.org/wiki/Zirkel_(Karlsruhe)), [Stadtlexikon – Zirkel](https://stadtlexikon.karlsruhe.de/index.php/De:Lexikon:top-3043) | Halbkreis r = 200 m |
| Karl-Friedrich-Straße = zentrale Nord-Süd-Achse: Zirkel → Marktplatz → Rondellplatz → Ettlinger Tor/Kriegsstraße | [Wikipedia – Karl-Friedrich-Straße](https://de.wikipedia.org/wiki/Karl-Friedrich-Stra%C3%9Fe_(Karlsruhe)), [Stadtlexikon – Rondellplatz](https://stadtlexikon.karlsruhe.de/index.php/De:Lexikon:top-3109) | Achse x = 0 von z = 200 bis 640 |
| Marktplatz: Pyramide (Grabmal des Stadtgründers, 1823) zwischen Rathaus (Westseite, Portikus) und Evangelischer Stadtkirche (Ostseite, korinthischer Portikus); Kaiserstraße an der Nordseite | [Wikipedia – Marktplatz](https://de.wikipedia.org/wiki/Marktplatz_(Karlsruhe)), [Stadtlexikon – Pyramide](https://stadtlexikon.karlsruhe.de/index.php/De:Lexikon:top-2219) | Pyramide (0, 360), Rathaus West, Kirche Ost |
| Kaiserstraße: ca. 2 km, gerade Ost-West; Durlacher Tor → Kronenplatz → Marktplatz → Europaplatz; Fußgängerzone Europaplatz–Kronenplatz; trifft am Marktplatz rechtwinklig auf die Karl-Friedrich-Straße | [Wikipedia – Kaiserstraße](https://de.wikipedia.org/wiki/Kaiserstra%C3%9Fe_(Karlsruhe)), [Wikipedia – Europaplatz](https://de.wikipedia.org/wiki/Europaplatz_(Karlsruhe)) | z = 330, Fußgängerzone x −470 … 220 |

## 2. Spielgeometrie (Koordinaten in m, Ursprung = Schlossturm, Norden = −Z, Osten = +X)

- Verdichtungsfaktor gegenüber der Realität ca. **0,55**; Kernfläche ca. 1,1 km × 1,2 km (Nordhälfte Park).
- **Schloss:** Hauptbau mit Mittelrisalit, Säulenportikus, Mansarddach, zwei abgewinkelten Flügeln (±55°), achteckigem Turm mit Kuppel und Laterne.
- **Schlossplatz:** Kiesvorplatz, Kieswege entlang der Fächerstrahlen, Baumreihen; nördlich Schlossgarten mit See und lockerem Baumbestand.
- **Fächer:** 9 Strahlen vom Zirkel (r = 200) bis zur Kaiserstraße (z = 330). Südlich der Kaiserstraße gehen ausgewählte Strahlen in Nord-Süd-Straßen über (Interpretation).
- **Karl-Friedrich-Straße** nördlich des Marktplatzes als Fußgänger-Boulevard (Sichtachse zum Schloss, frei von Möblierung).
- **Plätze:** Marktplatz, Europaplatz, Kronenplatz, Rondellplatz (mit Säule), Durlacher Tor (Torbogen-Skulptur), Ettlinger Tor (Pavillon).
- **Äußerer Rundkurs** (spielerisch verdichtet): Adenauerring (Bogen um den Schlossgarten), Westring und Ostring (fiktiv), Kriegsstraße.
- **Fiktive Nebenstraßen:** Schlossallee West/Ost, Hofgartenstraße, Stallhofstraße, Kutschergasse, Kanzleistraße, Rondellstraße.
- **Straßenbahn:** nur dekorative Gleise auf der Kriegsstraße, eine stilisierte Haltestelle und U-Strab-Zugänge als Kulisse. **Keine** Behauptung einer realen, aktuellen Linienführung.
- **Weitere Stadtteile** (Durlach, Turmberg, Rheinhafen, ZKM-Umfeld) sind nicht enthalten und nicht neben das Schloss gesetzt.

## 3. Bewusste Abweichungen

| Abweichung | Grund |
|---|---|
| Einige Fächerstraßen kreuzen die Fußgängerzone für Autos | Befahrbares, zusammenhängendes Straßennetz ohne Sackgassen |
| Lamm- und Kreuzstraße als schmale Anliegerstraßen ohne KI-Verkehr | Vermeidung von Sackgassen für die Verkehrs-KI |
| Rundkurs-Straßen „Westring/Ostring“ fiktiv | Spielerischer Rundkurs für Verfolgungen |
| Gebäude sind generische Blockrandbebauung | Kein Anspruch auf reale Gebäude außer den Landmarken |
| Alle Firmen, Personen und Geschäfte sind erfunden | Keine Darstellung realer Unternehmen |

## 4. Datenquelle im Projekt

`data/world/karlsruhe_layout.json` ist die **einzige** Kartenquelle. Daraus erzeugt `CityGraphBuilder` den Straßengraphen,
aus dem Weltaufbau, Verkehr, Polizei, Missionsziele und Karte abgeleitet werden.
