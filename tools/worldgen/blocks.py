"""Häuserblöcke (Gehwegplatten) aus dem Straßennetz und Bebauung je Bebauungsstil.

Kantencodes je Gebäudewand (Feld "e"): 1 = Straßenfassade, 2 = Hof-/Rückseite, 3 = freiliegende Seite, 0 = Brandwand.
Dachtypen (Feld "r"): g = Satteldach (Traufe entlang Kante 0), h = Walmdach, f = Flachdach, m = Mansarddach.
Stil (Feld "s"): 0 Altbau, 1 modern, 2 Dorf/Fachwerk, 3 Industrie, 4 Hochhaus, 5 Campus, 6 Villa/Einfamilienhaus.
"""
from __future__ import annotations

import math

from shapely import affinity
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import polygonize, unary_union
from shapely.strtree import STRtree

from geo import hash01
from network import CLASS_ORDER, ROAD_CLASSES, edge_width

SIDEWALK = 3.2

STYLES = {
    #              Parzellentiefe, Breite min/max, Stockwerke min/max, Laden-Wkt., Lücken, Stil-Id, Flachdach-Wkt.
    "altstadt":     {"kind": "ring", "depth": 14.0, "w": (10, 17), "floors": (4, 6), "shop": 0.35, "gap": 0.02, "s": 0, "flat": 0.12},
    "gruenderzeit": {"kind": "ring", "depth": 13.0, "w": (11, 18), "floors": (4, 5), "shop": 0.15, "gap": 0.04, "s": 0, "flat": 0.1},
    "dorf":         {"kind": "ring", "depth": 11.0, "w": (9, 15), "floors": (2, 3), "shop": 0.08, "gap": 0.15, "s": 2, "flat": 0.0},
    "modern":       {"kind": "ring", "depth": 15.0, "w": (18, 32), "floors": (5, 7), "shop": 0.2, "gap": 0.1, "s": 1, "flat": 1.0},
    "zeile":        {"kind": "rows", "depth": 12.0, "floors": (3, 5), "s": 1, "flat": 0.5},
    "hochhaus":     {"kind": "rows", "depth": 14.0, "floors": (8, 15), "s": 4, "flat": 1.0},
    "campus":       {"kind": "rows", "depth": 18.0, "floors": (3, 5), "s": 5, "flat": 1.0},
    "villa":        {"kind": "houses", "floors": (1, 2), "s": 6, "flat": 0.1},
    "industrie":    {"kind": "halls", "floors": (2, 3), "s": 3, "flat": 1.0},
}
WALL_COLORS = 12
ROOF_COLORS = 4

BLOCK_KIND_PRIORITY = ["water", "zoo", "garden", "cemetery", "sports", "rail", "plaza", "parking", "park", "forest", "industry_yard",
    "field"]


def _safe_inter_area(a, b) -> float:
    """Schnittfläche; ungültige Geometrien (z. B. OSM-Multipolygone) werden bereinigt statt abzubrechen."""
    try:
        return a.intersection(b).area
    except Exception:  # GEOSException: TopologyException
        return a.buffer(0).intersection(b.buffer(0)).area


