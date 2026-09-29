#!/usr/bin/env python3
"""Prüft erzeugte Weltdaten: kein Gebäude ragt in eine Fahrspur. Exit-Code 1 bei Fehlern.

Aufruf: python3 tools/worldgen/validate_world.py [data/world/ka]
"""
from __future__ import annotations

import glob
import gzip
import json
import math
import os
import sys

from shapely import affinity
from shapely.geometry import LineString, Point, Polygon, box
from shapely.strtree import STRtree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Grundfläche der Platzhalter-Landmarken in Metern – synchron halten mit LandmarkBuilder._placeholder (GDScript)
PLACEHOLDER_SIZES = {"hauptbahnhof": (240, 36), "gewaechshaus": (60, 22), "stadion": (180, 130), "hafenkran": (8, 8),
    "turmberg": (9, 9)}


def _schloss_parts() -> list:
    parts = [(0, 12, 72, 20, 0), (0, 24.5, 24, 5, 0), (0, 29, 20, 2, 0), (0, -3, 15, 15, 0)]
    for side in (-1, 1):
        ang = math.radians(side * 55.0)
        d = (math.sin(ang), math.cos(ang))
        yaw = math.degrees(math.atan2(-d[1], d[0]))
        parts.append((side * 34 + d[0] * 46, 14 + d[1] * 46, 92, 16, yaw))
        parts.append((side * 34 + d[0] * 98, 14 + d[1] * 98, 14, 22, yaw))
    return parts


# Grundrisse der Detail-Landmarken: (Modellausrichtung in Grad oder None, [(cx, cz, breite, tiefe, gier°), …]) in lokalen
# Koordinaten – synchron halten mit LandmarkBuilder (MODEL_ROT, _schloss, _rathaus, …) und LandmarksExtra.staatstheater.
# Modellausrichtung gesetzt: Modell ist für diese Drehung gebaut, der Knoten wird um (rot − Modellausrichtung) gedreht;
# None: das Modell verwendet rot direkt.
LM_PARTS = {
    "schloss": (0.0, _schloss_parts()),
    "rathaus": (90.0, [(-2, -6, 64, 60, 0), (19, 32, 22, 16, 0), (33, 0, 2, 17, 0)]),
    "stadtkirche": (-90.0, [(4.5, 0, 48, 31, 0), (-28, 0, 2, 23, 0), (-23.5, 0, 9, 24.4, 0)]),
    "pyramide": (0.0, [(0, 0, 8.2, 8.2, 0)]),
    "saeule": (None, [(0, 0, 4, 4, 0)]),
    "brunnen": (None, [(0, 0, 9.2, 9.2, 0)]),
    "torbogen": (None, [(-3.6, 0, 1.6, 1.6, 0), (3.6, 0, 1.6, 1.6, 0)]),
    "staatstheater": (None, [(0, 10, 70, 50, 0), (-22, 18, 30, 34, 0), (20, 20, 26, 30, 0), (0, 42, 60, 14, 0),
                             (0, -21, 64, 8, 0)]),
}


def landmark_footprints(lm: dict) -> list:
    """Grundriss-Polygone einer Landmarke in Weltkoordinaten (leer, wenn kein Grundriss bekannt)."""
    x, z = lm["pos"]
    rot = float(lm.get("rot", 0.0))
    out = []
    if lm["type"] in PLACEHOLDER_SIZES:
        sx, sz = PLACEHOLDER_SIZES[lm["type"]]
        out.append(affinity.rotate(box(x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2), -rot, origin=(x, z)))
    elif lm["type"] in LM_PARTS:
        model_rot, parts = LM_PARTS[lm["type"]]
        eff = rot - model_rot if model_rot is not None else rot
        for cx, cz, sx, sz, yaw in parts:
            b = affinity.rotate(box(cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2), -yaw, origin=(cx, cz))
            b = affinity.rotate(b, -eff, origin=(0, 0))
            out.append(affinity.translate(b, x, z))
    return out


