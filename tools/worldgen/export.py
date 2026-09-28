"""Props, Gehwegnetz, Parkplätze, Sektorierung, Fern-LOD, Kartenbild und world.json."""
from __future__ import annotations

import gzip
import json
import math
import os
from collections import defaultdict

from PIL import Image, ImageDraw
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from shapely.strtree import STRtree

from geo import ORIGIN_LAT, ORIGIN_LON, hash01
from network import CLASS_ORDER, ROAD_CLASSES

SECTOR = 256.0
LOD_TILE = 1024.0
MAP_M_PER_PX = 4.0
Q = 10.0  # Koordinaten in Dezimetern (Ganzzahlen) -> kompaktes JSON

AREA_KINDS = ["water", "forest", "park", "zoo", "garden", "cemetery", "sports", "rail", "plaza", "industry_yard", "field", "urban"]
SLAB_KINDS = {"urban", "plaza", "park", "zoo", "garden", "cemetery", "sports", "industry_yard"}
PROP_KINDS = ["lamp", "tree", "bench", "bin", "bike", "bollard", "car"]


def qi(v: float) -> int:
    return int(round(v * Q))


def flat(coords) -> list[int]:
    out = []
    for x, z in coords:
        out.append(qi(x))
        out.append(qi(z))
    return out


def ring_of(poly: Polygon) -> list:
    return list(poly.exterior.coords)[:-1]


def split_holes(poly: Polygon, depth: int = 0) -> list:
    """Polygon mit Löchern an einer senkrechten Linie durch das erste Loch teilen (rekursiv) -> lochfreie Teile."""
    if not poly.interiors or depth > 12:
        return [poly]
    hx = poly.interiors[0].centroid.x
    x0, z0, x1, z1 = poly.bounds
    left = poly.intersection(box(x0 - 1, z0 - 1, hx, z1 + 1))
    right = poly.intersection(box(hx, z0 - 1, x1 + 1, z1 + 1))
    out = []
    for part in (left, right):
        for g in getattr(part, "geoms", [part]):
            if isinstance(g, Polygon) and g.area > 1.0:
                out += split_holes(g, depth + 1)
    return out


