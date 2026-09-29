#!/usr/bin/env bash
# Lädt den Geofabrik-Extrakt "Regierungsbezirk Karlsruhe" (OSM-PBF, © OpenStreetMap-Mitwirkende, ODbL) mit Fortsetzen
# und MD5-Prüfung. Alternative zu fetch_osm.py (Overpass). Ergebnis: <cache>/karlsruhe-regbez-latest.osm.pbf
# Aufruf: tools/worldgen/fetch_geofabrik.sh [cache-ordner] [max-versuche]
set -u
CACHE="${1:-$HOME/osm_cache}"
MAX="${2:-2000}"
URL="https://download.geofabrik.de/europe/germany/baden-wuerttemberg/karlsruhe-regbez-latest.osm.pbf"
UA="Faecherstadt-worldgen/0.2 (nicht-kommerzieller Spielprototyp)"
mkdir -p "$CACHE"
cd "$CACHE" || exit 1
F="karlsruhe-regbez-latest.osm.pbf"
for i in $(seq 1 "$MAX"); do
  if [ ! -s "$F.md5" ]; then
    curl -s -m 30 -A "$UA" -o "$F.md5" "$URL.md5" || rm -f "$F.md5"
  fi
  curl -s -m 600 -A "$UA" -C - -o "$F" "$URL"
  if [ -s "$F.md5" ] && [ -s "$F" ]; then
    want=$(cut -d' ' -f1 "$F.md5")
    have=$(md5sum "$F" | cut -d' ' -f1)
    if [ "$want" = "$have" ]; then
      echo "[geofabrik] vollständig ($(du -h "$F" | cut -f1)), MD5 ok"
      exit 0
    fi
  fi
  [ $((i % 20)) -eq 0 ] && echo "[geofabrik] Versuch $i, bisher $(du -h "$F" 2>/dev/null | cut -f1)"
  sleep 3
done
echo "[geofabrik] aufgegeben"
exit 1
