"""OpenStreetMap-Quelle für Karlsruhe (Daten © OpenStreetMap-Mitwirkende, ODbL 1.0).

Liest die Overpass-Rohdaten aus dem Cache (tools/worldgen/fetch_osm.py) und liefert dasselbe Zwischenformat wie
ka_authored.py – ergänzt um fertige Graphdaten (GRAPH), echte Gebäudegrundrisse (BUILDINGS), Ampelstandorte (SIGNALS),
Einzelbäume (TREES) sowie Haltestellen/Linien (STOPS, ROUTES) für den ÖPNV.

Übernommen aus ka_authored.py (Spielgestaltung, nicht aus OSM): LANDMARKS, POIS, LABELS, DISTRICTS (Bebauungsstile), BOUNDS.

Straßengraph: Topologie aus den OSM-Knoten (gemeinsame Knoten = Kreuzung), daher keine falschen Kreuzungen an
Brücken. Straßentunnel werden ausgelassen (keine Unterwelt im Spiel). Kantenbreite je Kante (Flags ab Bit 8, 0,5 m).
"""
from __future__ import annotations

import glob
import json
import math
import os
import re
from collections import defaultdict

from shapely import affinity
from shapely.geometry import LineString, MultiPolygon, Point, Polygon
from shapely.ops import polygonize, unary_union
from shapely.strtree import STRtree

import ka_authored as ka
from geo import hash01, ll

SOURCE = "osm"
SOURCE_NOTE = "OpenStreetMap (© OpenStreetMap-Mitwirkende, ODbL 1.0), Abruf über Overpass-API"

BOUNDS = ka.BOUNDS
LANDMARKS = ka.LANDMARKS
POIS = ka.POIS
LABELS = ka.LABELS
DISTRICTS = [dict(d, grid=None) for d in ka.DISTRICTS]

MAX_EDGE = 60.0

# highway -> (Klasse, Standardbreite zweirichtung, Standardspuren je Richtung bei Einbahn)
HIGHWAY = {
    "motorway": ("motorway", 24.0, 2), "motorway_link": ("motorway", 7.0, 1),
    "trunk": ("trunk", 17.0, 2), "trunk_link": ("trunk", 7.0, 1),
    "primary": ("primary", 15.0, 2), "primary_link": ("primary", 7.0, 1),
    "secondary": ("secondary", 13.0, 2), "secondary_link": ("secondary", 7.0, 1),
    "tertiary": ("tertiary", 12.0, 1), "tertiary_link": ("tertiary", 6.5, 1),
    "residential": ("residential", 8.5, 1), "unclassified": ("residential", 8.0, 1), "road": ("residential", 8.0, 1),
    "living_street": ("service", 6.5, 1), "service": ("service", 5.5, 1),
    "pedestrian": ("pedestrian", 12.0, 1),
}
SKIP_SERVICE = {"driveway", "parking_aisle", "drive-through", "emergency_access", "private"}

AREA_RULES = [  # (Schlüssel, Werte oder None, Art) – erste passende Regel gewinnt
    ("natural", {"water"}, "water"), ("water", None, "water"), ("waterway", {"riverbank", "dock"}, "water"),
    ("landuse", {"reservoir", "basin"}, "water"),
    ("tourism", {"zoo"}, "zoo"),
    ("amenity", {"grave_yard"}, "cemetery"), ("landuse", {"cemetery"}, "cemetery"),
    ("leisure", {"pitch", "stadium", "sports_centre", "track", "golf_course", "swimming_pool"}, "sports"),
    ("landuse", {"allotments"}, "garden"), ("leisure", {"garden"}, "garden"),
    ("leisure", {"park", "playground", "dog_park", "recreation_ground"}, "park"),
    ("landuse", {"grass", "recreation_ground", "village_green", "flowerbed"}, "park"),
    ("natural", {"grassland", "heath", "scrub"}, "park"),
    ("landuse", {"forest"}, "forest"), ("natural", {"wood"}, "forest"),
    ("landuse", {"railway"}, "rail"),
    ("amenity", {"parking"}, "parking"),
    ("amenity", {"marketplace"}, "plaza"), ("place", {"square"}, "plaza"), ("area:highway", {"pedestrian"}, "plaza"),
    ("highway", {"pedestrian"}, "plaza"),
    ("landuse", {"industrial", "port", "depot", "construction", "brownfield"}, "industry_yard"),
    ("landuse", {"farmland", "meadow", "orchard", "vineyard", "farmyard", "greenfield", "plant_nursery"}, "field"),
    ("natural", {"wetland", "beach", "sand"}, "field"),
]
URBAN_LANDUSE = {"residential", "commercial", "retail", "education", "institutional", "religious", "military"}

HOUSE_TYPES = {"house", "detached", "semidetached_house", "terrace", "bungalow", "farm", "cabin"}
SMALL_TYPES = {"garage", "garages", "shed", "hut", "kiosk", "service", "transformer_tower", "carport", "greenhouse",
    "container", "toilets", "bunker"}
