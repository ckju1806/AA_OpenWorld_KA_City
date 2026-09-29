#!/usr/bin/env python3
"""Lädt OpenStreetMap-Daten für den Spielausschnitt Karlsruhe über die Overpass-API (kachelweise, mit Wiederholungen).

Aufruf:  python3 tools/worldgen/fetch_osm.py [--cache ~/osm_cache] [--tiles 6x4]
Ergebnis: <cache>/ka_<layer>_<i>_<j>.json  (Rohdaten, NICHT versioniert – Daten © OpenStreetMap-Mitwirkende, ODbL)

Warum Overpass statt Geofabrik-Extrakt: Der Geofabrik-Download ist aus der Cloud-Umgebung nicht erreichbar
(Verbindung wird nach dem TLS-Handshake getrennt); Overpass funktioniert (mit gelegentlichen Abbrüchen -> Wiederholung).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from geo import ORIGIN_LAT, ORIGIN_LON, M_PER_DEG_LAT, M_PER_DEG_LON  # noqa: E402

BOUNDS = (-9500.0, -4100.0, 8000.0, 6300.0)   # x_min, z_min, x_max, z_max (m, Ursprung Schlossturm)
MARGIN = 300.0                                  # Rand, damit Straßen am Kartenrand vollständig sind
URLS = ["https://overpass-api.de/api/interpreter"]
UA = "Faecherstadt-worldgen/0.2 (nicht-kommerzieller Spielprototyp; Kartenaufbau offline)"

LAYERS = {
    # Straßen, Gleise, Gewässerlinien, Flächen, Gebäude – je Kachel
    "lines": """
      way["highway"]({bb});
      way["railway"~"^(rail|tram|light_rail|subway|narrow_gauge)$"]({bb});
      way["waterway"~"^(river|canal|stream|ditch)$"]({bb});
    """,
    "areas": """
      way["landuse"]({bb}); relation["landuse"]({bb});
      way["leisure"]({bb}); relation["leisure"]({bb});
      way["natural"~"^(water|wood|scrub|grassland|heath|wetland|beach|sand)$"]({bb});
      relation["natural"~"^(water|wood|scrub|grassland|wetland)$"]({bb});
      way["amenity"~"^(parking|grave_yard|school|university|hospital|marketplace)$"]({bb});
      way["tourism"~"^(zoo|attraction)$"]({bb}); relation["tourism"="zoo"]({bb});
      way["area:highway"]({bb}); way["place"~"^(square)$"]({bb});
      way["waterway"="riverbank"]({bb}); relation["water"]({bb}); way["water"]({bb});
    """,
    "buildings": """
      way["building"]({bb}); relation["building"]({bb});
      way["building:part"]({bb});
    """,
    "points": """
      node["highway"~"^(traffic_signals|bus_stop|crossing)$"]({bb});
      node["railway"~"^(tram_stop|station|halt|stop)$"]({bb});
      node["public_transport"]({bb});
      node["shop"]({bb}); node["amenity"~"^(restaurant|cafe|bar|fast_food|pub|bank|pharmacy|kiosk|fuel|police|hospital)$"]({bb});
      node["natural"="tree"]({bb});
    """,
}


def ll_bbox(x0, z0, x1, z1):
    """(x,z)-Rechteck -> Overpass-bbox (south, west, north, east)."""
    south = ORIGIN_LAT - z1 / M_PER_DEG_LAT
    north = ORIGIN_LAT - z0 / M_PER_DEG_LAT
    west = ORIGIN_LON + x0 / M_PER_DEG_LON
    east = ORIGIN_LON + x1 / M_PER_DEG_LON
    return f"{south:.6f},{west:.6f},{north:.6f},{east:.6f}"


def query(body: str, out: str, tries: int = 150) -> bool:
    data = "[out:json][timeout:240][maxsize:1073741824];(" + body + ");out geom qt;"
    tmp = out + ".part"
    for k in range(tries):
        url = URLS[k % len(URLS)]
        r = subprocess.run(["curl", "-s", "-m", "400", "-A", UA, "--data-urlencode", "data=" + data, url, "-o", tmp,
            "-w", "%{http_code}"], capture_output=True, text=True)
        code = r.stdout.strip()
        if code == "200":
            try:
                with open(tmp) as f:
                    d = json.load(f)
                if "remark" in d and "error" in str(d.get("remark", "")).lower():
                    print(f"    Server-Hinweis: {d['remark'][:120]}", flush=True)
                else:
                    os.replace(tmp, out)
                    return True
            except (json.JSONDecodeError, OSError):
                pass
        # 000 = Tunnel/TLS-Abbruch am Egress-Gateway (schnell erneut versuchen); 429/504 = Server ausgelastet
        wait = 3 if code in ("", "000") else (15 if code in ("429", "504") else 8)
        print(f"    Versuch {k + 1} fehlgeschlagen (HTTP {code or '-'}), neuer Versuch in {wait} s", flush=True)
        time.sleep(wait)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.expanduser("~/osm_cache"))
    ap.add_argument("--tiles", default="10x6")
    ap.add_argument("--layers", default=",".join(LAYERS))
    ap.add_argument("--routes-only", action="store_true", help="nur ÖPNV-Relationen abrufen")
    args = ap.parse_args()
    nx, nz = (int(v) for v in args.tiles.split("x"))
    os.makedirs(args.cache, exist_ok=True)
    x0, z0, x1, z1 = BOUNDS
    x0 -= MARGIN
    z0 -= MARGIN
    x1 += MARGIN
    z1 += MARGIN
    sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
    failed = []
    for layer in ([] if args.routes_only else args.layers.split(",")):
        for i in range(nx):
            for j in range(nz):
                out = os.path.join(args.cache, f"ka_{layer}_{i}_{j}.json")
                if os.path.exists(out):
                    continue
                bb = ll_bbox(x0 + i * sx, z0 + j * sz, x0 + (i + 1) * sx, z0 + (j + 1) * sz)
                t0 = time.time()
                print(f"[osm] {layer} Kachel {i},{j} ({bb}) ...", flush=True)
                if query(LAYERS[layer].replace("{bb}", bb), out):
                    print(f"[osm]   ok: {os.path.getsize(out) / 1e6:.1f} MB in {time.time() - t0:.0f} s", flush=True)
                else:
                    failed.append(out)
                    print("[osm]   FEHLGESCHLAGEN", flush=True)
                time.sleep(2)
    # ÖPNV-Linien (Relationen) für den ganzen Ausschnitt – getrennt nach Schiene und Bus (kleinere Antworten),
    # danach zu ka_routes.json zusammengeführt
    out = os.path.join(args.cache, "ka_routes.json")
    if not os.path.exists(out):
        bb = ll_bbox(x0, z0, x1, z1)
        parts = []
        for tag, rx in (("rail", "tram|light_rail|train"), ("bus", "bus")):
            po = os.path.join(args.cache, f"ka_routes_{tag}.json")
            if not os.path.exists(po):
                print(f"[osm] ÖPNV-Linien ({tag}) ...", flush=True)
                ok = query(f'relation["route"~"^({rx})$"]({bb});', po)
                print("[osm]   ok" if ok else "[osm]   FEHLGESCHLAGEN", flush=True)
                if not ok:
                    failed.append(po)
                    continue
            parts.append(po)
        if len(parts) == 2:
            els = []
            for po in parts:
                with open(po) as fh:
                    els += json.load(fh).get("elements", [])
            with open(out + ".part", "w") as fh:
                json.dump({"elements": els}, fh)
            os.replace(out + ".part", out)
            print(f"[osm] ÖPNV-Linien zusammengeführt: {len(els)} Relationen", flush=True)
    print(f"[osm] fertig, fehlgeschlagen: {len(failed)}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
