# Exploración: prototipo-motor

Fase **explore** del SDD · 2026-10-30 · ningún cambio de código · estado: pendiente de aprobación para pasar a `propose`. Cuando algo dice "sin verificar" o "leído", significa que no se comprobó ejecutándolo.

**Leyenda.** Las anclas `#Lx-Ly` apuntan a líneas del commit fijado.

| Alias | Ruta | Nota |
|---|---|---|
| `CX` | `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad/research/src/cx-26.3/sources/wine` | Wine de CrossOver 26.3. Es volátil; se rehace con `BE/inputs.json:4-6` |
| `SP` | `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad` | Experimentos Dart en `SP/dartplat/exp/`, log upstream en `SP/hblog-1793389283/`, copias de Highball, Whisky y Mythic en `SP/ops5/` |
| `BE` | `/Users/quasar/Documents/GitHub/Bodega/bodega-engine` | |
| `INV` | `/Users/quasar/Documents/investigacion-launcher` | |
| `HB` | `https://github.com/gauthierpiarrette/highball/blob/aac8cdc4630ca35ad1f79acf9db5bbc1b5e760fc` | `HBK` = `HB/Sources/HighballKit` |
| `WH` | `https://github.com/Whisky-App/Whisky/blob/fd5480a76b3ebfe3419a1ab86ca3695f5cc328f8/WhiskyKit/Sources/WhiskyKit` | |
| `MY` | `https://github.com/MythicApp/Mythic/blob/754223978e61fb6efcff1e3152ae426bad0020b7/Mythic/Utilities` | |
| `DSDK` | `/opt/homebrew/share/flutter/bin/cache/dart-sdk` | Dart 3.13.0 |
| `DVM` | `https://github.com/dart-lang/sdk/blob/3.13.0/runtime/bin` | |
| `RT` | `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine-wine-11.0-20261030T202616Z-primer-build.tar.gz` | Primer runtime. Solo se listó con `tar -tvzf`; no se extrajo |

## 1. Problema y alcance

Es el primer entregable de la fase F0 (`INV/INFORME-FINAL.md:720`): un paquete Dart puro, `engine`, más un CLI compilado con `dart compile exe`. Tiene que hacer cinco cosas:

1. Instalar y localizar el runtime de `bodega-engine`.
2. Crear una botella win64.
3. Lanzar un `.exe` con el entorno correcto.
4. Escribir un log por cada ejecución.
5. Esperar al wineserver de la botella o matarlo.

Queda fuera del alcance:
- la UI Flutter;
- la gamedb (`INV/INFORME-FINAL.md:423-535`);
- DXMT por juego (`:270-279`);
- las tiendas (`:352-421`);
- arm64 (`:723`).

**Punto de partida**
- El repo `bodega` está vacío: rama `master`, sin commits. Lo que hay que conocer son tres piezas existentes: el contrato que genera `BE/.github/workflows/build.yml`, el árbol `CX` y `dart:io`.
- El run 41110607147 terminó bien el 2026-10-30, y `RT` ya está descargado: 334 861 341 B, el mismo tamaño que el asset publicado. `shasum -a 256 -c` da OK.

## 2. Contrato del runtime

### 2.1 Tarball y binarios