INDUSTRY_TYPES = {"industrial", "warehouse", "manufacture", "hangar", "storage_tank", "silo", "barn", "farm_auxiliary"}
CAMPUS_TYPES = {"university", "school", "college", "kindergarten", "hospital", "public", "civic", "government"}
STYLE_IDS = {"altstadt": 0, "gruenderzeit": 0, "dorf": 2, "modern": 1, "zeile": 1, "hochhaus": 4, "campus": 5, "villa": 6, "industrie": 3}


def _num(v, default=None):
    if v is None:
        return default
    m = re.match(r"\s*([0-9]+(?:[.,][0-9]+)?)", str(v))
    return float(m.group(1).replace(",", ".")) if m else default


def _load(cache: str, layer: str) -> list[dict]:
    seen = {}
    for f in sorted(glob.glob(os.path.join(cache, f"ka_{layer}_*.json"))):
        with open(f) as fh:
            for el in json.load(fh).get("elements", []):
                seen[(el["type"], el["id"])] = el
    return list(seen.values())


def _way_xy(el) -> list[tuple[float, float]]:
    return [ll(g["lat"], g["lon"]) for g in el.get("geometry", []) if g]


def _rel_polys(el) -> list[Polygon]:
    """Multipolygon-Relation (out geom) -> Polygone (äußere Ringe, innere als Löcher)."""
    outer, inner = [], []
    for m in el.get("members", []):
        if m.get("type") != "way" or not m.get("geometry"):
            continue
        pts = [ll(g["lat"], g["lon"]) for g in m["geometry"] if g]
        if len(pts) < 2:
            continue
        (inner if m.get("role") == "inner" else outer).append(LineString(pts))
    if not outer:
        return []
    polys = [p for p in polygonize(unary_union(outer))]
    holes = [p for p in polygonize(unary_union(inner))] if inner else []
    out = []
    for p in polys:
        g = p
        for h in holes:
            if p.contains(h.representative_point()):
                g = g.difference(h)
        out += [q for q in getattr(g, "geoms", [g]) if isinstance(q, Polygon)]
    return out


def _polys_of(el) -> list[Polygon]:
    if el["type"] == "way":
        pts = _way_xy(el)
        if len(pts) >= 4 and math.dist(pts[0], pts[-1]) < 0.01:
            p = Polygon(pts).buffer(0)
            return [q for q in getattr(p, "geoms", [p]) if isinstance(q, Polygon)]
        return []
    if el["type"] == "relation":
        return [q.buffer(0) for q in _rel_polys(el)]
    return []


def _area_kind(tags: dict) -> str | None:
    for key, vals, kind in AREA_RULES:
        v = tags.get(key)
        if v is None:
            continue
        if key == "highway" and tags.get("area") != "yes":
            continue
        if key == "leisure" and v == "garden" and tags.get("access") == "private":
            continue
        if vals is None or v in vals:
            return kind
    return None


# --------------------------------------------------------------------------- Straßen
MIN_WIDTH = {"motorway": 12.0, "trunk": 10.0, "primary": 8.0, "secondary": 7.5, "tertiary": 7.0, "residential": 5.5, "service": 3.5}
MIN_WIDTH_ONEWAY = {"motorway": 8.0, "trunk": 7.0, "primary": 5.0, "secondary": 4.5, "tertiary": 4.0, "residential": 3.5, "service": 3.0}


def _road_attrs(tags: dict):
    hw = tags.get("highway")
    if hw not in HIGHWAY:
        return None
    if tags.get("area") == "yes":
        return None
    if tags.get("tunnel") in ("yes", "culvert", "flooded") or _num(tags.get("layer"), 0) < 0:
        return None
    if hw == "service" and (tags.get("service") in SKIP_SERVICE or tags.get("access") in ("private", "no")):
        return None
    if tags.get("access") in ("private", "no") and hw in ("residential", "unclassified", "living_street"):
        return None
    cls, w_default, lanes_default = HIGHWAY[hw]
    oneway_tag = tags.get("oneway")
    oneway = oneway_tag in ("yes", "1", "true", "-1") or tags.get("junction") in ("roundabout", "circular") or \
        (hw in ("motorway", "motorway_link") and oneway_tag != "no")
    width = _num(tags.get("width"))
    if width is not None and not (3.0 <= width <= 40.0):
        width = None
    if width is None:
        lanes = _num(tags.get("lanes"))
        if oneway and cls not in ("pedestrian",):
            n = lanes if lanes else lanes_default
            width = max(4.5, n * 3.3 + 1.0)
        elif lanes and cls in ("motorway", "trunk", "primary", "secondary", "tertiary"):
            width = max(7.0, lanes * 3.3 + 2.0)
        else:
            width = w_default
    # Mindestbreiten je Klasse (OSM-„width“ beschreibt teils nur einen Fahrstreifen): zwei Fahrzeuge müssen sich
    # begegnen können, Einbahnstraßen einen Streifen plus Rand haben
    mins = MIN_WIDTH_ONEWAY if oneway else MIN_WIDTH
    width = max(width, mins.get(cls, 0.0))
    width = round(width * 2.0) / 2.0
    bridge = tags.get("bridge") not in (None, "no") or _num(tags.get("layer"), 0) > 0
    name = tags.get("name") or tags.get("ref") or ""
    return {"cls": cls, "width": width, "oneway": oneway, "reverse": oneway_tag == "-1", "bridge": bridge, "name": name}


