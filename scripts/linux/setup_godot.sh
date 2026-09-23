#!/usr/bin/env bash
# Lädt Godot 4.7.2 (Linux-Editor) und die Export-Templates, prüft SHA512 gegen die offizielle Liste und installiert sie.
# Idempotent: bereits vorhandene, geprüfte Dateien werden nicht erneut geladen.
set -euo pipefail
VER="4.7.2-stable"
DIR="${GODOT_DIR:-$HOME/godot}"
TPL_DIR="$HOME/.local/share/godot/export_templates/4.7.2.stable"
BASE="https://github.com/godotengine/godot/releases/download/$VER"
BASE_BUILDS="https://github.com/godotengine/godot-builds/releases/download/$VER"
EDITOR_ZIP="Godot_v${VER}_linux.x86_64.zip"
TPZ="Godot_v${VER}_export_templates.tpz"
mkdir -p "$DIR" "$TPL_DIR"
cd "$DIR"
curl -fsSL -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
fetch() {  # fetch <datei> <url1> [url2]
  local f="$1"; shift
  if [ -f "$f" ] && grep " $f\$" SHA512-SUMS.txt | sha512sum -c --status; then echo "[setup] $f bereits vorhanden und geprüft"; return; fi
  for url in "$@"; do
    echo "[setup] Lade $url"
    if curl -fL -C - -o "$f" "$url"; then break; fi
  done
  grep " $f\$" SHA512-SUMS.txt | sha512sum -c
}
fetch "$EDITOR_ZIP" "$BASE/$EDITOR_ZIP" "$BASE_BUILDS/$EDITOR_ZIP"
fetch "$TPZ" "$BASE/$TPZ" "$BASE_BUILDS/$TPZ"
unzip -oq "$EDITOR_ZIP"
chmod +x "Godot_v${VER}_linux.x86_64"
unzip -oq "$TPZ" "templates/windows_*" "templates/version.txt" -d tpl_tmp
cp tpl_tmp/templates/* "$TPL_DIR/"
rm -rf tpl_tmp
echo "[setup] Editor: $DIR/Godot_v${VER}_linux.x86_64   (z. B. ln -sf ... /usr/local/bin/godot)"
echo "[setup] Templates: $TPL_DIR"
"$DIR/Godot_v${VER}_linux.x86_64" --headless --version