- **Empaquetado.** `engine-<versión>-<UTC>-<nota>.tar.gz` más su `.sha256`, publicados en una release privada cuyo tag es ese nombre (`BE/.github/workflows/build.yml:117-119,134-136`; `/Users/quasar/Documents/GitHub/Bodega/crear-repo.sh:9`). Ocupa 1065 MB descomprimido (`SP/hblog-1793389283/log.tail:2505`).
- **Contenido de `RT`.** 5243 entradas, todas con prefijo `./`: `engine/{bin,lib,share}` y tres carpetas vacías (`renderers/`, `frameworks/`, `tools/`). No hay `manifest.json`, ningún `.dylib` ni `i386-unix` (`build.yml:78-79,118`). Conserva los permisos de ejecución; el mtime de `wine.inf` es la hora del build.
- **Binarios.** `bin/` solo tiene `wine` y `wineserver` (`build.yml:74`). `bin/wine` hace `execv` al loader real, `lib/wine/x86_64-unix/wine`, sin cambiar de PID (`CX/dlls/ntdll/unix/loader.c:2523-2547`). No hay `wine64`, `wine-preloader` ni `bin/wineboot` (`CX/configure.ac:948-959,2105`), así que los helpers se lanzan como `bin/wine wineboot`.
- **DLL.**
  - Viene el `d3d11/dxgi/d3d10core` de Wine. De DXMT v0.80 solo trae el placeholder `winemetal.dll`, sin `winemetal.so` (`build.yml:96-106`), así que sin overlay DX10/11 va por wined3d.
  - Mono 10.4.1 y Gecko 2.47.4 están en `share/wine` (`build.yml:85-95`).
- **Faltan las bibliotecas del host.**
  - FreeType, GnuTLS, SDL2 y MoltenVK se cargan por nombre corto (`SP/hblog-1793389283/log.part:966-988`; `CX/aclocal.m4:61-72`), y `winedmo.so` enlaza el FFmpeg de Homebrew Intel (`CX/dlls/winedmo/Makefile.in:6`).
  - En este Mac `/usr/local/lib` solo tiene `libmetalirconverter.dylib`, así que faltan fuentes (`CX/dlls/win32u/freetype.c:1483-1486`), TLS, SDL y Vulkan.
  - MoltenVK no es imprescindible: ni DXMT ni wined3d lo necesitan, porque con el parche 0002 wined3d prueba OpenGL primero. Sin MoltenVK solo aparece un `err:` (`CX/dlls/win32u/vulkan.c:3005-3016`; `BE/patches/0002-wined3d-auto-renderer-opengl-first.patch:1-30`).
- **Salud.**
  - `bin/wine --version` imprime `wine-11.0` sin prefijo (`CX/dlls/ntdll/unix/loader.c:2555-2604`).
  - Los 6 archivos mínimos están en `RT` (`HBK/EngineStore.swift#L637-L646`): `bin/{wine,wineserver}`, `x86_64-windows/{kernel32,ntdll}.dll`, `i386-windows/kernel32.dll` y `x86_64-unix/ntdll.so`.
  - errno 86 significa que falta Rosetta (`HBK/WineRunner.swift#L236-L246`). Para comprobarlo antes: `/usr/bin/arch -x86_64 /usr/bin/true`, que aquí devuelve 0.
  - Es reubicable: las rutas salen de `realpath(ntdll.so)` (`CX/dlls/ntdll/unix/loader.c:475-499`).

### 2.2 Entorno mínimo

| Variable | Regla | Ref |
|---|---|---|
| `WINEPREFIX` | La única obligatoria. Tiene que ser una ruta absoluta; si no, es un error fatal | `CX/dlls/ntdll/unix/loader.c:462-463` |
| `WINEMSYNC` (`0` o `1`) | Siempre explícita y con el mismo valor en toda la botella. Sin definir equivale a apagada | `CX/dlls/ntdll/unix/msync.c:417-424` |
| `WINEDEBUG=fixme-all` | Las líneas `err:` siguen saliendo | `HBK/Bottle.swift#L756` |
| `WINEDLLOVERRIDES=winemenubuilder.exe=d` | Evita que aparezcan accesos directos en el Escritorio | `HBK/Bottle.swift#L812-L821` |
| `ROSETTA_ADVERTISE_AVX=1` | Para apagarla hay que quitarla | `INV/06-apple-silicon-platform.md:31` |
| `DOTNET_EnableWriteXorExecute=0` | La pone CrossOver para .NET | `/Users/quasar/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine:697` |
| `WINEDLLPATH_PREPEND=<dir>` | Solo para el overlay de DXMT (parche 0003) | `BE/patches/0003-ntdll-winedllpath-prepend.patch:1-37` |

