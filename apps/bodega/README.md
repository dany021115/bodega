# bodega

Windows games on Apple Silicon

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Linux

Bodega runs on Linux x86_64 with Ubuntu 24.04 or newer. On other distros, use the `.tar.gz`.

### Requirements

- x86_64 architecture.
- Vulkan with a real GPU.
- Audio through PulseAudio or PipeWire (`pipewire-pulse`).
- Ubuntu 24.04 or newer.

### Install

- `.deb`: `sudo apt install ./Bodega-<ver>-linux-amd64.deb`. It installs to `/opt/bodega` and adds the `bodega` command and a menu entry.
- `.tar.gz` (`Bodega-<ver>-linux-x86_64.tar.gz`): extract it and run `./bodega` from the extracted folder.
- AppImage: `chmod +x Bodega-<ver>-linux-x86_64.AppImage` and run it. If it fails because of FUSE, install `libfuse2t64` (Ubuntu 24.04) or run it with `--appimage-extract-and-run`.

### Data

Bottles, the runtime and the backend layers live in `~/.local/share/bodega` (or `$XDG_DATA_HOME/bodega`).

### Wine and backends

- The package ships Wine 11.21 staging WoW64 (Kron4ek). You do not need to install Wine.
- Backends: `wine` (no layers) and `dxvk`, which brings DXVK for D3D8 to D3D11 and vkd3d-proton for D3D12.

### CLI

```
bodega create prueba
bodega run prueba notepad
bodega backend list
bodega backend test prueba dxvk
bodega option prueba gpu discrete
bodega option prueba gamemode on
```

### Linux options

- HUD: `--hud` shows fps and frame times. If MangoHud is installed (`sudo apt install mangohud`), it uses MangoHud and saves a CSV in `<bottle>/logs/perf/` when the game closes. Otherwise it shows the DXVK HUD, with no log.
- Wine logs: on Linux they are `-all` by default, as in Proton. To debug, use `BODEGA_WINEDEBUG`, for example `BODEGA_WINEDEBUG=fixme-all`.
- High density: changes only Wine's `LogPixels`.
- GPU per bottle: `auto` or `discrete`. `discrete` uses the PRIME offload variables (NVIDIA and Mesa).
- GameMode: if `gamemoderun` is installed, it wraps the launch.

### Controllers

Wine uses the system's SDL2 for controllers and, without it, `udev`. Bodega does not configure anything in the bottle. `bodega pads` lists the controllers the kernel sees, whether your user can open them and whether SDL2 is missing, with the package for your distro.

If a controller does not show up in the game:

- Install the udev rules for controllers (`steam-devices`: on Ubuntu it comes from multiverse, and on Arch from multilib) and plug it in again.
- Install SDL2 (`libsdl2-2.0-0`, `SDL2` or `sdl2-compat`).

### ntsync

The bundled Wine has no esync or fsync variables, so there is no way to force them. Wine uses ntsync only if `/dev/ntsync` exists and your user can access it.

- `.deb`: already set up. It loads the module at boot and gives the user of the active session access, without `chmod`.
- `.tar.gz` and AppImage: do it once by hand:

```
echo ntsync | sudo tee /etc/modules-load.d/bodega-ntsync.conf
echo 'KERNEL=="ntsync", MODE="0660", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/70-bodega-ntsync.rules
sudo modprobe ntsync
sudo udevadm control --reload-rules
sudo udevadm trigger --sysname-match=ntsync
```

To check it, `ls -l /dev/ntsync` should show the device. With a game open, `sudo lsof /dev/ntsync` should show the wineserver. If your kernel does not ship the module, Wine works all the same, but slower.

### Not on Linux

These do not exist on Linux: DXMT, D3DMetal, DLSS and AVX. The app hides them.

### Building

`tool/package_linux.sh` is run from the repo root on Ubuntu 24.04. It leaves the `.deb`, `.tar.gz` and AppImage in `dist/`. For releases, use the `release-linux` workflow, which is run by hand with a `vX.Y.Z` tag. The tags are created by `tag-version` on push to main. A binary built on a newer Ubuntu does not run on 24.04.

### Licenses

Wine is LGPL. The notices and the reference to the source code come in the package's `LICENSES/` (see `LICENSES/NOTICE.md`).
