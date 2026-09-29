#!/usr/bin/env bash
# Stellt die Release-Dateien zusammen (nach scripts/linux/build_windows.sh):
#   build/release/Faecherstadt_Windows_x64_v<Version>.zip
#   build/release/GTA_KA_installieren_und_starten.bat   (Name und SHA256 des ZIP eingetragen)
#   build/release/SHA256SUMS.txt
# Die Dateien werden als GitHub-Release-Anhang veröffentlicht (nicht im Repo versioniert – Speicherbudget).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(grep -E '^config/version=' "$ROOT/project.godot" | cut -d'"' -f2)"
NAME="Faecherstadt_Windows_x64_v${VERSION}.zip"
SRC="$ROOT/build/$NAME"
OUT="$ROOT/build/release"
[ -f "$SRC" ] || { echo "[release] $SRC fehlt – zuerst scripts/linux/build_windows.sh ausführen"; exit 2; }
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$SRC" "$OUT/$NAME"
HASH="$(sha256sum "$OUT/$NAME" | cut -d' ' -f1)"
sed -e "s/@NAME@/$NAME/g" -e "s/@HASH@/$HASH/g" "$ROOT/tools/release/installer_template.bat" > "$OUT/GTA_KA_installieren_und_starten.bat"
grep -q "$HASH" "$OUT/GTA_KA_installieren_und_starten.bat"
(cd "$OUT" && sha256sum "$NAME" GTA_KA_installieren_und_starten.bat > SHA256SUMS.txt)
echo "[release] Version $VERSION"
ls -la "$OUT"
cat "$OUT/SHA256SUMS.txt"