def _build_graph(ways, bounds):
    import network as net
    x0, z0, x1, z1 = bounds
    usage = defaultdict(int)
    rows = []
    for el in ways:
        attrs = _road_attrs(el.get("tags", {}))
        if attrs is None:
            continue
        ids = el.get("nodes", [])
        geo = el.get("geometry", [])
        if len(ids) != len(geo) or len(ids) < 2:
            continue
        pts = [ll(g["lat"], g["lon"]) if g else None for g in geo]
        if any(p is None for p in pts):
            continue
        if attrs["reverse"]:
            ids, pts = ids[::-1], pts[::-1]
        rows.append((ids, pts, attrs))
        for k, nid in enumerate(ids):
            usage[nid] += 2 if k in (0, len(ids) - 1) else 1
    names = [""]
    name_idx = {"": 0}
    nodes: list[tuple[float, float]] = []
    osm_node = {}

    def junction(nid, p):
        if nid not in osm_node:
            osm_node[nid] = len(nodes)
            nodes.append(p)
        return osm_node[nid]

    raw = {}
    for ids, pts, attrs in rows:
        if attrs["name"] not in name_idx:
            name_idx[attrs["name"]] = len(names)
            names.append(attrs["name"])
        cls_i = net.CLASS_ORDER.index(attrs["cls"])
        flags = (2 if attrs["bridge"] else 0) | (4 if attrs["oneway"] else 0) | (int(attrs["width"] * 2) << 8)
        # an Kreuzungsknoten teilen
        cuts = [0] + [k for k in range(1, len(ids) - 1) if usage[ids[k]] >= 2] + [len(ids) - 1]
        for s, e in zip(cuts, cuts[1:]):
            seg = pts[s:e + 1]
            line = LineString(seg).simplify(0.8, preserve_topology=False)
            coords = list(line.coords) if not line.is_empty else [seg[0], seg[-1]]
            # lange Abschnitte in <= MAX_EDGE teilen
            fine = [coords[0]]
            for a, b in zip(coords, coords[1:]):
                n = max(1, int(math.ceil(math.dist(a, b) / MAX_EDGE)))
                for k in range(1, n + 1):
                    fine.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
            chain = [junction(ids[s], seg[0])]
            for p in fine[1:-1]:
                nodes.append(p)
                chain.append(len(nodes) - 1)
            chain.append(junction(ids[e], seg[-1]))
            for a, b in zip(chain, chain[1:]):
                if a == b or math.dist(nodes[a], nodes[b]) < 0.05:
                    continue
                key = (min(a, b), max(a, b))
                old = raw.get(key)
                if old is not None and net.ROAD_CLASSES[net.CLASS_ORDER[old[2]]]["rank"] >= net.ROAD_CLASSES[attrs["cls"]]["rank"]:
                    continue
                raw[key] = (a, b, cls_i, name_idx[attrs["name"]], flags)
    edges = list(raw.values())
    # auf den Kartenausschnitt beschränken
    inside = [x0 + 2 <= p[0] <= x1 - 2 and z0 + 2 <= p[1] <= z1 - 2 for p in nodes]
    edges = [e for e in edges if inside[e[0]] and inside[e[1]]]
    # ebenerdige Berührungen ohne gemeinsamen Knoten (Datenfehler) teilen – Brücken ausgenommen
    edges = net._split_contacts(nodes, edges, ground_only=True)
    edges = net._drop_islands(edges, min_nodes=60)
    edges = _drop_non_drivable_fragments(edges)
    nodes, edges = net._compact(nodes, edges)
    return nodes, edges, names


def _drop_building_stubs(graph, blds):
    """Befahrbare Sackgassen-Stummel entfernen, deren freies Ende in oder bis 2 m an einem Gebäude liegt
    (Ladehof-/Garageneinfahrten): für das Spiel ohne Nutzen, sonst ragen Gebäudeecken in die Fahrspur."""
    import network as net
    nodes, edges, names = graph
    polys = []
    for el in blds:
        polys += _polys_of(el)
    tree = STRtree(polys)
    removed = 0
    for _round in range(4):
        deg = defaultdict(int)
        for e in edges:
            if net.ROAD_CLASSES[net.CLASS_ORDER[e[2]]]["drivable"]:
                deg[e[0]] += 1
                deg[e[1]] += 1
        keep = []
        n0 = removed
        for e in edges:
            cls = net.CLASS_ORDER[e[2]]
            if cls in ("service", "residential") and (deg[e[0]] == 1 or deg[e[1]] == 1):
                end = e[0] if deg[e[0]] == 1 else e[1]
                pt = Point(nodes[end])
                if any(polys[i].distance(pt) < 2.0 for i in tree.query(pt.buffer(2.0))):
                    removed += 1
                    continue
            keep.append(e)
        edges = keep
        if removed == n0:
            break
    if removed == 0:
        return graph
    edges = net._drop_islands(edges, min_nodes=60)
    edges = _drop_non_drivable_fragments(edges)
    nodes, edges = net._compact(nodes, edges)
    print(f"[osm] {removed} Sackgassen-Stummel an Gebäuden entfernt")
    return nodes, edges, names


