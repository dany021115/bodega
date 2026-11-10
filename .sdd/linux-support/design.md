# Design: Linux support

## Decisions

1. An abstract class `HostPlatform` in the engine. The new files are `part of 'engine.dart'`, like `apps.dart`, `backends.dart` and `catalog.dart`: that way `MacPlatform` and `LinuxPlatform` see the private members (`_layer`, `_installed`, `_overrides`...) and the diff is small.
2. A replaceable global: `HostPlatform hostPlatform = HostPlatform.detect();`. Tests swap it. The platform is not passed as a parameter.
3. The name `Platform` clashes with `dart:io`, hence `HostPlatform`.
4. Wine bundled with the same layout as today: `runtime/wine-<ver>/engine/{bin,lib,share}`. The rest of the engine doesn't change.
5. Backends on Linux: layers copied into the prefix (`system32`/`syswow64`), enabled per process with `WINEDLLOVERRIDES=...=n,b`. No Wine patch.
6. `LinuxPlatform.prepareHome` registers the bundled runtime and layers. `bodegaHome` calls it, so the CLI and the app are covered with no further changes.

## Interface (fixed signatures; T1, T3 and T6 share them)

```dart
typedef HostIssue = ({String title, String detail, String? command});
typedef HostCapabilities = ({
  bool highRes, bool avx, bool dlss, bool d3dmetal, bool sdl,
  bool gpu, bool gameMode, List<String> syncModes,
});

abstract class HostPlatform {
  static HostPlatform detect();            // darwin -> Mac, linux -> Linux, other: throw 'sistema no soportado: ...'
  String get displayName;                  // 'Mac' | 'Linux' (for UI text)
  String defaultHome(Map<String, String> env);
  void prepareHome(String home);           // Mac: nothing. Linux: registerBundled
  Map<String, String> baseEnv(Map<String, String> parent);
  List<String> get requiredFiles;
  String tool(String name);                // Mac: '/usr/bin/$name'. Linux: name
  (String, List<String>) get sha256Tool;   // Mac: ('/usr/bin/shasum', ['-a','256']). Linux: ('sha256sum', [])
  Future<void> afterExtract(String dir);   // Mac: xattr -dr com.apple.quarantine. Linux: nothing
  Future<List<HostIssue>> checkHost();
  HostCapabilities get capabilities;
  String get defaultSync;                  // Mac 'msync'. Linux 'none'
  Map<String, String> syncEnv(String mode);
  List<String> get backendNames;
  Map<String, ({String url, String sha256})> get pinnedBackends;
  ({String dir, String file}) get layerCheck;   // Mac ('x86_64-windows','x86_64-windows/d3d11.dll'). Linux ('x64','x64/d3d11.dll')
  Map<String, String> backendEnv(String home, String backend, {bool hud = false});
  Future<String> autoBackend(String home, String? exePath);
  String mapBackend(String name);          // Mac: identity. Linux: dxmt|d3dmetal -> dxvk
  List<(int, String)> probeCases(String home, String backend);
  Future<void> prepareBottle(String home, String name);   // Mac: _ensureGamepads. Linux: _ensureLayers
  List<List<String>> highResRegistry(bool value);          // [key, name, type, data]
  Map<String, String> gpuEnv(String gpu);
  List<String> launchWrapper({required bool gamemode});
}
```

New public top-level functions in `engine.dart`: `Future<List<HostIssue>> checkHost()`, `HostCapabilities hostCapabilities()`. `rosettaInstalled()` stays public.

## What moves where

