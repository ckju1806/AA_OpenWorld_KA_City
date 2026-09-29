#!/usr/bin/env python3
"""Neu gebaute Weltdaten sparsam installieren (Speicherbudget): nur Dateien mit geändertem Inhalt werden kopiert,
entfallene Dateien gelöscht. Bei .gz zählt der entpackte Inhalt (gzip-Kopf mit Zeitstempel wird ignoriert).

Aufruf: python3 tools/worldgen/install_world.py <gebaut> [data/world/ka]
"""
from __future__ import annotations

import gzip
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KEEP = {"map.webp.import"}   # Godot-Importdatei, nicht Teil des Builds


def _content(path: str) -> bytes:
    with open(path, "rb") as fh:
        raw = fh.read()
    return gzip.decompress(raw) if path.endswith(".gz") else raw


def _files(base: str) -> set:
    out = set()
    for d, _dirs, fs in os.walk(base):
        for f in fs:
            out.add(os.path.relpath(os.path.join(d, f), base))
    return out


def main() -> int:
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "data", "world", "ka")
    if not os.path.isfile(os.path.join(src, "world.json.gz")):
        print(f"[install] {src} enthält keine Weltdaten")
        return 1
    new, old = _files(src), _files(dst) - KEEP
    copied = removed = 0
    for rel in sorted(new):
        s, d = os.path.join(src, rel), os.path.join(dst, rel)
        if rel in old and _content(s) == _content(d):
            continue
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(s, d)
        copied += 1
    for rel in sorted(old - new):
        os.remove(os.path.join(dst, rel))
        removed += 1
    print(f"[install] {copied} Dateien übernommen, {removed} entfernt, {len(new) - copied} unverändert")
    return 0


if __name__ == "__main__":
    sys.exit(main())