Lo que sobra:
- `WINELOADER` y `WINESERVER`.
- `WINEDLLPATH`: se busca después del motor y crea hard links en `$TMPDIR` (`CX/dlls/ntdll/unix/loader.c:387-404,676-686`).
- `WINEARCH`: con `win32`, vacío o un valor inválido es un error fatal (`CX/dlls/ntdll/unix/server.c:1615-1620`).
- `CX_ALT_LOADER_SOCKET` (`CX/dlls/ntdll/unix/process.c:333-338`).
- `DYLD_*`, si las bibliotecas van junto a los módulos (ver §7).

### 2.3 Ciclo de vida de la botella

- **Crear.**
  - El primer proceso que arranca con un `WINEPREFIX` nuevo crea el prefijo. Solo hace `mkdir` del último componente, así que el padre tiene que existir (`CX/dlls/ntdll/unix/server.c:1322-1356`).
  - En cada sesión ese primer proceso lanza `wineboot.exe --init` y espera hasta 5 min (`CX/dlls/ntdll/unix/env.c:1543-1609`).
  - Highball usa `wine wineboot -u` y avisa de que tarda unos 90 s (`HBK/WineRunner.swift#L530-L535`; `HB/Sources/highball/main.swift#L110`). En el M2 Pro está sin medir.
- **Lista.**
  - Hacen falta dos cosas: exit 0 y que exista `drive_c/windows/syswow64/kernel32.dll` (`HBK/BottleStore.swift#L221-L276`).
  - Después hay que llamar a `wineserver -w`, porque el registro se guarda cada 30 s y al salir (`CX/server/registry.c:125`; `CX/server/request.c:906-915`).
  - Queda con Windows 10 y `C:\users\<$USER>` (`CX/dlls/ntdll/version.c:493-509`; `BE/patches/0001-use-the-real-user-name.patch:1-8`). Ocupa unos 304 MB (medido en CrossOver).
- **Lanzar.**
  - `bin/wine <ruta Unix> [args]` conserva el PID (`CX/dlls/ntdll/unix/loader.c:686-713`), así que `exitCode` es el código Windows truncado a 8 bits: 1638 llega como 102 (`HBK/WineRunner.swift#L46-L57`).
  - El cwd lo pone el lanzador; Highball usa la carpeta del exe (`HBK/WineRunner.swift#L436-L441`).
  - Con el parche 0012, un programa de 32 bits es un solo proceso (`BE/patches/0012-ntdll-x87sidecar-cooperative-attach.patch:17-26`).
- **Servidor.**
  - Hay uno por botella (`CX/dlls/ntdll/unix/server.c:1303-1314`) y sale 3 s después del último cliente (`CX/server/main.c:48`).
  - `-w` espera y devuelve 0; si no hay servidor, vuelve al instante.
  - `-k` mata la botella entera: SIGINT, unos 10,5 s de espera y luego SIGKILL. Devuelve 1 si no había servidor (`CX/server/main.c:86-103`; `CX/server/request.c:697-756`).
  - Ninguno de los dos necesita `WINEMSYNC`, pero sí el mismo `WINEPREFIX` absoluto (`CX/server/request.c:599-627`).
- **Sesión.** El primer proceso fija el modo msync (un proceso con el modo contrario sale con 1, `CX/dlls/ntdll/unix/msync.c:587-601`) y el entorno de los servicios (`HBK/WineRunner.swift#L381-L395`).

### 2.4 Logs

- La depuración sale por el fd 2, con `err` y `fixme` activados por defecto. Si stderr va a `/dev/null`, no se escribe nada (`CX/dlls/ntdll/unix/debug.c:199-211`).
- El wineserver se queda con el stderr del proceso que lo arrancó (`CX/server/request.c:869-871`). Por eso:
  - ese log recibe también la salida del servidor y de los servicios;
  - una tubería no ve EOF hasta que el servidor sale.