def make_blocks(nodes, edges, bounds, districts, areas, urban=None):
    """Flächen zwischen Straßen -> Blöcke mit Bordsteinpolygon. Rückgabe: Liste {poly, kind, district, style}.
    urban: optionale Geometrie bebauter Flächen (OSM: Wohn-/Gewerbegebiete + Gebäude); ohne sie gilt „in einem Viertel“."""
    lines = [LineString([nodes[e[0]], nodes[e[1]]]) for e in edges]
    widths = [edge_width(e) for e in edges]
    utree = STRtree(urban) if urban else None
    x0, z0, x1, z1 = bounds
    frame = LineString([(x0, z0), (x1, z0), (x1, z1), (x0, z1), (x0, z0)])
    faces = list(polygonize(unary_union(lines + [frame])))
    tree = STRtree(lines)
    dpolys = [(d, Polygon(d["poly"]).buffer(0)) for d in districts]
    apolys = [(a, Polygon(a["poly"], a.get("holes") or []).buffer(0)) for a in areas]
    atree = STRtree([p for _, p in apolys])
    blocks = []
    for fi, face in enumerate(faces):
        if face.area < 80:
            continue
        near = tree.query(face.buffer(15))
        cut = unary_union([lines[i].buffer(widths[i] * 0.5, cap_style=1) for i in near]) if len(near) else None
        curb = face.difference(cut) if cut is not None else face
        # Sonderflächen (Parks, Zoo, Plätze ...) aus dem Block herausschneiden -> eigene Blöcke
        pieces = []
        rest = curb
        hits = sorted(atree.query(curb), key=lambda ai: BLOCK_KIND_PRIORITY.index(apolys[ai][0]["kind"])
            if apolys[ai][0]["kind"] in BLOCK_KIND_PRIORITY else 99)
        for ai in hits:
            a, ap = apolys[ai]
            if a["kind"] not in BLOCK_KIND_PRIORITY or a["kind"] == "field" or rest.is_empty:
                continue
            inter = rest.intersection(ap)
            if inter.is_empty or inter.area < 60:
                continue
            pieces.append((inter, a["kind"], a["name"]))
            rest = rest.difference(ap)
        pieces.append((rest, None, ""))
        for geom, kind0, name in pieces:
            for part in getattr(geom, "geoms", [geom]):
                if not isinstance(part, Polygon) or part.area < 60:
                    continue
                part = part.simplify(0.25)
                if not isinstance(part, Polygon) or part.is_empty:
                    continue
                rp = part.representative_point()
                district = None
                for d, dp in dpolys:
                    if dp.contains(rp):
                        district = d
                        break
                if kind0:
                    kind = kind0
                elif utree is not None:
                    cover = sum(_safe_inter_area(urban[i], part) for i in utree.query(part)) if part.area < 4e6 else 0.0
                    kind = "urban" if cover > part.area * 0.15 or cover > 800 else "field"
                else:
                    kind = "urban" if district is not None else "field"
                blocks.append({"poly": part, "kind": kind, "name": name, "district": district["id"] if district else "",
                    "style": district["style"] if district else "", "face": fi})
    return blocks


def _road_class_near(tree, lines, edges, p, max_d=25.0):
    best, bd = None, max_d
    for i in tree.query(Point(p).buffer(max_d)):
        d = lines[i].distance(Point(p))
        if d < bd:
            best, bd = CLASS_ORDER[edges[i][2]], d
    return best


