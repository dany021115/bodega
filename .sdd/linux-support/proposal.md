# Linux support (Ubuntu/Debian 24.04+)

Today Bodega runs only on macOS. This adds x86_64 Linux without changing anything on macOS.

## Scope

- A `HostPlatform` interface in the engine, with `MacPlatform` (today's code, moved as is) and `LinuxPlatform`.
- Wine staging WoW64 (Kron4ek), DXVK and vkd3d-proton ship inside the package. DXVK and vkd3d-proton form a single `dxvk` backend (D3D9 to D3D12).
- `.deb`, `.tar.gz` and AppImage packages, with `tool/package_linux.sh` and a workflow that is only started by hand (`workflow_dispatch`).
- Extras: HUD with `DXVK_HUD`, DPI with `LogPixels`, sync selector, per-bottle GPU, GameMode.
- The Wine user inherits the Linux user name.

Out: Gamescope, DLSS/NVAPI, aarch64, Flatpak/Snap, building Wine, an automatic `wineboot -u` after updating Wine, relabeling the catalog status.

Working rule for this delivery: the code is written, and nothing is tested (no tests, no `flutter build`, no Wine) until the user installs Flutter 3.47. Tests are written but not run.

## Requirements (EARS)

| ID | Requirement |
|---|---|
| R1 | The engine shall choose `MacPlatform` on darwin and `LinuxPlatform` on linux; on any other system it shall fail with "sistema no soportado" ("unsupported system"). |
| R2 | On macOS the engine shall behave as it does today (environment, tools, paths, backends, settings, Wine error messages). |
| R3 | On Linux the data root shall be `$XDG_DATA_HOME/bodega`, or `~/.local/share/bodega`. |
| R4 | When launching a Wine process on Linux, the environment shall inherit `DISPLAY`, `WAYLAND_DISPLAY`, `XAUTHORITY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, `LANG`, `LC_ALL`, `PULSE_SERVER`, `PULSE_COOKIE`, `XDG_SESSION_TYPE`, `VK_ICD_FILENAMES`, `VK_DRIVER_FILES` and `PATH` from the parent. It shall not carry Rosetta, MoltenVK or CrossOver variables. |
| R5 | When starting on Linux with a bundled runtime, the engine shall register it in `runtimes/<id>` (a link; a copy if `$APPIMAGE` exists) and make it `current` if there is no valid one. The same goes for the layers in `backends/`. |
| R6 | On Linux the backends shall be `wine` and `dxvk`. `dxmt`, `d3dmetal`, `sdl install` and `import d3dmetal` shall give a clear error. |
| R7 | When creating a bottle, or when launching if the bundled `dxvk` layer changed from the recorded one, the engine shall copy its DLLs to `system32` and `syswow64` and record it. |
| R8 | When a launch resolves to `dxvk`, the engine shall set the `n,b` overrides only in that process; per-exe exceptions keep working. |
| R9 | When looking for a file inside a prefix, the engine shall ignore letter case. On macOS the result is the same as today. |
| R10 | When checking the machine on Linux, the engine shall report whether x86_64, Vulkan or audio is missing, with the `apt`, `dnf` or `pacman` command depending on the distro. Setup is blocked until it is resolved. |
| R11 | The UI shall hide what the platform doesn't have (AVX, DLSS, D3DMetal, SDL, Retina) and offer the platform's sync modes. |
| R12 | On Linux the bundled Wine (11.21 staging) has no esync or fsync variables: it uses ntsync only if `/dev/ntsync` exists, with no way to force it through the environment. That is why `syncModes = ['none']`, `syncEnv` returns `{}` and the UI hides the selector when there is only one option. For ntsync, the user loads the module (`sudo modprobe ntsync`) and grants permissions on `/dev/ntsync`. |
| R13 | `--hud` shall set `DXVK_HUD` on Linux. The DPI setting shall change only `LogPixels`. |
| R14 | Each bottle shall have `gpu` (`auto` or `discrete`) and `gamemode`. `discrete` sets the offload variables. `gamemode`, if `gamemoderun` is installed, wraps the launch. |
| R15 | File pickers shall accept `.EXE`, `.MSI` and `.GZ` in uppercase. |
| R16 | The packages shall carry LGPL notices and the pointer to Wine's source code. |
| R17 | `tool/package_linux.sh` shall produce `.deb`, `.tar.gz` and AppImage. The workflow shall only have `workflow_dispatch`. |
| R18 | On Linux the Wine user shall be the session's user: `USER` and `LOGNAME` are always passed, with `id -un` as a fallback. |

## Acceptance criteria

Static (checked without the SDK):

- S1: `app/tool/check_layers.sh` passes.
- S2: outside `platform_mac.dart` and the tests, no `/usr/bin/`, `.dylib` or `Library/Application Support` remains in `packages/engine/lib`, except in the Mac-only functions (`rosettaInstalled`, `installSdl`, `x86Slice`, `importD3DMetal`) and the `_sdl` table.
- S3: `sha256sum -c` of what was downloaded, and `bash -n` of each script.
- S4: `assets.json` is valid JSON; the workflow is valid YAML and its only trigger is `workflow_dispatch`.
- S5: each of R1 to R18 is covered in the diff.

Manual (the user runs them with the SDK installed):

- M1: `dart analyze && dart test` in `packages/engine`; `flutter analyze && flutter test && tool/check_layers.sh` in `apps/bodega`.
- M2: `bodega create prueba` and `bodega run prueba notepad` open a window and play sound; `users/<your username>` exists in the prefix.
- M3: `bodega backend list` shows `wine` and `dxvk` as installed.
- M4: `bodega backend test prueba dxvk` gives OK on D3D11 (64 and 32 bits) and D3D12.
- M5: the three packages start and show the bundled runtime.
- M6: on macOS, `dart test` gives the same result as before.