def _clear_landmark_roads(graph, landmarks):
    """Landmarken-Grundrisse haben Vorrang vor Nebenstraßen: Wohn-/Erschließungskanten, deren Fahrspur den Kollisions-
    grundriss einer Landmarke schneidet, werden entfernt (danach Inseln bereinigt). Hauptstraßen bleiben (Prüfung meldet sie)."""
    import network as net
    from validate_world import landmark_footprints   # dieselben Grundrisse wie die Validierung
    nodes, edges, names = graph
    feet = [f for lm in landmarks for f in landmark_footprints(lm)]
    if not feet:
        return graph
    minor = {net.CLASS_ORDER.index(c) for c in ("residential", "service")}
    keep = []
    removed = 0
    for e in edges:
        if e[2] in minor:
            lane = LineString([nodes[e[0]], nodes[e[1]]]).buffer(min(2.6, net.edge_width(e) * 0.25) + 0.8, cap_style=2)
            if any(lane.intersection(f).area > 0.5 for f in feet if f.distance(lane) < 1.0):
                removed += 1
                continue
        keep.append(e)
    if removed == 0:
        return graph
    keep = net._drop_islands(keep, min_nodes=60)
    keep = _drop_non_drivable_fragments(keep)
    nodes, keep = net._compact(nodes, keep)
    print(f"[osm] {removed} Nebenstraßen-Kanten unter Landmarken entfernt")
    return nodes, keep, names


def _drop_non_drivable_fragments(edges):
    """Fußgängerkanten ohne Anschluss an das befahrbare Netz (isolierte Plätze) entfernen."""
    import network as net
    drive_nodes = set()
    for a, b, c, *_r in edges:
        if net.ROAD_CLASSES[net.CLASS_ORDER[c]]["drivable"]:
            drive_nodes.add(a)
            drive_nodes.add(b)
    adj = defaultdict(list)
    for a, b, *_r in edges:
        adj[a].append(b)
        adj[b].append(a)
    reach = set(drive_nodes)
    stack = list(drive_nodes)
    while stack:
        u = stack.pop()
        for v in adj[u]:
            if v not in reach:
                reach.add(v)
                stack.append(v)
    return [e for e in edges if e[0] in reach]


# --------------------------------------------------------------------------- Gebäude
def _building_style(tags, area, floors, district_style):
    t = tags.get("building", "yes")
    if t in INDUSTRY_TYPES or tags.get("industrial") or (district_style == "industrie" and t in ("yes", "commercial", "retail")):
        return 3
    if t in HOUSE_TYPES:
        return 2 if district_style == "dorf" else 6
    if t in CAMPUS_TYPES or tags.get("amenity") in ("university", "school", "college", "hospital"):
        return 5
    if floors >= 9:
        return 4
    if t in ("office", "commercial", "retail", "hotel", "supermarket"):
        return 1
    if district_style in STYLE_IDS:
        s = STYLE_IDS[district_style]
        if s == 6 and area > 400:
            return 1
        return s
    return 6 if area < 180 else 1


def _default_floors(tags, style, area, district_style, seed):
    t = tags.get("building", "yes")
    if t in SMALL_TYPES or area < 30:
        return 1
    if t in HOUSE_TYPES:
        return 2
    if style == 3:
        return 1 if area > 1500 else 2
    ranges = {"altstadt": (4, 5), "gruenderzeit": (4, 5), "dorf": (2, 3), "modern": (4, 6), "zeile": (3, 5), "hochhaus": (8, 12),
        "campus": (3, 4), "villa": (2, 2), "industrie": (1, 2)}
    f0, f1 = ranges.get(district_style, (2, 4))
    if area < 120:
        f1 = min(f1, 3)
    return f0 + int(seed * (f1 - f0 + 1))


