#!/usr/bin/env python3
"""Prüft erzeugte Weltdaten: kein Gebäude ragt in eine Fahrspur. Exit-Code 1 bei Fehlern.

Aufruf: python3 tools/worldgen/validate_world.py [data/world/ka]
"""
from __future__ import annotations

import glob
import gzip
import json
import os
import sys

from shapely import affinity
from shapely.geometry import LineString, Point, Polygon, box
from shapely.strtree import STRtree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Grundfläche der Platzhalter-Landmarken in Metern – synchron halten mit LandmarkBuilder._placeholder (GDScript)
PLACEHOLDER_SIZES = {"hauptbahnhof": (240, 36), "gewaechshaus": (60, 22), "stadion": (180, 130), "hafenkran": (8, 8),
    "turmberg": (9, 9)}


def validate(out_dir: str) -> int:
    w = json.load(gzip.open(os.path.join(out_dir, "world.json.gz")))
    q = w["q"]
    nf, ef = w["nodes"], w["edges"]
    nodes = [(nf[i] / q, nf[i + 1] / q) for i in range(0, len(nf), 2)]
    lanes = []
    for i in range(0, len(ef), 5):
        c = w["classes"][w["class_order"][ef[i + 2]]]
        if c["drivable"]:
            lane = min(2.6, c["width"] * 0.25) + 0.8
            lanes.append(LineString([nodes[ef[i]], nodes[ef[i + 1]]]).buffer(lane, cap_style=2))
    tree = STRtree(lanes)
    bad = 0
    for f in sorted(glob.glob(os.path.join(out_dir, "sectors", "*.json.gz"))):
        for b in json.load(gzip.open(f)).get("b", []):
            fl = b[0]
            pg = Polygon([(fl[i] / q, fl[i + 1] / q) for i in range(0, len(fl), 2)])
            for j in tree.query(pg):
                if lanes[j].intersection(pg).area > 0.5:
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
    # Platzhalter-Landmarken (Kollisionsquader) dürfen keine Fahrbahn überdecken
    lm_bad = 0
    for lm in w["landmarks"]:
        size = PLACEHOLDER_SIZES.get(lm["type"])
        if size is None:
            continue
        x, z = lm["pos"]
        foot = affinity.rotate(box(x - size[0] / 2, z - size[1] / 2, x + size[0] / 2, z + size[1] / 2), -lm.get("rot", 0.0),
            origin=(x, z))
        for j in tree.query(foot):
            if lanes[j].intersection(foot).area > 0.5:
                lm_bad += 1
                print(f"[prüfung] Landmarke {lm['type']} überdeckt eine Fahrbahn")
                break
    return bad + lm_bad


if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "data", "world", "ka")
    sys.exit(1 if validate(d) else 0)
