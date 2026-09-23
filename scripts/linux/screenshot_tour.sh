#!/usr/bin/env bash
# Screenshot-Tour unter Xvfb (Software-Rendering, Vulkan/lavapipe) zur visuellen Kontrolle.
# Aufruf: scripts/linux/screenshot_tour.sh <zielordner> [world=city|test] [breite] [höhe]
# Hinweis: Die gemessene FPS unter Software-Rendering ist NICHT repräsentativ für echte Hardware.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/artifacts/screenshots/latest}"
WORLD="${2:-city}"
W="${3:-1280}"
H="${4:-720}"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1 || true
timeout 900 xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path "$ROOT" --resolution "${W}x${H}" \
  -- --autostart --world="$WORLD" --screenshot-tour --shot-dir="$OUT" 2>&1 | grep -E "screenshot|SCRIPT ERROR|ERROR: Failed" || true
ls -la "$OUT"