def _buildings(els, graph, district_polys, reserves, clear_zones, shops):
    import blocks as bl
    import network as net
    nodes, edges, _names = graph
    road_lines = [LineString([nodes[e[0]], nodes[e[1]]]) for e in edges]
    road_w = [net.edge_width(e) for e in edges]
    drive = [net.ROAD_CLASSES[net.CLASS_ORDER[e[2]]]["drivable"] for e in edges]
    rtree = STRtree(road_lines)
    dtree = STRtree([p for _d, p in district_polys])
    shop_pts = [Point(p) for p in shops]
    stree = STRtree(shop_pts) if shop_pts else None
    raw = []
    for el in els:
        tags = el.get("tags", {})
        t = tags.get("building")
        if t is None or t in ("roof", "no", "ruins", "construction", "collapsed", "demolished", "proposed"):
            continue
        if tags.get("location") == "underground" or _num(tags.get("layer"), 0) < 0:
            continue
        for poly in _polys_of(el):
            if poly.area < 12:
                continue
            raw.append((poly, tags, el["id"]))
    out = []
    for bi, (poly, tags, oid) in enumerate(raw):
        # Fahrbahnen freihalten (OSM-Straßenbreiten sind Schätzungen; Passagen unter Gebäuden bleiben befahrbar)
        near = [i for i in rtree.query(poly.buffer(20)) if drive[i]]
        if near:
            cut = unary_union([road_lines[i].buffer(road_w[i] * 0.5 + 0.2, cap_style=1) for i in near])   # rund: keine Keillücken an Knicken
            poly = poly.difference(cut)
            # Nadeln/Splitter vom Zuschnitt entfernen (morphologisches Öffnen; sonst feste Kollisionswände in der Fahrbahn)
            poly = poly.buffer(-0.35, join_style=2).buffer(0.35, join_style=2)
            poly = poly.intersection(poly.envelope).difference(cut)
        if any(r.intersects(poly) for r in reserves) or any(c.intersects(poly) for c in clear_zones):
            continue
        for part in getattr(poly, "geoms", [poly]):
            if not isinstance(part, Polygon) or part.area < 12:
                continue
            part = part.simplify(0.3)
            if not isinstance(part, Polygon) or part.is_empty or part.area < 12:
                continue
            for piece in _split_holes(part):
                if piece.area < 12:
                    continue
                piece = piece if piece.exterior.is_ccw else Polygon(list(piece.exterior.coords)[::-1])
                coords = [tuple(c) for c in list(piece.exterior.coords)[:-1]]
                if len(coords) < 3:
                    continue
                cen = piece.representative_point()
                dstyle = ""
                for di in dtree.query(cen):
                    if district_polys[di][1].contains(cen):
                        dstyle = district_polys[di][0]["style"]
                        break
                seed = hash01("osm", oid, len(out))
                lv = _num(tags.get("building:levels"))
                h_tag = _num(tags.get("height"))
                area = piece.area
                floors_guess = int(lv) if lv else (max(1, int(round(h_tag / 3.2))) if h_tag else 0)
                style = _building_style(tags, area, floors_guess or 1, dstyle)
                floors = floors_guess or _default_floors(tags, style, area, dstyle, seed)
                floors = max(1, min(floors, 40))
                shop = 0
                if stree is not None:
                    for si in stree.query(piece):
                        if piece.contains(shop_pts[si]):
                            shop = 1
                            break
                roof_shape = tags.get("roof:shape", "")
                four = len(coords) == 4
                if roof_shape in ("flat", "skillion"):
                    roof = "f"
                elif roof_shape in ("gabled", "pitched", "gambrel", "saltbox") and four:
                    roof = "g"
                elif roof_shape in ("hipped", "half-hipped", "pyramidal") and four:
                    roof = "h"
                elif roof_shape == "mansard" and four:
                    roof = "m"
                elif style in (0, 2, 6) and four and area < 900:
                    roof = "m" if style == 0 and seed < 0.25 else "g"
                else:
                    roof = "f"
                b = bl._bld(coords, [3] * len(coords), floors, style, seed, shop, roof, int(hash01("c", oid) * bl.WALL_COLORS))
                if h_tag and 2.5 <= h_tag <= 160:
                    b["h"] = round(h_tag if roof == "f" else max(2.5, h_tag - 2.5), 1)
                out.append(b)
    _edge_codes(out, road_lines, road_w, rtree)
    for b in out:
        b["p"] = [[round(x, 1), round(z, 1)] for x, z in b["p"]]
    return out


def _split_holes(poly: Polygon) -> list[Polygon]:
    import export as ex
    return [p for p in ex.split_holes(poly) if isinstance(p, Polygon)]


def _edge_codes(buildings, road_lines, road_w, rtree):
    """Wandcodes: 0 = Brandwand (Nachbargebäude an derselben Kante), 1 = Straßenfassade, 3 = freiliegend."""
    import blocks as bl
    shared = defaultdict(int)
    for b in buildings:
        cs = b["p"]
        for a, c in zip(cs, cs[1:] + cs[:1]):
            shared[bl._ekey(a, c)] += 1
    # Brandwände auch bei nicht exakt gleichen Knoten: Kantenmitte liegt auf/in einem anderen Gebäude
    polys = [Polygon(b["p"]) for b in buildings]
    ptree = STRtree(polys)
    for bi, b in enumerate(buildings):
        cs = b["p"]
        codes = []
        for a, c in zip(cs, cs[1:] + cs[:1]):
            mid = Point((a[0] + c[0]) * 0.5, (a[1] + c[1]) * 0.5)
            if shared[bl._ekey(a, c)] >= 2:
                codes.append(0)
                continue
            touch = False
            for j in ptree.query(mid.buffer(0.4)):
                if j != bi and polys[j].distance(mid) < 0.35:
                    touch = True
                    break
            if touch:
                codes.append(0)
                continue
            street = False
            for i in rtree.query(mid.buffer(24)):
                if road_lines[i].distance(mid) < road_w[i] * 0.5 + 14.0:
                    street = True
                    break
            codes.append(1 if street else 3)
        coords, codes = bl._rotate_to_front(list(cs), codes)
        b["p"], b["e"] = coords, codes


