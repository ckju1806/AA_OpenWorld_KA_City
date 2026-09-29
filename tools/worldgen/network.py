"""Straßennetz: Nebenstraßenraster je Viertel, Verknotung, Attribut-Zuordnung, Graph mit kurzen Kanten."""
from __future__ import annotations

import math
from collections import defaultdict

from shapely import affinity
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree

from geo import hash01

# Straßenklassen: Breite (m, Bordstein zu Bordstein), Richtgeschwindigkeit (m/s), Eigenschaften
ROAD_CLASSES = {
    "motorway":    {"width": 24.0, "speed": 30.0, "drivable": True, "traffic": True, "major": True, "lights": False, "sidewalk": False, "rank": 9},
    "trunk":       {"width": 17.0, "speed": 20.0, "drivable": True, "traffic": True, "major": True, "lights": False, "sidewalk": False, "rank": 8},
    "primary":     {"width": 15.0, "speed": 15.0, "drivable": True, "traffic": True, "major": True, "lights": True, "sidewalk": True, "rank": 7},
    "secondary":   {"width": 13.0, "speed": 13.5, "drivable": True, "traffic": True, "major": True, "lights": True, "sidewalk": True, "rank": 6},
    "tertiary":    {"width": 12.0, "speed": 12.0, "drivable": True, "traffic": True, "major": False, "lights": False, "sidewalk": True, "rank": 5},
    "residential": {"width": 8.5, "speed": 8.5, "drivable": True, "traffic": True, "major": False, "lights": False, "sidewalk": True, "rank": 4},
    "service":     {"width": 6.0, "speed": 6.0, "drivable": True, "traffic": False, "major": False, "lights": False, "sidewalk": True, "rank": 3},
    "pedestrian":  {"width": 14.0, "speed": 0.0, "drivable": False, "traffic": False, "major": False, "lights": False, "sidewalk": True, "rank": 2},
}
CLASS_ORDER = list(ROAD_CLASSES.keys())


def edge_width(e) -> float:
    """Fahrbahnbreite einer Kante: Flags ab Bit 8 (0,5-m-Schritte, OSM) oder Klassenbreite."""
    w = (e[4] >> 8) & 0xFF
    return w * 0.5 if w > 0 else ROAD_CLASSES[CLASS_ORDER[e[2]]]["width"]
MAX_EDGE = 60.0
SNAP = 2.5

# Flächen ohne Nebenstraßen
NO_GRID_KINDS = {"water", "forest", "park", "zoo", "garden", "cemetery", "sports", "rail", "plaza"}


def grid_streets(district: dict, blockers) -> list[LineString]:
    """Nebenstraßenraster innerhalb eines Viertels (gedreht), ohne Parks/Wasser, mit zufällig ausgelassenen Abschnitten."""
    if not district.get("grid"):
        return []
    ang, sx, sz, off = district["grid"]
    poly = Polygon(district["poly"]).buffer(0)
    c = poly.centroid
    local = affinity.rotate(poly, -ang, origin=c)
    x0, z0, x1, z1 = local.bounds
    lines = []
    k = 0
    x = x0 + (off % sx) + sx * 0.5
    while x < x1:
        lines.append(LineString([(x, z0 - 5), (x, z1 + 5)]))
        x += sx * (0.85 + 0.3 * hash01(district["id"], "x", k))
        k += 1
    z = z0 + (off % sz) + sz * 0.5
    k = 0
    while z < z1:
        lines.append(LineString([(x0 - 5, z), (x1 + 5, z)]))
        z += sz * (0.85 + 0.3 * hash01(district["id"], "z", k))
        k += 1
    out = []
    grid = unary_union([affinity.rotate(l, ang, origin=c) for l in lines])
    clipped = grid.intersection(poly)
    if blockers is not None and not blockers.is_empty:
        clipped = clipped.difference(blockers)
    for g in getattr(clipped, "geoms", [clipped]):
        if isinstance(g, LineString) and g.length > 25.0:
            out.append(g)
    # Einzelne Rasterabschnitte weglassen -> größere, unregelmäßigere Blöcke
    kept = []
    for i, l in enumerate(out):
        if hash01(district["id"], "drop", i) < 0.08 and l.length < 160:
            continue
        kept.append(l)
    return kept