def validate(out_dir: str) -> int:
    w = json.load(gzip.open(os.path.join(out_dir, "world.json.gz")))
    q = w["q"]
    nf, ef = w["nodes"], w["edges"]
    nodes = [(nf[i] / q, nf[i + 1] / q) for i in range(0, len(nf), 2)]
    lanes = []
    lane_axes = []
    for i in range(0, len(ef), 5):
        c = w["classes"][w["class_order"][ef[i + 2]]]
        if c["drivable"]:
            fw = (ef[i + 4] >> 8) & 0xFF   # Kantenbreite aus den Flags (OSM), sonst Klassenbreite
            lane = min(2.6, (fw * 0.5 if fw > 0 else c["width"]) * 0.25) + 0.8
            axis = LineString([nodes[ef[i]], nodes[ef[i + 1]]])
            lanes.append(axis.buffer(lane, cap_style=2))
            lane_axes.append((axis, lane))
    tree = STRtree(lanes)
    bad = 0
    for f in sorted(glob.glob(os.path.join(out_dir, "sectors", "*.json.gz"))):
        for b in json.load(gzip.open(f)).get("b", []):
            fl = b[0]
            pg = Polygon([(fl[i] / q, fl[i + 1] / q) for i in range(0, len(fl), 2)])
            if not pg.is_valid:
                pg = pg.buffer(0)
            for j in tree.query(pg):
                inter = lanes[j].intersection(pg).area
                # Eindringtiefe: wie weit ragt ein Gebäudescheitel in die Spur (Nadeln/Splitter = feste Wände)?
                axis, half = lane_axes[j]
                verts = [c for g in getattr(pg, "geoms", [pg]) for c in g.exterior.coords]
                depth = max((half - axis.distance(Point(c)) for c in verts if lanes[j].contains(Point(c))), default=0.0)
                if inter > 0.5 or depth > 0.3:
                    bad += 1
                    if bad <= 5:
                        print(f"[prüfung] Gebäude in Fahrspur: {os.path.basename(f)} {pg.bounds}")
                    break
    print(f"[prüfung] Gebäude in Fahrspuren: {bad}")
    # Parkende Autos: Mitte mindestens 4,5 m von jeder befahrbaren Mittellinie (Spur 2,6 m + halbe Breiten + Abstand)
    centers = [LineString([nodes[ef[i]], nodes[ef[i + 1]]]) for i in range(0, len(ef), 5)
        if w["classes"][w["class_order"][ef[i + 2]]]["drivable"]]
    ctree = STRtree(centers)
    car_bad = 0
    for f in sorted(glob.glob(os.path.join(out_dir, "sectors", "*.json.gz"))):
        cars = json.load(gzip.open(f)).get("p", {}).get("car", [])
        for k in range(0, len(cars), 4):
            pt = Point(cars[k] / q, cars[k + 1] / q)
            j = ctree.nearest(pt)
            if centers[int(j)].distance(pt) < 4.5:
                car_bad += 1
                if car_bad <= 5:
                    print(f"[prüfung] Parkendes Auto zu nah an Fahrspur: {pt.x:.1f}, {pt.y:.1f}")
    print(f"[prüfung] Parkende Autos auf Fahrspuren: {car_bad}")
    bad += car_bad
    # Objekte mit Kollision (Laternen, Bäume, Poller, Bänke) nicht auf der Fahrbahn
    cw = []
    for i in range(0, len(ef), 5):
        c = w["classes"][w["class_order"][ef[i + 2]]]
        if c["drivable"]:
            fw = (ef[i + 4] >> 8) & 0xFF
            cw.append((fw * 0.5 if fw > 0 else c["width"]) * 0.5)
    prop_bad = 0
    for f in sorted(glob.glob(os.path.join(out_dir, "sectors", "*.json.gz"))):
        pp = json.load(gzip.open(f)).get("p", {})
        for kind in ("lamp", "tree", "bollard", "bench"):
            arr = pp.get(kind, [])
            for k in range(0, len(arr), 4):
                pt = Point(arr[k] / q, arr[k + 1] / q)
                for j in ctree.query(pt.buffer(15.0)):
                    if centers[int(j)].distance(pt) < cw[int(j)] - 0.2:
                        prop_bad += 1
                        if prop_bad <= 5:
                            print(f"[prüfung] {kind} auf Fahrbahn: {pt.x:.1f}, {pt.y:.1f}")
                        break
    print(f"[prüfung] Objekte auf Fahrbahnen: {prop_bad}")
    bad += prop_bad
    # Landmarken (Platzhalter- und Detailmodelle) dürfen keine Fahrbahn überdecken
    lm_bad = 0
    for lm in w["landmarks"]:
        for foot in landmark_footprints(lm):
            if any(lanes[j].intersection(foot).area > 0.5 for j in tree.query(foot)):
                lm_bad += 1
                print(f"[prüfung] Landmarke {lm['type']} überdeckt eine Fahrbahn bei {foot.centroid.x:.0f}, {foot.centroid.y:.0f}")
                break
    print(f"[prüfung] Landmarken auf Fahrbahnen: {lm_bad}")
    return bad + lm_bad


if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "data", "world", "ka")
    sys.exit(1 if validate(d) else 0)