# --------------------------------------------------------------------------- Landmarken an OSM verankern
# Typ -> Suchregeln (Tag-Bedingungen, Name als regulärer Ausdruck, Suchradius um die Näherungsposition in m).
# Treffer: nächstgelegenes passendes Element; Position = Schwerpunkt (bei mehreren Treffern im Cluster: Mittel).
ANCHORS = {
    "schloss": [{"name": r"^Schlossturm$", "r": 300}],
    "pyramide": [{"name": r"^Pyramide$", "tags": {"historic": "tomb"}, "r": 400}, {"name": r"^Pyramide$", "r": 150}],
    "brunnen": [{"name": r"^Europaplatz$", "tags": {"place": "square"}, "r": 400}],
    "rathaus": [{"tags": {"amenity": "townhall"}, "name": r"^Rathaus$", "r": 400}],
    "stadtkirche": [{"name": r"Evangelische Stadtkirche", "tags": {"building": "church"}, "r": 400}],
    "saeule": [{"name": r"Verfassungssäule|Obelisk", "r": 300},
               {"name": r"^Rondellplatz$", "tags": {"place": "square"}, "r": 400}],
    "hauptbahnhof": [{"name": r"^Karlsruhe Hauptbahnhof$", "tags": {"building": "train_station"}, "r": 600, "orient": True},
                     {"name": r"^Karlsruhe Hauptbahnhof$", "r": 600, "orient": True}],
    "gewaechshaus": [{"tags": {"building": "greenhouse"}, "r": 450, "cluster": 120}],
    "stadion": [{"tags": {"leisure": "stadium"}, "name": r"Wildpark", "r": 900, "orient": True},
                {"tags": {"leisure": "stadium"}, "r": 700, "orient": True}],
    "turmberg": [{"tags": {"man_made": "tower", "tower:type": "defensive"}, "r": 900},
                 {"name": r"^Turmberg$", "tags": {"natural": "peak"}, "r": 900},
                 {"name": r"Turmberg", "tags": {"man_made": "tower"}, "r": 900},
                 {"name": r"Turmberg", "tags": {"historic": None}, "r": 900}],
    "zoo": [{"tags": {"tourism": "zoo"}, "name": r"Zoo|Stadtgarten", "r": 700}],
    "hafenkran": [{"tags": {"man_made": "crane"}, "r": 1500, "cluster": 250}],
    "staatstheater": [{"name": r"^Badisches Staatstheater$", "r": 500, "orient": True}],
}


def _match(tags: dict, rule: dict) -> bool:
    for k, v in rule.get("tags", {}).items():
        if k not in tags or (v is not None and tags[k] != v):
            return False
    if "name" in rule and not re.search(rule["name"], tags.get("name", "")):
        return False
    return True


def _long_axis_rot(g) -> float:
    """Drehung (Grad, Godot-Konvention wie LANDMARKS.rot) der langen Seite des umschließenden Rechtecks;
    Front (lokal −z) zeigt nach Norden (−z)."""
    cs = list(g.minimum_rotated_rectangle.exterior.coords)
    e = [(cs[1][0] - cs[0][0], cs[1][1] - cs[0][1]), (cs[2][0] - cs[1][0], cs[2][1] - cs[1][1])]
    v = max(e, key=lambda t: math.hypot(*t))
    rot = -math.degrees(math.atan2(v[1], v[0]))
    while rot <= -90.0:
        rot += 180.0
    while rot > 90.0:
        rot -= 180.0
    return round(rot, 1)


