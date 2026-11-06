#!/usr/bin/env bash
# Usage: build_arch.sh <Bodega-X.Y.Z-linux-x86_64.tar.gz> <out dir>
# Wraps the tarball from package_linux.sh in a pacman package (needs makepkg,
# which refuses to run as root). Writes bodega-X.Y.Z-1-x86_64.pkg.tar.zst.
set -euo pipefail

tarball="$(readlink -f "$1")"
out="$(readlink -f "$2")"

dir="$(cd "$(dirname "$0")" && pwd)"
icon="$dir/../../apps/bodega/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

if [[ ! "$(basename "$tarball")" =~ ^Bodega-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64\.tar\.gz$ ]]; then
  echo "error: $tarball no es un Bodega-X.Y.Z-linux-x86_64.tar.gz" >&2
  exit 1
fi
version="${BASH_REMATCH[1]}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp "$dir/PKGBUILD" "$dir/bodega.install" "$dir/../linux/bodega.desktop" "$work/"
cp "$icon" "$work/bodega.png"
ln -s "$tarball" "$work/$(basename "$tarball")"

mkdir -p "$out"
(
  cd "$work"
  BODEGA_VERSION="$version" PKGDEST="$out" makepkg -f --nodeps --nocheck
)
ls -l "$out"/bodega-"$version"-*.pkg.tar.zst
