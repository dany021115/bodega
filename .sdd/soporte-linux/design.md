# Diseño: soporte Linux

## Decisiones

1. Una clase abstracta `HostPlatform` en el motor. Los archivos nuevos son `part of 'engine.dart'`, como `apps.dart`, `backends.dart` y `catalog.dart`: así `MacPlatform` y `LinuxPlatform` ven los miembros privados (`_layer`, `_installed`, `_overrides`...) y el diff es pequeño.
2. Un global sustituible: `HostPlatform hostPlatform = HostPlatform.detect();`. Las pruebas lo cambian. No se pasa la plataforma por parámetro.
3. El nombre `Platform` choca con `dart:io`, por eso `HostPlatform`.
4. Wine incluido con la misma estructura que hoy: `runtime/wine-<ver>/engine/{bin,lib,share}`. El resto del motor no cambia.
5. Backends en Linux: capas copiadas al prefijo (`system32`/`syswow64`), activadas por proceso con `WINEDLLOVERRIDES=...=n,b`. Sin parche de Wine.
6. `LinuxPlatform.prepareHome` registra el runtime y las capas incluidas. Lo llama `bodegaHome`, así la CLI y la app lo cubren sin más cambios.

## Interfaz (firmas fijas; T1, T3 y T6 las comparten)

```dart
typedef HostIssue = ({String title, String detail, String? command});
typedef HostCapabilities = ({
  bool highRes, bool avx, bool dlss, bool d3dmetal, bool sdl,
  bool gpu, bool gameMode, List<String> syncModes,
});

abstract class HostPlatform {
  static HostPlatform detect();            // darwin -> Mac, linux -> Linux, otro: throw 'sistema no soportado: ...'
  String get displayName;                  // 'Mac' | 'Linux' (para textos)
  String defaultHome(Map<String, String> env);
  void prepareHome(String home);           // Mac: nada. Linux: registerBundled
  Map<String, String> baseEnv(Map<String, String> parent);
  List<String> get requiredFiles;
  String tool(String name);                // Mac: '/usr/bin/$name'. Linux: name
  (String, List<String>) get sha256Tool;   // Mac: ('/usr/bin/shasum', ['-a','256']). Linux: ('sha256sum', [])
  Future<void> afterExtract(String dir);   // Mac: xattr -dr com.apple.quarantine. Linux: nada
  Future<List<HostIssue>> checkHost();
  HostCapabilities get capabilities;
  String get defaultSync;                  // Mac 'msync'. Linux 'none'
  Map<String, String> syncEnv(String mode);
  List<String> get backendNames;
  Map<String, ({String url, String sha256})> get pinnedBackends;
  ({String dir, String file}) get layerCheck;   // Mac ('x86_64-windows','x86_64-windows/d3d11.dll'). Linux ('x64','x64/d3d11.dll')
  Map<String, String> backendEnv(String home, String backend, {bool hud = false});
  Future<String> autoBackend(String home, String? exePath);
  String mapBackend(String name);          // Mac: identidad. Linux: dxmt|d3dmetal -> dxvk
  List<(int, String)> probeCases(String home, String backend);
  Future<void> prepareBottle(String home, String name);   // Mac: _ensureGamepads. Linux: _ensureLayers
  List<List<String>> highResRegistry(bool value);          // [key, name, type, data]
  Map<String, String> gpuEnv(String gpu);
  List<String> launchWrapper({required bool gamemode});
}
```

Top-level públicos nuevos en `engine.dart`: `Future<List<HostIssue>> checkHost()`, `HostCapabilities hostCapabilities()`. `rosettaInstalled()` se queda público.

## Qué sale de dónde

