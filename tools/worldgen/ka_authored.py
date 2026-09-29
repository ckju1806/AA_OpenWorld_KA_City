"""Handgezeichnete Karlsruhe-Quelle im Maßstab 1:1 (Übergangslösung ohne OSM-Daten).

Grundlage: Nutzer-Referenzscreenshot (kalibriert, 1 px ≈ 8,77 m) und allgemein bekannte Lagebeziehungen.
Alle Angaben sind NÄHERUNGEN (typisch ±50–150 m, Nebenstraßen als plausibles Raster). Sobald OSM-Daten
verfügbar sind, ersetzt `source_osm.py` diese Datei vollständig (gleiches Zwischenformat).

Zwischenformat (von build_world.py verarbeitet):
  ROADS      [{name, cls, pts, [tunnel], [bridge]}]         Straßenachsen
  AREAS      [{kind, name, poly}]                           Flächen: water, forest, park, zoo, garden, field,
                                                            cemetery, sports, rail, plaza, industry_yard
  WATERWAYS  [{name, pts, width}]                           Flüsse/Kanäle als Linien
  DISTRICTS  [{id, name, poly, style, grid}]                Bebauungsgebiete; grid = Nebenstraßenraster oder None
  LANDMARKS  [{type, pos, rot, name, clear}]                individuell modellierte Bauwerke
  POIS       [{id, name, pos, yaw, kind, clear}]            Spielorte (Missionen, Respawn, Spawn)
  LABELS     [{text, pos, size}]                            Kartenbeschriftungen
  RAILWAYS   [{name, pts, tracks}]                          Eisenbahnstrecken (Kulisse, ÖPNV in W5)
"""
from __future__ import annotations

import math

from geo import arc, polar, px

SOURCE = "authored"
SOURCE_NOTE = "Handgezeichnete Näherung nach Referenzscreenshot (keine Geodaten)"

# Weltgrenzen (x_min, z_min, x_max, z_max) = Ausschnitt des Referenzscreenshots
BOUNDS = (-9500.0, -4100.0, 8000.0, 6300.0)


def rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def kaiser_z(x: float) -> float:
    """Kaiserstraße: gerade Achse Mühlburger Tor (-1290, 318) -> Durlacher Tor (1030, 468)."""
    return 318.0 + (x + 1290.0) * (150.0 / 2320.0)


ZIRKEL_R = 240.0
FAN_NAMES = {  # Winkel (0 = Süden, + = Osten) -> Name; 9 Fächerstraßen Richtung Süden
    -45.0: "Waldstraße", -33.75: "Herrenstraße", -22.5: "Ritterstraße", -11.25: "Lammstraße",
    0.0: "Karl-Friedrich-Straße", 11.25: "Kreuzstraße", 22.5: "Adlerstraße", 33.75: "Kronenstraße", 45.0: "Waldhornstraße",
}