def _anchor_landmarks(landmarks: list, elements: list) -> list:
    """Kopie der Landmarkenliste mit Positionen realer OSM-Objekte; Freihalte-/Reservezonen werden mitverschoben."""
    out = []
    for lm in landmarks:
        lm = dict(lm)
        rot0 = float(lm.get("rot", 0.0))
        rules = ANCHORS.get(lm["type"], [])
        px_, pz_ = lm["pos"]
        hit = None
        for rule in rules:
            cands = []
            for el in elements:
                t = el.get("tags", {})
                if not _match(t, rule):
                    continue
                g = None
                if el["type"] == "node":
                    c = ll(el["lat"], el["lon"])
                else:
                    ps = _polys_of(el)
                    if not ps:
                        continue
                    g = max(ps, key=lambda q: q.area)
                    c = (g.centroid.x, g.centroid.y)
                d = math.dist(c, (px_, pz_))
                if d <= rule["r"]:
                    cands.append((d, c, g))
            if cands:
                cands.sort(key=lambda x: x[0])
                c0 = cands[0][1]
                if rule.get("orient") and cands[0][2] is not None:
                    lm["rot"] = _long_axis_rot(cands[0][2])
                if rule.get("cluster"):
                    near = [c for _d, c, _g in cands if math.dist(c, c0) <= rule["cluster"]]
                    c0 = (sum(c[0] for c in near) / len(near), sum(c[1] for c in near) / len(near))
                hit = c0
                break
        if hit is not None:
            dx, dz = hit[0] - px_, hit[1] - pz_
            lm["pos"] = [round(hit[0], 1), round(hit[1], 1)]
            if "reserve" in lm:
                res = Polygon([(x + dx, z + dz) for x, z in lm["reserve"]])
                if float(lm.get("rot", 0.0)) != rot0:
                    res = affinity.rotate(res, -(float(lm["rot"]) - rot0), origin=(hit[0], hit[1]))
                lm["reserve"] = [tuple(c) for c in res.exterior.coords[:-1]]
            lm["anchored"] = round(math.hypot(dx, dz), 1)
            print(f"[osm] Landmarke {lm['type']}: an OSM verankert (Versatz {math.hypot(dx, dz):.0f} m, Drehung {lm.get('rot', 0.0)}°)")
        else:
            print(f"[osm] Landmarke {lm['type']}: kein OSM-Objekt gefunden – Näherungsposition bleibt")
        out.append(lm)
    _align_to_axis(out)
    return out


# Landmarken, deren Ausrichtung der Stadtachse folgt (Schloss – Karl-Friedrich-Straße – Marktplatz)
AXIS_ALIGNED = ("schloss", "rathaus", "stadtkirche", "pyramide")


def _align_to_axis(lms: list) -> None:
    """Die Karlsruher Hauptachse (Schlossturm → Pyramide) ist real um einige Grad gegen Nord gedreht. Die Näherungs-
    Landmarken sind achsparallel modelliert; bei verankertem Turm und Pyramide wird die Drehung übernommen."""
    by = {lm["type"]: lm for lm in lms}
    s, p = by.get("schloss"), by.get("pyramide")
    if s is None or p is None or "anchored" not in s or "anchored" not in p:
        return
    dx, dz = p["pos"][0] - s["pos"][0], p["pos"][1] - s["pos"][1]
    axis = math.degrees(math.atan2(dx, dz))
    if abs(axis) > 15.0:
        print(f"[osm] Stadtachse unplausibel ({axis:.1f}°) – keine Drehung")
        return
    for t in AXIS_ALIGNED:
        lm = by.get(t)
        if lm is None:
            continue
        lm["rot"] = round(float(lm.get("rot", 0.0)) + axis, 1)
        if "reserve" in lm:
            res = affinity.rotate(Polygon(lm["reserve"]), -axis, origin=tuple(lm["pos"]))
            lm["reserve"] = [tuple(c) for c in res.exterior.coords[:-1]]
    print(f"[osm] Stadtachse {axis:.1f}° – übernommen für {', '.join(AXIS_ALIGNED)}")