- SIGPIPE se ignora (`CX/dlls/ntdll/unix/server.c:1659-1663`).
- Marcadores útiles: `err:module:import_dll` (`CX/dlls/ntdll/loader.c:1195`) y `wine: failed to start` (`CX/dlls/ntdll/unix/env.c:2112`).
- Para saber si DXMT está activo, `DXMT_LOG_PATH` (`SP/dl_dxmt/main/src_util_log_log.cpp:95-128`).

## 3. Cómo lo hacen otros

| Operación | Highball (GPL) | Whisky / Mythic | Receta mínima |
|---|---|---|---|
| Instalar | SHA-256, `/usr/bin/tar` a una carpeta temporal, comprobación de los 6 archivos, renombrado y quitar la cuarentena (`HBK/EngineStore.swift#L286-L348`, `#L586-L588`) | No verifican nada y tienen `wine64` fijo en el código (`WH/Wine/Wine.swift#L23-L28`). El SHA-256 de Mythic es un TODO (`MY/Engine/Engine.swift#L37-L50`) | `shasum -c` → `tar -xzf` → 6 archivos → `rename` → `xattr -dr` |
| Crear | Valida el nombre, corre `wineboot -u` sin overlay, borra la botella si falla y repara `syswow64` (`HBK/BottleStore.swift#L73-L149`, `#L221-L276`) | Whisky no mira el exit (`https://github.com/Whisky-App/Whisky/blob/fd5480a76b3ebfe3419a1ab86ca3695f5cc328f8/Whisky/View%20Models/BottleVM.swift#L40-L77`). Mythic busca una línea que aquí es TRACE (`MY/Wine/WineInterface.swift#L140-L216`; `CX/programs/wineboot/wineboot.c:1748`) | `mkdir -p` → JSON → `wineboot` → exit 0 + `syswow64` → `-w` |
| Lanzar | `wine <exe>` directo, con cwd en la carpeta del exe (`HBK/WineRunner.swift#L326-L379`; entorno: `HBK/Bottle.swift#L752-L829`) | Whisky usa `start /unix` sin `/wait` (`WH/Wine/Wine.swift#L99-L112`). Mythic no fija el cwd (`MY/GameManager/LocalGameManager.swift#L81-L100`) | `Process.start(bin/wine, [exe, ...args], workingDirectory: …)` |
| Log | Un archivo por ejecución, cabecera con lista blanca de datos, tope de 256 MB y pie `# exit=N` (`HBK/WineRunner.swift#L103-L163`, `#L229-L311`; `HBK/LogFilter.swift#L3-L56`) | Whisky vuelca todo el entorno (`WH/Wine/Wine.swift#L270-L283`). Mythic escribe en OSLog | Pie en cuanto llega `exitCode`, sin esperar EOF |
| Parar | `-k`, luego `-w` con tope de 10 s, luego reaper (`HBK/WineRunner.swift#L581-L599`) | Whisky no espera (`WH/Wine/Wine.swift#L211-L215`). Mythic reutiliza el `Process` (`MY/Wine/WineInterface.swift#L252-L267`) | `-k` (exit 1 = ya estaba parado) y luego `-w` con timeout |

Highball guarda un `bottle.json` versionado (`HBK/Bottle.swift#L379-L480`); en Dart basta con `dart:convert`. Todo se puede portar con la biblioteca estándar, salvo el reaper, que necesita FFI o `ps`.

## 4. Plataforma Dart (3.13.0)

**Entorno del proceso hijo**
- El mapa que se pasa tiene prioridad sobre el entorno heredado. La única forma de quitar una variable heredada es `includeParentEnvironment: false` (`DSDK/lib/io/process.dart:318-320`).
- Si falta `HOME`, Wine recurre a `getpwuid` (`CX/dlls/ntdll/unix/loader.c:432-452`).
- El UTF-8 funciona; se probó con `Caña` (`DVM/process.cc#L23-L58`).