| Today | Moves to |
|---|---|
| `bodegaHome`: path `~/Library/...` | `hostPlatform.defaultHome(env)`; at the end, `hostPlatform.prepareHome(home)` |
| `wineEnv`: list of keys, `PATH`, `WINEMSYNC`, `ROSETTA_ADVERTISE_AVX`, `DOTNET_...`, `MVK_...` | `baseEnv(parent)`; `wineEnv` adds `WINEPREFIX`, `WINEDLLOVERRIDES`, `WINEDEBUG`, `extra` |
| `requiredFiles` (const) | `hostPlatform.requiredFiles` (the top-level name stays, as a getter) |
| `/usr/bin/shasum`, `/usr/bin/tar`, `/usr/bin/curl`, `xattr` | `sha256Tool`, `tool('tar')`, `tool('curl')`, `afterExtract` |
| `rosettaInstalled()` in `bin/bodega.dart` | `checkHost()`; message `'${i.title}: ${i.command ?? i.detail}'` |
| `backendNames`, `_pinned`, `backendEnv`, `_autoBackend`, `d3d11.dll` check | platform members; the top-level functions delegate |
| `_defaults.sync = 'msync'`, `_checkSync` | `defaultSync`, `capabilities.syncModes` |
| `if (settings.sync == 'none') 'WINEMSYNC': '0'` | `...hostPlatform.syncEnv(settings.sync)` |
| `_ensureGamepads(...)` in `createBottle`, `runInBottle`, `openApp` | `hostPlatform.prepareBottle(...)` |
| `backendTest`: `cases` | `probeCases` |
| `setHighRes`: two hard-coded `reg add` calls | `highResRegistry(value)` |
| catalog: `entry.backend` | `mapBackend(entry.backend)` in `installEntry` |
| EAC hint "en Mac" ("on Mac") | `${hostPlatform.displayName}` |

`MacPlatform` returns exactly what there is today. Mac's `baseEnv`: `HOME USER LOGNAME TMPDIR __CF_USER_TEXT_ENCODING` from the parent + `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `WINEMSYNC=1`, `ROSETTA_ADVERTISE_AVX=1`, `DOTNET_EnableWriteXorExecute=0`, `MVK_CONFIG_LOG_LEVEL=2`.

## LinuxPlatform

- `defaultHome`: `$XDG_DATA_HOME/bodega` or `$HOME/.local/share/bodega`.
- `baseEnv`: from `parent` it passes `HOME TMPDIR LANG LC_ALL DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS PULSE_SERVER PULSE_COOKIE VK_ICD_FILENAMES VK_DRIVER_FILES PATH`. `USER` and `LOGNAME` always: `parent['USER'] ?? parent['LOGNAME'] ?? Process.runSync('id', ['-un']).stdout.trim()` (R18). If `PATH` is missing, `/usr/local/bin:/usr/bin:/bin:/usr/games`.
- `requiredFiles`: `engine/bin/wine`, `engine/bin/wineserver`, `engine/lib/wine/x86_64-unix/ntdll.so`, `engine/lib/wine/x86_64-windows/{kernel32,ntdll}.dll`, `engine/lib/wine/i386-windows/kernel32.dll`. No `.dylib`. (T2 confirms the tarball's real layout.)
- `capabilities`: `highRes true`, `avx false`, `dlss false`, `d3dmetal false`, `sdl false`, `gpu true`, `gameMode` = `gamemoderun` on the `PATH`, `syncModes` = `['none']`, `syncEnv` = `{}` always (see R12; T2 found no esync/fsync variables in Wine 11.21).
- `backendNames = ['wine','dxvk']`. `pinnedBackends` = `{}`: the `dxvk` layer combines DXVK and vkd3d-proton (two projects) and only comes bundled in the package. When packaging: `x64/` = DXVK `x64` + vkd3d-proton `x64`; `x32/` = DXVK `x32` + vkd3d-proton `x86` (the name changes).
- `backendEnv`: `dxvk` -> `WINEDLLOVERRIDES = '$_overrides;d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core,dxgi=n,b'`; `wine` -> `{}`; with `hud` it adds `DXVK_HUD=fps,frametimes`.
- `autoBackend`: `dxvk` if `_installed(home,'dxvk')`, otherwise `wine`.
- `probeCases`: `wine` -> `[(64,'11')]`; `dxvk` -> `[(64,'11'),(64,'12'),(32,'11')]`.
- `highResRegistry(value)`: only `HKCU\Control Panel\Desktop LogPixels REG_DWORD 192|96`.
- `gpuEnv('discrete')`: `DRI_PRIME=1`, `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only`. `auto` -> `{}`.
- `launchWrapper(gamemode: true)` -> `['gamemoderun']` if it is on the `PATH`; otherwise `[]`.
- `prepareBottle` -> `_ensureLayers`: if `_installed(home,'dxvk')` and the prefix is ready, it compares `prefix/.bodega-dxvk` with the contents of `$home/backends/dxvk/VERSION` (or with the resolved path if there is none). If they differ: it copies `x64/*.dll` to `drive_c/windows/system32` and `x32/*.dll` to `drive_c/windows/syswow64`, and writes the marker.
- `prepareHome` -> `registerBundled`: package root = `$BODEGA_BUNDLE`, or `dirname(Platform.resolvedExecutable)` if it has `runtime/`. For each `runtime/*` it creates `runtimes/<id>` (a link; `cp -a` if `$APPIMAGE`) and, if `runtimes/current` is missing or dangling, points it to the newest id. For each `backends/<name>` it creates `backends/<name>` the same way. A dangling link is deleted and recreated.
- `checkHost`: architecture (`uname -m` == `x86_64`), Vulkan (`ldconfig -p` with `libvulkan.so.1`, and some `*.json` in `/usr/share/vulkan/icd.d` or `/etc/vulkan/icd.d`), audio (`libpulse.so.0` in `ldconfig -p`). The command comes from `/etc/os-release` (`ID`/`ID_LIKE`): debian/ubuntu `sudo apt install ...`, fedora `sudo dnf install ...`, arch `sudo pacman -S ...`.

## Letter case (R9)

`String findCI(String root, String relative)` in `engine.dart`: if `root/relative` exists, it returns it as is (on Mac that is always the case). If not, it walks each segment, listing the directory and comparing in lowercase, without following symlinks. If it finds nothing, it returns the original path. It is a drop-in replacement: `File(findCI(drive, exe))`.

## New per-bottle settings

`BottleSettings` gains `String gpu` (`'auto'` | `'discrete'`, `auto` by default) and `bool gamemode` (`false` by default). They are only saved if they differ from the default. `setBottleOptions(home, name, {dlss, avx, gpu, gamemode, env})`.

## App

- `domain/entities/runtime_status.dart`: `RuntimeStatus({required List<HostIssue> issues, required bool runtime, required HostCapabilities capabilities})`, with `HostIssue` and `HostCapabilities` as the domain's own freezed entities (they don't import the engine).
- `RuntimeRepositoryImpl.status()` fills them from `checkHost()` and `hostCapabilities()`.
- `SetupState`: `issues`, `capabilities`; `isReady => issues.isEmpty && runtime`.
- `RosettaCard` becomes `RequirementCard`, which renders each `HostIssue` (title, detail, copyable command).
- The UI reads `SetupBloc.state.capabilities` to hide options and for the sync list.
- `BottleDetail` gains `gpu` and `gamemode`; `BottleRepository.setOptions(name, {dlss, avx, gpu, gamemode})`.
- Generic texts: "HUD de rendimiento" ("Performance HUD"), "Pantalla de alta densidad" ("High-density display").
- The `XTypeGroup`s add the uppercase extensions.
- `apps/bodega/linux/` is generated with `flutter create --platforms=linux --no-pub .` (Flutter 3.44.9 template).

