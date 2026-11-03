# Diseño: prototipo-motor

Este documento recoge solo las decisiones que no son obvias. Usa los alias de `exploration.md` y dos más:
- `SP/dyldtest`: experimento de dyld x86_64 bajo Rosetta en macOS 27.0.1.
- `SP/brewapi`: la API de Homebrew, consultada el 2026-11-02.

## §1 Bibliotecas del host: junto a los módulos, sin `DYLD_*`

**Hechos**
- **Rpath de los módulos.** Según `otool -l` sobre `RT`, los 31 `.so` de `lib/wine/x86_64-unix/` llevan `LC_RPATH @loader_path/`; `winegstreamer.so` añade además una ruta de Cellar. El loader `wine` no tiene ningún rpath.
- **Qué abre cada módulo**, según `strings`:

  | Módulo | Bibliotecas que abre | Llamada en el código |
  |---|---|---|
  | `win32u.so` | `libfreetype.6.dylib`, `libMoltenVK.dylib` | `CX/dlls/win32u/freetype.c:1483`, `CX/dlls/win32u/vulkan.c:3005-3015` |
  | `dwrite.so` | `libfreetype.6.dylib` | `CX/dlls/dwrite/freetype.c:119` |
  | `bcrypt.so` | `libgnutls.30.dylib` | `CX/dlls/bcrypt/gnutls.c:388-396` |
  | `crypt32.so` | `libgnutls.30.dylib` | `CX/dlls/crypt32/unixlib.c:100-108` |
  | `secur32.so` | `libgnutls.30.dylib` | `CX/dlls/secur32/schannel_gnutls.c:1481-1489` |
  | `winebus.so` | `libSDL2-2.0.0.dylib` | — |
  | `odbc32.so` | `libodbc.2.dylib` | — |

  Según `otool -L`, solo `winedmo.so` y `winegstreamer.so` enlazan `/usr/local/opt`.
- **Búsqueda de dlopen(3)** (sección SEARCHING): un nombre hoja se busca en los `LC_RPATH` del Mach-O que hace la llamada. `SP/dyldtest` lo confirma:
  - funciona con `env -i`, con cwd `/` y a través de `/bin/sh`;
  - sin `LC_RPATH` falla, y dyld no prueba `/usr/local/lib`.
- **El cwd va primero.** Con una biblioteca señuelo del mismo nombre en el cwd, se carga el señuelo (`SP/dyldtest/decoy`): en la práctica dyld mira el cwd antes que el `LC_RPATH`. Por eso el cwd lo fija siempre el motor (§4).

**Decisión.** El tarball de hostlibs deja las `.dylib` en `engine/lib/wine/x86_64-unix/`, con el id y las dependencias reescritos a `@loader_path/<hoja>` y firma ad hoc. No se toca ningún binario de Wine ni se exporta ninguna variable. Funciona para cualquier proceso de la botella, también para los hijos que un programa Windows lanza con su propio entorno.

Alternativas descartadas:
- `DYLD_FALLBACK_LIBRARY_PATH` dentro del script. `/bin/sh` está protegido por SIP (`HBK/EngineStore.swift#L523-L531`) y los hijos pierden la variable (`BE/patches-arm64/0030-unixlib-host-libraries-next-to-wine.patch:7-16`).
- Reescribir los rpaths del motor: obligaría a firmar de nuevo 31 módulos en cada build.

**Workflow `build-hostlibs.yml`**
- **Homebrew congelado.** La API de hoy ya no tiene bottles Intel de freetype 2.15.0, gettext, gmp, libpng, libunistring ni p11-kit (`SP/brewapi/*.json`). En cambio:
  - la imagen del runner ya trae freetype y gnutls, que no salen en «Would install» (`SP/hblog-1793389283/log.part:204-219`);
  - molten-vk 1.4.2 tiene bottle `sonoma` (`:663`).

  `HOMEBREW_NO_AUTO_UPDATE` y `HOMEBREW_NO_INSTALL_UPGRADE` evitan compilar desde fuente. `timeout-minutes: 15` limita lo que cuesta el ×10. Si una actualización semanal de la imagen deja de traer freetype o gnutls, la guarda `brew list --versions freetype gnutls` (R17) corta el job en segundos en vez de compilar hasta el tope. `hostlibs.txt` anota `$ImageOS` y `$ImageVersion`.