**Modos de arranque**
- En `normal` e `inheritStdio` el hijo comparte sesión y grupo con el padre (`DVM/process_macos.cc#L487-L546`; `INV/10-app-stack.verify.md:21`).
- `detached` hace `setsid` y redirige el stdio a `/dev/null` (`DVM/process_macos.cc#L448-L546`).

**`Process.run` no sirve**
- Espera a EOF (`DSDK/lib/_internal/vm/bin/process_patch.dart:649`), así que con Wine se cuelga.
- En la prueba con un daemon equivalente, `exitCode` llegó a los 23 ms y `run` a los ~3 s (`SP/dartplat/exp/daemon_pipe.dart`).
- Lo correcto es `Process.start` seguido de `await exitCode`.

**Modo adjunto**
- La VM sigue viva mientras el hijo viva (`DSDK/lib/io/process.dart:350-356`).
- Ctrl-C y SIGHUP le llegan al juego, y Wine no gestiona SIGHUP (`CX/dlls/ntdll/unix/signal_x86_64.c:3023-3040`; leído).
- Llamar a `IOSink.add` después de cerrarlo lanza `StateError` (`DSDK/lib/io/io_sink.dart:151-153`). Por eso el sink pertenece al listener, y el pie se escribe con `FileMode.append`.

**Modo desacoplado**
- No se pueden pasar descriptores al hijo, así que para que el log lo escriba el kernel hace falta un shell. Verificado con un pie `# exit=7` (`SP/dartplat/exp/detached_footer.dart:4-7`):
  ```dart
  Process.start('/bin/sh', ['-c', r'"$@" >>"$BODEGA_LOG" 2>&1 </dev/null; echo "# exit=$?" >>"$BODEGA_LOG"',
      'bodega-run', wine, ...args], environment: {...env, 'BODEGA_LOG': log}, mode: ProcessStartMode.detached);
  ```
- En este modo no hay `exitCode`, y `kill()` puede alcanzar un pid reutilizado (`process_patch.dart:564-579`).
- Para comandos cortos basta con `inheritStdio` y `exec "$@" >>log 2>&1`: el exit llegó a los 28 ms (`SP/dartplat/exp/inherit_log.dart:7-10`).
- `/bin/sh` está protegido por SIP, que borra las variables `DYLD_*` (`HBK/EngineStore.swift#L523-L531`).

**Señales, Rosetta y compilación**
- `kill` actúa sobre un solo pid; matar por grupo es peligroso (`INV/10-app-stack.verify.md:69`).
- Rosetta es transparente (`SP/dartplat/exp/rosetta_test.dart`).
- `dart compile exe` genera un binario arm64 de 5,76 MB con firma ad hoc. Con hardened runtime necesita `cs.allow-unsigned-executable-memory` (`INV/10-app-stack.verify.md:55-61`).

**Archivos y dependencias**
- El SDK no tiene chmod ni SHA-256. Se usan dos herramientas del sistema:
  - `/usr/bin/tar -xzf`, que conserva permisos y mtimes, y también la cuarentena (`/usr/share/man/man1/tar.1:325-330`);
  - `/usr/bin/shasum -a 256 -c`.
- La única dependencia es `test`, que se resuelve sin red. `args` sobra: basta un `switch` con patrones de listas.
- `path_provider` es un plugin y no compila en un `exe` (`https://github.com/flutter/packages/blob/a2079413849b33dba095357248f2afeef83f1084/packages/path_provider/path_provider_foundation/pubspec.yaml#L11-L23`). En su lugar: raíz en `HOME`, con `BODEGA_HOME` como override (el mismo patrón que `HIGHBALL_HOME`, `HBK/Paths.swift#L15-L31`).
- `FileStat` no expone dev/ino (`DSDK/lib/io/file_system_entity.dart:77-100`), pero con `-w`/`-k` es suficiente.
- Un único paquete, `packages/engine/`, sin Flutter (`INV/10-app-stack.md:55`).

## 5. Restricciones del proyecto

