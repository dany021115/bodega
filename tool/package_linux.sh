#!/usr/bin/env bash
# Builds the Linux packages (.deb, .tar.gz, AppImage) into dist/.
# Run from the repo root. The release build is made on ubuntu-24.04 (see release-linux.yml).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

cache="$root/packaging/linux/cache"

# Prints one field of an asset from assets.json: version, or the file name from its url.
asset() {
  python3 -I -c '
import json, os, sys
for a in json.load(open(sys.argv[1]))["assets"]:
    if a["name"] == sys.argv[2]:
        print(a["version"] if sys.argv[3] == "version" else os.path.basename(a["url"]))
' "$root/packaging/linux/assets.json" "$1" "$2"
}

wine_ver="$(asset wine version)"
wine_file="$(asset wine file)"
dxvk_ver="$(asset dxvk version)"
dxvk_file="$(asset dxvk file)"
vkd3d_ver="$(asset vkd3d-proton version)"
vkd3d_file="$(asset vkd3d-proton file)"
appimagetool_file="$(asset appimagetool file)"
ver="$(awk '/^version:/ { split($2, v, "+"); print v[1]; exit }' apps/bodega/pubspec.yaml)"

glibc="$(getconf GNU_LIBC_VERSION | awk '{ print $2 }')"
if [ "$(printf '%s\n' 2.39 "$glibc" | sort -V | tail -n 1)" != "2.39" ]; then
  echo "aviso: glibc local $glibc es mas nuevo que el de Ubuntu 24.04 (2.39). Construye en ubuntu-24.04 (el workflow) para releases."
fi

packaging/linux/fetch_assets.sh

(
  cd apps/bodega
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  flutter build linux --release
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stage="$tmp/stage"
mkdir -p "$stage"

dart compile exe packages/engine/bin/bodega.dart -o "$stage/bodega-cli"
cp -a apps/bodega/build/linux/x64/release/bundle/. "$stage/"

wine_dir="$stage/runtime/wine-$wine_ver"
mkdir -p "$wine_dir/engine"
tar -xJf "$cache/wine/$wine_file" -C "$wine_dir/engine" --strip-components=1

mkdir "$tmp/dxvk" "$tmp/vkd3d"
tar -xzf "$cache/dxvk/$dxvk_file" -C "$tmp/dxvk" --strip-components=1
tar --zstd -xf "$cache/vkd3d-proton/$vkd3d_file" -C "$tmp/vkd3d" --strip-components=1

# vkd3d-proton names its 32-bit folder x86 where DXVK says x32.
backend="$stage/backends/dxvk"
mkdir -p "$backend/wine/x64" "$backend/wine/x32"
cp -a "$tmp/dxvk/x64/." "$tmp/vkd3d/x64/." "$backend/wine/x64/"
cp -a "$tmp/dxvk/x32/." "$tmp/vkd3d/x86/." "$backend/wine/x32/"
printf 'dxvk-%s+vkd3d-proton-%s\n' "$dxvk_ver" "$vkd3d_ver" > "$backend/VERSION"

cp -a packaging/linux/LICENSES "$stage/LICENSES"

out="$root/dist"
mkdir -p "$out"

bash packaging/linux/build_deb.sh "$stage" "$ver" "$out/Bodega-$ver-linux-amd64.deb"

tar -czf "$out/Bodega-$ver-linux-x86_64.tar.gz" -C "$stage" .

APPIMAGETOOL="$cache/appimagetool/$appimagetool_file" \
  bash packaging/linux/build_appimage.sh "$stage" "$ver" "$out/Bodega-$ver-linux-x86_64.AppImage"

ls -l "$out"