- **`bundle`.** Es un port de `BE/.github/workflows/build-arm64.yml:223-268` con dos cambios:
  - las raíces llegan como argumentos (`$ROOTS`, la única lista del job), lo que permite el ensayo local solo con freetype y gnutls;
  - no incluye la parte de SDL3.

  La carga con ctypes (`:266-268`) la reemplaza la sonda: cargar las tres raíces carga todo el cierre.
- **`probe`.** Un solo `probe.c` sirve para las dos piezas:
  - Con `-DMOD` se compila `x86_64-unix/probe.so` con `-dynamiclib -Wl,-rpath,@loader_path/`, igual que un módulo de Wine. Exporta una función que hace `dlopen` del nombre que recibe.
  - Sin esa macro sale un ejecutable sin `LC_RPATH`, igual que el loader. Abre `probe.so` por ruta absoluta, llama a esa función con cada argumento y sale con 1, tras imprimir `dlerror()`, si alguna falla.

  El paso, con el shell por defecto del runner (`bash -e`):
  ```sh
  probe="$PWD/probe"; dir=$(cd out/engine/lib/wine/x86_64-unix && pwd -P); log="$RUNNER_TEMP/probe.log"
  (cd / && env -i DYLD_PRINT_LIBRARIES=1 "$probe" "$dir/probe.so" $ROOTS) 2>"$log" || { cat "$log"; exit 1; }
  cat "$log"
  for r in $ROOTS; do grep -F "$dir/$r" "$log"; done
  if grep -q "$(brew --prefix)/" "$log"; then exit 1; fi
  ```
  - Las rutas se fijan antes del `cd /`, y el `2>` va fuera del subshell: dentro, `probe.log` caería en `/`, que es de root, y el paso moriría con «Permission denied».
  - `pwd -P` da la ruta real, que es la que imprime dyld.
  - El `grep -F` del bucle corta con `set -e`; la última línea usa `if` porque `set -e` no detecta un `! grep` que falle.
  - En T2, `RUNNER_TEMP` apunta al scratchpad y `ROOTS` va sin MoltenVK.

  `probe.so` no acaba en el tarball, porque el patrón es `*.dylib`.
- **`tarball`.** `(cd out && tar -czf ../$name.tar.gz hostlibs.txt engine/lib/wine/x86_64-unix/*.dylib)`.
  - Solo contiene archivos, así que extraerlo encima del motor no cambia modos de carpetas ni el mtime de `wine.inf` (trampa 12). Sí actualiza el mtime de `engine/lib/wine/x86_64-unix/`, que no importa.
  - `shasum -a 256 … | tee ….sha256`, como en `BE/.github/workflows/build.yml:119`.
  - Tope: `stat -f %z` por debajo de 30 MiB.
- **`publish`.** Igual que `build.yml:128-136`, pero con `GH_REPO: ${{ github.repository }}`, porque no hay checkout. El nombre se recupera con `ls hostlibs-*.tar.gz`, sin pasar variables entre pasos.

**Acoplamiento.** Las sonames `libfreetype.6` y `libgnutls.30` aparecen a la vez en las raíces del workflow y en `requiredFiles`. Si un motor futuro cambia alguna, `install` falla de forma visible.

## §2 Lanzamiento por `/bin/sh` y código de salida

Hay un único script, `S`:

```sh
l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s
```

Se lanza con `Process.start('/bin/sh', ['-c', S, 'bodega', log, wine, programa, ...args], mode: …, workingDirectory: cwd, environment: wineEnv(…), includeParentEnvironment: false)`.