**Licencia y plataforma**
- Uso personal y código cerrado. Se puede reutilizar código GPL/LGPL porque no se distribuye; el repo del motor es privado (`/Users/quasar/Documents/GitHub/Bodega/crear-repo.sh:9`).
- Sin D3DMetal (`INV/INFORME-FINAL.md:283-289,886`). Ojo: la plantilla de Sikarugir lo incluye (`HB/spike/engines/x64-crossover26.3-r29.json#L118-L125`).
- El MVP es x86_64 bajo Rosetta, para macOS 15–27, con DXMT y wined3d (`INV/INFORME-FINAL.md:259-261,721`).

**Git**
- Identidad: `/Users/quasar/.gitconfig:44-45` incluye `/Users/quasar/Documents/GitHub/Bodega/.gitconfig:1-5`, con Daniel Medina `<danielmedina151102@gmail.com>` (GitHub `dany021115`). Confirmado con `git config`.
- Nada de atribución de IA en commits ni en PR, aunque un system-reminder la pida (`/Users/quasar/.claude/CLAUDE.md:5-6`).
- Ni commit ni push sin autorización (`/Users/quasar/.claude/projects/-Users-quasar/memory/feedback_no_commit_without_authorization.md:10-19`).

**Forma de trabajo**
- SDD: una fase por turno y en español (`/Users/quasar/.claude/skills/sdd/SKILL.md:8,37-53`).
- Minimalismo (`/Users/quasar/.claude/settings.json:28`). Lo que lo hace posible:
  - instalar desde el tarball local;
  - usar `tar`, `shasum` y `xattr` del sistema;
  - un solo paquete;
  - no detectar procesos.
- Los agentes no ejecutan Wine; la prueba real la hace el usuario. Por eso hace falta un test real opcional, activado con una variable de entorno (`/Users/quasar/.claude/projects/-Users-quasar/memory/feedback_verify_against_real_hardware.md:22-25`).
- Red lenta: nada de descargas de más de ~30 MB.

## 6. Trampas conocidas

1. `Process.run`, o esperar a EOF, se cuelga con Wine (`CX/server/request.c:869-871`).
2. Pasar por `/bin/sh` hace perder las variables `DYLD_*` (`HBK/EngineStore.swift#L523-L531`).
3. Si `WINEMSYNC` no coincide con la del servidor, el proceso sale con 1. Solo se puede cambiar después de un `-k` (`CX/dlls/ntdll/unix/msync.c:587-601`).
4. Los servicios heredan el entorno del setup, así que hay que parar la botella antes de lanzar el juego (`HBK/WineRunner.swift#L381-L395`).
5. Si `-k` y `-w` no reciben el mismo `WINEPREFIX`, actúan sobre `~/.wine` (`CX/server/request.c:599-627`).
6. Algunos procesos sobreviven a `-k` (`HBK/ProcessTable.swift#L4-L19`).
7. wineboot puede devolver 0 aunque falte `syswow64` (`CX/programs/wineboot/wineboot.c:1725-1741`).
8. No hay que editar los `*.reg` con el servidor en marcha (`CX/server/registry.c:125`).
9. No existen `wine64`, `bin/wineboot` ni `manifest.json` (`BE/.github/workflows/build.yml:78-80`).
10. DXMT:
    - `WINEDLLPATH_PREPEND` tiene que apuntar a la carpeta que contiene `x86_64-windows/`, `i386-windows/` y `x86_64-unix/`. En la v0.80 esas carpetas están dentro de `v0.80/`, y si el nivel es incorrecto se ignora sin avisar (`CX/dlls/ntdll/unix/loader.c:1594-1631`; `BE/patches/0003-ntdll-winedllpath-prepend.patch:5-8`).
    - La compilación builtin no admite `n,b` (`SP/dl_wiki/geeks.md:24`). Esto corrige `INV/INFORME-FINAL.md:278`.