| Hoy | Pasa a |
|---|---|
| `bodegaHome`: ruta `~/Library/...` | `hostPlatform.defaultHome(env)`; al final `hostPlatform.prepareHome(home)` |
| `wineEnv`: lista de claves, `PATH`, `WINEMSYNC`, `ROSETTA_ADVERTISE_AVX`, `DOTNET_...`, `MVK_...` | `baseEnv(parent)`; `wineEnv` añade `WINEPREFIX`, `WINEDLLOVERRIDES`, `WINEDEBUG`, `extra` |
| `requiredFiles` (const) | `hostPlatform.requiredFiles` (nombre top-level se mantiene como getter) |
| `/usr/bin/shasum`, `/usr/bin/tar`, `/usr/bin/curl`, `xattr` | `sha256Tool`, `tool('tar')`, `tool('curl')`, `afterExtract` |
| `rosettaInstalled()` en `bin/bodega.dart` | `checkHost()`; mensaje `'${i.title}: ${i.command ?? i.detail}'` |
| `backendNames`, `_pinned`, `backendEnv`, `_autoBackend`, `d3d11.dll` check | miembros de la plataforma; las funciones top-level delegan |
| `_defaults.sync = 'msync'`, `_checkSync` | `defaultSync`, `capabilities.syncModes` |
| `if (settings.sync == 'none') 'WINEMSYNC': '0'` | `...hostPlatform.syncEnv(settings.sync)` |
| `_ensureGamepads(...)` en `createBottle`, `runInBottle`, `openApp` | `hostPlatform.prepareBottle(...)` |
| `backendTest`: `cases` | `probeCases` |
| `setHighRes`: dos `reg add` fijos | `highResRegistry(value)` |
| catálogo: `entry.backend` | `mapBackend(entry.backend)` en `installEntry` |
| pista de EAC "en Mac" | `${hostPlatform.displayName}` |

