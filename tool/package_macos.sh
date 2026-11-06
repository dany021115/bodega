#!/usr/bin/env bash
# Builds Bodega-X.Y.Z-macos-arm64.dmg into dist/. Needs macOS on Apple Silicon.
# The engine and host libraries come from local files or from this repo's releases.
# Bash 3.2 compatible (the macOS runner's bash): no arrays, mapfile or ${var,,}.
set -euo pipefail

usage() {
  cat <<'EOF'
Uso: tool/package_macos.sh [--engine FILE --hostlibs FILE] [--engine-tag TAG] [--hostlibs-tag TAG] [--help]

Construye dist/Bodega-X.Y.Z-macos-arm64.dmg. Solo macOS con Apple Silicon.

  --engine FILE       tarball del motor local (con su .sha256 al lado)
  --hostlibs FILE     tarball de las librerias del host local (con su .sha256 al lado)
  --engine-tag TAG    release engine-* a descargar (por defecto, la mas reciente)
  --hostlibs-tag TAG  release hostlibs-* a descargar (por defecto, la mas reciente)
  --help              muestra este uso

Sin --engine y --hostlibs, los tarballs se bajan de las releases de este repo con gh.
EOF
}

engine=""
hostlibs=""
engine_tag=""
hostlibs_tag=""
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) engine="${2:?falta FILE tras --engine}"; shift 2 ;;
    --hostlibs) hostlibs="${2:?falta FILE tras --hostlibs}"; shift 2 ;;
    --engine-tag) engine_tag="${2:?falta TAG tras --engine-tag}"; shift 2 ;;
    --hostlibs-tag) hostlibs_tag="${2:?falta TAG tras --hostlibs-tag}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -n "$engine$hostlibs" ] && { [ -z "$engine" ] || [ -z "$hostlibs" ]; }; then
  echo "--engine y --hostlibs van juntos" >&2
  exit 1
fi

# Relative local paths are resolved before the cd to the repo root.
case "$engine" in ""|/*) ;; *) engine="$PWD/$engine" ;; esac
case "$hostlibs" in ""|/*) ;; *) hostlibs="$PWD/$hostlibs" ;; esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  echo "solo se construye en macOS con Apple Silicon" >&2
  exit 1
fi

ver="$(awk '/^version:/ { split($2, v, "+"); print v[1]; exit }' apps/bodega/pubspec.yaml)"

if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "falta Rosetta: instalala con softwareupdate --install-rosetta --agree-to-license" >&2
  exit 1
fi

cache="$root/packaging/macos/cache"

# Prints the newest release tag of this repo that starts with the prefix.
latest_tag() {
  gh release list --limit 100 --json tagName | python3 -I -c '
import json, sys
for r in json.load(sys.stdin):
    if r["tagName"].startswith(sys.argv[1]):
        print(r["tagName"])
        break
' "$1"
}

# Downloads a release of this repo into a fresh cache/<kind> and sets $tarball to its .tar.gz.
# $1 kind (engine|hostlibs), $2 tag prefix, $3 tag (empty = newest).
download() {
  local kind="$1" prefix="$2" tag="$3" dir
  dir="$cache/$kind"
  if [ -z "$tag" ]; then
    tag="$(latest_tag "$prefix")"
  fi
  if [ -z "$tag" ]; then
    echo "no hay release ${prefix}* en este repositorio: lanza el workflow build-engine con publish_release (y build-hostlibs para hostlibs) o pasa --engine/--hostlibs" >&2
    exit 1
  fi
  rm -rf "$dir"
  mkdir -p "$dir"
  gh release download "$tag" --pattern '*.tar.gz' --pattern '*.tar.gz.sha256' --dir "$dir"
  set -- "$dir"/*.tar.gz
  if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "la release $tag no trae exactamente un .tar.gz" >&2
    exit 1
  fi
  tarball="$1"
}

if [ -z "$engine" ]; then
  download engine "engine-" "$engine_tag"
  engine="$tarball"
  download hostlibs "hostlibs-" "$hostlibs_tag"
  hostlibs="$tarball"
fi

(
  cd apps/bodega
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  flutter build macos --release
)
app="$root/apps/bodega/build/macos/Build/Products/Release/Bodega.app"
if [ ! -d "$app" ]; then
  echo "no se encontro $app tras flutter build macos" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

dart compile exe packages/engine/bin/bodega.dart -o "$tmp/bodega-cli"

# Seeds a throwaway data directory with the CLI itself; BODEGA_BUNDLE points nowhere so nothing is registered.
seed="$tmp/seed"
export BODEGA_HOME="$seed"
export BODEGA_BUNDLE="$tmp/sin-paquete"
"$tmp/bodega-cli" install "$engine" "$hostlibs"
"$tmp/bodega-cli" sdl install
"$tmp/bodega-cli" backend install dxmt
"$tmp/bodega-cli" backend install dxvk
unset BODEGA_HOME BODEGA_BUNDLE

# Assemble inside a copy so build/ stays clean. cp -R keeps symlinks.
out_app="$tmp/Bodega.app"
ditto "$app" "$out_app"
bundle="$out_app/Contents/Resources/bundle"
mkdir -p "$bundle/runtime" "$bundle/backends"

for d in "$seed"/runtimes/*/; do
  name="$(basename "$d")"
  case "$name" in current|.tmp-*) continue ;; esac
  # No trailing slash: BSD cp would copy the folder's contents, not the folder.
  cp -R "${d%/}" "$bundle/runtime/"
done

for d in "$seed"/backends/*/; do
  case "$(basename "$d")" in .tmp-*) continue ;; esac
  cp -R "${d%/}" "$bundle/backends/"
done

cp "$tmp/bodega-cli" "$out_app/Contents/MacOS/bodega-cli"
chmod 755 "$out_app/Contents/MacOS/bodega-cli"

# Ad hoc signature. Developer ID and notarization are out of scope: the first launch needs
# right click, Open (see LEEME.txt).
codesign --force --deep --sign - "$out_app"
codesign --verify --deep "$out_app"

dmg_dir="$tmp/dmg"
mkdir -p "$dmg_dir"
ditto "$out_app" "$dmg_dir/Bodega.app"
ln -s /Applications "$dmg_dir/Applications"
cp "$root/packaging/macos/LEEME.txt" "$dmg_dir/LEEME.txt"

mkdir -p "$root/dist"
dmg="$root/dist/Bodega-$ver-macos-arm64.dmg"
hdiutil create -volname "Bodega $ver" -srcfolder "$dmg_dir" -ov -format UDZO "$dmg"

ls -l "$dmg"
shasum -a 256 "$dmg"
