#!/usr/bin/env bash
# Usage: build_deb.sh <stage> <version> <out.deb>
# Puts the staged app under /opt/bodega and links the CLI into /usr/bin.
set -euo pipefail

stage="$1"
version="$2"
out="$3"

dir="$(cd "$(dirname "$0")" && pwd)"
icon="$dir/../../apps/bodega/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

pkg="$(mktemp -d)"
trap 'rm -rf "$pkg"' EXIT
chmod 755 "$pkg"

mkdir -p "$pkg/opt/bodega" "$pkg/usr/bin" "$pkg/usr/share/applications" \
  "$pkg/usr/share/icons/hicolor/512x512/apps" "$pkg/DEBIAN"

cp -a "$stage/." "$pkg/opt/bodega/"
ln -s /opt/bodega/bodega-cli "$pkg/usr/bin/bodega"
install -m 644 "$dir/bodega.desktop" "$pkg/usr/share/applications/bodega.desktop"
sed -i 's|^Exec=.*|Exec=/opt/bodega/bodega|' "$pkg/usr/share/applications/bodega.desktop"
install -m 644 "$icon" "$pkg/usr/share/icons/hicolor/512x512/apps/bodega.png"

installed_size="$(du -sk "$pkg/opt" "$pkg/usr" | awk '{ s += $1 } END { print s }')"

cat > "$pkg/DEBIAN/control" <<EOF
Package: bodega
Version: $version
Section: games
Priority: optional
Architecture: amd64
Installed-Size: $installed_size
Maintainer: roilanrodriguez55
Depends: libgtk-3-0t64 | libgtk-3-0, libvulkan1, libpulse0
Recommends: mesa-vulkan-drivers, gamemode, mangohud
Description: launcher to play Windows games with Wine
 Bodega runs Windows games and programs with Wine, with DXVK and
 vkd3d-proton layers included. License notices and sources in /opt/bodega/LICENSES.
EOF

# ntsync: load the module at boot and give the session user access to /dev/ntsync.
mkdir -p "$pkg/etc/modules-load.d" "$pkg/usr/lib/udev/rules.d"
echo ntsync > "$pkg/etc/modules-load.d/bodega-ntsync.conf"
echo '/etc/modules-load.d/bodega-ntsync.conf' > "$pkg/DEBIAN/conffiles"
echo 'KERNEL=="ntsync", MODE="0660", TAG+="uaccess"' > "$pkg/usr/lib/udev/rules.d/70-bodega-ntsync.rules"

# postinst must never fail the install: kernels or containers may lack ntsync or udevadm.
cat > "$pkg/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
modprobe ntsync || true
udevadm control --reload-rules || true
udevadm trigger --sysname-match=ntsync || true
exit 0
EOF
chmod 755 "$pkg/DEBIAN/postinst"

dpkg-deb --root-owner-group --build "$pkg" "$out"