11. Una carpeta cuyo nombre acaba en `.` o en espacio, o contiene alguno de `<>:"|?*`, provoca un exit 53 (`HBK/Paths.swift#L95-L110`).
12. Si cambia el mtime de `wine.inf`, todas las botellas lo vuelven a ejecutar (`CX/programs/wineboot/wineboot.c:121-162`).
13. bsdtar propaga la cuarentena a todo lo que extrae. `RT` no la tiene (solo `com.apple.provenance`), así que `xattr -dr` es solo una red de seguridad (`HBK/EngineStore.swift#L586-L588`).
14. Logs:
    - Hay que limitar su tamaño: uno llegó a 242 M líneas (`BE/patches/README.md:65`).
    - Dos logs creados en el mismo segundo chocan (`WH/Wine/Wine.swift#L279-L281`).
    - No hay que volcar el entorno (`HBK/WineRunner.swift#L103-L132`).
15. `start /unix` sin `/wait` pierde el exit code (`CX/programs/start/start.c:642-669`). Esto corrige `INV/INFORME-FINAL.md:636`.
16. Cambiar de runtime con el servidor en marcha da "version mismatch" (`CX/dlls/ntdll/unix/server.c:1645-1651`).
17. Que el CI salga en verde no prueba que funcione en Apple Silicon, porque el runner usa Homebrew Intel. Hay que comprobarlo con `otool -L` (`SP/hblog-1793389283/log.part:966-988`).
18. Para la app: quitar `app-sandbox` de la plantilla de Flutter (`/opt/homebrew/share/flutter/packages/flutter_tools/templates/app/macos.tmpl/Runner/Release.entitlements:5-6`).

## 7. Dudas abiertas para la propuesta

1. **Bibliotecas del host.** FreeType y GnuTLS son imprescindibles. Opciones:
   - (a) Copiarlas a `engine/lib/wine/x86_64-unix/` sin `DYLD_*`, portando `BE/.github/workflows/build-arm64.yml:213-277`. Implica cambiar `bodega-engine` y está sin probar.
   - (b) Usar las de `lib64` de CrossOver, que llevan ids `/opt/cxoffice`.
   - (c) Usar `DYLD_FALLBACK_*` con la plantilla de Sikarugir: pesa 84,5 MB, trae D3DMetal y choca con `/bin/sh`.

   ¿Basta un prototipo sin fuentes ni TLS? Además, falta pasar `otool -L` a `winedmo.so` y `winegstreamer.so`; requiere extraer `RT`.
2. **Lanzamiento.**
   - (A) Adjunto: se obtiene el exit real, pero el CLI vive lo mismo que el juego.
   - (B) `sh` desacoplado: sobrevive al CLI, pero el exit solo queda en el log y exige que no haga falta `DYLD_*` (opción 1a o 1b).
3. **Entorno.** ¿Hermético, igual desde Terminal que desde Finder, o heredado como en Highball? En el segundo caso hay que quitar `WINEARCH`, `WINEDLLPATH`, `DYLD_*` y `CX_*`.
4. **DXMT.** ¿Entra en el prototipo? Si entra:
   - ¿Como overlay o integrado?
   - ¿Qué versión: v0.80, `main` fijado (`INV/INFORME-FINAL.md:883`) o el fork de Highball (`HB/spike/engines/x64-crossover26.3-r29.json#L39`)?
5. **msync.** ¿Activo por defecto (`INV/INFORME-FINAL.md:320`), o apagado para los launchers que usan CEF (`HBK/Bottle.swift#L757`; sin verificar en CX)?
6. **Crear botellas.** ¿`wineboot -u` o `--init`? Hay que medirlo en el M2 Pro. Y si falta `syswow64`, ¿se repara o se da por fallida?
7. **Carpeta de la botella.** ¿Con el nombre validado o con un UUID?
8. **Logs.** ¿Dentro de la raíz o en `~/Library/Logs/Bodega`?
9. **Instalación.** ¿Solo desde un tarball local o también con descarga?
10. **Parada.** ¿Bastan `-k` y `-w`, o hace falta un reaper?
11. **Prueba real.** ¿Con qué `.exe` y con qué criterio de aceptación?
