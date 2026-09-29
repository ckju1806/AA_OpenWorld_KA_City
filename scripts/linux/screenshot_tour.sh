#!/usr/bin/env bash
# Screenshot-Tour unter Xvfb (Software-Rendering, Vulkan/lavapipe) zur visuellen Kontrolle.
# Aufruf: scripts/linux/screenshot_tour.sh <zielordner> [world=city|test] [breite] [höhe] [nur=teil1,teil2]
# Hinweis: Die gemessene FPS unter Software-Rendering ist NICHT repräsentativ für echte Hardware.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/artifacts/screenshots/latest}"
WORLD="${2:-city}"
W="${3:-1280}"
H="${4:-720}"
ONLY="${5:-}"
EXTRA=()
if [ -n "$ONLY" ]; then EXTRA+=("--tour-only=$ONLY"); fi
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1 || true
timeout 2400 xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path "$ROOT" --resolution "${W}x${H}" \
  -- --autostart --world="$WORLD" --screenshot-tour --shot-dir="$OUT" "${EXTRA[@]}" 2>&1 | grep -E "screenshot|SCRIPT ERROR|ERROR: Failed" || true
ls -la "$OUT"
# Zusätzlich: Hauptmenü (ohne Autostart; nicht bei gefilterter Tour)
[ -n "$ONLY" ] && exit 0
timeout 300 xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path "$ROOT" --resolution "${W}x${H}" \
  -- --menu-shot --shot-dir="$OUT/menue" 2>&1 | grep -E "screenshot|SCRIPT ERROR|ERROR: Failed" || true
