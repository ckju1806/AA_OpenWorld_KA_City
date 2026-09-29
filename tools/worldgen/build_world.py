#!/usr/bin/env python3
"""Erzeugt die Spielwelt-Daten data/world/ka/ (world.json.gz, sectors/, lod/, map.webp).

Aufruf:  python3 tools/worldgen/build_world.py [--source osm|authored] [--cache ~/osm_cache] [--out data/world/ka]
         (osm: vorher tools/worldgen/fetch_osm.py ausführen; Kartendaten © OpenStreetMap-Mitwirkende, ODbL)
Abhängigkeiten (nur Werkzeug, nicht im Spiel): shapely, numpy, pillow  (pip install shapely numpy pillow)
Deterministisch: gleiche Eingaben -> gleiche Ausgaben.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from shapely.geometry import Point, Polygon  # noqa: E402
from shapely.strtree import STRtree  # noqa: E402

import blocks as bl  # noqa: E402
import export as ex  # noqa: E402
import network as net  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def resolve_pois(pois, nodes, edges, names):
    """Straßengebundene POIs an die genannte Straße legen (Gehweg, Fahrspur, Parkstreifen oder Mitte)."""
    import math
    out = []
    for p in pois:
        p = dict(p)
        road = p.pop("road", None)
        side = p.pop("side", "sidewalk")
        heading = p.pop("heading", None)
        if road is None:
            out.append(p)
            continue
        px_, pz_ = p["pos"]
        # Fahrzeugziele (Bordstein/Spur/Mitte) nur auf befahrbaren Abschnitten (reale Straßen sind teils Fußgängerzone)
        need_drive = side in ("curb", "lane", "center")

        def _nearest(ref, ok):
            bst = None
            for e in edges:
                if not ok(e):
                    continue
                a, b = nodes[e[0]], nodes[e[1]]
                dx, dz = b[0] - a[0], b[1] - a[1]
                L2 = dx * dx + dz * dz
                if L2 < 1e-6:
                    continue
                t = max(0.0, min(1.0, ((ref[0] - a[0]) * dx + (ref[1] - a[1]) * dz) / L2))
                q = (a[0] + dx * t, a[1] + dz * t)
                d = math.dist(q, ref)
                if bst is None or d < bst[0]:
                    bst = (d, e, q)
            return bst

        def _drivable(e):
            return net.ROAD_CLASSES[net.CLASS_ORDER[e[2]]]["drivable"]

        # 1) nächster Punkt der benannten Straße (beliebige Klasse)
        best = _nearest((px_, pz_), lambda e: names[e[3]] == road)
        if best is not None and need_drive and not _drivable(best[1]):
            # 2) befahrbarer Teil derselben Straße in der Nähe? sonst nächste Fahrbahn an genau dieser Stelle
            anchor = best[2]
            same = _nearest(anchor, lambda e: names[e[3]] == road and _drivable(e))
            if same is not None and same[0] <= 60.0:
                best = same
            else:
                best = _nearest(anchor, _drivable)
                print(f"[welt] POI {p['id']}: '{road}' hier Fußgängerzone – Fahrbahn '{names[best[1][3]]}' daneben verwendet")
        if best is None:
            raise SystemExit(f"POI {p['id']}: Straße '{road}' nicht im Netz")
        _, e, q = best
        a, b = nodes[e[0]], nodes[e[1]]
        L = math.dist(a, b)
        d = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        w = net.edge_width(e)
        if heading is not None:
            f = (-math.sin(math.radians(heading)), -math.cos(math.radians(heading)))
            if f[0] * d[0] + f[1] * d[1] < 0:
                d = (-d[0], -d[1])
        right = (-d[1], d[0])
        if side == "lane":
            pos = (q[0] + right[0] * w * 0.25, q[1] + right[1] * w * 0.25)
            fwd = d
        elif side == "curb":
            off = max(w * 0.5 - 1.3, w * 0.25)
            pos = (q[0] + right[0] * off, q[1] + right[1] * off)
            fwd = d
        elif side == "center":
            pos = q
            fwd = d
        else:
            s = 1.0 if (px_ - q[0]) * right[0] + (pz_ - q[1]) * right[1] >= 0 else -1.0
            off = w * 0.5 + 1.8
            pos = (q[0] + right[0] * off * s, q[1] + right[1] * off * s)
            fwd = (-right[0] * s, -right[1] * s)
        p["pos"] = [round(pos[0], 2), round(pos[1], 2)]
        p["yaw"] = round(math.degrees(math.atan2(-fwd[0], -fwd[1])), 1)
        p["road"] = road
        out.append(p)
    return out


def signal_nodes(nodes, edges, signals, max_d: float = 22.0):
    """OSM-Ampelknoten -> nächstgelegene Kreuzung (Grad >= 3 im Verkehrsnetz)."""
    import math
    deg = {}
    for a, b, c, *_r in edges:
        if net.ROAD_CLASSES[net.CLASS_ORDER[c]]["traffic"]:
            deg[a] = deg.get(a, 0) + 1
            deg[b] = deg.get(b, 0) + 1
    cand = [n for n, d in deg.items() if d >= 3]
    if not cand:
        return []
    tree = STRtree([Point(nodes[n]) for n in cand])
    out = set()
    for p in signals:
        i = int(tree.nearest(Point(p)))
        if math.dist(nodes[cand[i]], p) <= max_d:
            out.add(cand[i])
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="osm", choices=["authored", "osm"])
    ap.add_argument("--cache", default=os.path.expanduser("~/osm_cache"))
    ap.add_argument("--out", default=os.path.join(ROOT, "data", "world", "ka"))
    args = ap.parse_args()
    t0 = time.time()
    if args.source == "osm":
        import source_osm
        src = source_osm.load(args.cache)
        nodes, edges, names = src.GRAPH
    else:
        import ka_authored as src
        nodes, edges, names = net.build_network(src.ROADS, src.DISTRICTS, src.AREAS)
    print(f"[welt] Netz: {len(nodes)} Knoten, {len(edges)} Kanten ({time.time() - t0:.1f} s)")
    pois = resolve_pois(src.POIS, nodes, edges, names)
    reserves = [Polygon(l["reserve"]) for l in src.LANDMARKS if "reserve" in l]
    clear = [Point(l["pos"]).buffer(l["clear"]) for l in src.LANDMARKS if l.get("clear", 0) > 0]
    poi_clear = [Point(p["pos"]).buffer(p["clear"]) for p in pois if p.get("clear", 0) > 0]
    if args.source == "osm":
        buildings = src.build_buildings((nodes, edges, names), poi_clear)
        print(f"[welt] Gebäude (OSM): {len(buildings)} ({time.time() - t0:.1f} s)")
        urban = []
        for g in list(src.URBAN) + [Polygon(b["p"]) for b in buildings]:
            g = g if g.is_valid else g.buffer(0)   # Selbstüberschneidungen nach Rundung/Zuschnitt bereinigen
            urban += [q for q in getattr(g, "geoms", [g]) if isinstance(q, Polygon) and not q.is_empty]
        blocks = bl.make_blocks(nodes, edges, src.BOUNDS, src.DISTRICTS, src.AREAS, urban=urban)
    else:
        blocks = bl.make_blocks(nodes, edges, src.BOUNDS, src.DISTRICTS, src.AREAS)
        lines = net.edge_lines(nodes, edges)
        tree = STRtree(lines)
        buildings = []
        for bi, b in enumerate(blocks):
            buildings += bl.build_block(b, bi, reserves, tree, lines, edges, clear + poi_clear)
        print(f"[welt] Gebäude: {len(buildings)} ({time.time() - t0:.1f} s)")
    print(f"[welt] Blöcke: {len(blocks)} ({time.time() - t0:.1f} s)")
    trees = getattr(src, "TREES", None) or None
    props = ex.make_props(nodes, edges, blocks, buildings, src.AREAS, trees=trees)
    print("[welt] Props: " + ", ".join(f"{k} {len(v)}" for k, v in props.items()))
    walk = ex.make_walk(blocks, nodes, edges)
    print(f"[welt] Gehwege: {len(walk[0])} Schleifen, {len(walk[1])} Querungen, {len(walk[2])} Flanierbereiche")
    extra = {}
    if hasattr(src, "SIGNALS"):
        extra["signals"] = signal_nodes(nodes, edges, src.SIGNALS)
        print(f"[welt] Ampelkreuzungen: {len(extra['signals'])}")
    if hasattr(src, "STOPS"):
        import transit
        extra["transit"] = transit.build(src, nodes, edges, names)
    if os.path.isdir(args.out):
        for sub in ("sectors", "lod"):
            shutil.rmtree(os.path.join(args.out, sub), ignore_errors=True)
    os.makedirs(args.out, exist_ok=True)
    meta = {"source": src.SOURCE, "note": src.SOURCE_NOTE}
    stats = ex.export_world(args.out, meta, nodes, edges, names, blocks, buildings, props, src.AREAS, src.WATERWAYS, src.RAILWAYS,
        src.LANDMARKS, pois, src.LABELS, src.DISTRICTS, walk, src.BOUNDS, extra)
    size = ex.render_map(os.path.join(args.out, "map.webp"), src.BOUNDS, nodes, edges, blocks, buildings, src.AREAS, src.WATERWAYS,
        src.RAILWAYS)
    map_bytes = os.path.getsize(os.path.join(args.out, "map.webp"))
    total = stats["bytes"] + map_bytes
    print(f"[welt] Sektoren {stats['sectors']}, LOD-Kacheln {stats['lod_tiles']}, world.json.gz {stats['world_bytes'] / 1e6:.2f} MB, "
        f"Karte {size[0]}x{size[1]} px {map_bytes / 1e6:.2f} MB, gesamt {total / 1e6:.1f} MB ({time.time() - t0:.1f} s)")
    if total > 40 * 1024 * 1024:
        print("[welt] FEHLER: Speicherbudget 40 MB überschritten")
        sys.exit(1)
    import validate_world
    if validate_world.validate(args.out):
        print("[welt] FEHLER: Validierung fehlgeschlagen")
        sys.exit(1)


if __name__ == "__main__":
    main()
