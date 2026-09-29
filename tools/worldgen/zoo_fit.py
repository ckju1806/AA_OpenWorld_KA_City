"""Zoo-Gehege an die reale Zoofläche anpassen (OSM-Quelle).

Die Standardanordnung (`data/world/zoo_layout.json`, lokale Koordinaten zur Zoo-Landmarke) ist eine freie Näherung.
In der OSM-Welt liegen dort Stadtgartensee, Zoogebäude und Wege. Diese Funktion sucht für jedes Gehege die nächstgelegene
freie Stelle innerhalb der Zoofläche (ohne Wasser, Gebäude, Wege, andere Gehege), verkleinert es notfalls und schreibt das
Ergebnis in den Landmarkeneintrag (`enclosures`, `entrance`). Das Spiel übernimmt diese Anordnung für Zäune und Tiere.
"""
from __future__ import annotations

import json
import math
import os

from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from shapely.prepared import prep

import network as net

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STEP = 3.0          # Suchraster in m
GAP = 4.0           # Mindestabstand zwischen Gehegen / zu Hindernissen
SCALES = (1.0, 0.85, 0.7, 0.55)


def fit(landmarks: list, areas: list, buildings: list, nodes: list, edges: list) -> dict | None:
    zoo = next((l for l in landmarks if l["type"] == "zoo"), None)
    if zoo is None:
        return None
    with open(os.path.join(ROOT, "data", "world", "zoo_layout.json"), encoding="utf-8") as fh:
        layout = json.load(fh)
    zx, zz = zoo["pos"]
    rot = math.radians(float(zoo.get("rot", 0.0)))
    if abs(rot) > 1e-6:
        return None    # Suche nur für achsparallele Zoo-Landmarke (OSM: Drehung 0)
    near = Point(zx, zz).buffer(700)
    zoo_polys = [Polygon(a["poly"], a.get("holes", [])) for a in areas if a["kind"] == "zoo"]
    zoo_area = unary_union([p.buffer(0) for p in zoo_polys if p.buffer(0).intersects(near)])
    if zoo_area.is_empty:
        return None
    obst = [Polygon(a["poly"]).buffer(0).buffer(GAP) for a in areas if a["kind"] == "water" and Polygon(a["poly"]).buffer(0).intersects(near)]
    obst += [Polygon(b["p"]).buffer(0).buffer(GAP) for b in buildings if Polygon(b["p"]).buffer(0).intersects(near)]
    for e in edges:
        ln = LineString([nodes[e[0]], nodes[e[1]]])
        if ln.intersects(near):
            obst.append(ln.buffer(net.edge_width(e) * 0.5 + 1.5))
    # Eingang frei halten (Gebäude links/rechts, Vorplatz)
    ex, ez = layout.get("entrance", [0, 250])
    obst.append(box(zx + ex - 26, zz + ez - 18, zx + ex + 26, zz + ez + 8))
    free = zoo_area.buffer(-2.0).difference(unary_union(obst))
    placed = []
    out = []
    moved = 0.0
    for enc in sorted(layout["enclosures"], key=lambda e: -e["size"][0] * e["size"][1]):
        want = (zx + enc["center"][0], zz + enc["center"][1])
        best = None
        for sc in SCALES:
            sx, sz = enc["size"][0] * sc, enc["size"][1] * sc
            room = free.difference(unary_union(placed)) if placed else free
            room_p = prep(room)
            # Kandidaten ringweise um die Wunschposition (nächste freie Stelle gewinnt)
            for r in range(0, 90):
                ring = []
                for i in range(-r, r + 1):
                    for j in (-r, r) if abs(i) != r else range(-r, r + 1):
                        ring.append((want[0] + i * STEP, want[1] + j * STEP))
                ring.sort(key=lambda c: math.dist(c, want))
                for cx, cz in ring:
                    rect = box(cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2)
                    if room_p.contains(rect):
                        best = (cx, cz, sx, sz)
                        break
                if best:
                    break
            if best:
                break
        if best is None:
            print(f"[zoo] Gehege {enc['id']}: kein freier Platz – entfällt")
            continue
        cx, cz, sx, sz = best
        placed.append(box(cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2).buffer(GAP))
        moved = max(moved, math.dist((cx, cz), want))
        e2 = dict(enc)
        e2["center"] = [round(cx - zx, 1), round(cz - zz, 1)]
        e2["size"] = [round(sx, 1), round(sz, 1)]
        out.append(e2)
    order = {e["id"]: i for i, e in enumerate(layout["enclosures"])}
    out.sort(key=lambda e: order[e["id"]])
    zoo["enclosures"] = out
    zoo["entrance"] = [ex, ez]
    print(f"[zoo] {len(out)}/{len(layout['enclosures'])} Gehege auf freie Zooflächen gesetzt (max. Versatz {moved:.0f} m)")
    return zoo
