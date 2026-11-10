#!/usr/bin/env bash
# Usage: build_arch.sh <Bodega-X.Y.Z-linux-x86_64.tar.gz> <out dir>
# Wraps the tarball from package_linux.sh in a pacman package (needs makepkg,
# which refuses to run as root). Writes Bodega-X.Y.Z-arch-x86_64.pkg.tar.zst, named like the
# other release files; the package inside is still `bodega`.
set -euo pipefail

tarball="$(readlink -f "$1")"
out="$(readlink -f "$2")"

dir="$(cd "$(dirname "$0")" && pwd)"
icon="$dir/../../apps/bodega/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

if [[ ! "$(basename "$tarball")" =~ ^Bodega-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64\.tar\.gz$ ]]; then
  echo "error: $tarball is not a Bodega-X.Y.Z-linux-x86_64.tar.gz" >&2
  exit 1
fi
version="${BASH_REMATCH[1]}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp "$dir/PKGBUILD" "$dir/bodega.install" "$dir/../linux/bodega.desktop" "$work/"
cp "$icon" "$work/bodega.png"
ln -s "$tarball" "$work/$(basename "$tarball")"

mkdir -p "$out" "$work/dest"
(
  cd "$work"
  # makepkg names it bodega-X.Y.Z-<pkgrel>-x86_64.pkg.tar.zst. PKGDEST must not be ./pkg, which is
  # makepkg's own staging dir; a private one also keeps stale builds out.
  BODEGA_VERSION="$version" PKGDEST="$work/dest" makepkg -f --nodeps --nocheck
)
mv "$work"/dest/bodega-"$version"-*-x86_64.pkg.tar.zst "$out/Bodega-$version-arch-x86_64.pkg.tar.zst"
ls -l "$out/Bodega-$version-arch-x86_64.pkg.tar.zst"
