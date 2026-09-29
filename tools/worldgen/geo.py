"""Koordinaten und kleine Geometrie-Helfer für die Weltgenerierung.

Spielkoordinaten: 1 Einheit = 1 m, Ursprung = Karlsruher Schlossturm, +X = Osten, +Z = Süden (Norden = -Z).
"""
from __future__ import annotations

import hashlib
import math

# Schlossturm Karlsruhe (WGS84)
ORIGIN_LAT = 49.013480
ORIGIN_LON = 8.404440
M_PER_DEG_LAT = 111_195.0
M_PER_DEG_LON = 111_320.0 * math.cos(math.radians(ORIGIN_LAT))

# Kalibrierung des Referenz-Screenshots (Nutzervorlage): Maßstab 1 500 m = 171 px, Schloss bei (1088, 581)
SHOT_M_PER_PX = 1500.0 / 171.0
SHOT_ORIGIN = (1088.0, 581.0)


def ll(lat: float, lon: float) -> tuple[float, float]:
    """WGS84 -> Spielkoordinaten (x, z)."""
    return ((lon - ORIGIN_LON) * M_PER_DEG_LON, (ORIGIN_LAT - lat) * M_PER_DEG_LAT)


def to_ll(x: float, z: float) -> tuple[float, float]:
    return (ORIGIN_LAT - z / M_PER_DEG_LAT, ORIGIN_LON + x / M_PER_DEG_LON)


def px(u: float, v: float) -> tuple[float, float]:
    """Pixel im Referenz-Screenshot -> Spielkoordinaten (Näherung, ±50 m)."""
    return ((u - SHOT_ORIGIN[0]) * SHOT_M_PER_PX, (v - SHOT_ORIGIN[1]) * SHOT_M_PER_PX)


def polar(cx: float, cz: float, r: float, deg: float) -> tuple[float, float]:
    """Wie PolyUtil.polar im Spiel: 0° = Süden (+Z), 90° = Osten (+X)."""
    a = math.radians(deg)
    return (cx + math.sin(a) * r, cz + math.cos(a) * r)


def arc(cx: float, cz: float, r: float, from_deg: float, to_deg: float, step: float = 5.0) -> list[tuple[float, float]]:
    n = max(1, int(round(abs(to_deg - from_deg) / step)))
    return [polar(cx, cz, r, from_deg + (to_deg - from_deg) * i / n) for i in range(n + 1)]


def hash01(*vals) -> float:
    """Deterministischer Hash -> [0, 1)."""
    h = hashlib.blake2b(repr(vals).encode(), digest_size=8).digest()
    return int.from_bytes(h, "little") / 2**64


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def dist(a, b) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def rnd(v: float, d: int = 2) -> float:
    return round(float(v), d)
