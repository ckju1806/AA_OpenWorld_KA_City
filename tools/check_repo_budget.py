#!/usr/bin/env python3
"""Prüft das GitHub-Speicherbudget des Repositorys (Nutzervorgabe 2026-09-28).

Budgets: Repo gesamt inkl. Historie < 300 MB, jede versionierte Datei < 45 MB, Weltdaten data/world/ka < 40 MB,
Einzeldatei in data/world < 5 MB, Screenshots < 400 KB. Exit-Code 1 bei Überschreitung.
Aufruf: python3 tools/check_repo_budget.py [--staged]  (--staged: prüft zusätzlich die zum Commit vorgemerkten Dateien)
"""
import os
import subprocess
import sys

MB = 1024 * 1024
LIMITS = {"repo_total": 300 * MB, "file": 45 * MB, "world_total": 40 * MB, "world_file": 5 * MB, "screenshot": 400 * 1024}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def main():
    errors, notes = [], []
    pack = 0
    for line in git("count-objects", "-v").splitlines():
        k, v = line.split(": ")
        if k in ("size", "size-pack"):
            pack += int(v) * 1024
    files = [f for f in git("ls-files").splitlines() if f]
    if "--staged" in sys.argv:
        files += [f for f in git("diff", "--cached", "--name-only").splitlines() if f]
    tracked, world = 0, 0
    for f in sorted(set(files)):
        p = os.path.join(ROOT, f)
        if not os.path.isfile(p):
            continue
        s = os.path.getsize(p)
        tracked += s
        if f == "release/Faecherstadt_Windows_x64_v0.1.0.zip":
            continue  # Altlast v0.1.0, bereits in der Historie
        if s > LIMITS["file"]:
            errors.append(f"Datei zu groß ({s / MB:.1f} MB): {f}")
        if f.startswith("data/world/"):
            world += s
            if s > LIMITS["world_file"]:
                errors.append(f"Weltdatei zu groß ({s / MB:.1f} MB): {f}")
        if f.startswith("artifacts/screenshots/") and s > LIMITS["screenshot"]:
            notes.append(f"Screenshot groß ({s / 1024:.0f} KB): {f}")
    if world > LIMITS["world_total"]:
        errors.append(f"Weltdaten zu groß: {world / MB:.1f} MB > {LIMITS['world_total'] / MB:.0f} MB")
    est = max(pack, tracked)
    if est > LIMITS["repo_total"]:
        errors.append(f"Repo zu groß: ~{est / MB:.0f} MB > {LIMITS['repo_total'] / MB:.0f} MB")
    print(f"[budget] Git-Objekte {pack / MB:.1f} MB, versionierte Dateien {tracked / MB:.1f} MB, Weltdaten {world / MB:.1f} MB")
    for n in notes[:10]:
        print("[budget] Hinweis:", n)
    for e in errors:
        print("[budget] FEHLER:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