- **`run`** usa `ProcessStartMode.detached`, que hace `setsid` y manda el stdio a `/dev/null` (`DVM/process_macos.cc#L448-L546`). Así, ni Ctrl-C ni el SIGHUP de la Terminal llegan al juego; Wine no gestiona SIGHUP (`CX/dlls/ntdll/unix/signal_x86_64.c:3022-3040`). Es la variante E7 (`SP/dartplat/exp/detached_footer.dart:4-7`).
- **`create`** usa el mismo `S` con `ProcessStartMode.inheritStdio` y `await exitCode`, como en E8 (`SP/dartplat/exp/inherit_log.dart:7-10`). El `sh` sale con el código de wine, y aquí Ctrl-C sí aborta.
- **Sin `exec`.** El `sh` tiene que seguir vivo para escribir el pie.
- **Ruta del log en `$1`.** Va como argumento y no como variable, para que el entorno de Wine sea exactamente `wineEnv`.
- **`.exit` atómico.** Se escribe en un temporal y se mueve dentro de la misma carpeta; el rename es atómico. `exitOf(log)` lo consulta cada 250 ms y nunca lee un archivo a medio escribir.
- **Qué vale el código.**
  - `bin/wine` hace `execv` al loader sin cambiar de PID (`CX/dlls/ntdll/unix/loader.c:2523-2547`). Por eso `$?` es el código de Windows truncado a 8 bits: 1638 llega como 102 (`HBK/WineRunner.swift#L46-L57`).
  - Si el proceso muere por una señal, `$?` vale 128 + la señal, por ejemplo después de `stop`.
  - `wine: failed to open` termina con `STATUS_DLL_NOT_FOUND`, que truncado da 53 (`CX/dlls/ntdll/unix/env.c:1920-1926`): es el exit 53 de la trampa 11.
- **Sin tuberías de Dart hacia Wine.** Por la trampa 1 (`CX/server/request.c:869-871`) y porque `Process.run` espera al EOF (`DSDK/lib/_internal/vm/bin/process_patch.dart:649`). `Process.run` solo se usa con herramientas que terminan: `tar`, `shasum`, `xattr`, `arch` y `wine --version`, que no arranca el servidor (`CX/dlls/ntdll/unix/loader.c:2555-2604`).

## §3 Logs y el stderr que hereda el wineserver

El wineserver hace `setsid` y solo redirige stdin y stdout (`CX/server/request.c:864-871`). Se queda, por tanto, con el fd 2 del primer proceso de la sesión, y lo mismo les pasa a los servicios. Consecuencias:
1. Ese log sigue recibiendo líneas después del pie; E8 mostró a un demonio escribiendo cuando el padre ya había salido. Por eso toda comprobación exige que el log **contenga** `# exit=N`.
2. Nada espera el EOF del log: el código se lee del `.exit`.
3. Poner un tope de tamaño obligaría a usar una tubería o a truncar periódicamente desde un proceso vivo. Se deja sin tope ni rotación (`ponytail:`):
   - el log de 242 M líneas lo corrigió el parche 0014 (`BE/patches/README.md:65`);
   - con `fixme-all` solo salen las líneas `err:`.

Otras decisiones del log:
- **Nombre:** con microsegundos y `File.createSync(exclusive: true)` (`DSDK/lib/io/file.dart:256`). Así no pueden chocar dos logs, que es el fallo de Whisky (`WH/Wine/Wine.swift#L279-L281`).
- **Cabecera:** lista blanca de tres líneas. Nunca vuelca el entorno (`HBK/WineRunner.swift#L103-L132`).

**Pistas.** `hintsIn(log)` lee el log en streaming (`openRead`, `latin1` y `LineSplitter`, sin cargarlo entero) y lo compara con una tabla fija:

| Marcador | Origen | Pista |
|---|---|---|
| `cannot find the FreeType` | `CX/dlls/win32u/freetype.c:1486`, `CX/dlls/dwrite/freetype.c:122` | faltan las hostlibs: reinstala con su tarball |
| `ailed to load libgnutls` | `CX/dlls/bcrypt/gnutls.c:401`, `CX/dlls/crypt32/unixlib.c:113`, `CX/dlls/secur32/schannel_gnutls.c:1494` | ídem |
| `version mismatch` | `CX/dlls/ntdll/unix/server.c:1648` | hay un servidor de otro runtime: `bodega stop <b>` |
| `wine: failed to open` | `CX/dlls/ntdll/unix/env.c:1925` | revisa la ruta del programa (trampa 11) |

No hay marcadores de msync (`CX/dlls/ntdll/unix/msync.c:600,636`) ni `Bad CPU type`: con `WINEMSYNC=1` constante (§4) y Rosetta comprobada antes de cada verbo (R3) no pueden salir, y si `bootstrap_look_up` fallara por otra causa, `bodega stop` no lo arreglaría.

## §4 Entorno hermético y directorio de trabajo

`includeParentEnvironment: false` es la única forma de quitar una variable heredada (`DSDK/lib/io/process.dart:318-320`). El mapa completo está en R12. Lo que no es obvio:

- **Variables que quedan fuera por construcción:**

  | Variable | Problema | Referencia |
  |---|---|---|
  | `WINEARCH` | es fatal con `win32` | `CX/dlls/ntdll/unix/server.c:1615-1620` |
  | `WINEDLLPATH` | crea hard links en `$TMPDIR` | `CX/dlls/ntdll/unix/loader.c:387-404` |
  | `CX_LIBVULKAN` y `CX_ACTIVE_GRAPHICS_BACKEND` | cambian la biblioteca Vulkan | `CX/dlls/win32u/vulkan.c:3005-3011` |
  | `CX_APPLEGPTK_LIBD3DSHARED_PATH` | carga libd3dshared, de D3DMetal | `CX/dlls/ntdll/unix/loader.c:1323-1331` |
  | `DYLD_*` | no hacen falta | §1 |

  Si faltan `HOME` o `USER`, Wine usa `getpwuid` (`CX/dlls/ntdll/unix/loader.c:432-452`).
- **Sin `LANG` ni `LC_*`.** `setlocale` devuelve `C` y Wine toma el idioma y la región de `CFLocale` (`CX/dlls/ntdll/unix/env.c:734-760`). El resultado es el mismo desde la Terminal y desde Finder.
- **`WINEDEBUG`** sale de `BODEGA_WINEDEBUG` (por defecto `fixme-all`), nunca del `WINEDEBUG` del padre: un `+all` olvidado en la shell no llena el disco con GB de log. `ponytail:` es la única perilla que se lee del llamador.
- **`MVK_CONFIG_LOG_LEVEL=2`.**
  - MoltenVK registra en nivel INFO por defecto (`SP/research/src/moltenvk-upstream/MoltenVK-1.2.10/MoltenVK/MoltenVK/Utility/MVKEnvironment.h:221`).
  - win32u crea una instancia Vulkan cada vez que refresca la caché de pantallas, al menos una vez por sesión (`CX/dlls/win32u/sysparams.c:2839`, `CX/dlls/win32u/vulkan.c:3128`).
  - Highball usa 2 (`SP/hb/Bottle.swift:778`).
- **`WINEMSYNC=1` constante.** Así no se pueden mezclar modos (trampa 3, `CX/dlls/ntdll/unix/msync.c:587-601`). `wineserver -k` y `-w` reciben el mismo mapa y, por tanto, el mismo `WINEPREFIX` (trampa 5).
- **cwd:**
  - en `create`, `bottles/<b>`;
  - para una ruta Unix, su carpeta, ya validada;
  - para `C:\…`, su carpeta dentro de `prefix/drive_c` si existe (R13), como hace Highball con la carpeta del exe (`HBK/WineRunner.swift#L436-L441`);
  - en otro caso, `prefix/drive_c`.

  Hay dos motivos: dyld mira el cwd antes que el `LC_RPATH` (§1), y Wine convierte el cwd en una ruta DOS (trampa 11).

## §5 Crear la botella