# --------------------------------------------------------------------------- Laden
def load(cache: str):
    """Liest den Cache und liefert ein Objekt mit allen Feldern des Zwischenformats."""
    class S:
        pass
    s = S()
    for k in ("SOURCE", "SOURCE_NOTE", "BOUNDS", "LANDMARKS", "POIS", "LABELS", "DISTRICTS"):
        setattr(s, k, globals()[k])
    lines = _load(cache, "lines")
    areas_raw = _load(cache, "areas")
    blds = _load(cache, "buildings")
    points = _load(cache, "points")
    print(f"[osm] Rohdaten: {len(lines)} Linien, {len(areas_raw)} Flächen, {len(blds)} Gebäude, {len(points)} Punkte")
    lms = _anchor_landmarks(LANDMARKS, blds + areas_raw + points)
    s.LANDMARKS = lms
    x0, z0, x1, z1 = BOUNDS
    frame = Polygon([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    # Straßengraph
    s.GRAPH = _build_graph([w for w in lines if w["type"] == "way" and "highway" in w.get("tags", {})], BOUNDS)
    s.GRAPH = _clear_landmark_roads(s.GRAPH, lms)
    s.GRAPH = _drop_building_stubs(s.GRAPH, blds)
    print(f"[osm] Graph: {len(s.GRAPH[0])} Knoten, {len(s.GRAPH[1])} Kanten")
    s.ROADS = []
    # Flächen
    s.AREAS = []
    urban = []
    for el in areas_raw:
        tags = el.get("tags", {})
        kind = _area_kind(tags)
        polys = _polys_of(el)
        if kind is None:
            if tags.get("landuse") in URBAN_LANDUSE:
                urban += polys
            continue
        for p in polys:
            p = p.intersection(frame)
            for q in getattr(p, "geoms", [p]):
                if isinstance(q, Polygon) and q.area > 30:
                    q = q.simplify(0.5)
                    if isinstance(q, Polygon) and not q.is_empty:
                        s.AREAS.append({"kind": kind, "name": tags.get("name", ""), "poly": [tuple(c) for c in q.exterior.coords[:-1]],
                            "holes": [[tuple(c) for c in r.coords[:-1]] for r in q.interiors if Polygon(r).area > 50]})
    s.URBAN = urban
    # Gewässerlinien
    widths = {"river": 25.0, "canal": 14.0, "stream": 5.0, "ditch": 2.0}
    s.WATERWAYS = []
    for w in lines:
        wt = w.get("tags", {}).get("waterway")
        if wt in widths and w.get("tags", {}).get("tunnel") not in ("yes", "culvert"):
            pts = _way_xy(w)
            if len(pts) >= 2:
                wd = _num(w["tags"].get("width"), widths[wt])
                s.WATERWAYS.append({"name": w["tags"].get("name", ""), "pts": pts, "width": max(1.5, min(wd, 60.0))})
    # Gleise
    s.RAILWAYS = []
    for w in lines:
        t = w.get("tags", {})
        rw = t.get("railway")
        if rw in ("rail", "tram", "light_rail", "subway", "narrow_gauge"):
            pts = _way_xy(w)
            if len(pts) < 2:
                continue
            tunnel = t.get("tunnel") not in (None, "no") or _num(t.get("layer"), 0) < 0
            s.RAILWAYS.append({"name": t.get("name", ""), "pts": pts, "tracks": 1, "kind": rw, "tunnel": tunnel,
                "bridge": t.get("bridge") not in (None, "no"), "service": t.get("service", "")})
    # Punkte
    s.SIGNALS, s.TREES, s.STOPS, shops = [], [], [], []
    for p in points:
        t = p.get("tags", {})
        if "lat" not in p:
            continue
        xy = ll(p["lat"], p["lon"])
        if not (x0 <= xy[0] <= x1 and z0 <= xy[1] <= z1):
            continue
        if t.get("highway") == "traffic_signals":
            s.SIGNALS.append(xy)
        if t.get("natural") == "tree":
            s.TREES.append(xy)
        if t.get("shop") or t.get("amenity"):
            shops.append(xy)
        if t.get("railway") in ("tram_stop", "station", "halt") or t.get("highway") == "bus_stop" or \
                t.get("public_transport") in ("stop_position", "platform", "station"):
            s.STOPS.append({"name": t.get("name", ""), "pos": xy, "tram": t.get("tram") == "yes" or t.get("railway") == "tram_stop"
                or t.get("light_rail") == "yes", "bus": t.get("bus") == "yes" or t.get("highway") == "bus_stop",
                "train": t.get("train") == "yes" or t.get("railway") in ("station", "halt"), "kind": t.get("public_transport", "")})
    # Linien (für W5)
    s.ROUTES = []
    rf = os.path.join(cache, "ka_routes.json")
    if os.path.exists(rf):
        with open(rf) as fh:
            for el in json.load(fh).get("elements", []):
                if el.get("type") != "relation":
                    continue
                t = el.get("tags", {})
                stops, ways = [], []
                for m in el.get("members", []):
                    if m.get("type") == "node" and m.get("role", "").startswith("stop") and "lat" in m:
                        stops.append(ll(m["lat"], m["lon"]))
                    elif m.get("type") == "way" and m.get("role", "") in ("", "forward", "backward") and m.get("geometry"):
                        ways.append([ll(g["lat"], g["lon"]) for g in m["geometry"] if g])
                s.ROUTES.append({"ref": t.get("ref", ""), "name": t.get("name", ""), "route": t.get("route", ""),
                    "colour": t.get("colour", ""), "from": t.get("from", ""), "to": t.get("to", ""), "stops": stops, "ways": ways})
    # Gebäude
    reserves = [Polygon(l["reserve"]) for l in lms if "reserve" in l]
    clear = [Point(l["pos"]).buffer(l["clear"]) for l in lms if l.get("clear", 0) > 0]
    district_polys = [(d, Polygon(d["poly"]).buffer(0)) for d in DISTRICTS]
    s._building_els = blds
    s._building_args = (district_polys, reserves, clear, shops)
    s.BUILDINGS = None   # wird nach dem Auflösen der POIs erzeugt (Freihaltezonen), siehe build_buildings

    def build_buildings(graph, poi_clear):
        return _buildings(blds, graph, district_polys, reserves, clear + poi_clear, shops)
    s.build_buildings = build_buildings
    print(f"[osm] Flächen {len(s.AREAS)}, Gewässer {len(s.WATERWAYS)}, Gleise {len(s.RAILWAYS)}, Ampeln {len(s.SIGNALS)}, "
        f"Bäume {len(s.TREES)}, Haltestellen {len(s.STOPS)}, Linien {len(s.ROUTES)}")
    return s