`MacPlatform` devuelve exactamente lo de hoy. `baseEnv` de Mac: `HOME USER LOGNAME TMPDIR __CF_USER_TEXT_ENCODING` del padre + `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `WINEMSYNC=1`, `ROSETTA_ADVERTISE_AVX=1`, `DOTNET_EnableWriteXorExecute=0`, `MVK_CONFIG_LOG_LEVEL=2`.

## LinuxPlatform

- `defaultHome`: `$XDG_DATA_HOME/bodega` o `$HOME/.local/share/bodega`.
- `baseEnv`: de `parent` pasa `HOME TMPDIR LANG LC_ALL DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS PULSE_SERVER PULSE_COOKIE VK_ICD_FILENAMES VK_DRIVER_FILES PATH`. `USER` y `LOGNAME` siempre: `parent['USER'] ?? parent['LOGNAME'] ?? Process.runSync('id', ['-un']).stdout.trim()` (R18). Si falta `PATH`, `/usr/local/bin:/usr/bin:/bin:/usr/games`.
- `requiredFiles`: `engine/bin/wine`, `engine/bin/wineserver`, `engine/lib/wine/x86_64-unix/ntdll.so`, `engine/lib/wine/x86_64-windows/{kernel32,ntdll}.dll`, `engine/lib/wine/i386-windows/kernel32.dll`. Sin `.dylib`. (T2 confirma la estructura real del tarball.)
- `capabilities`: `highRes true`, `avx false`, `dlss false`, `d3dmetal false`, `sdl false`, `gpu true`, `gameMode` = `gamemoderun` en el `PATH`, `syncModes` = `['none']`, `syncEnv` = `{}` siempre (ver R12; T2 no halló variables de esync/fsync en Wine 11.21).
- `backendNames = ['wine','dxvk']`. `pinnedBackends` = `{}`: la capa `dxvk` mezcla DXVK y vkd3d-proton (dos proyectos) y solo viene incluida en el paquete. Al empaquetar: `x64/` = DXVK `x64` + vkd3d-proton `x64`; `x32/` = DXVK `x32` + vkd3d-proton `x86` (el nombre cambia).
- `backendEnv`: `dxvk` -> `WINEDLLOVERRIDES = '$_overrides;d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core,dxgi=n,b'`; `wine` -> `{}`; con `hud` añade `DXVK_HUD=fps,frametimes`.
- `autoBackend`: `dxvk` si `_installed(home,'dxvk')`, si no `wine`.
- `probeCases`: `wine` -> `[(64,'11')]`; `dxvk` -> `[(64,'11'),(64,'12'),(32,'11')]`.
- `highResRegistry(value)`: solo `HKCU\Control Panel\Desktop LogPixels REG_DWORD 192|96`.
- `gpuEnv('discrete')`: `DRI_PRIME=1`, `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only`. `auto` -> `{}`.
- `launchWrapper(gamemode: true)` -> `['gamemoderun']` si está en el `PATH`; si no `[]`.
- `prepareBottle` -> `_ensureLayers`: si `_installed(home,'dxvk')` y el prefijo está listo, compara `prefix/.bodega-dxvk` con el contenido de `$home/backends/dxvk/VERSION` (o la ruta resuelta si no hay). Si difiere: copia `x64/*.dll` a `drive_c/windows/system32` y `x32/*.dll` a `drive_c/windows/syswow64`, y escribe la marca.
- `prepareHome` -> `registerBundled`: raíz del paquete = `$BODEGA_BUNDLE` o `dirname(Platform.resolvedExecutable)` si tiene `runtime/`. Para cada `runtime/*` crea `runtimes/<id>` (enlace; `cp -a` si `$APPIMAGE`) y, si `runtimes/current` falta o está colgado, lo apunta al id más nuevo. Para cada `backends/<name>` crea `backends/<name>` igual. Un enlace colgado se borra y se rehace.
- `checkHost`: arquitectura (`uname -m` == `x86_64`), Vulkan (`ldconfig -p` con `libvulkan.so.1` y algún `*.json` en `/usr/share/vulkan/icd.d` o `/etc/vulkan/icd.d`), audio (`libpulse.so.0` en `ldconfig -p`). El comando sale de `/etc/os-release` (`ID`/`ID_LIKE`): debian/ubuntu `sudo apt install ...`, fedora `sudo dnf install ...`, arch `sudo pacman -S ...`.

## Mayúsculas (R9)

`String findCI(String root, String relative)` en `engine.dart`: si `root/relative` existe, la devuelve tal cual (en Mac siempre ocurre así). Si no, recorre cada segmento listando el directorio y comparando en minúsculas, sin seguir enlaces simbólicos. Si no encuentra nada, devuelve la ruta original. Es un reemplazo directo: `File(findCI(drive, exe))`.

## Ajustes nuevos por botella

`BottleSettings` gana `String gpu` (`'auto'` | `'discrete'`, por defecto `auto`) y `bool gamemode` (por defecto `false`). Se guardan solo si difieren. `setBottleOptions(home, name, {dlss, avx, gpu, gamemode, env})`.

## App

- `domain/entities/runtime_status.dart`: `RuntimeStatus({required List<HostIssue> issues, required bool runtime, required HostCapabilities capabilities})`, con `HostIssue` y `HostCapabilities` como entidades freezed propias del dominio (no importan el motor).
- `RuntimeRepositoryImpl.status()` las llena desde `checkHost()` y `hostCapabilities()`.
- `SetupState`: `issues`, `capabilities`; `isReady => issues.isEmpty && runtime`.
- `RosettaCard` pasa a `RequirementCard`, que pinta cada `HostIssue` (título, detalle, comando copiable).
- La UI lee `SetupBloc.state.capabilities` para ocultar opciones y para la lista de sync.
- `BottleDetail` gana `gpu` y `gamemode`; `BottleRepository.setOptions(name, {dlss, avx, gpu, gamemode})`.
- Textos genéricos: "HUD de rendimiento", "Pantalla de alta densidad".
- Los `XTypeGroup` añaden las extensiones en mayúscula.
- `apps/bodega/linux/` se genera con `flutter create --platforms=linux --no-pub .` (plantilla de Flutter 3.44.9).

## Paquete

```
/opt/bodega/                    (también la raíz del tar.gz y del AppImage)
  bodega                        app Flutter
  lib/ data/                    bundle de Flutter
  bodega-cli                    CLI
  runtime/wine-<ver>/engine/    Wine
  backends/dxvk/{VERSION,wine/{x64,x32}}
  LICENSES/                     avisos LGPL, referencia al código fuente
/usr/bin/bodega -> /opt/bodega/bodega-cli      (.deb)
/usr/share/applications/bodega.desktop         (.deb)
```

## Rendimiento (referencia Proton)

Proton fuerza por defecto `WINEDEBUG=-all`, `DXVK_LOG_LEVEL=none`, `VKD3D_DEBUG=none` y `VKD3D_SHADER_DEBUG=none`. Linux copia esos valores: `defaultWineDebug` es `-all` (`BODEGA_WINEDEBUG` sigue ganando) y `baseEnv` añade los tres `none`. macOS mantiene `fixme-all`.

El HUD usa MangoHud si está instalado (`MANGOHUD=1`, con `MANGOHUD_CONFIG` que activa `autostart_log=1` y `output_folder=<botella>/logs/perf`). Sin MangoHud queda el `DXVK_HUD` de DXVK, sin registro.

No se puede copiar de Proton con el Wine incluido:

- esync y fsync: el Wine de Kron4ek staging 11.21 no tiene esas variables.
- ntsync: solo funciona si existe `/dev/ntsync`.
- Proton usa Wine de 32 bits clásico. Bodega usa WoW64.