- **El `--init` automático.** Todo proceso sin padre pasa por `build_initial_params`, que llama a `run_wineboot`. Este lanza `wineboot.exe --init` una vez por sesión y lo espera hasta 5 min (`CX/dlls/ntdll/unix/env.c:1543-1609,1908`). Ese `--init` instala el prefijo nuevo porque aún no existe `.update-timestamp` (`CX/programs/wineboot/wineboot.c:121-162,1713`).
- **Por qué sin banderas.** Por lo anterior basta `wine wineboot` sin banderas: así wineboot no llama a `update_wineprefix` ni a `start_services_process`, y solo hace los pasos ligeros (claves dinámicas, RunOnce, Run y StartUp; `wineboot.c:1949-1977`).
  - `-u` fuerza una segunda pasada completa de `wine.inf`, incluido Wow64Install (`wineboot.c:1713,1740,1965`).
  - Un `--init` explícito vuelve a llamar a `start_services_process` (`wineboot.c:1959-1963`).
  - Plan B, si verify encuentra un prefijo incompleto: `-u`, que es lo que usa Highball (`HBK/WineRunner.swift#L530-L535`).
- **Después, `wineserver -w`.** Espera al `--init` si pasó de 5 min, y también a services y a explorer. Al salir, el servidor guarda el registro (`CX/server/request.c:909`; el guardado periódico es cada 30 s, `CX/server/registry.c:125`). El tope es de 10 min con `exitCode.timeout`; si se agota, se ejecuta `-k` y se da error.
- **Cuándo está lista.** Exit 0, `syswow64/kernel32.dll` y `system.reg`.
  - No se repara syswow64; Highball copia `i386-windows` (`HBK/BottleStore.swift#L221-L276`). En un prototipo queremos ver ese fallo.
  - El motor no borra nada, así que no tiene que protegerse del enlace `dosdevices/z:` → `/` (`CX/dlls/ntdll/unix/server.c:1350-1354`). Los tests sí borran (§6).

## §6 Instalación y tests sin Wine

- **Instalación.** Si `runtimes/<id>` ya existe, falla antes de verificar o extraer nada (R6). Motor y hostlibs se extraen en un solo staging, con un rename atómico al final: un runtime visible siempre está completo. El `.tmp-<id>` que deje un intento fallido se borra al empezar. `current` también cambia con un rename atómico (R7).
- **`wine --version` antes del rename.** Descubre tres problemas:
  - una cuarentena;
  - un binario sin firma que macOS mate (`strip` quitó la firma del motor);
  - Rosetta ausente. El errno 86 llega como `ProcessException` porque aquí no hay `sh` de por medio.
- **Runtime falso del test.** Se empaqueta con `/usr/bin/tar` y `shasum`, igual que el real:
  - `engine/bin/wine` (script `sh`):
    - con `--version` imprime `wine-11.0`;
    - con `wineboot` crea `drive_c/windows/syswow64/kernel32.dll` y `system.reg`, salvo si `WINEPREFIX` contiene `/broken/`;
    - con cualquier otro argumento imprime sus argumentos, deja un `sleep 5 &` con el log abierto (hace de wineserver) y sale con 7.
  - `engine/bin/wineserver` (script `sh`): `-k` devuelve 1 y `-w` devuelve 0.
  - El resto de `requiredFiles` son archivos vacíos. Las hostlibs falsas son las dos `.dylib` vacías más `hostlibs.txt`.
