# Arch support (Arch Linux, CachyOS, Manjaro…)

Bodega already runs on x86_64 Linux (`.sdd/linux-support/`), but the packaging is only for Ubuntu/Debian: `tool/package_linux.sh` requires `dpkg-deb` and fails on Arch, and the "Falta Vulkan" ("Vulkan is missing") warning suggests `vulkan-radeon` even when the GPU is not AMD.

## Scope

- A pacman package (`Bodega-X.Y.Z-arch-x86_64.pkg.tar.zst`, with the same naming style as the other files in the release; inside, the package is still `bodega`) built with `makepkg`, from the `.tar.gz` that `package_linux.sh` already builds. Same contents as the `.deb`: `/opt/bodega`, `/usr/bin/bodega`, `.desktop`, icon and ntsync.
- `package_linux.sh` works on Arch: the `.deb` and the pacman package are only built if their tool exists.
- The `release-linux` workflow also uploads the pacman package, built in an `archlinux` container from the `.tar.gz` (without recompiling, so Ubuntu 24.04's glibc stays the baseline).
- On Arch, `checkHost` suggests the Vulkan package for the actual GPU.

Out of scope: publishing to the AUR, a pacman repository of our own, 32-bit packages (WoW64 Wine does not need them), other distros.

## Requirements (EARS)

| ID | Requirement |
|---|---|
| A1 | When `package_linux.sh` runs without `dpkg-deb`, it shall warn and continue: the `.tar.gz` and the AppImage are built anyway. |
| A2 | When `package_linux.sh` runs with `makepkg` and not as root, it shall build `dist/Bodega-X.Y.Z-arch-x86_64.pkg.tar.zst`; otherwise, it shall warn and continue. |
| A3 | The pacman package shall install the same as the `.deb`: `/opt/bodega`, `/usr/bin/bodega` → `/opt/bodega/bodega-cli`, `bodega.desktop` with `Exec=/opt/bodega/bodega`, the 512 icon and the ntsync loading (`modules-load.d` and a `uaccess` udev rule). |
| A4 | The package shall depend on `gtk3`, `vulkan-icd-loader` and `libpulse`; it shall suggest `nvidia-utils`, `vulkan-radeon`, `vulkan-intel`, `gamemode` and `mangohud`. |
| A5 | `makepkg` shall not strip symbols (`!strip`): Wine and the Flutter bundle reach the disk as they were built. |
| A6 | If Vulkan is missing on a distro whose `ID` or `ID_LIKE` is `arch`, `checkHost` shall suggest `vulkan-icd-loader` plus the driver for each GPU vendor detected in `/sys/class/drm/card*/device/vendor` (`0x10de` → `nvidia-utils`, `0x1002` → `vulkan-radeon`, `0x8086` → `vulkan-intel`), without repeats. With no known GPU (a VM) it shall suggest `vulkan-swrast`. |
| A7 | `release-linux` shall build the pacman package in an `archlinux:base-devel` container from the `.tar.gz` of `build`, and `release` shall upload it along with the others. |

## Acceptance criteria

- `dart analyze && dart test` in `packages/engine` (A6, with a test for `archVulkanPackages`).
- `bash -n` on each script; the workflows are valid YAML.
- `package_linux.sh` and `build_arch.sh` on CachyOS: the `.pkg.tar.zst` exists; `pacman -Qlp` lists `/opt/bodega/bodega`, `/usr/bin/bodega`, the `.desktop`, the icon, the udev rule and the `modules-load.d`; `pacman -Qip` shows the dependencies from A4.
- Manual (the user runs it): `sudo pacman -U dist/Bodega-*-arch-x86_64.pkg.tar.zst`, open Bodega from the menu and see the bundled runtime; `bodega` in the terminal.
- Not verifiable here: the workflow's `arch` job (it only runs on GitHub).