def _edge_codes(poly: Polygon, front_ring, court) -> list[int]:
    codes = []
    cs = list(poly.exterior.coords)[:-1]
    for a, b in zip(cs, cs[1:] + cs[:1]):
        mid = Point((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        if front_ring.distance(mid) < 0.35:
            codes.append(1)
        elif court is not None and court.boundary.distance(mid) < 0.35:
            codes.append(2)
        else:
            codes.append(0)
    return codes


def _rotate_to_front(coords, codes):
    """Knotenliste so drehen, dass Kante 0 eine Straßenfassade ist (für Satteldach und Eingänge)."""
    if 1 in codes:
        k = codes.index(1)
        coords = coords[k:] + coords[:k]
        codes = codes[k:] + codes[:k]
    return coords, codes


def _bld(coords, codes, floors, style, seed, shop, roof, color, gf=None):
    fh = 3.2
    ground = 4.2 if shop else 3.5
    if style == 3:
        fh, ground = 4.5, 5.0
    h = ground + (floors - 1) * fh
    return {"p": coords, "e": codes, "f": floors, "h": round(h, 1), "s": style, "sh": 1 if shop else 0, "r": roof,
        "c": color, "sd": round(seed, 3)}


def build_block(block, bi, reserves, road_tree, road_lines, edges, clear_zones):
    st = STYLES.get("industrie" if block["kind"] == "industry_yard" else block["style"])
    if st is None or block["kind"] not in ("urban", "industry_yard"):
        return []
    front = block["poly"].buffer(-SIDEWALK, join_style=2)
    out = []
    for part in getattr(front, "geoms", [front]):
        if not isinstance(part, Polygon) or part.area < 90:
            continue
        part = part.simplify(0.3)
        kind = st["kind"]
        if kind == "ring":
            out += _ring(part, st, block, bi, road_tree, road_lines, edges)
        elif kind == "rows":
            out += _rows(part, st, block, bi)
        elif kind == "houses":
            out += _houses(part, st, block, bi)
        elif kind == "halls":
            out += _halls(part, st, block, bi)
    # Seitenwände ohne Nachbargebäude -> freiliegende Fassade (Code 3) statt Brandwand
    shared = {}
    for b in out:
        cs = b["p"]
        for a, c in zip(cs, cs[1:] + cs[:1]):
            k = _ekey(a, c)
            shared[k] = shared.get(k, 0) + 1
    for b in out:
        cs = b["p"]
        for i, (a, c) in enumerate(zip(cs, cs[1:] + cs[:1])):
            if b["e"][i] == 0 and shared.get(_ekey(a, c), 0) < 2:
                b["e"][i] = 3
    keep = []
    for b in out:
        poly = Polygon(b["p"])
        if any(r.intersects(poly) for r in reserves) or any(c.intersects(poly) for c in clear_zones):
            continue
        b["p"] = [[round(x, 1), round(z, 1)] for x, z in b["p"]]
        keep.append(b)
    return keep


def _ekey(a, b):
    ka = (round(a[0], 1), round(a[1], 1))
    kb = (round(b[0], 1), round(b[1], 1))
    return (ka, kb) if ka < kb else (kb, ka)


def _ring(front: Polygon, st, block, bi, road_tree, road_lines, edges):
    depth = st["depth"]
    court = front.buffer(-depth, join_style=2)
    if court.is_empty or court.area < 120:
        court = front.buffer(-depth * 0.7, join_style=2)
    solid = court.is_empty or court.area < 60
    ring = front if solid else front.difference(court)
    ext = list(front.exterior.coords)[:-1]
    cuts = []
    wmin, wmax = st["w"]
    for i, (a, b) in enumerate(zip(ext, ext[1:] + ext[:1])):
        L = math.dist(a, b)
        if L < 2 * depth:
            continue
        # Innennormale (Polygon gegen den Uhrzeigersinn orientiert -> links)
        dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, nz = -dz, dx
        if not front.contains(Point((a[0] + b[0]) * 0.5 + nx * 1.0, (a[1] + b[1]) * 0.5 + nz * 1.0)):
            nx, nz = -nx, -nz
        t = depth
        k = 0
        while True:
            w = wmin + (wmax - wmin) * hash01(bi, i, k)
            t += w
            if t > L - depth + 0.1:
                break
            px_, pz_ = a[0] + dx * t, a[1] + dz * t
            cuts.append(LineString([(px_ - nx * 0.5, pz_ - nz * 0.5), (px_ + nx * (depth + 1.5), pz_ + nz * (depth + 1.5))]))
            k += 1
    pieces = [ring] if not cuts else [p for p in polygonize(unary_union([ring.boundary] + cuts)) if ring.contains(p.representative_point())]
    out = []
    front_ring = front.exterior
    for li, lot in enumerate(pieces):
        if lot.area < 25:
            continue
        lot = lot.simplify(0.2)
        if not isinstance(lot, Polygon) or len(lot.exterior.coords) < 4:
            continue
        lot = lot if lot.exterior.is_ccw else Polygon(list(lot.exterior.coords)[::-1])
        seed = hash01(bi, li, "lot")
        if hash01(bi, li, "gap") < st["gap"]:
            continue
        coords = [tuple(c) for c in list(lot.exterior.coords)[:-1]]
        codes = _edge_codes(lot, front_ring, None if solid else court)
        coords, codes = _rotate_to_front(coords, codes)
        cen = lot.centroid
        rc = _road_class_near(road_tree, road_lines, edges, (cen.x, cen.y), depth + 20)
        f0, f1 = st["floors"]
        bonus = 1 if rc in ("primary", "secondary", "pedestrian") and block["style"] != "dorf" else 0
        floors = f0 + int(hash01(bi, li, "f") * (f1 - f0 + 1)) + bonus
        shop_p = 1.0 if rc == "pedestrian" else (st["shop"] * (2.2 if rc in ("primary", "secondary") else 1.0))
        shop = hash01(bi, li, "shop") < shop_p
        flat = hash01(bi, li, "flat") < st["flat"] or len(coords) != 4
        roof = "f" if flat else ("m" if st["s"] == 0 and hash01(bi, li, "m") < 0.2 else "g")
        out.append(_bld(coords, codes, floors, st["s"], seed, shop, roof, int(hash01(bi, li, "c") * WALL_COLORS)))
    return out


def _main_angle(poly: Polygon) -> float:
    mrr = poly.minimum_rotated_rectangle
    cs = list(mrr.exterior.coords)
    best, ang = 0, 0.0
    for a, b in zip(cs, cs[1:]):
        L = math.dist(a, b)
        if L > best:
            best, ang = L, math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
    return ang


def _rows(front: Polygon, st, block, bi):
    inner = front.buffer(-4.0, join_style=2)
    if inner.is_empty:
        return []
    ang = _main_angle(inner)
    c = inner.centroid
    loc = affinity.rotate(inner, -ang, origin=c)
    x0, z0, x1, z1 = loc.bounds
    depth = st["depth"]
    spacing = depth * (2.2 if st["s"] == 4 else 2.4)
    out = []
    z = z0 + 2.0
    ri = 0
    while z + depth < z1:
        strip = Polygon([(x0, z), (x1, z), (x1, z + depth), (x0, z + depth)]).intersection(loc)
        for g in getattr(strip, "geoms", [strip]):
            if not isinstance(g, Polygon) or g.area < 120:
                continue
            gx0, gz0, gx1, gz1 = g.bounds
            seg_len = 70.0 if st["s"] != 4 else 32.0
            x = gx0
            k = 0
            while x < gx1 - 12:
                L = min(seg_len * (0.7 + 0.5 * hash01(bi, ri, k)), gx1 - x)
                piece = Polygon([(x, gz0), (x + L, gz0), (x + L, gz1), (x, gz1)]).intersection(g)
                if isinstance(piece, Polygon) and piece.area > 100:
                    rect = piece.minimum_rotated_rectangle
                    clipped = rect.area > piece.area * 1.03
                    if clipped:
                        # Umrechteck ragte über den Block hinaus -> beschneiden (dann Flachdach)
                        rect = rect.intersection(loc)
                        if not isinstance(rect, Polygon) or rect.area < 100:
                            x += L + 9.0
                            k += 1
                            continue
                        rect = rect.simplify(0.5)
                    world = affinity.rotate(rect, ang, origin=c)
                    world = world if world.exterior.is_ccw else Polygon(list(world.exterior.coords)[::-1])
                    coords = [tuple(p) for p in list(world.exterior.coords)[:-1]]
                    f0, f1 = st["floors"]
                    floors = f0 + int(hash01(bi, ri, k, "f") * (f1 - f0 + 1))
                    flat = hash01(bi, ri, k, "flat") < st["flat"] or len(coords) != 4
                    out.append(_bld(coords, [3] * len(coords), floors, st["s"], hash01(bi, ri, k), False,
                        "f" if flat else "g", int(hash01(bi, ri, k, "c") * WALL_COLORS)))
                x += L + 9.0
                k += 1
        z += spacing
        ri += 1
    return out


def _houses(front: Polygon, st, block, bi):
    out = []
    ext = list(front.exterior.coords)[:-1]
    placed = []
    for i, (a, b) in enumerate(zip(ext, ext[1:] + ext[:1])):
        L = math.dist(a, b)
        if L < 14:
            continue
        dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, nz = -dz, dx
        if not front.contains(Point((a[0] + b[0]) * 0.5 + nx, (a[1] + b[1]) * 0.5 + nz)):
            nx, nz = -nx, -nz
        t = 5.0
        k = 0
        while t < L - 12:
            lot_w = 15 + 8 * hash01(bi, i, k)
            w = 8.5 + 3.5 * hash01(bi, i, k, "w")
            d = 8.0 + 3.0 * hash01(bi, i, k, "d")
            setback = 4.0 + 3.0 * hash01(bi, i, k, "s")
            cx, cz = a[0] + dx * (t + lot_w * 0.5), a[1] + dz * (t + lot_w * 0.5)
            p0 = (cx - dx * w / 2 + nx * setback, cz - dz * w / 2 + nz * setback)
            p1 = (cx + dx * w / 2 + nx * setback, cz + dz * w / 2 + nz * setback)
            p2 = (p1[0] + nx * d, p1[1] + nz * d)
            p3 = (p0[0] + nx * d, p0[1] + nz * d)
            poly = Polygon([p0, p1, p2, p3])
            if not poly.exterior.is_ccw:
                poly = Polygon([p0, p3, p2, p1])
                coords = [p1, p0, p3, p2]
            else:
                coords = [p0, p1, p2, p3]
            if front.contains(poly) and not any(q.intersects(poly.buffer(2.0)) for q in placed):
                placed.append(poly)
                f0, f1 = st["floors"]
                floors = f0 + int(hash01(bi, i, k, "f") * (f1 - f0 + 1))
                roof = "f" if hash01(bi, i, k, "flat") < st["flat"] else ("h" if hash01(bi, i, k, "hip") < 0.35 else "g")
                out.append(_bld(coords, [1, 3, 3, 3], floors, st["s"], hash01(bi, i, k), False, roof,
                    int(hash01(bi, i, k, "c") * WALL_COLORS)))
            t += lot_w
            k += 1
    return out


def _halls(front: Polygon, st, block, bi):
    inner = front.buffer(-7.0, join_style=2)
    out = []
    for g in getattr(inner, "geoms", [inner]):
        if not isinstance(g, Polygon) or g.area < 300:
            continue
        ang = _main_angle(g)
        c = g.centroid
        loc = affinity.rotate(g, -ang, origin=c)
        x0, z0, x1, z1 = loc.bounds
        n = max(1 + int(hash01(bi, "n") * 3), int(math.ceil((x1 - x0) / 110.0)))   # Hallen höchstens ~100 m lang
        step = (x1 - x0) / n
        for k in range(n):
            piece = Polygon([(x0 + k * step + 5, z0), (x0 + (k + 1) * step - 5, z0), (x0 + (k + 1) * step - 5, z1), (x0 + k * step + 5, z1)]).intersection(loc)
            if not isinstance(piece, Polygon) or piece.area < 200:
                continue
            rect = piece.minimum_rotated_rectangle
            if rect.area > piece.area * 1.03:
                # Umrechteck ragte über den Block hinaus (bis in die Straße) -> auf die Innenfläche beschneiden
                rect = rect.intersection(loc)
                if not isinstance(rect, Polygon) or rect.area < 200:
                    continue
                rect = rect.simplify(0.5)
            world = affinity.rotate(rect, ang, origin=c)
            world = world if world.exterior.is_ccw else Polygon(list(world.exterior.coords)[::-1])
            coords = [tuple(p) for p in list(world.exterior.coords)[:-1]]
            f0, f1 = st["floors"]
            out.append(_bld(coords, [3] * len(coords), f0 + int(hash01(bi, k, "f") * (f1 - f0 + 1)), 3, hash01(bi, k), False, "f",
                int(hash01(bi, k, "c") * WALL_COLORS)))
    return out