- **Grupo `real runtime`.** Se activa si `BODEGA_TEST_RUNTIME` apunta a un runtime instalado o recién extraído. En un `BODEGA_HOME` temporal crea `runtimes/current` apuntando ahí, sin volver a extraer 1 GB, y ejecuta:
  - `--version`, `create`, `cmd /c echo ok` y `cmd /c exit 7`;
  - siempre, las dos sondas `rundll32`, que no abren diálogos (`CX/programs/rundll32/rundll32.c:317-331`); dwrite y bcrypt abren su biblioteca en `DllMain` (`CX/dlls/dwrite/main.c:46-50`, `CX/dlls/bcrypt/bcrypt_main.c:2837-2841`);
  - `stop`.

  Si el runtime tiene `x86_64-unix/libgnutls.30.dylib`, ningún log puede dar las pistas de FreeType y GnuTLS; si no lo tiene, tienen que salir. Así T15 y R21 no dependen de efectos laterales: sin las sondas, GnuTLS solo se carga de rebote al instalar Mono y Gecko (msi importa crypt32 y appwiz.cpl importa bcrypt: `CX/dlls/msi/Makefile.in:3`, `CX/dlls/appwiz.cpl/Makefile.in:2`), y `cmd` no importa ninguna de las dos (`CX/programs/cmd/Makefile.in:2`).
- **Limpieza.** `tearDownAll` hace `stopBottle` (`wineserver -k`) y después `Directory(home).deleteSync(recursive: true)`, que borra los enlaces sin seguirlos (`DSDK/lib/io/directory.dart:290,313`): ni `dosdevices/z:` → `/` ni `runtimes/current` arrastran su destino. `rm -rf` se comporta igual. Un listado recursivo de una botella pasa siempre `followLinks: false`, porque el valor por defecto es `true` (`directory.dart:350-353,376-379`) y recorrería el disco entero a través de `z:`.

## §7 Riesgos aceptados y planes B

- **Búsqueda por `LC_RPATH`.** Bajo Rosetta solo está medida en macOS 27; la sonda del CI cubre macOS 15 en Intel nativo. En tu Mac la comprueban T16 (sin pistas ni `Failed to load libMoltenVK`) y, de forma directa, el `lsof` de U3.
  - Plan B: `DYLD_FALLBACK_LIBRARY_PATH` dentro de `S`.
  - Plan C: portar `patches-arm64/0030`, lo que obliga a recompilar.
- **Firma del motor.** Si macOS matara los binarios del motor por no tener firma, `install` los firmaría ad hoc (`codesign -f -s -`, permitido por la decisión 3).
- **Homebrew Intel caduca.** La imagen dura hasta ~agosto de 2027 y Homebrew deja Intel el 2027-09-01 (`INV/INFORME-FINAL.md:710-711`). El tarball queda guardado en la release.
- **Sin vídeo.** winedmo y winegstreamer enlazan `/usr/local/opt` y fallan sin romper nada (`CX/dlls/ntdll/unix/virtual.c:851-853`).
- **Mandos solo por IOHID**, porque no hay SDL2.
- **Sin reaper.** Algún proceso puede sobrevivir a `-k` (trampa 6); la aceptación lo mira con `pgrep`.
- **Sin tope de log.** Un `err:` en bucle puede hacerlo crecer.
- **`runtimes/current` es global.** Instalar otro runtime con botellas en marcha da `version mismatch` (trampa 16), y cada botella vuelve a pasar por `wine.inf` (trampa 12). Antes de instalar, `bodega stop`.
- **Sin `.exit`.** Si el `sh` muere por SIGKILL no se escribe el `.exit`, y `bodega run` espera hasta que pulses Ctrl-C.
- **Ctrl-C durante `create`.** Deja la carpeta a medias: hay que hacer `bodega stop <b>` y `rm -rf`.
- **`wait` justo después de lanzar desde otra Terminal** puede volver antes de que exista el servidor.
- **Sombreado por el cwd.** Una `.dylib` con el mismo nombre en la carpeta de un juego taparía las hostlibs, porque dyld mira primero el cwd. Es improbable.
- **Rutas de configuración.** GnuTLS y p11-kit traen rutas `/usr/local/etc` que no existen. TLS valida con crypt32 y las raíces del llavero (`CX/dlls/winhttp/net.c:97,158`, `CX/dlls/crypt32/unixlib.c:648-651`); lo comprueba el `cscript` de T16.
- **Commit, push y dispatch** los lanzas tú desde tu Terminal (T3, T17); el agente prepara los comandos y solo comprueba el resultado, porque el clasificador ya bloqueó un push suyo.