def build_network(roads: list[dict], districts: list[dict], areas: list[dict]):
    """Liefert (nodes, edges, names). nodes: [(x, z)], edges: [(a, b, cls, name_idx, flags)]."""
    blockers = unary_union([Polygon(a["poly"]).buffer(8) for a in areas if a["kind"] in NO_GRID_KINDS])
    src = []  # (LineString, cls, name, flags)
    for r in roads:
        flags = (1 if r.get("tunnel") else 0) | (2 if r.get("bridge") else 0) | (4 if r.get("oneway") else 0)
        src.append((LineString(r["pts"]), r["cls"], r["name"], flags))
    major = unary_union([s[0].buffer(ROAD_CLASSES[s[1]]["width"] * 0.5 + 25) for s in src])
    for d in districts:
        for l in grid_streets(d, unary_union([blockers, major])):
            src.append((l, "residential", "", 0))
    # Verknoten
    noded = unary_union([s[0] for s in src])
    parts = [g for g in getattr(noded, "geoms", [noded]) if isinstance(g, LineString) and g.length > 0.5]
    tree = STRtree([s[0] for s in src])
    names: list[str] = [""]
    name_idx = {"": 0}
    node_index: dict = {}
    nodes: list[tuple[float, float]] = []
    grid = defaultdict(list)

    def node_for(p):
        key = (int(math.floor(p[0] / SNAP)), int(math.floor(p[1] / SNAP)))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for ni in grid[(key[0] + dx, key[1] + dz)]:
                    q = nodes[ni]
                    if (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2 < SNAP * SNAP:
                        return ni
        nodes.append((float(p[0]), float(p[1])))
        grid[key].append(len(nodes) - 1)
        return len(nodes) - 1

    raw_edges = {}
    for part in parts:
        mid = part.interpolate(0.5, normalized=True)
        best = None
        for i in tree.query(mid.buffer(0.6)):
            s = src[i]
            if s[0].distance(mid) < 0.6:
                if best is None or ROAD_CLASSES[s[1]]["rank"] > ROAD_CLASSES[best[1]]["rank"]:
                    best = s
        if best is None:
            continue
        if best[2] not in name_idx:
            name_idx[best[2]] = len(names)
            names.append(best[2])
        coords = list(part.coords)
        # lange Abschnitte in <= MAX_EDGE teilen
        pts = [coords[0]]
        for a, b in zip(coords, coords[1:]):
            seg = math.dist(a, b)
            n = max(1, int(math.ceil(seg / MAX_EDGE)))
            for k in range(1, n + 1):
                t = k / n
                pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        ids = [node_for(p) for p in pts]
        for a, b in zip(ids, ids[1:]):
            if a == b:
                continue
            key = (min(a, b), max(a, b))
            cls_i = CLASS_ORDER.index(best[1])
            if key in raw_edges and ROAD_CLASSES[CLASS_ORDER[raw_edges[key][2]]]["rank"] >= ROAD_CLASSES[best[1]]["rank"]:
                continue
            raw_edges[key] = (a, b, cls_i, name_idx[best[2]], best[3])
    edges = list(raw_edges.values())
    edges = _prune_spurs(nodes, edges)
    edges = _close_dead_ends(nodes, edges, blockers)
    edges = _drop_islands(edges)
    edges = _split_contacts(nodes, edges)
    nodes, edges = _compact(nodes, edges)
    return nodes, edges, names


def _split_contacts(nodes, edges, tol: float = 0.4, ground_only: bool = False):
    """Kanten, die sich ohne gemeinsamen Knoten berühren oder schneiden (Rundungs-/Einrast-Reste), am Kontaktpunkt teilen.
    ground_only: Brücken/Tunnel (Flags 1|2) nie mit anderen Kanten verknoten."""
    for _round in range(4):
        lines = [LineString([nodes[e[0]], nodes[e[1]]]) for e in edges]
        tree = STRtree(lines)
        splits = defaultdict(list)   # Kante -> Knoten, die eingefügt werden
        for i, li in enumerate(lines):
            ei = edges[i]
            for j in tree.query(li.buffer(tol)):
                j = int(j)
                if j <= i:
                    continue
                ej = edges[j]
                if {ei[0], ei[1]} & {ej[0], ej[1]}:
                    continue
                if ground_only and ((ei[4] | ej[4]) & 3):
                    continue
                lj = lines[j]
                if li.distance(lj) > tol:
                    continue
                # Endpunkt der einen Kante auf der anderen -> dort teilen
                handled = False
                for e_a, l_b, idx_b in ((ei, lj, j), (ej, li, i)):
                    for n in (e_a[0], e_a[1]):
                        if Point(nodes[n]).distance(l_b) <= tol:
                            splits[idx_b].append(n)
                            handled = True
                if handled:
                    continue
                ip = li.intersection(lj)
                if ip.is_empty or ip.geom_type != "Point":
                    continue
                nodes.append((ip.x, ip.y))
                splits[i].append(len(nodes) - 1)
                splits[j].append(len(nodes) - 1)
        if not splits:
            break
        out = []
        for k, e in enumerate(edges):
            if k not in splits:
                out.append(e)
                continue
            a, b = nodes[e[0]], nodes[e[1]]
            L = LineString([a, b])
            mids = sorted(set(splits[k]) - {e[0], e[1]}, key=lambda n: L.project(Point(nodes[n])))
            seq = [e[0]] + mids + [e[1]]
            for u, v in zip(seq, seq[1:]):
                if u != v:
                    out.append((u, v) + tuple(e[2:]))
        edges = out
    return edges


def _close_dead_ends(nodes, edges, blockers, reach: float = 95.0):
    """Offene Rasterenden mit dem nächsten Knoten verbinden (ohne Kreuzung/ohne Parks); Reste -> Anliegerstraße."""
    deg = defaultdict(int)
    adj = defaultdict(set)
    for a, b, *_r in edges:
        deg[a] += 1
        deg[b] += 1
        adj[a].add(b)
        adj[b].add(a)
    lines = edge_lines(nodes, edges)
    tree = STRtree(lines)
    node_pts = [LineString([p, (p[0] + 0.01, p[1])]) for p in nodes]
    ntree = STRtree(node_pts)
    res_i = CLASS_ORDER.index("residential")
    added = []
    added_lines = []
    for n in [i for i in range(len(nodes)) if deg[i] == 1]:
        p = nodes[n]
        # Richtung des offenen Endes
        (nb,) = tuple(adj[n]) if len(adj[n]) == 1 else (None,)
        if nb is None:
            continue
        dx, dz = p[0] - nodes[nb][0], p[1] - nodes[nb][1]
        dl = math.hypot(dx, dz) or 1.0
        dx, dz = dx / dl, dz / dl
        best, best_d = None, reach
        for m in ntree.query(LineString([p, (p[0] + 0.01, p[1])]).buffer(reach)):
            if m == n or m in adj[n]:
                continue
            q = nodes[m]
            d = math.dist(p, q)
            if d < 5.0 or d > best_d:
                continue
            if ((q[0] - p[0]) * dx + (q[1] - p[1]) * dz) / d < 0.5:  # nur grob geradeaus weiter
                continue
            seg = LineString([p, q])
            if blockers is not None and seg.intersects(blockers):
                continue
            crossing = any(seg.crosses(al) for al in added_lines)
            for li in ([] if crossing else tree.query(seg)):
                l = lines[li]
                inter = l.intersection(seg)
                if not inter.is_empty and inter.distance(LineString([q, q])) > 0.5 and inter.distance(LineString([p, p])) > 0.5:
                    crossing = True
                    break
            if not crossing:
                best, best_d = m, d
        if best is not None:
            added.append((n, best, res_i, 0, 0))
            added_lines.append(LineString([p, nodes[best]]))
            deg[n] += 1
            deg[best] += 1
            adj[n].add(best)
            adj[best].add(n)
    edges = edges + added
    # Sackgassen-Ketten im Verkehrsnetz iterativ zu Anliegerstraßen herabstufen (nur Wohn-/Nebenstraßen)
    svc = CLASS_ORDER.index("service")
    minor = {res_i, CLASS_ORDER.index("tertiary")}
    out = list(edges)
    for _ in range(60):
        tdeg = defaultdict(int)
        for a, b, c, *_r in out:
            if ROAD_CLASSES[CLASS_ORDER[c]]["traffic"]:
                tdeg[a] += 1
                tdeg[b] += 1
        changed = 0
        for i, (a, b, c, nm, f) in enumerate(out):
            if c in minor and (tdeg[a] == 1 or tdeg[b] == 1):
                out[i] = (a, b, svc, nm, f)
                changed += 1
        if changed == 0:
            break
    return out


def _prune_spurs(nodes, edges, min_len: float = 30.0):
    """Kurze Sackgassen-Stummel aus dem Raster entfernen (nur Wohnstraßen)."""
    for _ in range(4):
        deg = defaultdict(int)
        for a, b, *_r in edges:
            deg[a] += 1
            deg[b] += 1
        keep = []
        removed = 0
        for e in edges:
            a, b, cls_i = e[0], e[1], e[2]
            if CLASS_ORDER[cls_i] == "residential" and (deg[a] == 1 or deg[b] == 1):
                if math.dist(nodes[a], nodes[b]) < min_len:
                    removed += 1
                    continue
            keep.append(e)
        edges = keep
        if removed == 0:
            break
    return edges


def _drop_islands(edges, min_nodes: int = 40):
    """Kleine, vom Hauptnetz getrennte befahrbare Inseln entfernen (Rasterreste)."""
    adj = defaultdict(list)
    for a, b, c, *_r in edges:
        if ROAD_CLASSES[CLASS_ORDER[c]]["drivable"]:
            adj[a].append(b)
            adj[b].append(a)
    comp = {}
    sizes = []
    for s in adj:
        if s in comp:
            continue
        stack = [s]
        comp[s] = len(sizes)
        n = 0
        while stack:
            u = stack.pop()
            n += 1
            for v in adj[u]:
                if v not in comp:
                    comp[v] = len(sizes)
                    stack.append(v)
        sizes.append(n)
    out = []
    for e in edges:
        if ROAD_CLASSES[CLASS_ORDER[e[2]]]["drivable"] and sizes[comp[e[0]]] < min_nodes:
            continue
        out.append(e)
    return out


def _compact(nodes, edges):
    used = sorted({e[0] for e in edges} | {e[1] for e in edges})
    remap = {old: i for i, old in enumerate(used)}
    return [nodes[i] for i in used], [(remap[a], remap[b], c, n, f) for a, b, c, n, f in edges]


def edge_lines(nodes, edges):
    return [LineString([nodes[e[0]], nodes[e[1]]]) for e in edges]
