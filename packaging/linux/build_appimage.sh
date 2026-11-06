#!/usr/bin/env bash
# Usage: APPIMAGETOOL=<path> build_appimage.sh <stage> <version> <out.AppImage>
# <version> is unused here; it keeps the same arguments as build_deb.sh.
set -euo pipefail

stage="$1"
version="$2"
out="$3"
tool="${APPIMAGETOOL:?falta APPIMAGETOOL con la ruta de appimagetool}"

dir="$(cd "$(dirname "$0")" && pwd)"
icon="$dir/../../apps/bodega/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
appdir="$work/Bodega.AppDir"
mkdir "$appdir"

cp -a "$stage/." "$appdir/"
sed 's|^Exec=.*|Exec=bodega|' "$dir/bodega.desktop" > "$appdir/bodega.desktop"
install -m 644 "$icon" "$appdir/bodega.png"

cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/bodega" "$@"
EOF
chmod 755 "$appdir/AppRun"

cp "$tool" "$work/appimagetool"
chmod 755 "$work/appimagetool"

# Extract-and-run avoids needing FUSE on the build machine.
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$work/appimagetool" "$appdir" "$out"
