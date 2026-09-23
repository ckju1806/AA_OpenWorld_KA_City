#!/usr/bin/env bash
# Führt alle automatisierten Tests headless aus (deterministisch mit --fixed-fps 60).
# Aufruf: scripts/linux/run_tests.sh [filter]   z. B.  unit | integration | test_player
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
FILTER="${1:-}"
LOG_DIR="$ROOT/artifacts/test-logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/tests_${STAMP}.log"
echo "[tests] Import ..."
"$GODOT" --headless --path "$ROOT" --import > "$LOG_DIR/import_${STAMP}.log" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG_DIR/import_${STAMP}.log"; then
  echo "[tests] Import-/Parse-Fehler, siehe $LOG_DIR/import_${STAMP}.log"; exit 2
fi
echo "[tests] Tests ... (Log: $LOG)"
ARGS=()
[ -n "$FILTER" ] && ARGS+=("--filter=$FILTER")
set +e
"$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://tests/test_runner.tscn -- "${ARGS[@]}" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e
if grep -qE "SCRIPT ERROR" "$LOG"; then
  echo "[tests] Laufzeit-Skriptfehler im Log gefunden."; RC=3
fi
echo "[tests] Exit-Code: $RC"
exit $RC