# --------------------------------------------------------------------------- Props
def make_props(nodes, edges, blocks, buildings, areas):
    slabs = [b["poly"] for b in blocks if b["kind"] in ("urban", "plaza")]
    stree = STRtree(slabs)

    def on_slab(p):
        pt = Point(p)
        return any(slabs[i].contains(pt) for i in stree.query(pt))

    deg = defaultdict(int)
    for e in edges:
        deg[e[0]] += 1
        deg[e[1]] += 1
    props = defaultdict(list)  # kind -> [(x, z, yaw, variant)]
    for ei, (a, b, c, nm, f) in enumerate(edges):
        cls = CLASS_ORDER[c]
        rc = ROAD_CLASSES[cls]
        pa, pb = nodes[a], nodes[b]
        L = math.dist(pa, pb)
        if L < 4:
            continue
        dx, dz = (pb[0] - pa[0]) / L, (pb[1] - pa[1]) / L
        nx, nz = -dz, dx
        yaw = math.atan2(-dx, -dz)
        w2 = rc["width"] * 0.5
        if cls == "pedestrian":
            t = 8.0
            k = 0
            while t < L - 6:
                x, z = pa[0] + dx * t, pa[1] + dz * t
                side = 1 if k % 2 == 0 else -1
                props["tree"].append((x + nx * 4.6 * side, z + nz * 4.6 * side, 0.0, 1))
                props["bench"].append((x + nx * 3.0 * -side, z + nz * 3.0 * -side, yaw + (math.pi * 0.5 if side < 0 else -math.pi * 0.5), 0))
                if k % 2 == 0:
                    props["bin"].append((x + nx * 3.2 * -side + dx * 2.0, z + nz * 3.2 * -side + dz * 2.0, 0.0, 0))
                t += 18.0
                k += 1
            continue
        if not rc["sidewalk"]:
            continue
        # Laternen, abwechselnd links/rechts
        t = 6.0 + 20.0 * hash01(ei, "l")
        k = 0
        while t < L - 3:
            side = 1 if (k + ei) % 2 == 0 else -1
            p = (pa[0] + dx * t + nx * (w2 + 0.9) * side, pa[1] + dz * t + nz * (w2 + 0.9) * side)
            if on_slab(p):
                # Laternenarm (lokale +X-Achse) zeigt zur Fahrbahn: Richtung -n*side; Godot-Yaw = atan2(-vz, vx)
                vx, vz = -nx * side, -nz * side
                props["lamp"].append((p[0], p[1], math.atan2(-vz, vx), 0))
            t += 34.0
            k += 1
        # Straßenbäume an Haupt- und Alleestraßen
        name_is_allee = False
        if cls in ("primary", "secondary") or name_is_allee:
            t = 10.0
            while t < L - 8:
                for side in (1, -1):
                    p = (pa[0] + dx * t + nx * (w2 + 2.0) * side, pa[1] + dz * t + nz * (w2 + 2.0) * side)
                    if on_slab(p):
                        props["tree"].append((p[0], p[1], 0.0, 0))
                t += 14.0
        # Parkende Autos am Fahrbahnrand (rechte Seite), deterministisch. Nur wo Parkstreifen und Fahrspur
        # nebeneinander passen (Breite >= 11,4 m: Spurmitte 2,6 m + halbe Wagenbreite + Abstand < Parkposition - halbe Breite)
        # und mit Abstand zu Kreuzungen (Abbiegebögen).
        if cls in ("tertiary", "secondary") and L > 32 and w2 * 2 >= 11.4 and hash01(ei, "car") < 0.45:
            t = 14.0 + max(0.0, L - 28.0) * hash01(ei, "cp")
            p = (pa[0] + dx * t + nx * (w2 - 1.0), pa[1] + dz * t + nz * (w2 - 1.0))
            props["car"].append((p[0], p[1], yaw, int(hash01(ei, "cv") * 100)))
    # Plätze: Bänke und Bäume am Rand
    for bl in blocks:
        if bl["kind"] != "plaza":
            continue
        ring = bl["poly"].buffer(-3.5)
        for g in getattr(ring, "geoms", [ring]):
            if not isinstance(g, Polygon):
                continue
            ext = g.exterior
            n = int(ext.length / 16)
            for i in range(n):
                p = ext.interpolate(i * 16.0)
                q = ext.interpolate(i * 16.0 + 1.0)
                yaw = math.atan2(-(q.x - p.x), -(q.y - p.y))
                if i % 3 == 0:
                    props["tree"].append((p.x, p.y, 0.0, 1))
                else:
                    props["bench"].append((p.x, p.y, yaw + math.pi * 0.5, 0))
                if i % 4 == 1:
                    props["bin"].append((p.x + 1.2, p.y, 0.0, 0))
    # Fahrradständer vor Läden
    for bi, b in enumerate(buildings):
        if b["sh"] and hash01(bi, "bike") < 0.3:
            (x0, z0), (x1, z1) = b["p"][0], b["p"][1]
            mx, mz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
            L = math.hypot(x1 - x0, z1 - z0) or 1.0
            nx, nz = (z1 - z0) / L, -(x1 - x0) / L  # nach außen (CCW-Polygon)
            props["bike"].append((mx + nx * 1.6, mz + nz * 1.6, math.atan2(-(x1 - x0), -(z1 - z0)), int(hash01(bi, "bc") * 100)))
    # Poller an Übergängen Fußgängerzone -> Fahrbahn
    ped = [i for i, e in enumerate(edges) if CLASS_ORDER[e[2]] == "pedestrian"]
    drive_nodes = {e[0] for e in edges if ROAD_CLASSES[CLASS_ORDER[e[2]]]["drivable"]} | {e[1] for e in edges if ROAD_CLASSES[CLASS_ORDER[e[2]]]["drivable"]}
    for i in ped:
        a, b = edges[i][0], edges[i][1]
        for n, o in ((a, b), (b, a)):
            if n in drive_nodes:
                pa, pb = nodes[n], nodes[o]
                L = math.dist(pa, pb) or 1.0
                dx, dz = (pb[0] - pa[0]) / L, (pb[1] - pa[1]) / L
                nx, nz = -dz, dx
                for s in (-4.5, -1.5, 1.5, 4.5):
                    props["bollard"].append((pa[0] + dx * 12 + nx * s, pa[1] + dz * 12 + nz * s, 0.0, 0))
    return props


