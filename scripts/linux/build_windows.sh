#!/usr/bin/env bash
# Reproduzierbarer Windows-x64-Export (Release) von Linux aus.
# Ergebnis: build/windows/Faecherstadt.exe + Faecherstadt.pck sowie build/Faecherstadt_Windows_x64_v<Version>.zip
# Voraussetzung: Godot 4.7.2 + Export-Templates 4.7.2 (siehe scripts/linux/setup_godot.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT_DIR="$ROOT/build/windows"
LOG_DIR="$ROOT/artifacts/test-logs"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/export_${STAMP}.log"
VERSION="$(grep -E '^config/version=' "$ROOT/project.godot" | cut -d'"' -f2)"
ZIP="$ROOT/build/Faecherstadt_Windows_x64_v${VERSION}.zip"
mkdir -p "$OUT_DIR" "$LOG_DIR"

echo "[build] Godot: $("$GODOT" --version)"
TPL="${HOME}/.local/share/godot/export_templates/$("$GODOT" --version | sed -E 's/^([0-9.]+\.[a-z]+).*/\1/')"
[ -f "$TPL/windows_release_x86_64.exe" ] || { echo "[build] Export-Templates fehlen in $TPL (scripts/linux/setup_godot.sh ausführen)"; exit 2; }

echo "[build] Import ..."
"$GODOT" --headless --path "$ROOT" --import > "$LOG" 2>&1 || true
rm -f "$OUT_DIR/Faecherstadt.exe" "$OUT_DIR/Faecherstadt.pck" "$OUT_DIR/Faecherstadt.console.exe"
echo "[build] Export (Release) ... (Log: $LOG)"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$OUT_DIR/Faecherstadt.exe" >> "$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|ERROR: .*[Ee]xport" "$LOG"; then
  echo "[build] Fehler im Export-Log."; exit 3
fi
[ -f "$OUT_DIR/Faecherstadt.exe" ] && [ -f "$OUT_DIR/Faecherstadt.pck" ] || { echo "[build] Exportdateien fehlen."; exit 4; }

echo "[build] Prüfe PE-Header ..."
python3 - "$OUT_DIR/Faecherstadt.exe" "$OUT_DIR/Faecherstadt.pck" <<'PY'
import struct, sys
exe, pck = sys.argv[1], sys.argv[2]
with open(exe, "rb") as f:
    d = f.read(4096)
assert d[:2] == b"MZ", "kein MZ-Header"
pe = struct.unpack_from("<I", d, 0x3C)[0]
assert d[pe:pe + 4] == b"PE\0\0", "kein PE-Header"
machine = struct.unpack_from("<H", d, pe + 4)[0]
subsystem = struct.unpack_from("<H", d, pe + 24 + 68)[0]
print(f"  EXE: MZ/PE ok, Maschine 0x{machine:04x} ({'x86_64' if machine == 0x8664 else 'UNERWARTET'}), Subsystem {subsystem} ({'GUI' if subsystem == 2 else 'Konsole' if subsystem == 3 else '?'})")
assert machine == 0x8664, "nicht x86_64"
with open(pck, "rb") as f:
    magic = f.read(4)
print(f"  PCK: Kennung {magic!r}")
assert magic == b"GDPC", "PCK-Kennung falsch"
PY

echo "[build] ZIP ..."
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Faecherstadt"
cp "$OUT_DIR/Faecherstadt.exe" "$OUT_DIR/Faecherstadt.pck" "$STAGE/Faecherstadt/"
cp "$ROOT/README.md" "$ROOT/CONTROLS.md" "$ROOT/ASSET_LICENSES.md" "$ROOT/KNOWN_ISSUES.md" "$ROOT/LICENSE" "$STAGE/Faecherstadt/"
rm -f "$ZIP"
(cd "$STAGE" && python3 -c "
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, _, files in os.walk('Faecherstadt'):
        for n in sorted(files):
            z.write(os.path.join(root, n))
" "$ZIP")
rm -rf "$STAGE"
echo "[build] Ergebnis:"
ls -la "$OUT_DIR"
sha256sum "$OUT_DIR/Faecherstadt.exe" "$OUT_DIR/Faecherstadt.pck" "$ZIP"
