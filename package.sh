#!/usr/bin/env bash
# Usage: package.sh <ppsspp-source-dir> <PPSSPP.rpx> <out-dir> [old-archive-dir]
# Produces <out-dir>/ppsspp-wiiu.zip : unzip onto the root of your SD card.
set -euo pipefail

SRC="${1:?source dir}"; RPX="${2:?PPSSPP.rpx path}"; OUT="${3:?out dir}"; OLD="${4:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT

[ -f "$RPX" ] || { echo "missing $RPX" >&2; exit 1; }
[ -d "$SRC/assets" ] || { echo "missing $SRC/assets" >&2; exit 1; }

# Homebrew Launcher entry
mkdir -p "$STAGE/wiiu/apps/ppsspp"
cp "$RPX" "$STAGE/wiiu/apps/ppsspp/PPSSPP.rpx"
cat > "$STAGE/wiiu/apps/ppsspp/meta.xml" <<XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<app version="1">
  <name>PPSSPP</name>
  <coder>PPSSPP team / aliaspider (Wii U port)</coder>
  <version>wiiu-branch build</version>
  <short_description>PSP emulator</short_description>
  <long_description>PPSSPP rebuilt from the aliaspider wiiu branch.</long_description>
</app>
XML

# Data folder the port reads: sd:/ppsspp/
mkdir -p "$STAGE/ppsspp/roms" "$STAGE/ppsspp/PSP/SYSTEM"
cp -r "$SRC/assets" "$STAGE/ppsspp/assets"
find "$STAGE/ppsspp/assets" -name '.git*' -prune -exec rm -rf {} + 2>/dev/null || true
cp "$HERE/config/ppsspp.ini" "$STAGE/ppsspp/PSP/SYSTEM/ppsspp.ini"

# Optional: forwarder + WUP installer from your original archive
if [ -n "$OLD" ]; then
  [ -d "$OLD/install" ] && cp -r "$OLD/install" "$STAGE/install"
  [ -d "$OLD/wiiu/apps/wup_installer_gx2" ] && cp -r "$OLD/wiiu/apps/wup_installer_gx2" "$STAGE/wiiu/apps/"
fi

mkdir -p "$OUT"
rm -f "$OUT/ppsspp-wiiu.zip"
(cd "$STAGE" && zip -qr "$OUT/ppsspp-wiiu.zip" .)
cp "$RPX" "$OUT/PPSSPP.rpx"
echo "==> Package: $OUT/ppsspp-wiiu.zip"