# --------------------------------------------------------------------------- Gehwegnetz
def make_walk(blocks, nodes, edges):
    loops = []
    for b in blocks:
        if b["kind"] not in ("urban", "plaza", "park", "garden", "zoo", "cemetery"):
            continue
        inner = b["poly"].buffer(-1.6, join_style=2)
        for g in getattr(inner, "geoms", [inner]):
            if isinstance(g, Polygon) and g.area > 150:
                s = g.simplify(0.8)
                if isinstance(s, Polygon) and len(s.exterior.coords) >= 4:
                    loops.append(ring_of(s))
    pts, owner = [], []
    for li, lp in enumerate(loops):
        for vi, p in enumerate(lp):
            pts.append(Point(p))
            owner.append((li, vi))
    tree = STRtree(pts)
    road_lines = [LineString([nodes[e[0]], nodes[e[1]]]) for e in edges if ROAD_CLASSES[CLASS_ORDER[e[2]]]["drivable"]]
    rtree = STRtree(road_lines)
    cross = []
    for k, p in enumerate(pts):
        li, vi = owner[k]
        cands = []
        for j in tree.query(p.buffer(28.0)):
            lj, vj = owner[j]
            if lj == li:
                continue
            d = p.distance(pts[j])
            if 6.0 < d < 28.0:
                seg = LineString([p, pts[j]])
                if any(road_lines[r].intersects(seg) for r in rtree.query(seg)):
                    cands.append((d, lj, vj))
        cands.sort()
        for d, lj, vj in cands[:2]:
            cross.append([li, vi, lj, vj])
    wander = []
    for b in blocks:
        if b["kind"] in ("plaza", "park", "zoo", "garden"):
            c = b["poly"].centroid
            r = math.sqrt(b["poly"].area / math.pi) * 0.55
            if r > 6:
                wander.append([qi(c.x), qi(c.y), qi(min(r, 60.0)), AREA_KINDS.index(b["kind"])])
    return loops, cross, wander


# --------------------------------------------------------------------------- Sektorierung
def sector_of(x, z, bounds):
    return (int(math.floor((x - bounds[0]) / SECTOR)), int(math.floor((z - bounds[1]) / SECTOR)))