## Package

```
/opt/bodega/                    (also the root of the tar.gz and of the AppImage)
  bodega                        Flutter app
  lib/ data/                    Flutter bundle
  bodega-cli                    CLI
  runtime/wine-<ver>/engine/    Wine
  backends/dxvk/{VERSION,wine/{x64,x32}}
  LICENSES/                     LGPL notices, pointer to the source code
/usr/bin/bodega -> /opt/bodega/bodega-cli      (.deb)
/usr/share/applications/bodega.desktop         (.deb)
```

## Performance (Proton as the reference)

Proton forces `WINEDEBUG=-all`, `DXVK_LOG_LEVEL=none`, `VKD3D_DEBUG=none` and `VKD3D_SHADER_DEBUG=none` by default. Linux copies those values: `defaultWineDebug` is `-all` (`BODEGA_WINEDEBUG` still wins) and `baseEnv` adds the three `none` values. macOS keeps `fixme-all`.

The HUD uses MangoHud if it is installed (`MANGOHUD=1`, with a `MANGOHUD_CONFIG` that turns on `autostart_log=1` and `output_folder=<bottle>/logs/perf`). Without MangoHud, DXVK's own `DXVK_HUD` remains, with no logging.

What can't be copied from Proton with the bundled Wine:

- esync and fsync: Kron4ek's staging 11.21 Wine doesn't have those variables.
- ntsync: it only works if `/dev/ntsync` exists.
- Proton uses classic 32-bit Wine. Bodega uses WoW64.
