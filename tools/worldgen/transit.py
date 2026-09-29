"""ÖPNV-Daten aus OSM-Routen (Straßenbahn/Stadtbahn, Bus, S-Bahn): Linienverläufe, Haltestellen, Tunnelabschnitte.

Ausgabe (world.json -> "transit"):
  stops: [{name, pos:[x,z] (dm), modes:"t"/"b"/"tb"...}]
  lines: [{ref, name, mode, colour, pts: flach (dm), tun_m: [[s0, s1], ...] Tunnelbereiche (m entlang), stops: [stop_idx], s: [m entlang]}]
  track_offset: seitlicher Versatz (m) je Fahrtrichtung für Bahnen (0 bei OSM-Gleisen, die je Richtung eigene Gleise haben)
Linien verlassen teils die Karte: dann wird der längste zusammenhängende Abschnitt im Ausschnitt verwendet.
"""
from __future__ import annotations

import math

from shapely.geometry import LineString, Point, box
from shapely.ops import linemerge, unary_union
from shapely.strtree import STRtree

from export import flat, qi

MODE = {"tram": "tram", "light_rail": "tram", "bus": "bus", "train": "train"}


def _chain(ways):
    """Mitglieds-Wege einer Route zu einer Linie verbinden (Reihenfolge wie in der Relation, Richtung angepasst)."""
    out = []
    for w in ways:
        if len(w) < 2:
            continue
        if not out:
            out = list(w)
            continue
        end = out[-1]
        if math.dist(end, w[0]) <= math.dist(end, w[-1]):
            seg = w
        else:
            seg = w[::-1]
        if not out or math.dist(out[-1], seg[0]) > 60.0:
            # Lücke: prüfen, ob das Umdrehen des bisherigen Stücks passt (erste Weg-Richtung falsch geraten)
            if len(out) >= 2 and math.dist(out[0], seg[0]) < math.dist(out[-1], seg[0]):
                out = out[::-1]
        out += seg[1:] if math.dist(out[-1], seg[0]) < 0.5 else seg
    return out


def build(src, nodes, edges, names):
    x0, z0, x1, z1 = src.BOUNDS
    frame = box(x0 + 5, z0 + 5, x1 - 5, z1 - 5)
    tunnels = [LineString(r["pts"]) for r in src.RAILWAYS if r.get("tunnel") and len(r["pts"]) >= 2]
    tun_geom = unary_union([t.buffer(3.0) for t in tunnels]) if tunnels else None
    named = [s for s in src.STOPS if s["name"]]
    ntree = STRtree([Point(s["pos"]) for s in named]) if named else None
    stops: list[dict] = []
    stop_key = {}

    def stop_for(p, mode):
        name = ""
        if ntree is not None:
            i = int(ntree.nearest(Point(p)))
            if math.dist(named[i]["pos"], p) < 60.0:
                name = named[i]["name"]
        key = (name, round(p[0] / 40.0), round(p[1] / 40.0)) if name else (round(p[0]), round(p[1]))
        if key not in stop_key:
            stop_key[key] = len(stops)
            stops.append({"name": name, "pos": [qi(p[0]), qi(p[1])], "modes": ""})
        si = stop_key[key]
        m = mode[0]
        if m not in stops[si]["modes"]:
            stops[si]["modes"] += m
        return si

    lines = []
    seen = set()
    for r in src.ROUTES:
        mode = MODE.get(r["route"])
        if mode is None or not r["ways"]:
            continue
        pts = _chain(r["ways"])
        if len(pts) < 2:
            continue
        line = LineString(pts).simplify(1.0)
        inside = line.intersection(frame)
        parts = [g for g in getattr(inside, "geoms", [inside]) if isinstance(g, LineString)]
        if not parts:
            continue
        part = max(parts, key=lambda g: g.length)
        if part.length < 800.0:
            continue
        # Richtung beibehalten
        if Point(part.coords[0]).distance(Point(pts[0])) > Point(part.coords[-1]).distance(Point(pts[0])) and \
                line.project(Point(part.coords[0])) > line.project(Point(part.coords[-1])):
            part = LineString(list(part.coords)[::-1])
        coords = list(part.coords)
        # Haltestellen entlang der Linie
        st = []
        for p in r["stops"]:
            if part.distance(Point(p)) > 25.0:
                continue
            s = part.project(Point(p))
            st.append((s, stop_for(p, mode)))
        st.sort()
        dedup = []
        for s, si in st:
            if dedup and (dedup[-1][1] == si or s - dedup[-1][0] < 30.0):
                continue
            dedup.append((s, si))
        if len(dedup) < 2:
            continue
        key = (mode, r["ref"], round(coords[0][0] / 50), round(coords[0][1] / 50), round(coords[-1][0] / 50), round(coords[-1][1] / 50))
        if key in seen:
            continue
        seen.add(key)
        # Tunnelabschnitte als Bogenlängen-Bereiche (m); robust auch bei wenigen Stützpunkten
        tun = []
        if tun_geom is not None and mode != "bus":
            inter = part.intersection(tun_geom)
            for g in getattr(inter, "geoms", [inter]):
                if not isinstance(g, LineString) or g.length < 20.0:
                    continue
                a = part.project(Point(g.coords[0]))
                b = part.project(Point(g.coords[-1]))
                tun.append([round(min(a, b), 1), round(max(a, b), 1)])
            tun.sort()
            merged = []
            for rg in tun:
                if merged and rg[0] - merged[-1][1] < 25.0:
                    merged[-1][1] = max(merged[-1][1], rg[1])
                else:
                    merged.append(rg)
            tun = [rg for rg in merged if rg[1] - rg[0] >= 40.0]
        lines.append({"ref": r["ref"], "name": r["name"], "mode": mode, "colour": r["colour"], "pts": flat(coords), "tun_m": tun,
            "stops": [si for _s, si in dedup], "s": [round(s, 1) for s, _si in dedup]})
    lines.sort(key=lambda l: ({"tram": 0, "train": 1, "bus": 2}[l["mode"]], l["ref"]))
    print(f"[welt] ÖPNV: {len(lines)} Linienverläufe ({sum(1 for l in lines if l['mode'] == 'tram')} Bahn, "
        f"{sum(1 for l in lines if l['mode'] == 'bus')} Bus), {len(stops)} Haltestellen, "
        f"{sum(len(l['tun_m']) for l in lines)} Tunnelabschnitte")
    return {"stops": stops, "lines": lines, "track_offset": float(getattr(src, "TRACK_OFFSET", 0.0))}