def export_world(out_dir, meta, nodes, edges, names, blocks, buildings, props, areas, waterways, railways, landmarks, pois,
        labels, districts, walk, bounds):
    os.makedirs(os.path.join(out_dir, "sectors"), exist_ok=True)
    sectors = defaultdict(lambda: {"a": [], "k": [], "b": [], "e": [], "n": [], "p": {k: [] for k in PROP_KINDS}, "r": [], "lm": []})

    def boxes_for(geom):
        x0, z0, x1, z1 = geom.bounds
        i0, j0 = sector_of(x0, z0, bounds)
        i1, j1 = sector_of(x1, z1, bounds)
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                bx = bounds[0] + i * SECTOR
                bz = bounds[1] + j * SECTOR
                yield (i, j), box(bx, bz, bx + SECTOR, bz + SECTOR)

    def add_poly_clipped(key, kind_i, geom):
        for (ij, sq) in boxes_for(geom):
            part = geom.intersection(sq)
            for g0 in getattr(part, "geoms", [part]):
                if not isinstance(g0, Polygon) or g0.area <= 2.0:
                    continue
                for g in split_holes(g0):
                    g = g.simplify(0.2)
                    if not isinstance(g, Polygon) or g.is_empty or g.area <= 2.0:
                        continue
                    if not g.exterior.is_ccw:
                        g = Polygon(list(g.exterior.coords)[::-1])
                    sectors[ij][key].append([kind_i, flat(ring_of(g))])

    # Bodenflächen (Wasser, Wald, Parks, ...) und Flussläufe
    for a in areas:
        add_poly_clipped("a", AREA_KINDS.index(a["kind"]), Polygon(a["poly"]).buffer(0))
    for w in waterways:
        add_poly_clipped("a", AREA_KINDS.index("water"), LineString(w["pts"]).buffer(w["width"] * 0.5))
    # Blockplatten (Bordstein)
    for b in blocks:
        if b["kind"] in SLAB_KINDS:
            add_poly_clipped("k", AREA_KINDS.index(b["kind"]), b["poly"])
    # Gebäude
    for b in buildings:
        xs = [p[0] for p in b["p"]]
        zs = [p[1] for p in b["p"]]
        ij = sector_of(sum(xs) / len(xs), sum(zs) / len(zs), bounds)
        sectors[ij]["b"].append([flat(b["p"]), "".join(str(c) for c in b["e"]), b["f"], qi(b["h"]), b["s"], b["sh"], b["r"], b["c"],
            int(b["sd"] * 1000)])
    # Straßenkanten und Kreuzungen
    deg = defaultdict(int)
    for ei, e in enumerate(edges):
        pa, pb = nodes[e[0]], nodes[e[1]]
        sectors[sector_of((pa[0] + pb[0]) * 0.5, (pa[1] + pb[1]) * 0.5, bounds)]["e"].append(ei)
        deg[e[0]] += 1
        deg[e[1]] += 1
    for ni, p in enumerate(nodes):
        if deg[ni] >= 3 or deg[ni] == 1:
            sectors[sector_of(p[0], p[1], bounds)]["n"].append(ni)
    # Props
    for kind, lst in props.items():
        for x, z, yaw, var in lst:
            sectors[sector_of(x, z, bounds)]["p"][kind] += [qi(x), qi(z), int(round(yaw * 1000)), int(var)]
    # Bahnstrecken (geclippt)
    for r in railways:
        line = LineString(r["pts"])
        for ij, sq in boxes_for(line):
            part = line.intersection(sq)
            for g in getattr(part, "geoms", [part]):
                if isinstance(g, LineString) and g.length > 1:
                    sectors[ij]["r"].append([int(r.get("tracks", 2)), flat(list(g.coords))])
    for li, lm in enumerate(landmarks):
        sectors[sector_of(lm["pos"][0], lm["pos"][1], bounds)]["lm"].append(li)

    total = 0
    written = []
    for (i, j), s in sorted(sectors.items()):
        if i < 0 or j < 0:
            continue
        data = json.dumps(s, separators=(",", ":")).encode()
        gz = gzip.compress(data, 9)
        with open(os.path.join(out_dir, "sectors", "s_%d_%d.json.gz" % (i, j)), "wb") as fh:
            fh.write(gz)
        total += len(gz)
        written.append([i, j])

    # Fern-LOD: gedrehte Quader je Gebäude, je 1-km-Kachel
    lod = defaultdict(list)
    for b in buildings:
        poly = Polygon(b["p"])
        mrr = poly.minimum_rotated_rectangle
        cs = list(mrr.exterior.coords)[:4]
        if len(cs) < 4:
            continue
        w = math.dist(cs[0], cs[1])
        d = math.dist(cs[1], cs[2])
        ang = math.atan2(cs[1][1] - cs[0][1], cs[1][0] - cs[0][0])
        c = mrr.centroid
        roof_extra = 0.0 if b["r"] == "f" else 2.5
        key = (int(math.floor((c.x - bounds[0]) / LOD_TILE)), int(math.floor((c.y - bounds[1]) / LOD_TILE)))
        lod[key] += [qi(c.x), qi(c.y), qi(w), qi(d), int(round(ang * 1000)), qi(b["h"] + roof_extra), b["c"], b["s"]]
    os.makedirs(os.path.join(out_dir, "lod"), exist_ok=True)
    lod_tiles = []
    for (i, j), arr in sorted(lod.items()):
        gz = gzip.compress(json.dumps(arr, separators=(",", ":")).encode(), 9)
        with open(os.path.join(out_dir, "lod", "t_%d_%d.json.gz" % (i, j)), "wb") as fh:
            fh.write(gz)
        total += len(gz)
        lod_tiles.append([i, j])

    world = {
        "format": "faecherstadt-world", "version": 2, **meta, "origin": [ORIGIN_LAT, ORIGIN_LON],
        "bounds": list(bounds), "sector": SECTOR, "sectors": written, "lod": {"tile": LOD_TILE, "tiles": lod_tiles},
        "q": Q, "classes": ROAD_CLASSES, "class_order": CLASS_ORDER, "area_kinds": AREA_KINDS, "prop_kinds": PROP_KINDS,
        "nodes": flat(nodes), "edges": [v for e in edges for v in e], "names": names,
        "pois": pois, "labels": labels, "landmarks": landmarks,
        "districts": [{"id": d["id"], "name": d["name"], "style": d["style"], "poly": flat(Polygon(d["poly"]).simplify(5).exterior.coords[:-1])}
            for d in districts],
        "walk": {"loops": [flat(lp) for lp in walk[0]], "cross": [v for c in walk[1] for v in c], "wander": [v for w in walk[2] for v in w]},
        "rail": [{"name": r["name"], "tracks": r.get("tracks", 2), "pts": flat(r["pts"])} for r in railways],
        "map": {"image": "map.webp", "m_per_px": MAP_M_PER_PX},
    }
    wz = gzip.compress(json.dumps(world, separators=(",", ":"), ensure_ascii=False).encode(), 9)
    with open(os.path.join(out_dir, "world.json.gz"), "wb") as fh:
        fh.write(wz)
    total += len(wz)
    return {"sectors": len(written), "lod_tiles": len(lod_tiles), "bytes": total, "world_bytes": len(wz)}


