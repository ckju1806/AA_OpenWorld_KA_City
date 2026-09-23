#!/usr/bin/env python3
"""Erzeugt das Windows-Icon (assets/icons/faecherstadt.ico) ohne externe Bibliotheken.

Motiv (eigenes Werk): Fächer-Straßen, die von einem Turm ausgehen, vor Abendhimmel.
Das ICO enthält PNG-kodierte Bilder in 16, 32, 48, 64, 128 und 256 Pixel.
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons", "faecherstadt.ico")
OUT_PNG = os.path.join(ROOT, "assets", "icons", "faecherstadt_256.png")


def lerp(a, b, t):
    return a + (b - a) * t


def render(size):
    px = []
    s = size / 256.0
    cx, cy = 128 * s, 92 * s
    rays = [(36, 222), (66, 230), (96, 236), (128, 238), (160, 236), (190, 230), (220, 222)]
    for y in range(size):
        row = []
        for x in range(size):
            fx, fy = (x + 0.5) / s, (y + 0.5) / s
            # abgerundetes Quadrat
            r = 44
            dx = max(8 + r - fx, 0, fx - (248 - r))
            dy = max(8 + r - fy, 0, fy - (248 - r))
            inside = (dx * dx + dy * dy) <= r * r and 8 <= fx <= 248 and 8 <= fy <= 248
            if not inside:
                row.append((0, 0, 0, 0))
                continue
            t = (fy - 8) / 240.0
            if t < 0.6:
                c0, c1, tt = (0x2b, 0x1d, 0x3a), (0xb8, 0x56, 0x3a), t / 0.6
            else:
                c0, c1, tt = (0xb8, 0x56, 0x3a), (0xf2, 0xa6, 0x5a), (t - 0.6) / 0.4
            col = [lerp(c0[i], c1[i], tt) for i in range(3)]
            dark = False
            for ex, ey in rays:
                ax, ay, bx, by = 128, 92, ex, ey
                vx, vy = bx - ax, by - ay
                l2 = vx * vx + vy * vy
                u = max(0.0, min(1.0, ((fx - ax) * vx + (fy - ay) * vy) / l2))
                d = math.hypot(fx - (ax + vx * u), fy - (ay + vy * u))
                if d < 4.5:
                    dark = True
            if 60 <= fx <= 196 and 104 <= fy <= 118:
                dark = True
            if 116 <= fx <= 140 and 70 <= fy <= 104:
                dark = True
            if 44 <= fy <= 70 and abs(fx - 128) <= (fy - 44) * 16.0 / 26.0:
                dark = True
            if dark:
                col = [0x1b, 0x14, 0x20]
            if math.hypot(fx - 128, fy - 92) < 9:
                col = [0xff, 0xd2, 0x7a]
            row.append((int(col[0]), int(col[1]), int(col[2]), 255))
        px.append(row)
    return px


def png_bytes(px):
    h = len(px)
    w = len(px[0])
    raw = b"".join(b"\x00" + bytes([c for p in row for c in p]) for row in px)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sizes = [16, 32, 48, 64, 128, 256]
    images = [png_bytes(render(sz)) for sz in sizes]
    header = struct.pack("<HHH", 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    entries = b""
    for sz, data in zip(sizes, images):
        entries += struct.pack("<BBBBHHII", sz % 256, sz % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    with open(OUT, "wb") as f:
        f.write(header + entries + b"".join(images))
    with open(OUT_PNG, "wb") as f:
        f.write(images[-1])
    print("Icon geschrieben:", OUT)


if __name__ == "__main__":
    main()