def fan_end(deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    r = (318.0 + 1290.0 * 150.0 / 2320.0) / (math.cos(a) - (150.0 / 2320.0) * math.sin(a))
    return polar(0, 0, r, deg)


ROADS: list[dict] = []
AREAS: list[dict] = []
WATERWAYS: list[dict] = []
DISTRICTS: list[dict] = []
LANDMARKS: list[dict] = []
POIS: list[dict] = []
LABELS: list[dict] = []
RAILWAYS: list[dict] = []


def road(name, cls, pts, **kw):
    ROADS.append({"name": name, "cls": cls, "pts": [tuple(map(float, p)) for p in pts], **kw})


# --------------------------------------------------------------------------- Innenstadt: Fächer
road("Zirkel", "secondary", arc(0, 0, ZIRKEL_R, -90, 90, 5.625))
for deg, name in FAN_NAMES.items():
    end = fan_end(deg)
    cls = "pedestrian" if deg == 0.0 else ("tertiary" if abs(deg) >= 22.5 else "residential")
    road(name, cls, [polar(0, 0, ZIRKEL_R, deg), end])
    # südlich der Kaiserstraße als Nord-Süd-Straßen bis zur Kriegsstraße
    # Lamm- und Kreuzstraße enden am Marktplatz (Rathaus/Stadtkirche); die übrigen laufen als Nord-Süd-Straßen weiter
    if abs(deg) >= 22.5:
        road(name, "tertiary", [end, (end[0], 900.0)])
# Karl-Friedrich-Straße: Marktplatz -> Rondellplatz (Fußgängerzone) -> Ettlinger Tor
road("Karl-Friedrich-Straße", "pedestrian", [fan_end(0.0), (0.0, 700.0)])
road("Karl-Friedrich-Straße", "secondary", [(0.0, 700.0), (0.0, 790.0), (-40.0, 878.0)])
# Kaiserstraße
road("Kaiserstraße", "primary", [(-1290, kaiser_z(-1290)), (-720, kaiser_z(-720))])
road("Kaiserstraße", "pedestrian", [(-720, kaiser_z(-720)), (515, kaiser_z(515))])
road("Kaiserstraße", "primary", [(515, kaiser_z(515)), (1030, kaiser_z(1030))])
# Straßen parallel zur Kaiserstraße
road("Stephanienstraße", "tertiary", [(-1250, 150), (-700, 175), (-330, 190)])
road("Amalienstraße", "tertiary", [(-1270, 265), (-470, 285)])
road("Erbprinzenstraße", "tertiary", [(-900, 600), (-40, 610)])
road("Zähringerstraße", "residential", [(40, 540), (520, 560)])
road("Markgrafenstraße", "tertiary", [(40, 655), (1000, 660)])
road("Hebelstraße", "residential", [(-900, 700), (-40, 710)])
road("Akademiestraße", "residential", [(-690, 230), (-350, 245)])
road("Kapellenstraße", "residential", [(500, 560), (1000, 570)])
road("Kriegsstraße", "primary", [(-2400, 840), (-1100, 880), (-520, 905), (-60, 875), (300, 842), (735, 750), (1200, 742), (1760, 760), (2650, 790)])
road("Karlstraße", "secondary", [(-720, kaiser_z(-720)), (-620, 640), (-520, 905)])
road("Hirschstraße", "tertiary", [(-900, 100), (-880, kaiser_z(-880)), (-860, 880)])
road("Reinhold-Frank-Straße", "secondary", [(-1130, 0), (-1130, kaiser_z(-1130)), (-1120, 870)])
road("Hans-Thoma-Straße", "tertiary", [(-330, 190), (-300, 60)])

# --------------------------------------------------------------------------- Ausfall- und Ringstraßen
road("Kaiserallee", "primary", [(-1290, kaiser_z(-1290)), (-2400, 250), (-3530, 141)])
road("Rheinstraße", "primary", [(-3530, 141), (-4400, 60), (-5400, -120)])
road("Rheinbrückenstraße (B 10)", "trunk", [(-5400, -120), (-6200, -1200), (-7150, -2400), (-8000, -2750), (-9500, -3050)])
road("Moltkestraße", "secondary", [(-1290, kaiser_z(-1290)), (-1100, 0), (-877, -77)])
road("Adenauerring", "primary", arc(0, 0, 880, 265, 95, 5.0))
road("Linkenheimer Landstraße", "primary", [(-1100, 0), (-1500, -1200), (-1650, -2600), (-1700, -4100)])
road("Hertzstraße", "secondary", [(-3700, -350), (-2400, -330), (-1300, -300)])
road("Durlacher Allee", "primary", [(1030, kaiser_z(1030)), (2000, 560), (3000, 800), (3600, 1000), (4300, 1330), (4650, 1460)])
road("Pfinztalstraße", "secondary", [(4650, 1460), (5190, 1620), (5900, 1820), (7000, 2100), (8000, 2300)])
road("Ludwig-Erhard-Allee", "secondary", [(735, 750), (1500, 900), (2300, 1050), (3100, 1080)])
road("Ostring", "primary", [(2600, -500), (2620, 300), (2650, 800), (2700, 1300), (2850, 1900)])
road("Hagsfelder Allee", "secondary", [(877, -77), (1600, -400), (2600, -500), (3600, -900), (4400, -1100)])
road("Haid-und-Neu-Straße", "secondary", [(1030, kaiser_z(1030)), (1400, 250), (2620, 300)])
road("Ettlinger Straße", "primary", [(-60, 875), (-40, 1450), (20, 2060)])
road("Beiertheimer Allee", "primary", [(-520, 905), (-420, 1450), (-380, 2100), (-380, 2190)])
road("Rüppurrer Straße", "primary", [(735, 750), (640, 1400), (560, 2000), (520, 2215)])
road("Herrenalber Straße", "secondary", [(520, 2215), (470, 3000), (430, 3800), (420, 5200), (400, 6300)])
road("Ettlinger Allee", "primary", [(20, 2060), (100, 2800), (200, 3700), (260, 4600)])
road("Bahnhofstraße", "tertiary", [(-380, 2150), (20, 2150)])
road("Südendstraße", "tertiary", [(-1900, 1300), (-420, 1300)])
road("Kolpingstraße", "residential", [(-900, 1050), (-420, 1060)])
road("Durmersheimer Straße", "secondary", [(-380, 2190), (-900, 2500), (-1400, 2950), (-2400, 3700), (-3600, 5000)])
road("Pulverhausstraße", "secondary", [(-900, 2500), (-1700, 2700), (-2400, 3000), (-2900, 3200)])
road("Südtangente (B 10)", "trunk", [(-5200, 800), (-3600, 1600), (-1824, 2535), (-684, 2842), (-70, 2622), (807, 2315),
    (1684, 2140), (2298, 1833), (3175, 1219), (3613, 1000)])
road("Neureuter Straße (B 36)", "trunk", [(-3530, 141), (-3400, -1200), (-3350, -2600), (-3300, -4100)])
road("Karlsruher Straße (B 36)", "trunk", [(-3600, 1600), (-4800, 3000), (-6400, 4800), (-8200, 6300)])
road("Honsellstraße", "secondary", [(-4400, 60), (-5200, 300), (-6300, 350), (-7000, 400)])
road("Rheinhafenstraße", "secondary", [(-4400, 60), (-4600, -500), (-5400, -1100), (-6000, -1300)])
road("Knielinger Allee", "secondary", [(-1300, -300), (-3000, -700), (-4800, -1100), (-5400, -1100)])
road("Kriegsstraße West", "secondary", [(-2400, 840), (-3300, 800), (-3600, 1600)])
road("Pforzheimer Straße", "secondary", [(3000, 800), (3300, 1600), (3700, 2400), (4200, 3000)])
road("Wolfartsweierer Straße", "secondary", [(1684, 2140), (2200, 2600), (2800, 3200), (3300, 3800)])
# A 5 (angedeutet), von Nordosten nach Südwesten
road("A 5", "motorway", [(6157, -2798), (5000, -1500), (4200, -200), (3613, 1000), (2800, 2000), (2298, 2622),
    (2385, 4552), (1500, 5300), (631, 5779), (-600, 6300)])

# --------------------------------------------------------------------------- Bahn (Kulisse; ÖPNV folgt in W5)
RAILWAYS.append({"name": "Hauptbahn West–Ost", "tracks": 4, "pts": [(-3000, 2150), (-1500, 2330), (-180, 2345), (1300, 2290),
    (2600, 1900), (3600, 1500), (4227, 1377), (5200, 700), (6500, -2600)]})
RAILWAYS.append({"name": "Rheintalbahn Süd", "tracks": 2, "pts": [(1300, 2290), (900, 2800), (1000, 3500), (1150, 4600), (1300, 6300)]})
RAILWAYS.append({"name": "Rheinbahn West", "tracks": 2, "pts": [(-1500, 2330), (-3000, 1700), (-4600, 700), (-6000, -200),
    (-7200, -2000), (-9500, -3300)]})

# ---------------------------------------------------------------- ÖPNV-Näherung (nur ohne OSM-Daten; Linienführung vereinfacht)
# U-Strab: Stadtbahntunnel unter der Kaiserstraße (Rampen westlich Europaplatz und östlich Durlacher Tor)
_KS = [(-1290, kaiser_z(-1290)), (-900, kaiser_z(-900)), (-720, kaiser_z(-720)), (-300, kaiser_z(-300)), (0, kaiser_z(0)),
       (515, kaiser_z(515)), (800, kaiser_z(800)), (1030, kaiser_z(1030))]
RAILWAYS.append({"name": "Stadtbahntunnel Kaiserstraße", "tracks": 1, "kind": "tram", "tunnel": True,
                 "pts": [(-950, kaiser_z(-950)), (-720, kaiser_z(-720)), (0, kaiser_z(0)), (515, kaiser_z(515)), (900, kaiser_z(900))]})
# Südabzweig: Ettlinger Straße – Karl-Friedrich-Straße bis Marktplatz (Rampe südlich Kongresszentrum)
RAILWAYS.append({"name": "Stadtbahntunnel Südabzweig", "tracks": 1, "kind": "tram", "tunnel": True,
                 "pts": [(-47, 1250), (-60, 875), (0, 790), (0, 700), (0, kaiser_z(0))]})
TRACK_OFFSET = 1.6   # Linien folgen der Straßenachse: Bahnen je Richtung rechts versetzt
STOPS: list[dict] = []
ROUTES: list[dict] = []


def _stop(name, pos, tram=True, bus=False):
    STOPS.append({"name": name, "pos": (float(pos[0]), float(pos[1])), "tram": tram, "bus": bus, "train": False, "kind": "stop_position"})
    return (float(pos[0]), float(pos[1]))


_s_mbt = _stop("Mühlburger Tor", (-1290, kaiser_z(-1290)))
_s_eur = _stop("Europaplatz (U)", (-720, kaiser_z(-720)))
_s_mkt = _stop("Marktplatz (U)", (0, kaiser_z(0)))
_s_krp = _stop("Kronenplatz (U)", (515, kaiser_z(515)))
_s_dt = _stop("Durlacher Tor", (1030, kaiser_z(1030)))
_s_gtt = _stop("Gottesauer Platz", (2000, 560))
_s_dur = _stop("Durlach Schlossplatz", (5190, 1620))
_s_hbf = _stop("Hauptbahnhof (Vorplatz)", (20, 2060))
_s_ett = _stop("Ettlinger Tor", (-60, 875), tram=False, bus=True)
_s_kgz = _stop("Kongresszentrum (U)", (-54, 1050))
_s_etu = _stop("Ettlinger Tor/Staatstheater (U)", (0, 745))
_s_kri = _stop("Kriegsstraße/Karlstor", (-520, 905), tram=False, bus=True)
_s_kvp = _stop("Kaiserplatz", (-1275, 460), tram=False, bus=True)
_line1 = _KS + [(2000, 560), (3000, 800), (3600, 1000), (4300, 1330), (4650, 1460), (5190, 1620)]
ROUTES.append({"ref": "1", "name": "Linie 1: Mühlburger Tor – Durlach", "route": "tram", "colour": "#e2001a", "from": "Mühlburger Tor",
               "to": "Durlach", "stops": [_s_mbt, _s_eur, _s_mkt, _s_krp, _s_dt, _s_gtt, _s_dur], "ways": [_line1]})
ROUTES.append({"ref": "1", "name": "Linie 1: Durlach – Mühlburger Tor", "route": "tram", "colour": "#e2001a", "from": "Durlach",
               "to": "Mühlburger Tor", "stops": [_s_dur, _s_gtt, _s_dt, _s_krp, _s_mkt, _s_eur, _s_mbt], "ways": [_line1[::-1]]})
_line2 = [(20, 2060), (-40, 1450), (-60, 875), (0, 790), (0, 700), (0, kaiser_z(0))]
ROUTES.append({"ref": "2", "name": "Linie 2: Hauptbahnhof – Marktplatz", "route": "tram", "colour": "#0069b4", "from": "Hauptbahnhof",
               "to": "Marktplatz", "stops": [_s_hbf, _s_kgz, _s_etu, _s_mkt], "ways": [_line2]})
ROUTES.append({"ref": "2", "name": "Linie 2: Marktplatz – Hauptbahnhof", "route": "tram", "colour": "#0069b4", "from": "Marktplatz",
               "to": "Hauptbahnhof", "stops": [_s_mkt, _s_etu, _s_kgz, _s_hbf], "ways": [_line2[::-1]]})
# Straßenbahngleise an der Oberfläche (Tunnelabschnitt ausgenommen)
RAILWAYS.append({"name": "Straßenbahn Kaiserstraße West", "tracks": 2, "kind": "tram", "pts": [(-1290, kaiser_z(-1290)), (-1020, kaiser_z(-1020))]})
RAILWAYS.append({"name": "Straßenbahn Durlacher Allee", "tracks": 2, "kind": "tram", "pts": [(970, kaiser_z(970))] + _line1[7:]})
RAILWAYS.append({"name": "Straßenbahn Ettlinger Straße", "tracks": 2, "kind": "tram", "pts": [(20, 2060), (-40, 1450), (-44, 1320)]})
_bus = [(-1290, kaiser_z(-1290)), (-1250, 700), (-1100, 880), (-520, 905), (-60, 875), (-40, 1450), (20, 2060)]
ROUTES.append({"ref": "62", "name": "Bus 62: Kaiserplatz – Hauptbahnhof", "route": "bus", "colour": "#8a5cb0", "from": "Kaiserplatz",
               "to": "Hauptbahnhof", "stops": [_s_kvp, _s_kri, _s_ett, _s_hbf], "ways": [_bus]})
ROUTES.append({"ref": "62", "name": "Bus 62: Hauptbahnhof – Kaiserplatz", "route": "bus", "colour": "#8a5cb0", "from": "Hauptbahnhof",
               "to": "Kaiserplatz", "stops": [_s_hbf, _s_ett, _s_kri, _s_kvp], "ways": [_bus[::-1]]})

# --------------------------------------------------------------------------- Wasser
AREAS.append({"kind": "water", "name": "Rhein", "poly": [(-7400, -4100), (-7100, -4100), (-7650, -2464), (-7950, -184),
    (-8250, 1482), (-8700, 2797), (-9500, 3900), (-9500, 3300), (-9000, 2600), (-8500, 1300), (-8250, -200),
    (-7950, -2464)]})
for i, (z0, z1) in enumerate([(-360, -250), (-150, -40), (60, 167)]):
    AREAS.append({"kind": "water", "name": "Rheinhafen Becken %d" % (i + 1), "poly": rect(-7500, z0, -4900 + i * 250, z1)})
AREAS.append({"kind": "water", "name": "Knielinger See", "poly": [(-7050, -1400), (-6700, -1450), (-6600, -1100), (-6950, -1000)]})
AREAS.append({"kind": "water", "name": "Epplesee", "poly": [(-6300, 5450), (-5800, 5400), (-5700, 5800), (-6200, 5850)]})
AREAS.append({"kind": "water", "name": "Schlossgartensee", "poly": [(-420, -520), (-250, -560), (-180, -470), (-340, -420)]})
AREAS.append({"kind": "water", "name": "Stadtgartensee", "poly": [(-250, 1740), (-120, 1715), (-60, 1790), (-150, 1850), (-260, 1820)]})
WATERWAYS.append({"name": "Alb", "width": 16.0, "pts": [(-200, 6300), (-300, 4500), (-700, 3300), (-1000, 2650), (-1700, 2050),
    (-2400, 1400), (-2900, 900), (-3300, 450), (-4300, -300), (-5200, -800), (-6300, -1500), (-7700, -2000)]})

# --------------------------------------------------------------------------- Grün- und Sonderflächen
AREAS.append({"kind": "forest", "name": "Hardtwald", "poly": [(-600, -4100), (4600, -4100), (4600, -1800), (3200, -1400),
    (2500, -800), (1300, -950)] + [polar(0, 0, 1000, d) for d in (145, 160, 175, 190, 205)] + [(-600, -1000)]})
AREAS.append({"kind": "forest", "name": "Rheinwald", "poly": [(-9500, -4100), (-7500, -4100), (-8050, -2464), (-8350, -184),
    (-8650, 1482), (-9100, 2797), (-9500, 3300)]})
AREAS.append({"kind": "forest", "name": "Oberwald", "poly": [(800, 2650), (2300, 2450), (2400, 3700), (900, 3800)]})
AREAS.append({"kind": "forest", "name": "Bergwald", "poly": [(5800, 2600), (8000, 2600), (8000, 6300), (5600, 6300)]})
AREAS.append({"kind": "park", "name": "Schlossgarten", "poly": [(-840, -60), (-800, -430), (-560, -700), (-150, -860),
    (250, -830), (420, -420), (380, -60)]})
AREAS.append({"kind": "plaza", "name": "Schlossplatz", "poly": [(-230, 20)] + arc(0, 0, ZIRKEL_R - 12, -75, 75, 7.5) + [(230, 20)]})
AREAS.append({"kind": "garden", "name": "Botanischer Garten", "poly": rect(-560, 30, -330, 180)})
AREAS.append({"kind": "zoo", "name": "Zoologischer Stadtgarten", "poly": [(-330, 1470), (-60, 1470), (-20, 2060), (-340, 2090)]})
AREAS.append({"kind": "plaza", "name": "Festplatz", "poly": rect(-330, 1330, -60, 1450)})
AREAS.append({"kind": "park", "name": "Citypark", "poly": [(850, 1100), (1350, 1080), (1380, 1450), (870, 1470)]})
AREAS.append({"kind": "park", "name": "Günther-Klotz-Anlage", "poly": [(-3000, 1100), (-2000, 1180), (-1850, 1650), (-2900, 1700)]})
AREAS.append({"kind": "park", "name": "Nymphengarten", "poly": rect(820, 520, 980, 640)})
AREAS.append({"kind": "cemetery", "name": "Hauptfriedhof", "poly": rect(1700, -380, 2300, 120)})
AREAS.append({"kind": "sports", "name": "Wildparkstadion", "poly": [polar(670, -780, 125, d) for d in range(0, 360, 20)]})  # außerhalb des Adenauerrings (real ~49.020 N, 8.413 E)
AREAS.append({"kind": "plaza", "name": "Marktplatz", "poly": rect(-48, kaiser_z(-48) + 8, 48, 540)})
AREAS.append({"kind": "plaza", "name": "Europaplatz", "poly": [polar(-720, kaiser_z(-720), 42, d) for d in range(0, 360, 20)]})
AREAS.append({"kind": "plaza", "name": "Kronenplatz", "poly": [polar(515, kaiser_z(515), 34, d) for d in range(0, 360, 20)]})
AREAS.append({"kind": "plaza", "name": "Durlacher Tor", "poly": [polar(1030, kaiser_z(1030), 45, d) for d in range(0, 360, 20)]})
AREAS.append({"kind": "plaza", "name": "Rondellplatz", "poly": [polar(0, 760, 36, d) for d in range(0, 360, 20)]})
AREAS.append({"kind": "plaza", "name": "Ettlinger Tor", "poly": [polar(-50, 878, 40, d) for d in range(0, 360, 20)]})
AREAS.append({"kind": "plaza", "name": "Bahnhofplatz", "poly": rect(-300, 2160, -60, 2215)})
AREAS.append({"kind": "rail", "name": "Gleisfeld Hauptbahnhof", "poly": [(-3000, 2100), (1300, 2250), (1300, 2420), (-3000, 2250)]})
AREAS.append({"kind": "industry_yard", "name": "Rheinhafen", "poly": rect(-7400, -600, -4500, 1000)})
AREAS.append({"kind": "field", "name": "Felder Nordost", "poly": [(4600, -4100), (8000, -4100), (8000, 600), (4800, 600)]})
AREAS.append({"kind": "field", "name": "Felder Süd", "poly": [(-6800, 4100), (-400, 4100), (-400, 6300), (-6800, 6300)]})

# --------------------------------------------------------------------------- Bebauungsgebiete
# style: altstadt | gruenderzeit | zeile | hochhaus | villa | dorf | industrie | campus | modern
# grid: (Winkel°, Blocklänge, Blocktiefe, Versatz) oder None (nur vorhandene Straßen)
def district(id_, name, poly, style, grid=None):
    DISTRICTS.append({"id": id_, "name": name, "poly": poly, "style": style, "grid": grid})


district("innenstadt", "Innenstadt", [(-1250, 150), (-330, 190), (-240, 230), (240, 230), (460, 140), (460, 420),
    (1030, 468), (1100, 900), (-1250, 900)], "altstadt", None)
district("kit", "KIT Campus Süd", [(460, -600), (1250, -300), (1300, 150), (1030, 440), (460, 420)], "campus", (0, 180, 140, 40))
district("weststadt", "Weststadt", [(-2600, -300), (-1250, -300), (-1250, 880), (-2600, 880)], "gruenderzeit", (2, 150, 105, 20))
district("muehlburg", "Mühlburg", [(-3900, -300), (-2600, -300), (-2600, 880), (-3400, 880), (-3900, 400)], "gruenderzeit", (6, 135, 100, 35))
district("nordweststadt", "Nordweststadt", [(-2500, -1700), (-1600, -1700), (-1350, -300), (-2500, -300)], "zeile", (-8, 150, 115, 10))
district("hardtwaldsiedlung", "Hardtwaldsiedlung", [(-1550, -2300), (-650, -2300), (-650, -1000), (-1350, -300), (-1550, -1000)], "villa", (0, 130, 80, 0))
district("nordstadt", "Nordstadt", [(-650, -1900), (-300, -1900), (-300, -1050), (-650, -1050)], "zeile", (0, 140, 110, 0))
district("neureut", "Neureut", [(-2900, -4100), (-600, -4100), (-600, -2500), (-2900, -2500)], "villa", (-5, 140, 85, 15))
district("knielingen", "Knielingen", [(-6100, -2100), (-4300, -2100), (-4300, -500), (-6100, -600)], "dorf", (12, 120, 90, 25))
district("rheinhafen", "Rheinhafengebiet", [(-7400, -600), (-4500, -600), (-4500, 1000), (-7400, 1000)], "industrie", (0, 260, 190, 0))
district("gruenwinkel", "Grünwinkel", [(-4800, 900), (-3050, 900), (-3050, 2400), (-4800, 2400)], "zeile", (-12, 150, 110, 20))
district("daxlanden", "Daxlanden", [(-6200, 2300), (-4400, 2300), (-4400, 3900), (-6200, 3900)], "dorf", (15, 125, 90, 30))
district("oberreut", "Oberreut", [(-3600, 3000), (-2200, 3000), (-2200, 4100), (-3600, 4100)], "hochhaus", (0, 170, 150, 0))
district("beiertheim", "Beiertheim-Bulach", [(-1800, 2450), (-500, 2450), (-500, 3200), (-1800, 3200)], "dorf", (5, 120, 90, 10))
district("suedweststadt", "Südweststadt", [(-1850, 900), (-420, 905), (-380, 2100), (-1850, 2050)], "gruenderzeit", (0, 140, 100, 15))
district("suedstadt", "Südstadt", [(-40, 900), (720, 780), (560, 2100), (20, 2060)], "gruenderzeit", (0, 120, 100, 5))
district("suedost", "Südost / Citypark", [(740, 780), (2650, 800), (2700, 1300), (1684, 2140), (560, 2100)], "modern", (8, 130, 110, 20))
district("oststadt", "Oststadt", [(1250, -300), (2600, -500), (2650, 790), (1030, 470), (1300, 150)], "gruenderzeit", (3, 140, 100, 25))
district("rintheim", "Rintheim / Rintheimer Feld", [(2650, -1300), (3700, -1300), (3700, 800), (2650, 790)], "zeile", (-10, 160, 120, 15))
district("hagsfeld", "Hagsfeld", [(3700, -1700), (4600, -1700), (4600, -300), (3700, -300)], "dorf", (20, 120, 90, 0))
district("weiherfeld", "Weiherfeld-Dammerstock", [(-900, 2900), (300, 2850), (300, 3700), (-900, 3700)], "zeile", (0, 140, 100, 0))
district("rueppurr", "Rüppurr", [(-300, 3700), (1700, 3700), (1700, 5600), (-300, 5600)], "villa", (0, 130, 85, 20))
district("durlach_altstadt", "Durlach Altstadt", [polar(5190, 1650, 330, d) for d in range(0, 360, 30)], "dorf", (20, 90, 70, 0))
district("durlach", "Durlach", [(4300, 700), (6500, 900), (6600, 2600), (4200, 2800)], "villa", (20, 130, 90, 30))
district("aue", "Durlach-Aue", [(4400, 2800), (5800, 2800), (5800, 3700), (4400, 3700)], "villa", (10, 130, 85, 0))
district("rheinstetten", "Rheinstetten", [(-9000, 5000), (-6800, 5000), (-6800, 6300), (-9000, 6300)], "villa", (25, 140, 90, 0))
district("waldstadt", "Waldstadt", [(2000, -3000), (3400, -3000), (3400, -1900), (2000, -1900)], "zeile", (0, 170, 130, 0))

# --------------------------------------------------------------------------- Landmarken (individuell modelliert)
def landmark(type_, pos, rot=0.0, name="", clear=0.0, **kw):
    LANDMARKS.append({"type": type_, "pos": [float(pos[0]), float(pos[1])], "rot": float(rot), "name": name,
        "clear": float(clear), **kw})


landmark("schloss", (0, 0), 0, "Schloss Karlsruhe", 0.0, reserve=[(-330, -80), (330, -80), (330, 70), (-330, 70)])
landmark("pyramide", (0, kaiser_z(0) + 28), 0, "Pyramide", 10)
landmark("rathaus", (-78, 470), 90, "Rathaus", 0, reserve=rect(-120, 420, -50, 525))
landmark("stadtkirche", (78, 470), -90, "Evangelische Stadtkirche", 0, reserve=rect(50, 420, 120, 525))
landmark("saeule", (0, 760), 0, "Verfassungssäule", 6)
landmark("brunnen", (-720, kaiser_z(-720)), 0, "Brunnen Europaplatz", 6)
landmark("hauptbahnhof", (-180, 2240), 0, "Karlsruhe Hauptbahnhof", 0, reserve=rect(-320, 2215, -40, 2270))
landmark("gewaechshaus", (-445, 105), 0, "Gewächshäuser Botanischer Garten", 0, reserve=rect(-540, 60, -350, 150))
landmark("torbogen", (1030, kaiser_z(1030)), 0, "Durlacher Tor", 0)
landmark("stadion", (670, -780), 0, "Stadion am Wildpark", 0, reserve=rect(575, -850, 765, -710))
landmark("turmberg", (5800, 1450), 0, "Turmberg (Aussichtsturm)", 25)
landmark("hafenkran", (-6200, -200), 0, "Hafenkräne", 0)
landmark("zoo", (-180, 1760), 0, "Zoologischer Stadtgarten", 0)

# --------------------------------------------------------------------------- Spielorte
def poi(id_, name, pos, yaw=0.0, kind="ort", clear=0.0, **kw):
    POIS.append({"id": id_, "name": name, "pos": [float(pos[0]), float(pos[1])], "yaw": float(yaw), "kind": kind,
        "clear": float(clear), **kw})


poi("spawn", "Startpunkt Marktplatz", (-18, 505), 0, "spawn", 4)
# Straßengebundene Orte: werden in build_world an die genannte Straße angelegt
#   side: sidewalk (Gehweg, Blick zur Straße) | lane (rechte Fahrspur, Blick in Fahrtrichtung) | curb (Parkstreifen)
#   heading: gewünschte Fahrtrichtung in Grad (Godot-Yaw: 0 = Norden, 90 = Westen, 180 = Süden, -90 = Osten)
poi("klinikum", "St.-Fächer-Klinik (fiktiv)", (1450, 745), 0, "respawn", 6, road="Kriegsstraße", side="sidewalk")
poi("revier", "Polizeirevier Innenstadt (fiktiv)", (-640, 700), 0, "respawn", 6, road="Karlstraße", side="sidewalk")
# Mission 1 – Fächerblitz-Kurier (Südweststadt -> Kronenstraße -> Zähringerstraße)
poi("hanne", "Hanne Brettschneider (Fächerblitz-Kurier)", (-1240, 1300), 0, "auftraggeber", 3, road="Südendstraße", side="sidewalk")
poi("depot_van", "Lieferwagen Fächerblitz", (-1205, 1300), 0, "fahrzeug", 6, road="Südendstraße", side="curb", heading=-90)
poi("baeckerei", "Bäckerei Brezelglück", (fan_end(33.75)[0], 700), 0, "abholung", 2, road="Kronenstraße", side="sidewalk", sign="Bäckerei Brezelglück")
poi("baeckerei_parken", "Halt Bäckerei", (fan_end(33.75)[0], 712), 0, "fahrziel", 0, road="Kronenstraße", side="curb", heading=180)
poi("kanzlei", "Kanzlei Dr. Hagedorn", (240, 548), 0, "abgabe", 2, road="Zähringerstraße", side="sidewalk", sign="Kanzlei Dr. Hagedorn")
poi("kanzlei_parken", "Ladezone Zähringerstraße", (228, 548), 0, "fahrziel", 0, road="Zähringerstraße", side="curb", heading=-90)
# Mission 2 – Toni „Turbo“ Kessler (Durlacher Allee) und Kontrollpunkte der Fächer-Runde
poi("toni", "Toni „Turbo“ Kessler", (1330, 490), 0, "auftraggeber", 3, road="Durlacher Allee", side="sidewalk")
poi("rennwagen", "Fächer GT", (1360, 495), 0, "fahrzeug", 8, road="Durlacher Allee", side="lane", heading=-90)
for i, (road_name, near) in enumerate([
        ("Durlacher Allee", (2000, 560)), ("Ostring", (2630, 250)), ("Hagsfelder Allee", (1600, -400)),
        ("Adenauerring", polar(0, 0, 880, 135)), ("Adenauerring", polar(0, 0, 880, 180)), ("Adenauerring", polar(0, 0, 880, 225)),
        ("Moltkestraße", (-1050, -20)), ("Reinhold-Frank-Straße", (-1128, 600)), ("Kriegsstraße", (-520, 905)),
        ("Kriegsstraße", (300, 842)), ("Kriegsstraße", (1200, 742)), ("Kriegsstraße", (1760, 760))]):
    poi("m2_cp%02d" % (i + 1), "Kontrollpunkt %d" % (i + 1), near, 0, "kontrollpunkt", 0, road=road_name, side="center")
# Mission 3 – Ewald Riegel (Oststadt) -> Lager Rheinhafen -> Schrauberei Mäule (Weststadt)
poi("ewald", "Ewald Riegel (Antiquitäten)", (1500, 225), 0, "auftraggeber", 3, road="Haid-und-Neu-Straße", side="sidewalk", sign="Antiquitäten Riegel")
poi("riegel_wagen", "Dunkle Limousine", (1540, 232), 0, "fahrzeug", 8, road="Haid-und-Neu-Straße", side="curb", heading=-90)
poi("lager", "Lagerhof Rheinhafen", (-5600, 330), 0, "fahrziel", 10, road="Honsellstraße", side="curb", heading=90)
poi("maeule", "Schrauberei Mäule", (-2000, -318), 0, "fahrziel", 12, road="Hertzstraße", side="curb", heading=90, sign="Schrauberei Mäule")

# ---------------------------------------------------------------- Kampagne W8 (fiktive Personen/Firmen, reale Straßen nur als Orte)
# Hanne (Kurier): Eilzustellung / Nachtschicht
poi("drop_karlstrasse", "Kanzleibote Karlstraße", (-640, 520), 0, "fahrziel", 0, road="Karlstraße", side="curb", heading=0)
poi("drop_adenauerring", "Institut am Ring", (683, -553), 0, "fahrziel", 0, road="Adenauerring", side="curb", heading=120)
poi("drop_ruepurrer", "Praxis Rüppurrer Straße", (660, 1250), 0, "fahrziel", 0, road="Rüppurrer Straße", side="curb", heading=180)
poi("drop_ostring", "Werkstatt Ostring", (2640, 700), 0, "fahrziel", 0, road="Ostring", side="curb", heading=180)
poi("paket_1", "Paketkasten Hans-Thoma-Straße", (-315, 125), 0, "abholung", 0, road="Hans-Thoma-Straße", side="curb", heading=0)
poi("paket_2", "Paketkasten Moltkestraße", (-1134, 57), 0, "abholung", 0, road="Moltkestraße", side="curb", heading=0)
poi("paket_3", "Paketkasten Kaiserallee", (-1900, 280), 0, "abholung", 0, road="Kaiserallee", side="curb", heading=90)
poi("paket_4", "Paketkasten Ludwig-Erhard-Allee", (1500, 900), 0, "abholung", 0, road="Ludwig-Erhard-Allee", side="curb", heading=90)
poi("hbf_ladezone", "Ladezone Hauptbahnhof", (-40, 2000), 0, "fahrziel", 0, road="Ettlinger Straße", side="curb", heading=180)
# Toni (Autohaus): Ersatzteile / Probefahrt
poi("autohaus_parken", "Hof Autohaus Kessler", (1300, 480), 0, "fahrziel", 0, road="Durlacher Allee", side="curb", heading=-90)
poi("kunde_wagen", "Vorführwagen", (1250, 470), 0, "fahrzeug", 8, road="Durlacher Allee", side="lane", heading=90)
poi("kunde_ziel", "Parkplatz Pfinztalstraße", (5500, 1700), 0, "fahrziel", 0, road="Pfinztalstraße", side="curb", heading=90)
# Mira (Informantin, freie Journalistin „Fächerbote“)
poi("mira", "Mira Kessel (Fächerbote)", (-600, 175), 0, "auftraggeber", 3, road="Stephanienstraße", side="sidewalk", sign="Redaktion Fächerbote")
poi("mira_wagen", "Miras Kombi", (-560, 178), 0, "fahrzeug", 8, road="Stephanienstraße", side="curb", heading=90)
poi("lager_beobachtung", "Beobachtungsposten Lagerhof", (-5600, 330), 0, "fahrziel", 0, road="Honsellstraße", side="center")
poi("spur_1", "Spur: Kapellenstraße", (750, 565), 0, "abholung", 2, road="Kapellenstraße", side="sidewalk")
poi("spur_2", "Spur: Hirschstraße", (-870, 600), 0, "abholung", 2, road="Hirschstraße", side="sidewalk")
poi("spur_3", "Spur: Amalienstraße", (-870, 275), 0, "abholung", 2, road="Amalienstraße", side="sidewalk")
poi("vesper_transporter", "Grauer Transporter", (-5560, 330), 0, "fahrzeug", 8, road="Honsellstraße", side="lane", heading=90)
poi("vesper_halle", "Halle Vesper-Logistik (fiktiv)", (-1500, 2900), 0, "fahrziel", 14, road="Durmersheimer Straße", side="curb", heading=45)
poi("tram_treff", "Treffpunkt Durlacher Tor", (930, 460), 0, "fahrziel", 0, road="Kaiserstraße", side="sidewalk")
poi("mira_wagen2", "Miras Kombi (Beweise)", (960, 462), 0, "fahrzeug", 8, road="Kaiserstraße", side="lane", heading=-90)
# Die zwei Gruppen (fiktiv)
poi("jo", "Jo Brenner (Hafenkolonne)", (-4700, -450), 0, "auftraggeber", 3, road="Rheinhafenstraße", side="sidewalk")
poi("jo_crew", "Kumpel an der Kaiserallee", (-1740, 290), 0, "abholung", 0, road="Kaiserallee", side="curb", heading=90)
poi("jo_wagen", "Pritschenwagen", (-4650, -420), 0, "fahrzeug", 8, road="Rheinhafenstraße", side="curb", heading=45)
poi("lia", "Lia Voss (Ringbande)", (620, 1500), 0, "auftraggeber", 3, road="Rüppurrer Straße", side="sidewalk")
poi("lia_wagen", "Lias Kompaktwagen", (630, 1540), 0, "fahrzeug", 8, road="Rüppurrer Straße", side="curb", heading=180)
poi("lia_garage", "Garagenhof Wolfartsweierer Straße", (2400, 2800), 0, "fahrziel", 0, road="Wolfartsweierer Straße", side="curb", heading=135)

# --------------------------------------------------------------------------- Beschriftungen
for text, pos, size in [
    ("Schloss", (0, -60), 2), ("Schlossgarten", (-250, -560), 2), ("Hardtwald", (1800, -2800), 3), ("Marktplatz", (0, 475), 2),
    ("Kaiserstraße", (-260, 395), 1), ("Europaplatz", (-720, 330), 2), ("Kronenplatz", (515, 410), 2), ("Durlacher Tor", (1030, 430), 2),
    ("Hauptbahnhof", (-180, 2280), 2), ("Zoo", (-180, 1700), 2), ("Citypark", (1100, 1260), 2), ("Botanischer Garten", (-445, 60), 1),
    ("Günther-Klotz-Anlage", (-2450, 1400), 2), ("Rheinhafen", (-6000, 450), 3), ("Weststadt", (-1900, 300), 3),
    ("Mühlburg", (-3250, 300), 3), ("Oststadt", (1900, 200), 3), ("Südstadt", (300, 1400), 3), ("Südweststadt", (-1100, 1500), 3),
    ("Durlach", (5190, 1500), 3), ("Rüppurr", (700, 4600), 3), ("Oberreut", (-2900, 3550), 3), ("Neureut", (-1700, -3300), 3),
    ("Knielingen", (-5200, -1300), 3), ("Grünwinkel", (-3900, 1650), 3), ("Daxlanden", (-5300, 3100), 3), ("Rintheim", (3150, -300), 3),
    ("Hagsfeld", (4150, -1000), 3), ("Weiherfeld", (-300, 3300), 3), ("Beiertheim", (-1150, 2800), 3), ("Rheinstetten", (-7900, 5600), 3),
    ("Rhein", (-8200, 800), 3), ("Oberwald", (1600, 3200), 2), ("KIT", (850, -150), 2), ("Waldstadt", (2700, -2450), 3),
    ("Nordweststadt", (-1950, -1000), 3), ("Kriegsstraße", (-300, 930), 1), ("Adenauerring", (-700, -700), 1),
]:
    LABELS.append({"text": text, "pos": [float(pos[0]), float(pos[1])], "size": size})