# --------------------------------------------------------------------------- Kartenbild
MAP_COLORS = {
    "bg": (58, 66, 54), "field": (74, 84, 60), "forest": (38, 62, 42), "park": (62, 96, 58), "zoo": (70, 102, 62),
    "garden": (70, 108, 70), "cemetery": (58, 84, 60), "sports": (70, 104, 64), "water": (54, 92, 128), "rail": (84, 80, 78),
    "plaza": (150, 138, 116), "industry_yard": (92, 90, 88), "urban": (96, 94, 96), "building": (142, 128, 118),
    "building_mod": (128, 132, 140), "rail_line": (58, 56, 60),
}
ROAD_COLORS = {"motorway": (232, 170, 90), "trunk": (228, 196, 120), "primary": (236, 222, 180), "secondary": (224, 220, 208),
    "tertiary": (206, 204, 198), "residential": (184, 182, 178), "service": (160, 158, 154), "pedestrian": (186, 164, 136)}


def render_map(path, bounds, nodes, edges, blocks, buildings, areas, waterways, railways):
    x0, z0, x1, z1 = bounds
    W = int((x1 - x0) / MAP_M_PER_PX)
    H = int((z1 - z0) / MAP_M_PER_PX)
    img = Image.new("RGB", (W, H), MAP_COLORS["field"])
    dr = ImageDraw.Draw(img)

    def P(p):
        return ((p[0] - x0) / MAP_M_PER_PX, (p[1] - z0) / MAP_M_PER_PX)

    order = ["field", "forest", "park", "cemetery", "sports", "garden", "zoo", "rail", "industry_yard", "water", "plaza"]
    for kind in order:
        for a in areas:
            if a["kind"] == kind:
                dr.polygon([P(p) for p in a["poly"]], fill=MAP_COLORS[kind])
    for w in waterways:
        dr.line([P(p) for p in w["pts"]], fill=MAP_COLORS["water"], width=max(2, int(w["width"] / MAP_M_PER_PX)))
    for b in blocks:
        if b["kind"] in SLAB_KINDS:
            dr.polygon([P(p) for p in ring_of(b["poly"])], fill=MAP_COLORS[b["kind"]])
    for b in buildings:
        dr.polygon([P(p) for p in b["p"]], fill=MAP_COLORS["building_mod" if b["s"] in (1, 3, 4, 5) else "building"])
    for r in railways:
        dr.line([P(p) for p in r["pts"]], fill=MAP_COLORS["rail_line"], width=3)
    for cls in reversed(CLASS_ORDER):
        col = ROAD_COLORS[cls]
        wpx = max(1, int(round(ROAD_CLASSES[cls]["width"] / MAP_M_PER_PX)))
        for e in edges:
            if CLASS_ORDER[e[2]] == cls:
                dr.line([P(nodes[e[0]]), P(nodes[e[1]])], fill=col, width=wpx)
    img.save(path, "WEBP", quality=88, method=6)
    return (W, H)
