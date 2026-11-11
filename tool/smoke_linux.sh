#!/usr/bin/env bash
# Usage: smoke_linux.sh <deb|arch|appimage> <dist dir>
# Installs one Linux package in a clean container and runs the CLI in it, with no window and without
# starting Wine. The package passes if the CLI starts (so its libraries load on that system),
# the host check finds nothing missing, and the bundled Wine and DXVK layer are registered.
# Needs docker. <dist dir> holds the files from tool/package_linux.sh, named as it names them.
set -euo pipefail

kind="${1:?usage: smoke_linux.sh <deb|arch|appimage> <dist dir>}"
dist="$(readlink -f "${2:?missing the dist directory}")"

case "$kind" in
  deb)
    image=ubuntu:24.04
    # apt installs the Recommends too, which bring a Vulkan driver (mesa-vulkan-drivers).
    install='apt-get update -qq && apt-get install -y -qq /dist/Bodega-*-linux-amd64.deb >/dev/null
bin=bodega'
    ;;
  arch)
    image=archlinux:base
    # vulkan-swrast is the Vulkan driver that checkHost suggests where there is no GPU.
    install='pacman -Syu --noconfirm >/dev/null && pacman -S --noconfirm vulkan-swrast >/dev/null
pacman -U --noconfirm /dist/Bodega-*-arch-x86_64.pkg.tar.zst >/dev/null
bin=bodega'
    ;;
  appimage)
    image=ubuntu:24.04
    # AppRun starts the window, so the AppImage is unpacked (no FUSE needed) and its CLI is run.
    install='apt-get update -qq && apt-get install -y -qq libvulkan1 mesa-vulkan-drivers libpulse0 >/dev/null
cp /dist/Bodega-*-linux-x86_64.AppImage /tmp/bodega.AppImage && chmod +x /tmp/bodega.AppImage
(cd /tmp && ./bodega.AppImage --appimage-extract >/dev/null)
bin=/tmp/squashfs-root/bodega-cli'
    ;;
  *)
    echo "unknown kind: $kind (deb, arch or appimage)" >&2
    exit 64
    ;;
esac

docker run --rm -v "$dist":/dist:ro "$image" bash -c "
set -euo pipefail
$install
export BODEGA_HOME=\"\$(mktemp -d)\"
out=\"\$(\$bin backend list)\"
echo \"\$out\"
echo \"\$out\" | grep -qx 'dxvk: installed'
test -x \"\$BODEGA_HOME/runtimes/current/engine/bin/wine\"
echo \"smoke $kind: OK\"
"
