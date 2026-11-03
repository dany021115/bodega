# Verificación: prototipo-motor

Fase **verify** del SDD · 2026-11-02 · contrasta los requisitos R1–R21 de `specs/*.md` con lo que construyó `apply` (T1–T16), con `design.md` y `tasks.md` como referencia.

**Convenciones**
- Rutas: los alias de `tasks.md` (`B`, `BE`, `P`, `RT`), más `SCR` = `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad`, donde está toda la evidencia. Esa carpeta es temporal: lo que hace falta para sostener cada estado está pegado aquí.
- En los bloques, `$SCR` sustituye literalmente a esa ruta y `<H>` a la raíz `BODEGA_HOME` del grupo (cada grupo dice cuál es). `[…]` marca un recorte. No se ha cambiado nada más; los rótulos en inglés son los de los scripts de los checks.
- `[S4]`, `[H3]`, `[C4]`, `[P1]`, `[V1]`… remiten a los bloques de §3. `test:N` es una línea de `P/test/engine_test.dart`.
- **Cumplido**: cada escenario del requisito tiene salida pegada, de este verify o de T15/T16. **Parcial**: al menos un escenario no se ha ejecutado tal como está escrito; §4 dice qué paso lo cierra. Un paso U que solo repite algo ya demostrado sale en §4 como confirmación y no rebaja el estado.
- **Refutador**: la primera ejecución falló por un corte de red. Se repitió y revisó los 16 requisitos marcados como cumplidos (R1–R10, R12, R15, R16, R18–R20): confirmó los 16, sin rebajas. Al redactar se releyó la evidencia del disco y se corrigieron tres detalles de redacción de los checks (§5.10); ningún estado cambió.

## 1. Resumen

| Estado | Nº | Requisitos |
|---|---|---|
| Cumplido | 20 | R1–R16, R18–R21 |
| Parcial | 1 | R17, aceptado por el usuario (§6) |
| No cumplido | 0 | — |

- **Sin Wine:** `dart analyze` → `No issues found!`; `dart test` → `All tests passed!`, con el grupo `real runtime` saltado por su motivo [S2, S4].
- **CLI:** `build/bodega` es arm64, con firma ad hoc válida, y solo enlaza `/usr/lib` y `/System`. Los códigos 64, 1 y N salen como dice R2 [S5, T13-1…T13-3, X2–X5, H5].
- **Runtime real con hostlibs, sin ventanas:** `install` en 4,28 s, `create` en 12,52 s, grupo `real runtime` verde y un `stop` en vivo que deja la botella sin procesos en 0,13 s [H1–H3]. Ningún log con hostlibs da pistas de FreeType o GnuTLS ni `Failed to load libMoltenVK`; sin hostlibs (T15) sí salen [P1, P2].
- **CI:** el run 41512345512 de `build-hostlibs` sale verde en 43 s sobre `macos-15-intel` y ejecuta exactamente el YAML del commit 8a00dea. Release, `.sha256` y archivos locales coinciden [C1–C10].
- **Hallazgo principal (§5.1):** tras `bodega stop`, el `run` que esperaba sale con **0** y su `.exit` dice `0` (2 de 2 veces), no con 128 + la señal como dice `design.md:89`. R11 y R14 se cumplen tal como están escritos, pero hay que decidir si se corrige el diseño o la spec.
- **Tareas:** T1–T17 hechas. U1–U4, U6 y U7 pasan. U5 se sustituyó por un check sin ventanas y U8 no se hizo (§7). Las tablas de §2 y §4 conservan el estado anterior a estas pruebas para las filas R11, R13, R14 y R21; manda §7.

## 2. Requisito → estado → evidencia

| Req | Estado | Evidencia | Falta |
|---|---|---|---|
| R1 · Raíz de datos | cumplido | Test `names and windows paths` [S4] (test:134-151): `BODEGA_HOME=$tmp/link/b` queda en `$tmp/real/b` (canonizada a través de un enlace, como `/tmp` → `/private/tmp`), con `runtimes/` y `bottles/`; `$tmp/a./b` da `FormatException` con `"a."` y `$tmp/a.` no llega a existir. CLI: `BODEGA_HOME=…/a./b` → `bodega: "a." en …`, exit 1, y la carpeta padre sigue vacía [T13-3]; una raíz válida recibe `bottles` y `runtimes` [T13-2]. | La raíz por defecto solo se ve en código (`lib/engine.dart:12`), porque todos los checks fijan `BODEGA_HOME`. La usa U1. |
| R2 · Verbos y códigos de salida | cumplido | Sin argumentos, con un verbo desconocido o con un número de argumentos incorrecto → el uso por stderr y 64, sin crear la raíz [T13-1, X2]. `create 'a b'` → `bodega: nombre de botella no válido: "a b" …`, 1 y sin `bottles/a b` [T13-2]. Otros errores → `bodega: …` y 1 [X3, X4, X5, H5c, H5d]. `run` sale con el N del `.exit` (53 y 1) [H5a, H5b]; `wait` y `stop`, con el suyo (0) [H3, H6]. Build: `dart compile exe` → `build/bodega`, `Mach-O 64-bit executable arm64`, `Signature=adhoc`, `valid on disk`, y `otool -L` solo con `/usr/lib` y `/System` [S5]. `pubspec.yaml` solo tiene `dev_dependencies: test` [S1]. | — |
| R3 · Rosetta | cumplido | Revisión del código, como prescribe la spec [X7]: con un verbo válido, `bin/bodega.dart:50-57` ejecuta `/usr/bin/arch -x86_64 /usr/bin/true` antes de `bodegaHome()`, que crea la raíz, y antes del verbo. Si falla, lanza `falta Rosetta: softwareupdate --install-rosetta --agree-to-license`, y el `catch` escribe `bodega: …` y deja 1; no puede quedar `bottles/x`. Caso positivo: la sonda da 0 en este Mac [X7] y los verbos llegan a ejecutarse [T13-2, T13-3, H1, H3a, P5]. | El camino negativo no se ejecuta: habría que desinstalar Rosetta. |
| R4 · Verificación antes de extraer | cumplido | Test `installRuntime` [S4] (test:178-197): un `.sha256` de ceros → `engine-b.tar.gz: FAILED`; uno que nombra otro archivo → `no corresponde a engine-b.tar.gz`; sin `.sha256` → `gh release download engine-b -R dany021115/bodega-engine`. Después, `runtimes/` sigue siendo `['current', 'engine-a']`, sin `.tmp-*`. CLI sin `.sha256` → `bodega: falta ….sha256: gh release download engine-zz -R dany021115/bodega-engine`, 1 y `runtimes/` vacío [X5]. `grep -rn HttpClient lib bin` no devuelve nada [X6]. `shasum -c` corre en la carpeta del tarball (`lib/engine.dart:105-112`). Par real: `OK` en las dos carpetas [C9]. | — |
| R5 · Extracción en un único staging | cumplido | Escenario 1, test `installRuntime` [S4] (test:199-207): sin `libgnutls` → `runtime incompleto: falta engine/lib/wine/x86_64-unix/libgnutls.30.dylib`, y `runtimes/` sigue siendo `['current', 'engine-a']`. Escenario 2, con los tarballs reales [H1]: exit 0 en 4,28 s, imprime `<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build`, `x86_64-unix/` tiene las 12 `.dylib` (`libgnutls.30.dylib` entre ellas) y no queda ninguna entrada `.tmp-*`. La repetición de T16 también imprimió la carpeta [P5]. | U1 lo repite en la raíz por defecto (confirmación). Sin ejercitar: el borrado de un `.tmp-<id>` de un intento anterior (`lib/engine.dart:117-118`, solo código). |
| R6 · Runtimes inmutables | cumplido | Test `installRuntime` [S4] (test:172-176): tras borrar `engine-a.tar.gz.sha256`, reinstalar A → `ya instalado`. La comprobación va antes de R4 y R5 (`lib/engine.dart:95-99`) y su mensaje da los pasos `bodega stop`, `rm -rf` y volver a instalar. El par del motor se conserva en `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (334861341 B y 120 B), con `shasum -c` OK y tamaño y digest iguales a los de la release [C9]. | — |
| R7 · Runtime actual | cumplido | Test `installRuntime` [S4] (test:160-215): sin runtime → `no hay runtime: bodega install`; tras A → `runtimes/engine-a`; tras B → `runtimes/engine-b`; con B borrado (`current` colgante) → otra vez `no hay runtime`. Real: `current -> engine-wine-11.0-20261030T202616Z-primer-build` [H1], y cada log lleva `# runtime engine-wine-11.0-20261030T202616Z-primer-build` [H2]. CLI sin runtime: `create x` y `stop y` → `bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>` y 1, sin `bottles/x` [X4]. | `run` y `wait` sin runtime: solo código (`lib/engine.dart:212,250`). |
| R8 · Nombre y estructura | cumplido | Test `names and windows paths` [S4] (test:121-126): acepta `prueba` y `cave-story_2` (`/h/bottles/<nombre>`) y lanza `FormatException` con `''`, `.x`, `-x`, `a.`, `a b`, `a/b`, `a:b` y 65 `a`. `run`, `wait` y `stop` sobre una botella que no existe → `no existe la botella nope` en el test (test:263-269) y en el CLI, con 1 y sin logs nuevos [X3, H5d]. Estructura: Wine crea `bottles/t/prefix` (`wine: created the configuration directory '<H>/bottles/t/prefix'`) y los logs van en `bottles/t/logs/` [H3a, H6]. Sin UUID ni JSON: `grep -niE 'uuid\|bottle\.json\|\.json'` → exit 1 [V1]. | — |
| R9 · Crear | cumplido | Test `fake runtime cycle` [S4] (test:224-233): el log de `createBottle('t')` contiene `# exit=0`, y un segundo `create t` → `ya existe … rm -rf`. Real: `create t` sale con 0 en 12,52 s e imprime `log: <H>/bottles/t/logs/2026-11-02T20-40-11.179908Z-wineboot.log`, que lleva `# cwd <H>/bottles/t`, `# argv wineboot` y `# exit=0`; tras el `-w` no queda ningún proceso [H3a]. También `create: 0:00:19.454293` [H2] y, en T15, `create: 0:00:10.369397` [P1]. Sin runtime no crea nada [X4]. | U2 anota el tiempo en la raíz por defecto. Sin ejercitar: wineboot ≠ 0 y el tope de 10 min de `-w` (`lib/engine.dart:183-193`, solo código). |
| R10 · Botella lista | cumplido | Test `fake runtime cycle` [S4] (test:234-241): `createBottle('broken')`, cuyo wineboot da 0 sin syswow64, lanza un error que contiene `<home>/bottles/broken/logs/`, y su `-wineboot.log` sigue ahí. Real, después de `-w`: `889967 <H>/bottles/t/prefix/drive_c/windows/syswow64/kernel32.dll` y `3354095 <H>/bottles/t/prefix/system.reg` [H3a]. | Que `run` exija la botella lista: solo código (`lib/engine.dart:215-218`). |
| R11 · Esperar y parar | **cumplido (§7)** | Escenario 1, test [S4] (test:260-261): con el `-k` falso que sale con 1, `stopBottle` → 0 y `waitBottle` → 0. Escenario 2 sin ventana, con `cmd /c ping -n 120 127.0.0.1` en lugar de notepad [H3]: `stop` → 0 en 0,25 s; los 10 procesos de la botella, wineserver incluido, desaparecen a +0,13 s; el `run` que esperaba vuelve a +0,38 s, y después ni `pgrep` ni `lsof` encuentran nada bajo `<H>`. El wineserver parado es el de este prefijo: su cwd es `/private/tmp/.wine-501/server-100000d-4c4ae29`, derivado del dev/ino del prefijo, aunque el shell padre exporta `WINEPREFIX` [H3, §3.1]. Sin servidor: `wait t` → 0 en 0,036 s [H4] y `stop t` → 0 en 0,04 s [H6]. | U7 (notepad, unos 11 s como mucho y `pgrep` de supervivientes, porque no hay reaper) y U6.3 (`wait` bloqueado hasta que se cierra el programa; aquí solo se ejecutó sin servidor). El `run` parado sale con 0 (§5.1). |
| R12 · Entorno hermético | cumplido | Escenarios 1 y 2: test `wineEnv is hermetic` [S4] (test:83-118), con un padre que trae `WINEARCH=win32`, `DYLD_LIBRARY_PATH`, `WINEDLLPATH`, `CX_ROOT`, `LANG`, `WINEDEBUG=+all` y `PATH=/opt/homebrew/bin`. Todo lanzamiento de `/bin/sh`, `wine` y `wineserver` pasa `environment: wineEnv(...)` e `includeParentEnvironment: false` (`lib/engine.dart:136-140,326-331,336-340`) [X6]. Escenario 3: `grep -cE 'DYLD_\|WINEARCH\|CX_\|LANG='` da 0 en el log de `run t cmd /c set` de T16 y en el de su repetición [P3], aunque el shell de esta sesión exporta `LANG` y `WINEPREFIX` [V1]. El log trae `WINEDEBUG=fixme-all`, `WINE_HOST_PATH=/usr/bin:/bin:/usr/sbin:/sbin` y el `WINEPREFIX` de la botella. | — |
| R13 · Programa y directorio de trabajo | **cumplido (§7)** | Escenario 1, test [S4] (test:251-259): `C:\Juegos\Mi Juego.exe`, con `drive_c/Juegos` creada → `# cwd $prefix/drive_c/Juegos`. Escenario 3, test (test:243-249): `$tmp/no/Juego.exe` → `FileSystemException` sin log nuevo; y en el CLI, `run t /nonexistent/x.exe` → `bodega: FileSystemException: Cannot resolve symbolic links, …`, 1 y sin logs nuevos [H5c]. Con el runtime real, los nombres sueltos (`cmd`, `rundll32`, `cscript`, `nonexistent.exe`) llevan `# cwd …/prefix/drive_c` [H2, H5a, P2]. `C:\nope\x.exe` se pasa tal cual (`# argv C:\nope\x.exe`) con cwd `drive_c`, porque la carpeta no existe [H5b]. El cwd del CLI no se hereda: el `sh` lanzado tiene cwd `<H>/bottles/t/prefix/drive_c` mientras el CLI corre en `B` [H3]. | Escenario 2 con notepad: U3. La rama de una ruta Unix que existe (resuelta, validada y con cwd en su carpeta) no se ejecutó: U5. |
| R14 · Lanzamiento desacoplado y código de salida | **cumplido (§7)** | Escenario 1, test [S4] (test:252-255): el programa falso sale con 7 y deja un `sleep 5 &` con el log abierto; `exitOf` devuelve 7 en menos de 2 s. Escenario 2, en dos mitades: con el runtime real, `cmd /c exit 7` deja `# exit=7` y un `.exit` con 7 (T15 [P1] y headless [H2]); y el CLI imprime `log: <ruta>` y sale con el N del `.exit` (53 y 1) [H5a, H5b]. Desacople: mientras el CLI espera, el `sh` lanzado tiene PPID 1 y PGID 54727, el mismo que `start.exe`, `cmd.exe` y `ping`, y al final escribe el pie y el `.exit` [H3]. | Escenario 3 (cerrar la Terminal) y Ctrl-C: U6.2 y U6.1. `bodega run t cmd /c exit 7; echo $?` no se ejecutó literalmente con el CLI. Tras `stop`, N = 0 (§5.1). |
| R15 · Un log por ejecución | cumplido | Test `fake runtime cycle` [S4] (test:256-258): el log de `C:\Juegos\Mi Juego.exe` termina en `-Mi_Juego.log` y contiene `# exit=7`. Con el runtime real los nombres son `<UTC con µs>-<etiqueta>.log`: `…-wineboot.log`, `…-cmd.log`, `…-rundll32.log`, `…-cscript.log`, `2026-11-02T20-46-14.412988Z-nonexistent.log` (de `nonexistent.exe`) y `2026-11-02T20-46-19.356089Z-x.log` (de `C:\nope\x.exe`). Todos empiezan por `# runtime <id>`, `# cwd …` y `# argv …`, ninguno vuelca el entorno y todos contienen su `# exit=N` [H2, H5, H6, P1, P2]. Creación exclusiva y sin tope: código (`lib/engine.dart:360-363`) [T13-4]. | U3 lo repite con notepad. Sin ejercitar: el tope de 40 caracteres de la etiqueta (`lib/engine.dart:237`). |
| R16 · Pistas | cumplido | Test `hints` [S4] (test:272-291): el log con los 4 marcadores da 4 pistas (FreeType, GnuTLS, `bodega stop`, ruta) y el limpio ninguna. T15, sin hostlibs: el grupo `real runtime`, que exige las pistas de FreeType y GnuTLS (test:337-344), pasa; sus logs tienen 15 marcadores de FreeType y 6 de GnuTLS en wineboot, y 2 y 1 en la sonda de bcrypt [P1]. CLI: `run t 'C:\nope\x.exe'` → stderr `pista: Wine no pudo abrir el programa: revisa su ruta (trampa 11)` y exit 53, igual que su `.exit` [H5b]; un `create` limpio → 0 líneas `pista:` [H3a]. | Pistas tras un `create` que falla: solo código (`bin/bodega.dart:18-31`). |
| R17 · Workflow manual y barato | **parcial** | Configuración [C7]: solo `workflow_dispatch`, con `publish_release` (booleano) y `ref_note`; `contents: write`; `runs-on: macos-15-intel`, igual que `build.yml:22`; `timeout-minutes: 15`; las 4 `HOMEBREW_*` y `ROOTS`; `install` con `timeout-minutes: 5`; sin checkout ni build de Wine. Escenario 1 [C1, C2]: run 41512345512 con `conclusion=success`, job de 43 s con `labels=["macos-15-intel"]`; la guarda imprime `freetype 2.14.3` y `gnutls 3.8.13_2`, e `install` solo vierte `molten-vk--1.4.2.sonoma.bottle.tar.gz`. Lo que corrió es el YAML del commit 8a00dea, que es `HEAD` y `origin/main` de `BE` [C6, C7]. | Escenario 2 (con una imagen sin freetype o gnutls, el job falla en segundos con el mensaje): no se ejecutó y ningún paso U lo cubre. Solo constan el texto de la guarda y su camino positivo. |
| R18 · Cierre y nombres | cumplido | Paso `bundle` verde (12 s). Imprime `x86_64-unix: [...]` con 12 hojas, una línea que va después de `assert not left, left` (YAML:78-80), así que la aserción pasó [C3]. Escenario, sobre el artefacto publicado [C11]: ninguna referencia fuera de `@loader_path/`, `/usr/lib/` y `/System/`; cada `.dylib` con `id=@loader_path/<hoja>`, x86_64, `Signature=adhoc` y `verify=valid`. La copia instalada en T16 da lo mismo [P4]. Las raíces llegan por argumento (`python3 - $ROOTS`) y el cierre no tiene SDL2, FFmpeg ni GStreamer [C3]. | La salida de T2 no forma parte de esta evidencia (T2 se cerró en `apply`). |
| R19 · Sonda de carga por nombre hoja | cumplido | Paso `probe` verde (3 s) en `macos-15-intel` [C4]. Sus 3 últimas líneas son el `grep -F` de cada raíz, cargada desde `/Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/`. De 605 imágenes únicas, 424 son de `/System/`, 167 de `/usr/lib/`, 13 de `out/…/x86_64-unix/` (12 `.dylib` y `probe.so`) y 1 es el ejecutable; 0 líneas con `/usr/local`, el prefijo de Homebrew Intel (ver `Cellar` en [C2]), ni con `/opt/homebrew`. El montaje ejecutado (`-Wl,-rpath,@loader_path/`, ejecutable sin rpath, `env -i`, `cd /`, log en `$RUNNER_TEMP`) es el del YAML [C4, C6]. | La salida de T2 no forma parte de esta evidencia. |
| R20 · Artefacto | cumplido | Escenario [C10]: `tar -tzf … \| grep -E '/$\|^\./'` no da nada (exit 1). Hay 13 entradas, todas archivos: `hostlibs.txt` y `engine/lib/wine/x86_64-unix/*.dylib`. `hostlibs.txt` lleva el nombre, `runner image: macos15 20260824.0482.1`, `brew list --versions` y los 12 archivos. Pesa 5121991 B (< 30 MiB), con la aserción del CI pasada [C5]. Nombre `hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz`, con la nota por `env` (`NOTE: primer-hostlibs`) [C5]. `.sha256` con el formato `<hex>  <nombre>`, igual que el del motor [C10]; `shasum -c` OK y digest igual al del asset [C9]. Release: tag = nombre del archivo, autor `github-actions[bot]`, creada por `publish` con `GH_TOKEN` y `GH_REPO` [C5, C8]. | Sin ejercitar: el saneado de `ref_note` (`primer-hostlibs` no tiene nada que cambiar). |
| R21 · Consumo sin variables | **cumplido (§7)** | Escenario 1: con hostlibs, 0 marcadores de FreeType o GnuTLS y 0 `mvk-info`/`Failed to load libMoltenVK` en los 5 logs de T16 (wineboot, `cmd /c set`, las dos sondas `rundll32` y `cscript`) y en los de su repetición; el paso 6 literal de T16 da `0` [P2, P5]. El grupo `real runtime` con hostlibs, que exige que no haya pistas, pasa, y sus 5 logs dan 0 [H2]. Escenario 2: T15, sin hostlibs, da las dos pistas y `Failed to load libMoltenVK.dylib`, con dyld buscando en `…/t15-rt/engine/lib/wine/x86_64-unix/libMoltenVK.dylib` [P1]. Escenario 3: `cscript //nologo C:\https.js` → `status=200` y `.exit` 0 [P2]. Escenario 4, sin ventana, en el Apple M2 Pro [V1]: `lsof` muestra `libfreetype.6.dylib` y `libpng16.16.dylib` cargadas desde `<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/` en `start.exe`, `plugplay.exe`, `winedevice.exe` y `cmd.exe`, lanzados por `build/bodega` con un entorno sin `DYLD_*` (R12) [H3]. Mecanismo: `win32u.so`, `dwrite.so`, `bcrypt.so`, `crypt32.so` y `secur32.so` llevan `LC_RPATH @loader_path/`, y el loader `wine` ninguno [C12]. | U3: glifos dibujados con FreeType y `lsof` de notepad. |

## 3. Salidas que respaldan cada estado

### 3.1 Grupo `static-unit-cli`

Evidencia en `$SCR/verify-static-unit-cli-20261102T202728Z` (`00-environment.txt` … `15-pubspec.txt`), del 2026-11-02 entre las 20:29 y las 20:36 UTC. Por las reglas de verify, los `BODEGA_HOME` de T13 son carpetas nuevas dentro de esa evidencia y no `$(mktemp -d)` en `$TMPDIR`; el check del uso también lleva una, para probar que no se crea nada. El sentido de cada comprobación de T13 no cambia. Los rótulos `---- Xn` de `09-extra-cli.txt` no coinciden con los ids `[Xn]` de este informe.

**Entorno**
```
## sw_vers / uname -m
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
arm64
## which dart / dart --version
/opt/homebrew/bin/dart
Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"
## inherited BODEGA_* / WINE* / TMPDIR (values of WINE* redacted to presence only)
(no BODEGA_* variables set)
WINEPREFIX=<set>
TMPDIR=/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/
```

**[S1] Dependencias** (T5; R2, sin dependencias de ejecución)
```
$ (cd P &&) dart pub get --offline
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 96.0.0 (107.0.0 available)
  analyzer 10.2.0 (14.3.0 available)
  package_config 2.2.0 (3.0.0 available)
Got dependencies!
3 packages have newer versions incompatible with dependency constraints.
Try `dart pub outdated` for more information.
[exit=0]
$ (cd P &&) cat pubspec.yaml
name: engine
publish_to: none

environment:
  sdk: ^3.13.0

dev_dependencies:
  test: ^1.31.1
[exit=0]
```
`pubspec.lock` no cambia: `efbc8199…` antes y después [POST].

**[S2] Análisis** (T5)
```
$ (cd P &&) dart analyze
Analyzing engine...
No issues found!
[exit=0]
```

**[S3] Formato** (higiene; no respalda ningún requisito)
```
$ (cd P &&) dart format --output=none --set-exit-if-changed lib bin test
Formatted 3 files (0 changed) in 0.01 seconds.
[exit=0]
```

**[S4] Tests sin Wine** (T6–T12 y T14)
```
## $TMPDIR bodega* entries BEFORE
(eval):4: no matches found: /var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega*
(none)
## BODEGA_TEST_RUNTIME=<unset>
$ (cd P &&) dart test
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: wineEnv is hermetic
00:00 +1: test/engine_test.dart: names and windows paths
00:00 +2: test/engine_test.dart: installRuntime
00:01 +3: test/engine_test.dart: fake runtime cycle
00:02 +4: test/engine_test.dart: hints
00:02 +5: test/engine_test.dart: real runtime cycle
  Skip: BODEGA_TEST_RUNTIME no está definida
00:02 +5 ~1: All tests passed!
[exit=0]  wall=3s
## $TMPDIR bodega* entries AFTER
(eval):10: no matches found: /var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega*
(none)
```
Qué da por pasado esta salida, según la línea `Comprobación` de cada spec:
- `wineEnv is hermetic` (test:83-118) → R12, escenarios 1 y 2.
- `names and windows paths` (test:120-152) → R1 y R8.
- `installRuntime` (test:154-216) → R4, R5, R6 y R7.
- `fake runtime cycle` (test:218-270) → R8 (botella inexistente), R9, R10, R11, R13, R14 y R15.
- `hints` (test:272-291) → R16.
- `real runtime cycle`, saltado con su motivo → T14. Sus aserciones con el runtime real están en [H2] y [P1].

**[S5] Compilación, tipo y firma** (R2; T13)
```
## pre-check: processes executing build/bodega
(none)
$ (cd P &&) mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega
Generated: /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
[exit=0]
## build/bodega AFTER recompile
-rwxr-xr-x@ 1 quasar  staff  6010208 Nov  2 15:30 /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
(before: e39ad46d1e2ded29b3a21650409d7964c81249b0bc26c1a043be0485c4b75bb0, 6010208 bytes, 14:15)
$ (cd B &&) file build/bodega
build/bodega: Mach-O 64-bit executable arm64
[exit=0]
$ (cd B &&) codesign -dv build/bodega
Executable=/Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
Identifier=bodega-555549444c4c440155553144a107cc88f2ac6917
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=11944 flags=0x20002(adhoc,linker-signed) hashes=367+2 location=embedded
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements count=0 size=12
[exit=0]
$ (cd B &&) otool -L build/bodega
build/bodega:
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 61123.100.169)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 2420.0.0)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 2420.0.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 1226.0.0)
[exit=0]
$ (cd B &&) codesign --verify --strict --verbose=2 build/bodega
build/bodega: valid on disk
build/bodega: satisfies its Designated Requirement
[exit=0]
```

**[T13-1] Sin argumentos** (R2)
```
---- T13.1 no arguments -> usage on stderr, 64
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>
[exit=64]
post: ls -ld $U
ls: $SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist: No such file or directory
```

**[T13-2] Nombre no válido** (R2, R8; R1, raíz válida; R3, caso positivo)
```
---- T13.2 invalid bottle name 'a b' -> 1
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-ab.wvnuTE build/bodega create a b
[stdout]
[stderr]
bodega: nombre de botella no válido: "a b" (letras, números, _ y -, hasta 64, sin empezar por _ ni -)
[exit=1]
```
El registro del comando perdió las comillas: el mensaje muestra que llegó un solo argumento, `"a b"` (con dos, el patrón no casaría y saldría el uso con 64). Estado de esa raíz, listado al redactar sin seguir enlaces:
```
$ ls -A h-ab.wvnuTE
bottles
runtimes
[exit=0]
$ ls -A h-ab.wvnuTE/bottles
[exit=0]
```

**[T13-3] Raíz con un componente `a.`** (R1, R2; R3, caso positivo)
```
---- T13.3 root with component 'a.' -> 1, names it
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-dot.p6KgMF/a./b build/bodega stop x
[stdout]
[stderr]
bodega: "a." en $SCR/verify-static-unit-cli-20261102T202728Z/h-dot.p6KgMF/a./b: Windows no admite nombres que acaben en punto o espacio ni que lleven <>:"|?*
[exit=1]
post: ls -A $H0 (must be empty: rejected root not created)
(ls exit=0)
```
Repetido al redactar: `ls -A h-dot.p6KgMF` → nada, `[exit=0]`.

**[T13-4] Marcas `ponytail:`** (T13; R10, R11, R12, R15 y design §7)
```
$ (cd P &&) cat lib/engine.dart bin/bodega.dart | grep -c 'ponytail:'
6
[exit=0]
$ (cd P &&) grep -n 'ponytail:' lib/engine.dart bin/bodega.dart
lib/engine.dart:69:  // ponytail: BODEGA_WINEDEBUG is the only knob read from the caller.
lib/engine.dart:150:  // ponytail: one global runtime; installing another while bottles run gives
lib/engine.dart:194:  // ponytail: syswow64 is not repaired (Highball copies i386-windows); in a
lib/engine.dart:256:  // ponytail: no reaper; whatever survives -k (trap 6) stays, and acceptance
lib/engine.dart:266:  // ponytail: no timeout; if the shell dies by SIGKILL there is no .exit and
lib/engine.dart:360:  // ponytail: no size cap or rotation; patch 0014 fixed the known runaway log
[exit=0]
```
Están las cinco simplificaciones que pide T13 (`:360`, `:69`, `:256`, `:194`, `:150`) y una más (`:266`).

**[X2] Verbo desconocido y aridad incorrecta** (R2)
```
---- X1 unknown verb -> usage, 64 (R2)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega frobnicate x
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>
[exit=64]
---- X2 wrong arity 'install' with 1 arg -> usage, 64 (R2)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega install only-one.tar.gz
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[…las otras 4 líneas del uso, iguales]
[exit=64]
post: ls -ld $U
ls: $SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist: No such file or directory
```

**[X3] Botella inexistente** (R8; R2)
```
---- X3 stop on missing bottle (R8)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega stop x
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
---- X4 wait on missing bottle (R8)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega wait x
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
---- X5 run on missing bottle (R8; program never reached)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega run x cmd /c echo ok
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
```

**[X4] Sin runtime instalado** (R7; R9, paso 1)
```
---- X6 create with no runtime installed (R7, R9.1)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega create x
[stdout]
[stderr]
bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[exit=1]
post: ls -A $H/bottles (must be empty)
(ls exit=0)
---- X7 stop on existing bottle dir but no runtime (R7)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega stop y
[stdout]
[stderr]
bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[exit=1]
```
Antes de `stop y` el check creó `bottles/y` a mano: que salga `no hay runtime` y no `no existe la botella y` lo confirma, porque `stopBottle` mira la botella antes que el runtime (`lib/engine.dart:255-258`).

**[X5] `install` sin `.sha256`** (R4)
```
---- X8 install without .sha256 (R4)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega install $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/engine-zz.tar.gz $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/hostlibs-zz.tar.gz
[stdout]
[stderr]
bodega: falta $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/engine-zz.tar.gz.sha256: gh release download engine-zz -R dany021115/bodega-engine
[exit=1]
post: ls -A $H/runtimes (must be empty: nothing new, no .tmp-*)
(ls exit=0)
```
`nofiles/` no existe (`ls -ld …/nofiles` → `No such file or directory`), así que aquí falta también el tarball; el caso con el tarball presente lo cubre el test (test:190-196).

**[X6] Búsquedas en el código** (R4, R12, R2; design §2)
```
$ (cd P &&) grep -rn HttpClient lib bin
[exit=1]  (1 = no match)
$ (cd P &&) grep -n '^import' lib/engine.dart bin/bodega.dart
bin/bodega.dart:1:import 'dart:io';
bin/bodega.dart:3:import 'package:engine/engine.dart';
lib/engine.dart:5:import 'dart:convert';
lib/engine.dart:6:import 'dart:io';
[exit=0]
$ (cd P &&) grep -nE 'Process\.(start|run)\(|includeParentEnvironment|^Future<String> _run' lib/engine.dart bin/bodega.dart
lib/engine.dart:124:    await Process.run('/usr/bin/xattr', [
lib/engine.dart:136:    final version = await Process.run(
lib/engine.dart:140:      includeParentEnvironment: false,
lib/engine.dart:326:}) => Process.start(
lib/engine.dart:331:  includeParentEnvironment: false,
lib/engine.dart:336:  final server = await Process.start(
lib/engine.dart:340:    includeParentEnvironment: false,
lib/engine.dart:372:Future<String> _run(String exe, List<String> args, [String? cwd]) async {
lib/engine.dart:373:  final result = await Process.run(exe, args, workingDirectory: cwd);
bin/bodega.dart:50:    final rosetta = await Process.run('/usr/bin/arch', [
[exit=0]
$ (cd P &&) grep -nE "_run\('" lib/engine.dart
107:    final out = await _run('/usr/bin/shasum', [
122:      await _run('/usr/bin/tar', ['-xzf', tarball, '-C', tmp.path]);
[exit=0]
$ (cd P &&) grep -n 'environment: wineEnv' lib/engine.dart
139:      environment: wineEnv('${tmp.path}/prefix', Platform.environment),
330:  environment: wineEnv(prefix, Platform.environment),
339:    environment: wineEnv(prefix, Platform.environment),
[exit=0]
```
`:136` es `wine --version`, `:326` el `/bin/sh` de `_start` y `:336` el `wineserver`. `Process.run` solo se usa con `xattr`, `wine --version`, `shasum`, `tar` y `arch`.

**[X7] Rosetta** (R3, revisión del código y caso positivo)
```
$ (cd P &&) grep -nE 'verb == null|exitCode = 64|/usr/bin/arch|falta Rosetta|bodegaHome\(Platform|exitCode = 1' bin/bodega.dart
44:  if (verb == null) {
46:    exitCode = 64;
50:    final rosetta = await Process.run('/usr/bin/arch', [
55:      throw 'falta Rosetta: '
58:    exitCode = await verb(bodegaHome(Platform.environment));
61:    exitCode = 1;
[exit=0]
$ /usr/bin/arch -x86_64 /usr/bin/true
[exit=0]
$ (cd P &&) sed -n '44,62p' bin/bodega.dart
  if (verb == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final rosetta = await Process.run('/usr/bin/arch', [
      '-x86_64',
      '/usr/bin/true',
    ]);
    if (rosetta.exitCode != 0) {
      throw 'falta Rosetta: '
          'softwareupdate --install-rosetta --agree-to-license';
    }
    exitCode = await verb(bodegaHome(Platform.environment));
  } catch (e) {
    stderr.writeln('bodega: ${e is FormatException ? e.message : e}');
    exitCode = 1;
  }
```
Un verbo desconocido sale con el uso antes de la sonda; con uno válido, la sonda va antes de `bodegaHome()`, que es lo que crea la raíz, y antes del verbo.

**[X8] Reproducibilidad del build** (identidad del binario; ver §5.5)
```
$ (cd P &&) dart compile exe bin/bodega.dart -o $EV/repro/bodega
Generated: $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
[exit=0]
## sizes / hashes
-rwxr-xr-x@ 1 quasar  wheel  6010208 Nov  2 15:35 $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
-rwxr-xr-x@ 1 quasar  staff  6010208 Nov  2 15:30 /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
6d7bab0a893d5d223f9595c5a7baaa7927bf3b7083c3d2eeab9f7575b26ce701  $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
## differing bytes: cmp -l build/bodega repro/bodega | wc -l
     101
## LC_UUID
[…]    uuid 4C4C4401-5555-3144-A107-CC88F2AC6917   (los dos)
## clusters of differing bytes (offsets decimal, gap>4096 starts a new cluster)
  5922298..5922303 (5 bytes)
  5932001..5932032 (32 bytes)
  6009981..6010044 (64 bytes)
## where: __LINKEDIT / code signature offsets
  dataoff 5998192
 datasize 12016
  fileoff 5947392
[…]
```

**[POST] Estado al terminar el grupo**
```
## source hashes BEFORE (00-environment.txt)
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
## source hashes AFTER (12-post-state.txt)
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
## all processes whose command mentions CrossOver (pid ppid start command, args trimmed to 160 chars)
  PID  PPID STARTED                      COMMAND
47400     1 Mon Nov  2 15:32:21 2026     /Users/quasar/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/../../bin/wineserver
79727     1 Fri Oct 30 15:11:15 2026     /Users/quasar/Applications/CrossOver.app/Contents/MacOS/CrossOver
## does bodega code reference CrossOver / an absolute wineserver path?
$ (cd P &&) grep -rniE 'crossover|Applications/' lib bin
[exit=1]  (1 = no match)
## timeline of this verification (evidence file mtimes, local time)
[…]
15:31:42  10-static-extras.txt
15:35:23  11-repro-and-code.txt
[…]
## creation (birth) and mtime of repro/ dir and repro/bodega (block 11's first write; local time)
birth 15:35:22  mtime 15:35:22  repro
birth 15:35:22  mtime 15:35:22  repro/bodega
```
Al redactar, las raíces de este grupo siguen sin runtime, así que ninguna invocación pudo resolver un `wine` o un `wineserver`:
```
$ ls -A h-ab.wvnuTE/runtimes
[exit=0]
$ ls -A h-x.Wg78U7/runtimes
[exit=0]
```
Los hashes coinciden también al redactar [V1]: lo verificado es el código que hay ahora.

### 3.2 Grupo `headless-runtime`

Evidencia en `$SCR/verify-headless-evidence-20261102T203816Z`, del 2026-11-02 entre las 20:38 y las 20:47 UTC. `<H>` = `$SCR/verify-headless-home-20261102T203816Z`, nueva (no existía) y borrada en [H6]. El binario es el `build/bodega` recompilado en [S5] (`7c10f6ab…`). Los tarballs son los de `RT` y las hostlibs de T4.

**[H1] `install` con los tarballs reales** (R1, R2, R3 positivo, R4, R5, R7; R20, consumo del tarball)
```
$ cd B && BODEGA_HOME=<H> /usr/bin/time -p build/bodega install /Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine-wine-11.0-20261030T202616Z-primer-build.tar.gz /Users/quasar/Documents/GitHub/Bodega/runtimes/hostlibs-x86_64-20261102T194229Z-primer-hostlibs/hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
start=2026-11-02T20:38:24Z
exit=0
end=2026-11-02T20:38:28Z
== stdout
<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
== stderr
real 4.28
user 2.16
sys 1.26
== runtimes/
lrwxr-xr-x  current -> engine-wine-11.0-20261030T202616Z-primer-build
drwxr-xr-x  engine-wine-11.0-20261030T202616Z-primer-build
== x86_64-unix dylibs
libfreetype.6.dylib libgmp.10.dylib libgnutls.30.dylib libhogweed.7.dylib libidn2.0.dylib libintl.8.dylib libMoltenVK.dylib libnettle.9.dylib libp11-kit.0.dylib libpng16.16.dylib libtasn1.6.dylib libunistring.5.dylib
974M  <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
.tmp-* entries in runtimes/: 0 ; bottles/ entries: 0
```

**[H2] Grupo `real runtime` con hostlibs** (R7, R9, R10, R11, R13, R14, R15, R16, R21)
```
$ cd P && TMPDIR=$SCR/verify-headless-tmpdir-20261102T203816Z BODEGA_TEST_RUNTIME=<H>/runtimes/current dart test -N 'real runtime'
start=2026-11-02T20:39:05Z
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: real runtime (setUpAll)
00:00 +0: test/engine_test.dart: real runtime cycle
create: 0:00:19.454293
00:25 +1: test/engine_test.dart: real runtime (tearDownAll)
00:25 +1: All tests passed!
end=2026-11-02T20:39:31Z
rc=0
```
El runtime tiene `x86_64-unix/libgnutls.30.dylib`, así que el test tomó la rama que exige que no haya pistas de FreeType ni de GnuTLS (test:337-344). Logs copiados antes de que `tearDownAll` borrara su raíz (`2-test-logs/`):
```
== 2026-11-02T20-39-25.432780Z-cmd.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv cmd /c echo ok
msync: bootstrapped mach port on wine-4c4a479-msync.
msync: up and running.
009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
ok
# exit=0
== 2026-11-02T20-39-27.850869Z-cmd.log (.exit 7)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv cmd /c exit 7
# exit=7
== 2026-11-02T20-39-28.496377Z-rundll32.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv rundll32 dwrite.dll,BodegaProbe
00f8:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"dwrite.dll"
# exit=0
== 2026-11-02T20-39-30.132522Z-rundll32.log (.exit 0)
[…cabecera igual]
# argv rundll32 bcrypt.dll,BodegaProbe
0144:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
== markers (cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK) count per log:
...20-39-05.974359Z-wineboot.log:0
...20-39-28.496377Z-rundll32.log:0
...20-39-27.850869Z-cmd.log:0
...20-39-25.432780Z-cmd.log:0
...20-39-30.132522Z-rundll32.log:0
== TMPD after test: empty (test home deleted by tearDownAll)
== pgrep -fl "<H>|<TMPD>": (none)
```
`Unable to find the entry point L"BodegaProbe"` es lo esperado: la sonda solo necesita que `DllMain` cargue la biblioteca (design §6).

**[H3a] `create t`** (R2, R8, R9, R10, R15; R16 y R21, sin pistas)
```
$ BODEGA_HOME=<H> /usr/bin/time -p build/bodega create t
start=2026-11-02T20:40:11Z
exit=0
end=2026-11-02T20:40:23Z
== stdout
log: <H>/bottles/t/logs/2026-11-02T20-40-11.179908Z-wineboot.log
== stderr
real 12.52
user 0.13
sys 0.11
== pista lines: 0
== ready files
-rw-r--r--  889967  <H>/bottles/t/prefix/drive_c/windows/syswow64/kernel32.dll
-rw-r--r-- 3354095  <H>/bottles/t/prefix/system.reg
== processes referencing H after create (wineserver -w returned):
(none)
== 6-bottle-t-logs/2026-11-02T20-40-11.179908Z-wineboot.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd <H>/bottles/t
# argv wineboot
wine: created the configuration directory '<H>/bottles/t/prefix'
msync: bootstrapped mach port on wine-4c4ae29-msync.
msync: up and running.
[…11 líneas err:ole, err:setupapi y err:ntoskrnl (winebth)]
# exit=0
```

**[H3] `stop` en vivo** (R11, R12, R13, R14, R15, R21). `3-live-stop.py` lanza `run` y lo deja esperando, como en una Terminal; cuando el wineserver de la botella está vivo, fotografía los procesos y ejecuta `stop`, consultando `ps` cada 100 ms.
```
launch 2026-11-02T20:45:15Z BODEGA_HOME=<H> bodega run t cmd /c 'ping -n 120 127.0.0.1'
run printed: log: <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log
alive check at +12.2s after launch, 2026-11-02T20:45:27Z
run CLI still waiting: True | .exit exists: False
--- pgrep -fl <H>
54728 /bin/sh -c l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s bodega <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/bin/wine cmd /c ping -n 120 127.0.0.1
54732 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/../../bin/wineserver
--- prefix dev/ino -> wineserver dir /tmp/.wine-501/server-100000d-4c4ae29
--- 10 processes whose open files/mappings mention <H> (lsof):
  PID  PPID  PGID STAT ELAPSED COMMAND
54728     1 54727 S      00:12 /bin/sh -c l=$1; shift; […]
54729 54728 54727 S      00:12 start.exe /exec cmd /c
54732     1 54732 Ss     00:12 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/../../bin/wineserver
54736     1 54736 Ss     00:12 C:\windows\system32\services.exe 
54738     1 54738 Ss     00:11 C:\windows\system32\winedevice.exe 
54740     1 54740 Ss     00:11 C:\windows\system32\plugplay.exe 
54751     1 54751 Ss     00:11 C:\windows\system32\svchost.exe -k LocalServiceNetworkRestricted 
54753     1 54753 Ss     00:11 C:\windows\system32\winedevice.exe 
54755     1 54727 S      00:10 C:\windows\system32\cmd.exe /c ping -n 120 127.0.0.1 
54757     1 54727 S      00:10 ping -n 120 127.0.0.1
[…]
wineserver pid 54732 cwd: wineserve 54732 quasar  cwd    DIR   1,13      192 79998510 /private/tmp/.wine-501/server-100000d-4c4ae29 | matches prefix server dir: True
--- stop at +12.7s after launch, 2026-11-02T20:45:27Z
stop: exit=0 returned at +0.25s stdout='' stderr=''
  pid  54753 gone at +0.13s  C:\windows\system32\winedevice.exe 
  pid  54755 gone at +0.13s  C:\windows\system32\cmd.exe /c ping -n 120 127.0.0.1 
  pid  54757 gone at +0.13s  ping -n 120 127.0.0.1 
  pid  54728 gone at +0.13s  /bin/sh -c l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "
  pid  54729 gone at +0.13s  start.exe /exec cmd /c
  pid  54732 gone at +0.13s  $SCR/veri
  pid  54736 gone at +0.13s  C:\windows\system32\services.exe 
  pid  54738 gone at +0.13s  C:\windows\system32\winedevice.exe 
  pid  54740 gone at +0.13s  C:\windows\system32\plugplay.exe 
  pid  54751 gone at +0.13s  C:\windows\system32\svchost.exe -k LocalServiceNetworkRestricted 
last tracked process gone at +0.13s; wineserver gone at +0.13s
waiting run CLI: exit=0 returned at +0.38s after stop
.exit file: 2026-11-02T20-45-15.066826Z-cmd.exit -> 0
log has "# exit=" lines: ['# exit=0'] | "Reply from" lines: 0 | log has "Ping statistics": False
[…]
run stdout: log: <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log
run stderr: ''
launch -> run returned: 13.1s (ping -n 120 alone would need >= 119 s)
--- wait t: exit=0 in 0.036s stdout='' stderr=''
--- pgrep -fl <H> after stop+wait:
(none)
--- processes with open files/mappings under <H> (lsof): (none)
```
Líneas de hostlibs en la foto de `lsof` tomada antes del `stop` (`3-lsof-before.txt`, filtrada a `<H>` por el script), consultadas al redactar:
```
$ grep -nE 'libfreetype|libgnutls|libMoltenVK' 3-lsof-before.txt
20:start.exe 54729 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
249:plugplay. 54740 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
309:winedevic 54753 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
350:cmd.exe   54755 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
$ grep -E 'x86_64-unix/lib[^/]+\.dylib' 3-lsof-before.txt | awk '{print $NF}' | sort | uniq -c
   4 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
   4 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libpng16.16.dylib
$ head -3 3-lsof-before.txt   (primera línea)
bash      54728 quasar  cwd       DIR               1,13        224            79998507 <H>/bottles/t/prefix/drive_c
```
Primer intento, con el mismo resultado (su sonda esperaba un proceso titulado `ping.exe`, agotó los 90 s y su limpieza ejecutó `bodega stop t`; §5.9):
```
launch 2026-11-02T20:41:29Z BODEGA_HOME=<H> bodega run t cmd /c 'ping -n 120 127.0.0.1'
run printed: log: <H>/bottles/t/logs/2026-11-02T20-41-29.185096Z-cmd.log
[…]
FAIL: ping.exe or wineserver not seen within 90 s -> cleanup: bodega stop t = 0
$ (al redactar) cabecera y cola de 6-bottle-t-logs/2026-11-02T20-41-29.185096Z-cmd.log, grep -c y stat del .exit
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd <H>/bottles/t/prefix/drive_c
# argv cmd /c ping -n 120 127.0.0.1
[…]
Reply from 127.0.0.1: bytes=32 time<1ms TTL=64
R# exit=0
Reply-from lines: 86  Ping statistics lines: 0
2026-11-02T15:42:59-0500 …/6-bottle-t-logs/2026-11-02T20-41-29.185096Z-cmd.exit   (contenido: 0)
```

**[H4] `wait` justo después del `stop`** (R11): la línea `--- wait t: exit=0 in 0.036s stdout='' stderr=''` de [H3].

**[H5] Fallos a propósito** (R2, R8, R13, R14, R15, R16; `5-failures.txt`)
```
=== bodega run t nonexistent.exe
exit=1 in 4.95s
stdout: 'log: <H>/bottles/t/logs/2026-11-02T20-46-14.412988Z-nonexistent.log\n'
stderr: ''
new files in bottles/t/logs: ['2026-11-02T20-46-14.412988Z-nonexistent.exit', '2026-11-02T20-46-14.412988Z-nonexistent.log']
  2026-11-02T20-46-14.412988Z-nonexistent.exit -> 1
  2026-11-02T20-46-14.412988Z-nonexistent.log:
   | # runtime engine-wine-11.0-20261030T202616Z-primer-build
   | # cwd <H>/bottles/t/prefix/drive_c
   | # argv nonexistent.exe
   | msync: bootstrapped mach port on wine-4c4ae29-msync.
   | msync: up and running.
   | 009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
   | Application could not be started, or no application associated with the specified file.
   | ShellExecuteEx failed: Environment variable not found.
   | # exit=1
=== bodega run t C:\nope\x.exe
exit=53 in 0.41s
stdout: 'log: <H>/bottles/t/logs/2026-11-02T20-46-19.356089Z-x.log\n'
stderr: 'pista: Wine no pudo abrir el programa: revisa su ruta (trampa 11)\n'
new files in bottles/t/logs: ['2026-11-02T20-46-19.356089Z-x.exit', '2026-11-02T20-46-19.356089Z-x.log']
  2026-11-02T20-46-19.356089Z-x.exit -> 53
  2026-11-02T20-46-19.356089Z-x.log:
   | # runtime engine-wine-11.0-20261030T202616Z-primer-build
   | # cwd <H>/bottles/t/prefix/drive_c
   | # argv C:\nope\x.exe
   | wine: failed to open "C:\\nope\\x.exe"
   | # exit=53
=== bodega run t /nonexistent/x.exe
exit=1 in 0.03s
stdout: ''
stderr: "bodega: FileSystemException: Cannot resolve symbolic links, path = '/nonexistent/x.exe' (OS Error: No such file or directory, errno = 2)\n"
new files in bottles/t/logs: none
=== bodega run nope cmd /c echo hi
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bodega wait nope
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bodega stop nope
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bottles/ now: ['t']
```
`[H5a]` es el primer caso, `[H5b]` el segundo, `[H5c]` el tercero y `[H5d]` los tres últimos.

**[H6] Limpieza** (R11, `stop` sin servidor; design §6)
```
== 6.1 bodega stop t
real 0.04
user 0.01
sys 0.01
exit=0
== 6.2 pgrep -fl <H> after stop
(none)
== 6.3 lsof (system-wide) lines mentioning <H>: 0
== 6.4 copy logs/ (+ .exit) to evidence
[…10 archivos: wineboot, cmd (intento 1), cmd (stop en vivo), nonexistent y x, cada uno con su .log y su .exit]
== 6.5 du -sh <H> before rm
1.5G	<H>
== 6.6 rm -rf <H>
rm exit=0
ls: <H>: No such file or directory
== 6.7 pgrep -fl verify-headless-home-20261102T203816Z after rm
(none)
== 6.8 lsof lines mentioning verify-headless-home-20261102T203816Z: 0
== TMPDIR used by the test group:
[…vacío]
(no process references it)
rmdir ok
== unrelated CrossOver processes (start times, local):
77714 Fri Oct 30 15:10:47 2026     C:\windows\system32\winedevice.exe 
79727 Fri Oct 30 15:11:15 2026     /Users/quasar/Applications/CrossOver.app/Contents/MacOS/CrossOver
== stale wineserver dir of the deleted prefix:
drwx------@ 3 quasar  wheel  96 Nov  2 15:46 /private/tmp/.wine-501/server-100000d-4c4ae29
```
El wineserver que dejaron [H5a] y [H5b] ya había terminado solo, así que este `stop` tomó el camino sin servidor; el `stop` con servidor es [H3].

### 3.3 Grupo `ci-evidence`

Evidencia en `$SCR/verify-ci-evidence-20261102`, que guarda una copia completa del log del run 41512345512 (`run-41512345512.log`, 1661 líneas). Las líneas del log van sin códigos ANSI y se ha quitado un glifo decorativo de Homebrew.

**[C1] Run y job** (R17, escenario 1; T3)
```
$ gh run view 41512345512 -R dany021115/bodega-engine --json conclusion,jobs,createdAt,updatedAt   (duraciones calculadas a partir de ahí)
run: conclusion=success createdAt=2026-11-02T19:41:54Z updatedAt=2026-11-02T19:42:45Z wall=51s
job build (125507111934): status=completed conclusion=success startedAt=2026-11-02T19:42:01Z completedAt=2026-11-02T19:42:44Z duration=43s
  1. Set up job                       success     1s
  2. guard                            success     4s
  3. install                          success     6s
  4. bundle                           success    12s
  5. probe                            success     3s
  6. tarball                          success     4s
  7. Run actions/upload-artifact@v4   success     3s
  8. publish                          success     5s
  9. Complete job                     success     0s
$ gh api repos/dany021115/bodega-engine/actions/jobs/125507111934 ; gh api repos/dany021115/bodega-engine/actions/runs
labels=["macos-15-intel"] runner_name=GitHub Actions 1000000439 runner_group=GitHub Actions head_sha=8a00dea8a08f5fa71444384113d28ce3b9bef1c9 head_branch=main workflow_name=build-hostlibs run_attempt=1
id=41512345512 path=.github/workflows/build-hostlibs.yml event=workflow_dispatch head_branch=main actor=dany021115 triggering_actor=dany021115
```

**[C2] `Set up job`, `guard` e `install`** (R17)
```
build	Set up job	2026-11-02T19:42:03.2082640Z Image: macos-15
build	Set up job	2026-11-02T19:42:03.2083630Z Version: 20260824.0482.1
build	Set up job	2026-11-02T19:42:03.2102840Z Contents: write
build	guard	2026-11-02T19:42:04.4737950Z ##[group]Run brew list --versions freetype gnutls || { echo 'runner image lacks freetype/gnutls; would build from source'; exit 1; }
build	guard	2026-11-02T19:42:04.4859230Z shell: /bin/bash -e {0}
build	guard	2026-11-02T19:42:04.4861190Z env:
build	guard	2026-11-02T19:42:04.4862270Z   HOMEBREW_NO_AUTO_UPDATE: 1
build	guard	2026-11-02T19:42:04.4866050Z   HOMEBREW_NO_INSTALL_UPGRADE: 1
build	guard	2026-11-02T19:42:04.4867910Z   HOMEBREW_NO_INSTALL_CLEANUP: 1
build	guard	2026-11-02T19:42:04.4869550Z   HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: 1
build	guard	2026-11-02T19:42:04.4871570Z   ROOTS: libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib
build	guard	2026-11-02T19:42:08.9729960Z freetype 2.14.3
build	guard	2026-11-02T19:42:08.9732430Z gnutls 3.8.13_2
build	install	2026-11-02T19:42:09.0077360Z ##[group]Run brew install freetype gnutls molten-vk
build	install	2026-11-02T19:42:10.9197720Z Warning: freetype 2.14.3 is already installed and up-to-date.
build	install	2026-11-02T19:42:10.9273240Z Warning: gnutls 3.8.13_2 is already installed and up-to-date.
build	install	2026-11-02T19:42:11.3169840Z ==> Would install 1 formula:
build	install	2026-11-02T19:42:14.1168050Z ==> Pouring molten-vk--1.4.2.sonoma.bottle.tar.gz
build	install	2026-11-02T19:42:14.8435160Z /usr/local/Cellar/molten-vk/1.4.2: 84 files, 92.2MB
```
`install` va de 19:42:08 a 19:42:14 (6 s) sin ninguna línea de compilación desde fuente; el `Cellar` en `/usr/local` es el de Homebrew Intel.

**[C3] `bundle`** (R18)
```
build	bundle	2026-11-02T19:42:14.8879650Z ##[group]Run python3 - $ROOTS <<'PY'
build	bundle	2026-11-02T19:42:14.9049300Z shell: /bin/bash -e {0}
[…]
build	bundle	2026-11-02T19:42:14.9053530Z   ROOTS: libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib
build	bundle	2026-11-02T19:42:26.4660220Z x86_64-unix: ['libMoltenVK.dylib', 'libfreetype.6.dylib', 'libgmp.10.dylib', 'libgnutls.30.dylib', 'libhogweed.7.dylib', 'libidn2.0.dylib', 'libintl.8.dylib', 'libnettle.9.dylib', 'libp11-kit.0.dylib', 'libpng16.16.dylib', 'libtasn1.6.dylib', 'libunistring.5.dylib']
```
En el YAML, el `print` (`:80`) va después de `assert not left, left` (`:78-79`), que falla con cualquier referencia fuera de `@loader_path/`, `/usr/lib/` y `/System/`.

**[C4] `probe`** (R19; R18 y R21, mecanismo). Consultas hechas al redactar sobre `step-probe.txt` (las 1467 líneas del paso) y `probe-images-unique.txt`:
```
$ sed … step-probe.txt | grep -nE 'clang |env -i|probe=|for r in|brew --prefix'
18:2026-11-02T19:42:26.4963230Z clang -DMOD -dynamiclib -Wl,-rpath,@loader_path/ -o out/engine/lib/wine/x86_64-unix/probe.so probe.c
19:2026-11-02T19:42:26.4965120Z clang -o probe probe.c
20:2026-11-02T19:42:26.4966340Z probe="$PWD/probe"; dir=$(cd out/engine/lib/wine/x86_64-unix && pwd -P); log="$RUNNER_TEMP/probe.log"
21:2026-11-02T19:42:26.4968160Z (cd / && env -i DYLD_PRINT_LIBRARIES=1 "$probe" "$dir/probe.so" $ROOTS) 2>"$log" || { cat "$log"; exit 1; }
23:2026-11-02T19:42:26.4970110Z for r in $ROOTS; do grep -F "$dir/$r" "$log"; done
24:2026-11-02T19:42:26.4971330Z if grep -q "$(brew --prefix)/" "$log"; then exit 1; fi
--- last 3 lines of probe step:
2026-11-02T19:42:29.1597870Z dyld[1607]: <BF093AA5-07EE-3280-982D-20E79E6B7A25> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
2026-11-02T19:42:29.1605930Z dyld[1607]: <346AFE88-06F2-3373-86DA-DD755E38609A> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libgnutls.30.dylib
2026-11-02T19:42:29.1610200Z dyld[1607]: <F92483CA-A7D5-3552-9360-C6F6A3470C00> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libMoltenVK.dylib
--- /usr/local lines: 0  /opt/homebrew lines: 0
$ wc -l probe-images-unique.txt ; clasificación por prefijo
     605 probe-images-unique.txt
OTHER: /Users/runner/work/bodega-engine/bodega-engine/probe
System=424 usr/lib=167 out/x86_64-unix=13 other=1
```

**[C5] `tarball`, artefacto y `publish`** (R20)
```
build	tarball	2026-11-02T19:42:29.2290430Z ##[group]Run set -o pipefail
build	tarball	2026-11-02T19:42:29.2292170Z name="hostlibs-x86_64-$(date -u +%Y%m%dT%H%M%SZ)-$(printf %s "$NOTE" | tr -c 'A-Za-z0-9_-' -)"
[…]
build	tarball	2026-11-02T19:42:29.2298700Z if tar -tzf "$name.tar.gz" | grep -E '/$|^\./'; then exit 1; fi
build	tarball	2026-11-02T19:42:29.2300040Z shasum -a 256 "$name.tar.gz" | tee "$name.tar.gz.sha256"
build	tarball	2026-11-02T19:42:29.2301120Z ls -la "$name.tar.gz"
build	tarball	2026-11-02T19:42:29.2301860Z test "$(stat -f %z "$name.tar.gz")" -lt $((30 * 1024 * 1024))
build	tarball	2026-11-02T19:42:29.2414250Z shell: /bin/bash -e {0}
build	tarball	2026-11-02T19:42:29.2430730Z   NOTE: primer-hostlibs
build	tarball	2026-11-02T19:42:33.5442490Z 3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
build	tarball	2026-11-02T19:42:33.5558310Z -rw-r--r--  1 runner  staff  5121991 Nov  2 19:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
build	Run actions/upload-artifact@v4	2026-11-02T19:42:33.6294860Z   retention-days: 14
build	Run actions/upload-artifact@v4	2026-11-02T19:42:34.1975640Z ##[warning]Retention days cannot be greater than the maximum allowed retention set within the repository. Using 1 instead.
build	Run actions/upload-artifact@v4	2026-11-02T19:42:36.8190010Z Artifact hostlibs has been successfully uploaded! Final size is 5062830 bytes. Artifact ID is 13171974984
build	publish	2026-11-02T19:42:36.8577300Z ##[group]Run f=$(ls hostlibs-*.tar.gz)
[…]
build	publish	2026-11-02T19:42:36.8687790Z   GH_TOKEN: ***
build	publish	2026-11-02T19:42:36.8688290Z   GH_REPO: dany021115/bodega-engine
build	publish	2026-11-02T19:42:41.2248050Z https://github.com/dany021115/bodega-engine/releases/tag/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
```
El paso corre con `bash -e`; acabó en `success`, así que ni el `grep` de entradas de directorio ni el `test` del tamaño (la última orden) fallaron.

**[C6] Lo ejecutado es el YAML del commit** (R17–R20)
```
ruby exit=0
guard: CI-echoed script == YAML run block (1 lines)
install: CI-echoed script == YAML run block (1 lines)
bundle: CI-echoed script == YAML run block (42 lines)
probe: CI-echoed script == YAML run block (23 lines)
tarball: CI-echoed script == YAML run block (10 lines)
publish: DIFFERS
$ cat scripts-diff-publish.txt
3c3
< gh release create "$tag" "$f" "$f.sha256" --title "$tag" --notes "FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run ${{ github.run_id }}. Versions in hostlibs.txt inside, checksum in the .sha256 file."
---
> gh release create "$tag" "$f" "$f.sha256" --title "$tag" --notes "FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run 41512345512. Versions in hostlibs.txt inside, checksum in the .sha256 file."
$ (al redactar) tamaño de cada scripts-diff-*.txt
guard diff bytes=       0
install diff bytes=       0
bundle diff bytes=       0
probe diff bytes=       0
tarball diff bytes=       0
publish diff bytes=     569
```
La única diferencia es la expansión de `${{ github.run_id }}` que hace GitHub.

**[C7] Configuración del workflow y estado de `BE`** (R17, R20; T1)
```
$ /usr/bin/ruby -ryaml -e 'YAML.load_file(ARGV[0])' /Users/quasar/Documents/GitHub/Bodega/bodega-engine/.github/workflows/build-hostlibs.yml   (+ volcado de la estructura)
exit=0
triggers: ["workflow_dispatch"]
inputs: publish_release(type=boolean, default=false), ref_note(type=string, default="manual")
permissions: {"contents"=>"write"}
jobs: ["build"]  runs-on: macos-15-intel  timeout-minutes: 15
env: {"HOMEBREW_NO_AUTO_UPDATE"=>"1", "HOMEBREW_NO_INSTALL_UPGRADE"=>"1", "HOMEBREW_NO_INSTALL_CLEANUP"=>"1", "HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"=>"1", "ROOTS"=>"libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib"}
step 1: name=guard    uses=- timeout-minutes=- if=- env=[]
step 2: name=install  uses=- timeout-minutes=5 if=- env=[]
step 3: name=bundle   uses=- timeout-minutes=- if=- env=[]
step 4: name=probe    uses=- timeout-minutes=- if=- env=[]
step 5: name=tarball  uses=- timeout-minutes=- if=- env=["NOTE"]
step 6: name=-        uses=actions/upload-artifact@v4 timeout-minutes=- if=- env=[]
step 7: name=publish  uses=- timeout-minutes=- if=${{ github.event.inputs.publish_release == 'true' }} env=["GH_TOKEN", "GH_REPO"]
any checkout step: false
build.yml:22:    runs-on: macos-15-intel
build.yml:45:          brew install -q mingw-w64 bison pkg-config ccache gnutls freetype sdl2 libpng jpeg-turbo gstreamer molten-vk || true
$ git -C BE log --oneline -2
8a00dea build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball
e497c41 Merge pull request #22 from gauthierpiarrette/dotlocal-dll-redirection
exit=0
$ git -C BE status --short
exit=0 (no lines above = clean)
$ git -C BE rev-parse HEAD origin/main
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
$ git -C BE show --stat --format=%H%n%an%n%aI%n%B HEAD
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
Daniel Medina
2026-11-02T14:41:49-05:00
build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball

 .github/workflows/build-hostlibs.yml | 137 +++++++++++++++++++++++++++++++++++
 1 file changed, 137 insertions(+)
```
El `head_sha` del run es ese mismo commit [C1]. En el YAML, `ref_note` no lleva clave `type` (§5.10).

**[C8] Releases** (R4, R6, R20; procedencia de `RT`)
```
$ gh release view engine-wine-11.0-20261030T202616Z-primer-build -R dany021115/bodega-engine
title:	engine-wine-11.0-20261030T202616Z-primer-build
tag:	engine-wine-11.0-20261030T202616Z-primer-build
draft:	false
prerelease:	false
immutable:	false
author:	github-actions[bot]
created:	2026-10-26T14:22:39Z
published:	2026-10-30T20:28:31Z
url:	https://github.com/dany021115/bodega-engine/releases/tag/engine-wine-11.0-20261030T202616Z-primer-build
asset:	engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
asset:	engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256
--
Wine from the pinned CrossOver source (inputs.json) with the patch series in patches/. Built by run 41110607147. Checksum in the .sha256 file.
$ gh release view hostlibs-x86_64-20261102T194229Z-primer-hostlibs -R dany021115/bodega-engine
title:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs
tag:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs
draft:	false
prerelease:	false
immutable:	false
author:	github-actions[bot]
created:	2026-11-02T19:41:49Z
published:	2026-11-02T19:42:41Z
url:	https://github.com/dany021115/bodega-engine/releases/tag/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
asset:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
asset:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256
--
FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run 41512345512. Versions in hostlibs.txt inside, checksum in the .sha256 file.
$ (al redactar) assets de los .json guardados por `gh release view --json assets`
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz size=334861341 state=uploaded digest=sha256:c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256 size=120 state=uploaded digest=sha256:fe2b347aca8eb66eff6b614a27b2017056399e283d6d78bc21dc588102766e7d
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz size=5121991 state=uploaded digest=sha256:3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256 size=122 state=uploaded digest=sha256:7d5b97a86ef3f1f87ca355b7051e1d501cc7ff3abbfb8dabcbdb5beddb158f87
$ gh release list -R dany021115/bodega-engine
hostlibs-x86_64-20261102T194229Z-primer-hostlibs	Latest	hostlibs-x86_64-20261102T194229Z-primer-hostlibs	2026-11-02T19:42:41Z
engine-wine-11.0-20261030T202616Z-primer-build		engine-wine-11.0-20261030T202616Z-primer-build	2026-10-30T20:28:31Z
```
`created` es la fecha del commit al que apunta el tag (8a00dea, 14:41:49-05:00); `published` es la del paso `publish`.

**[C9] `shasum -c` local y comparación con la release** (R4, R6, R20; T4)
```
=================== /Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
-rw-r--r--@ 1 quasar  staff  334861341 Oct 30 16:32 engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
-rw-r--r--@ 1 quasar  staff        120 Oct 30 16:30 engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256
--- cat *.sha256
c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62  engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
--- (cd engine-wine-11.0-20261030T202616Z-primer-build && /usr/bin/shasum -a 256 -c engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256)
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz: OK
exit=0
--- local size vs release asset size; local sha vs GitHub asset digest
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz          local=334861341  release=334861341  size_match=True digest_match=True
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256   local=120        release=120        size_match=True digest_match=True
=================== /Users/quasar/Documents/GitHub/Bodega/runtimes/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
-rw-r--r--@ 1 quasar  staff  5121991 Nov  2 14:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
-rw-r--r--@ 1 quasar  staff      122 Nov  2 14:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256
--- cat *.sha256
3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
--- (cd hostlibs-x86_64-20261102T194229Z-primer-hostlibs && /usr/bin/shasum -a 256 -c hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256)
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz: OK
exit=0
--- local size vs release asset size; local sha vs GitHub asset digest
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz        local=5121991    release=5121991    size_match=True digest_match=True
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256 local=122        release=122        size_match=True digest_match=True
```
El hash de las hostlibs es el mismo que imprimió el paso `tarball` del CI [C5].

**[C10] Forma del tarball de hostlibs** (R20)
```
$ /usr/bin/tar -tzvf hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
-rw-r--r--  0 runner staff    2772 Nov  2 14:42 hostlibs.txt
-rwxr-xr-x  0 runner staff  658384 Nov  2 14:42 engine/lib/wine/x86_64-unix/libfreetype.6.dylib
-rwxr-xr-x  0 runner staff  440864 Nov  2 14:42 engine/lib/wine/x86_64-unix/libgmp.10.dylib
-rwxr-xr-x  0 runner staff 2118016 Nov  2 14:42 engine/lib/wine/x86_64-unix/libgnutls.30.dylib
-rwxr-xr-x  0 runner staff  280880 Nov  2 14:42 engine/lib/wine/x86_64-unix/libhogweed.7.dylib
-rwxr-xr-x  0 runner staff  230560 Nov  2 14:42 engine/lib/wine/x86_64-unix/libidn2.0.dylib
-rwxr-xr-x  0 runner staff  209600 Nov  2 14:42 engine/lib/wine/x86_64-unix/libintl.8.dylib
-rwxr-xr-x  0 runner staff 5664496 Nov  2 14:42 engine/lib/wine/x86_64-unix/libMoltenVK.dylib
-rwxr-xr-x  0 runner staff  320784 Nov  2 14:42 engine/lib/wine/x86_64-unix/libnettle.9.dylib
-rwxr-xr-x  0 runner staff 1460656 Nov  2 14:42 engine/lib/wine/x86_64-unix/libp11-kit.0.dylib
-rwxr-xr-x  0 runner staff  192400 Nov  2 14:42 engine/lib/wine/x86_64-unix/libpng16.16.dylib
-rwxr-xr-x  0 runner staff   87616 Nov  2 14:42 engine/lib/wine/x86_64-unix/libtasn1.6.dylib
-rwxr-xr-x  0 runner staff 2061056 Nov  2 14:42 engine/lib/wine/x86_64-unix/libunistring.5.dylib
entries: 13 ; tar -tzf exit=0
R20 scenario grep -E "/$|^\./": no output, grep exit=1
entries outside {hostlibs.txt, engine/lib/wine/x86_64-unix/*.dylib}: none, grep exit=1
non-regular entries in verbose listing: none, grep exit=1
size check: 5121991 < 31457280 ? yes
b'c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62  engine-wine-11.0-20261030T202616Z-primer-build.tar.gz\n'
b'3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz\n'
$ (al redactar) head -3 hostlibs.txt ; grep -nE '^(freetype|gnutls|molten-vk) ' hostlibs.txt ; echo "file lines: $(grep -c x86_64-unix hostlibs.txt)"
hostlibs-x86_64-20261102T194229Z-primer-hostlibs
runner image: macos15 20260824.0482.1
ant 1.10.17
28:freetype 2.14.3
44:gnutls 3.8.13_2
92:molten-vk 1.4.2
file lines: 12
```

**[C11] Las 12 `.dylib` publicadas** (R18; R21, requisito previo). `otool -L`, `otool -l`, `otool -D`, `lipo -archs`, `codesign -dv` y `codesign -v` en una carpeta nueva, borrada después:
```
dependency refs NOT under @loader_path/, /usr/lib/, /System/ (expect none): (none) grep exit=1
distinct ref prefixes:
  25 @loader_path/
  16 /System/
  22 /usr/lib/
/usr/local: -L 0  -l 0 ; /opt/homebrew: -L 0  -l 0 ; @rpath: -L 0  -l 0 ; LC_RPATH: -L 0  -l 0
@loader_path refs that do not resolve to a file in the tarball: (none)
libfreetype.6.dylib      id=@loader_path/libfreetype.6.dylib         id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libgmp.10.dylib          id=@loader_path/libgmp.10.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libgnutls.30.dylib       id=@loader_path/libgnutls.30.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libhogweed.7.dylib       id=@loader_path/libhogweed.7.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libidn2.0.dylib          id=@loader_path/libidn2.0.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libintl.8.dylib          id=@loader_path/libintl.8.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libMoltenVK.dylib        id=@loader_path/libMoltenVK.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libnettle.9.dylib        id=@loader_path/libnettle.9.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libp11-kit.0.dylib       id=@loader_path/libp11-kit.0.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libpng16.16.dylib        id=@loader_path/libpng16.16.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libtasn1.6.dylib         id=@loader_path/libtasn1.6.dylib            id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libunistring.5.dylib     id=@loader_path/libunistring.5.dylib        id_ok=yes arch=x86_64 Signature=adhoc verify=valid
```

**[C12] `LC_RPATH` de los módulos del motor** (R21, mecanismo; design §1)
```
$ /usr/bin/tar -xzf <RT> -C <carpeta nueva> ./engine/lib/wine/x86_64-unix/{win32u,dwrite,bcrypt,crypt32,secur32}.so ./engine/lib/wine/x86_64-unix/wine ; lipo -archs ; otool -l (LC_RPATH) ; strings | nombres hoja   (carpeta borrada después)
tar exit=0
win32u.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libfreetype.6.dylib libMoltenVK.dylib 
dwrite.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libfreetype.6.dylib 
bcrypt.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
crypt32.so  arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
secur32.so  arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
wine        arch=x86_64 LC_RPATH=[] hostlib leaf strings: 
```

**[C13] Run del motor y retención** (procedencia de `RT`; §5.3 y §5.4)
```
# captured 2026-11-02T20:37:44Z
$ gh run view 41110607147 -R dany021115/bodega-engine --json conclusion,jobs,createdAt,updatedAt
failed to get run: HTTP 404: Not Found (https://api.github.com/repos/dany021115/bodega-engine/actions/runs/41110607147?exclude_pull_requests=true)
exit=1
$ gh api repos/dany021115/bodega-engine/actions/runs/41110607147
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/actions/workflow-runs#get-a-workflow-run","status":"404"}gh: Not Found (HTTP 404)
$ gh api repos/dany021115/bodega-engine/actions/runs/41110607147/logs (log archive)
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/actions/workflow-runs#download-workflow-run-logs","status":"404"}gh: Not Found (HTTP 404)
$ gh api repos/dany021115/bodega-engine/actions/workflows/build.yml/runs --jq .total_count
0
$ gh api repos/dany021115/bodega-engine/actions/runs --jq .total_count
1
$ gh api repos/dany021115/bodega-engine/commits/e497c41/check-runs
{"total_count":0,"check_runs":[]}
(resumen del check, mismas consultas a la API)
GET workflows/402129994 (build-arm64.yml) runs -> total_count: 0
GET commits/e497c41/check-suites -> total_count: 6, all third-party apps (render, codemagic-ci-cd, vercel, railway-app, openship-io, cloudflare-workers-and-pages) status=queued since 2026-10-30T18:52:3xZ; NO app=github-actions suite
(contrast) GET commits/8a00dea/check-suites -> 112494463517 app=github-actions status=completed conclusion=success runs=1
engine release target commit: e497c41d16a1... committed 2026-10-26T15:22:39+01:00 (= release 'created: 2026-10-26T14:22:39Z')
$ gh api repos/dany021115/bodega-engine/actions/permissions/artifact-and-log-retention
{"days":1,"maximum_allowed_days":400}
$ gh api 'repos/dany021115/bodega-engine/actions/artifacts?per_page=50'
total_count: 1
13171974984 hostlibs size=5062830 run=41512345512 expired=false created=2026-11-02T19:42:36Z expires=2026-11-03T19:41:55Z
```

### 3.4 Evidencia previa de T15 y T16, releída al redactar

Los archivos son los que dejaron T15, T16 y su repetición; los conteos y extractos se han sacado ahora con `cat`, `grep -c`, `head` y `tail` de solo lectura.

**[P1] T15, runtime sin hostlibs** (`$SCR/t15-run/run2`; R9, R14, R16, R21 escenario 2)
```
$ cat test.out ; cat test.rc ; cat times
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: real runtime (setUpAll)
00:00 +0: test/engine_test.dart: real runtime cycle
create: 0:00:10.369397
00:13 +1: test/engine_test.dart: real runtime (tearDownAll)
00:13 +1: All tests passed!
0
start 2026-11-02T19:23:53Z
end 2026-11-02T19:24:07Z
$ (por cada log de logs/) grep -c 'cannot find the FreeType', grep -c 'ailed to load libgnutls', grep -c 'Failed to load libMoltenVK' y el .exit
2026-11-02T19-23-54.003978Z-wineboot.log FreeType=15 GnuTLS=6 FailedMVK=1 exit=0
2026-11-02T19-24-04.374577Z-cmd.log FreeType=6 GnuTLS=0 FailedMVK=0 exit=0
2026-11-02T19-24-05.245607Z-cmd.log FreeType=2 GnuTLS=0 FailedMVK=0 exit=7
2026-11-02T19-24-05.608747Z-rundll32.log FreeType=4 GnuTLS=0 FailedMVK=1 exit=0
2026-11-02T19-24-06.495018Z-rundll32.log FreeType=2 GnuTLS=1 FailedMVK=0 exit=0
== 2026-11-02T19-23-54.003978Z-wineboot.log (cabecera)
# runtime t15-rt
# cwd /private/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega-realJzHoRj/bottles/t
# argv wineboot
[…]
# exit=0
== 2026-11-02T19-24-05.245607Z-cmd.log (.exit=7)
# runtime t15-rt
# cwd /private/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega-realJzHoRj/bottles/t/prefix/drive_c
# argv cmd /c exit 7
Wine cannot find the FreeType font library.  To enable Wine to
[…]
# exit=7
== 2026-11-02T19-24-06.495018Z-rundll32.log (.exit=0)
# runtime t15-rt
[…]
# argv rundll32 bcrypt.dll,BodegaProbe
[…]
0144:err:winediag:gnutls_process_attach failed to load libgnutls, no support for encryption
0144:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
== 2026-11-02T19-24-05.608747Z-rundll32.log (dwrite), línea de MoltenVK
00fc:err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib: dlopen(libMoltenVK.dylib, 0x0002): tried: 'libMoltenVK.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/RosettalibMoltenVK.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OSlibMoltenVK.dylib' (no such file), '$SCR/t15-rt/engine/lib/wine/x86_64-unix/libMoltenVK.dylib' (no such file), '/usr/lib/libMoltenVK.dylib' (no such file, not in dyld cache), 'libMoltenVK.dylib' (no such file)
```
La búsqueda de dyld pasa por `…/x86_64-unix/`, la carpeta del `LC_RPATH @loader_path/`, y por el cryptex de Rosetta: es el mismo mecanismo que, con hostlibs, deja el conteo en 0.

**[P2] T16, runtime con hostlibs** (`$SCR/t16-evidence-20261102T194630Z/logs`; R13, R15, R21 escenarios 1 y 3)
```
$ (por cada log) .exit y grep -cE 'cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK'
2026-11-02T19-47-16.113573Z-wineboot.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-00.690739Z-cmd.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-18.908812Z-rundll32.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-24.821389Z-rundll32.log exit=0 markers(4+mvk)=0
2026-11-02T19-49-03.057629Z-cscript.log exit=0 markers(4+mvk)=0
$ cat logs/*.log | grep -cE 'mvk-info|Failed to load libMoltenVK'     (paso 6 de T16, literal)
0
rc=1
== 2026-11-02T19-49-03.057629Z-cscript.log (.exit=0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv cscript //nologo C:\https.js
msync: bootstrapped mach port on wine-4bdb0b2-msync.
msync: up and running.
009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
011c:err:kerberos:kerberos_LsaApInitializePackage no Kerberos support, expect problems
status=200
# exit=0
== 2026-11-02T19-48-18.908812Z-rundll32.log (.exit=0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv rundll32 dwrite.dll,BodegaProbe
[…msync y winebth]
00d8:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"dwrite.dll"
# exit=0
== 2026-11-02T19-48-24.821389Z-rundll32.log (.exit=0)
[…cabecera igual]
# argv rundll32 bcrypt.dll,BodegaProbe
0124:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
```

**[P3] T16, `run t cmd /c set`** (R12, escenario 3; R21)
```
$ grep -cE 'DYLD_|WINEARCH|CX_|LANG=' $SCR/t16-evidence-20261102T194630Z/logs/2026-11-02T19-48-00.690739Z-cmd.log
0
rc=1
$ grep -cE 'DYLD_|WINEARCH|CX_|LANG=' $SCR/t16v-capture-20261102T200201Z/2026-11-02T20-02-57.191529Z-cmd.log
0
rc=1
$ head -3 <log de T16> ; nombres de las variables del resto del log (sin valores)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv cmd /c set
_ __CF_USER_TEXT_ENCODING ALLUSERSPROFILE APPDATA CLIENTNAME CommonProgramFiles CommonProgramFiles(x86) CommonProgramW6432 COMPUTERNAME ComSpec DOTNET_EnableWriteXorExecute HOMEDRIVE HOMEPATH LOCALAPPDATA LOGNAME LOGONSERVER MVK_CONFIG_LOG_LEVEL NUMBER_OF_PROCESSORS OS PATH PATHEXT PROCESSOR_ARCHITECTURE PROCESSOR_IDENTIFIER PROCESSOR_LEVEL PROCESSOR_REVISION ProgramData ProgramFiles ProgramFiles(x86) ProgramW6432 PROMPT PUBLIC ROSETTA_ADVERTISE_AVX SESSIONNAME SHLVL SystemDrive SystemRoot TEMP TMP USER USERDOMAIN USERNAME USERPROFILE windir WINE_HOST_HOME WINE_HOST_PATH WINE_HOST_PWD WINE_HOST_TMPDIR WINECONFIGDIR WINEDATADIR WINEDEBUG WINEDLLDIR0 WINEDLLOVERRIDES WINEHOMEDIR WINELOADER WINEMSYNC WINEPREFIX WINEUSERLOCALE WINEUSERNAME winsysdir
$ grep -nE '^(WINEDEBUG|WINE_HOST_PATH|WINEPREFIX|WINEMSYNC|WINEDLLOVERRIDES|MVK_CONFIG_LOG_LEVEL|ROSETTA_ADVERTISE_AVX|DOTNET_EnableWriteXorExecute|WINELOADER|SHLVL|_)=' <log de T16>
7:_=$SCR/t16-home-20261102T194630Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/bin/wine
17:DOTNET_EnableWriteXorExecute=0
23:MVK_CONFIG_LOG_LEVEL=2
38:ROSETTA_ADVERTISE_AVX=1
40:SHLVL=1
51:WINE_HOST_PATH=/usr/bin:/bin:/usr/sbin:/sbin
56:WINEDEBUG=fixme-all
58:WINEDLLOVERRIDES=winemenubuilder.exe=d
60:WINELOADER=\??\Z:\private\tmp\claude-501\-Users-quasar\cabea996-65df-4091-b3df-9592ba319dd4\scratchpad\t16-home-20261102T194630Z\runtimes\engine-wine-11.0-20261030T202616Z-primer-build\engine\lib\wine\x86_64-unix\wine
61:WINEMSYNC=1
62:WINEPREFIX=$SCR/t16-home-20261102T194630Z/bottles/t/prefix
```
`WINELOADER` (en forma de ruta NT), las variables de Windows y `WINE_HOST_*` (de `PATH`, `HOME`, `TMPDIR` y el cwd) las pone Wine; `_` y `SHLVL`, el `/bin/sh`. Bodega no las pasa.

**[P4] T16, `otool -L` de las `.dylib` instaladas** (R18, escenario)
```
$ grep -P '^\t' $SCR/t16-evidence-20261102T194630Z/otool-L.txt | grep -vE '^\s+(@loader_path/|/usr/lib/|/System/)'
rc=1
$ (cabeceras de otool-L.txt)
libfreetype.6.dylib: libgmp.10.dylib: libgnutls.30.dylib: libhogweed.7.dylib: libidn2.0.dylib: libintl.8.dylib: libMoltenVK.dylib: libnettle.9.dylib: libp11-kit.0.dylib: libpng16.16.dylib: libtasn1.6.dylib: libunistring.5.dylib:
$ head -6 otool-L.txt
$SCR/t16-home-20261102T194630Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib:
	@loader_path/libfreetype.6.dylib (compatibility version 27.0.0, current version 27.6.0)
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.12)
	/usr/lib/libbz2.1.0.dylib (compatibility version 1.0.0, current version 1.0.8)
	@loader_path/libpng16.16.dylib (compatibility version 72.0.0, current version 72.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.120.2)
```

**[P5] Repetición de T16 por su verificador** (`$SCR/t16v-capture-20261102T200201Z`; R3 positivo, R5, R21). Solo guardó stdout y stderr, sin los códigos de salida del CLI:
```
$ (por archivo) tamaño y contenido de 1-install, 2-create, 3-run y 8-stop (.out y .err)
### 1-install.out (     169 bytes)
$SCR/t16v-home-20261102T200201Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
### 1-install.err (       0 bytes)
### 2-create.out (     174 bytes)
log: $SCR/t16v-home-20261102T200201Z/bottles/t/logs/2026-11-02T20-02-23.145206Z-wineboot.log
### 2-create.err (       0 bytes)
### 3-run.out (     169 bytes)
log: $SCR/t16v-home-20261102T200201Z/bottles/t/logs/2026-11-02T20-02-57.191529Z-cmd.log
### 3-run.err (       0 bytes)
### 8-stop.out (       0 bytes)
### 8-stop.err (       0 bytes)
### wineboot exit: 0  cmd exit: 0
$ grep -cE 'cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK' *.log
…/2026-11-02T20-02-57.191529Z-cmd.log:0
…/2026-11-02T20-02-23.145206Z-wineboot.log:0
```

### 3.5 Comprobaciones hechas al redactar

**[V1] Código, binario, entorno, máquina y repo** (R8, R12, R21; T17)
```
$ date -u '+%Y-%m-%dT%H:%M:%SZ'
2026-11-02T21:48:54Z
$ (cd P &&) shasum -a 256 pubspec.yaml pubspec.lock lib/engine.dart bin/bodega.dart test/engine_test.dart
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
$ shasum -a 256 B/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
$ (cd P &&) grep -niE 'uuid|bottle\.json|\.json' lib/engine.dart bin/bodega.dart
[exit=1]
$ (presencia en el shell de esta sesión, sin valores)
LANG=<set>
LC_ALL=<unset>
WINEPREFIX=<set>
WINEARCH=<unset>
DYLD_LIBRARY_PATH=<unset>
BODEGA_HOME=<unset>
BODEGA_WINEDEBUG=<unset>
$ sysctl -n machdep.cpu.brand_string; uname -m; sw_vers -productVersion
Apple M2 Pro
arm64
27.0.1
$ git -C B status --short --branch
## No commits yet on master
?? .gitignore
?? .sdd/
?? packages/
$ git -C B log --oneline -3
fatal: your current branch 'master' does not have any commits yet
$ git -C B remote -v
(sin salida)
```

**[V2] Código de CX citado en §5.1** (`CX` = `$SCR/research/src/cx-26.3/sources/wine`, alias de `exploration.md`)
```
$ sed -n '751,755p' server/process.c
/* forced shutdown, used for wineserver -k */
void shutdown_master_socket(void)
{
    kill_all_processes();
    shutdown_stage = 2;
$ sed -n '1107,1117p' server/process.c
/* kill all processes */
static void kill_all_processes(void)
{
    struct list *ptr;

    while ((ptr = list_head( &process_list )))
    {
        struct process *process = LIST_ENTRY( ptr, struct process, entry );
        terminate_process( process, NULL, 1 );
    }
}
$ sed -n '266,267p;1031,1032p' dlls/ntdll/unix/server.c
    /* the server closed the connection; time to die... */
    abort_thread(0);
    /* the server closed the connection; time to die... */
    abort_thread(0);
$ sed -n '1499,1513p' dlls/ntdll/unix/thread.c
void abort_thread( int status )
{
    pthread_sigmask( SIG_BLOCK, &server_block_set, NULL );
    if (InterlockedDecrement( &nb_threads ) <= 0) abort_process( status );
    pthread_exit_wrapper( status );
}
[…]
void abort_process( int status )
{
    _exit( get_unix_exit_code( status ));
}
```

## 4. Pendiente del usuario

Ningún requisito queda **no cumplido**. Lo que falta depende de tus pasos U, en el M2 Pro y con ventanas, y de T17.

**Qué cierra o confirma cada paso**

| Req | Estado | Lo cierra | Lo confirma |
|---|---|---|---|
| R11 | parcial | U7 y U6.3 | — |
| R13 | parcial | U3 y U5 | — |
| R14 | parcial | U6.1 y U6.2 | U3, U5 |
| R17 | parcial | ningún paso U (escenario 2) | — |
| R21 | parcial | U3 | U2 |
| R1, R5, R6, R7 | cumplido | — | U1 |
| R9, R10, R16 | cumplido | — | U2 |
| R12, R15 | cumplido | — | U3 (y U5 para R15) |
| R2, R3 | cumplido | — | U1–U3 (el CLI con tu PATH y sin `BODEGA_HOME`) |
| R4, R8, R18, R19, R20 | cumplido | — | — |

**Pasos** (lo que se espera es el texto de `tasks.md`; las notas son de este verify)
- **U1** · `bodega install <engine…tar.gz> <hostlibs…tar.gz>`. Se espera que en menos de 2 min imprima `…/Application Support/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build` y que `ls` de `runtimes/current/engine/lib/wine/x86_64-unix/*.dylib` muestre `libfreetype.6`, `libgnutls.30`, `libMoltenVK` y su cierre. Ejercita por primera vez la raíz por defecto (R1) y repite R5 y R7 en ella. Después, no borres `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (R6). Referencia headless: 4,28 s [H1].
- **U2** · `time bodega create prueba`. Se espera exit 0, ninguna línea `pista:` (R16, R21) y unos 300 MB de `du -sh`. Anota el tiempo (R9). Referencia: 12,52 s [H3a], 19,45 s [H2] y 10,37 s en T15 [P1]. Las líneas `err:ole`, `err:setupapi` y `winebth … c00000e5` del log de wineboot salieron en todos los `create` de T16 y de este verify, y no impidieron que la botella quedara lista [H3a].
- **U3** · `bodega run prueba notepad`, escribir «Caña, acción, pingüino» y, en otra Terminal, `lsof -p $(pgrep -n -f notepad) | grep -E 'libfreetype|libgnutls|libMoltenVK'`. Se espera que los glifos se vean bien y que todas las líneas de `lsof` estén bajo `…/Bodega/runtimes/<id>/engine/lib/wine/x86_64-unix/` (cierra R21); que la cabecera diga `# cwd …/prefix/drive_c` (R13, escenario 2); y que al cerrar, `echo $?` dé 0 y el log tenga `# exit=0` y la cabecera de 3 líneas, sin variables de tu entorno (R15, R12, R14).
- **U4** · `bodega run prueba winecfg`. No cierra ningún requisito concreto: es una comprobación general del prefijo (Windows 10).
- **U5** · `bodega run prueba "$HOME/Juegos/Cave Story ñ/Doukutsu.exe"`. Se espera que `# cwd` termine en `Cave Story ñ` y que `bodega run` termine con el código del juego. Es la rama de ruta Unix de R13, que ningún check ha ejecutado; con U3 cierra R13. El log se llamará `…-Doukutsu.log` (R15).
- **U6** · Desacople. U6.1 (Ctrl-C) y U6.2 (cerrar la Terminal con el programa abierto) cierran R14. U6.3 (`bodega wait prueba` y cerrar el programa; vuelve unos 3 s después) es la parte de R11 que aquí solo se ejecutó sin servidor.
- **U7** · `bodega run prueba notepad` en una Terminal y `bodega stop prueba` en otra. Se espera que `stop` salga con 0, que notepad se cierre en unos 11 s como mucho y que el primer `run` termine; con U6.3, cierra R11. Ten en cuenta dos cosas:
  - Ese primer `run` saldrá con **0** y su log dirá `# exit=0` (§5.1). U7 no fija ese código, así que no es un fallo del paso.
  - `pgrep -fl wine` no basta para buscar supervivientes. En [H3], `pgrep -fl <H>` solo encontró 2 de los 10 procesos de la botella: los demás se titulan `C:\windows\system32\…`, sin la ruta de la botella, y la mayoría tampoco contienen `wine` (`services.exe`, `plugplay.exe`, `svchost.exe`, `cmd.exe`; previsiblemente también `notepad.exe`). Además, `pgrep -fl wine` lista procesos de tu CrossOver.app (§5.6). Lo que sí encontró los 10 fue `lsof` buscando la ruta de la botella o del runtime, por ejemplo `lsof -n -P -w | grep -F "Application Support/Bodega/" | awk '{print $1, $2}' | sort -u`, que tiene que salir vacío después del `stop`.
- **U8** · Opcional: un juego DX9 o DX11 tuyo. No cierra ningún requisito; es información para el cambio de DXMT.
- **T17** · Commit en `B`, con los comandos de `tasks.md:104-110`. Ningún requisito depende de él para cumplirse, pero ahora mismo nada de este cambio está versionado: `## No commits yet on master` con `.gitignore`, `.sdd/` y `packages/` sin seguimiento [V1]. Como el `git add` incluye `.sdd`, conviene hacerlo con este `verify.md` ya revisado para que entre en el commit. `build/` está en `.gitignore`, así que `build/bodega` no se versiona. `archive` usa `git mv`, que exige archivos versionados: T17 va antes que `archive`. Comprobación del agente: `git -C B log --oneline -1` muestra el commit y `git -C B status --short` sale vacío.

## 5. Observaciones

1. **`stop` no deja 128 + la señal; el `run` parado sale con 0.** Ocurrió 2 de 2 veces: con el `stop` a +12,7 s [H3] y con el de la limpieza del primer intento, a +90 s, cuando el log ya tenía 86 respuestas de ping y ninguna línea `Ping statistics` [H3]. En el árbol de procesos, el hijo directo del `sh` es `start.exe /exec cmd /c` (54729), y `cmd.exe` y `ping` tienen PPID 1 [H3]. En el código de CX [V2], `wineserver -k` llama a `shutdown_master_socket` → `kill_all_processes` → `terminate_process(process, NULL, 1)`; cada cliente, al ver cerrada la conexión con el servidor, hace `abort_thread(0)` → `abort_process(0)` → `_exit(get_unix_exit_code(0))`. Es decir, sale con `_exit` y 0, no muere por una señal, y `$?` vale 0. En [H3] todo terminó a +0,13 s; no se ha observado el caso en que `-k` llega al SIGKILL (unos 10,5 s, según la decisión 10 de `proposal.md`).
   - Efecto: por el código de salida, un `run` terminado con `stop` no se distingue de un programa que sale bien con 0. Además, la salida del programa puede quedar a medias: el log del primer intento acaba en `R# exit=0`, con la última línea cortada.
   - R11 (cierra en unos 11 s y termina el `run`) y R14 (el CLI sale con el N del `.exit`) se cumplen tal como están escritos. Lo que es falso para este runtime es el ejemplo de `design.md:89` («Si el proceso muere por una señal, `$?` vale 128 + la señal, por ejemplo después de `stop`»).
   - Necesita una decisión antes de `archive`: corregir esa línea del diseño o exigir otra cosa en la spec. Verify no ha cambiado código, specs, diseño ni `tasks.md`.
2. **Nombre suelto inexistente, sin pista.** `bodega run t nonexistent.exe` sale con 1 tras 4,95 s y el log solo dice `Application could not be started, or no application associated with the specified file.` y `ShellExecuteEx failed: Environment variable not found.`, un texto engañoso. No sale `pista:` porque los marcadores de R16 solo cazan `wine: failed to open`, que es lo que da una ruta `C:\…` (exit 53 y pista) [H5]. No incumple R16, que fija la lista de marcadores.
3. **El run del motor ya no existe en GitHub.** `gh run view 41110607147` y sus `/jobs`, `/attempts/1` y `/logs` dan HTTP 404; el historial de Actions solo tiene el run 41512345512, `build.yml` y `build-arm64.yml` tienen 0 runs, y el commit e497c41, destino de la release del motor, no tiene check runs [C13]. Quedan sin evidencia la conclusión, los pasos y la duración de ese run. Solo hay pruebas indirectas: la release del motor la publicó `github-actions[bot]` el 2026-10-30T20:28:31Z, su texto dice `Built by run 41110607147` y su asset coincide en tamaño y digest con `RT` [C8, C9]. No se ha averiguado la causa (borrado manual o retención). `exploration.md:39` es el único registro de que terminó bien. No afecta a ningún requisito.
4. **Retención de 1 día.** El repo tiene `{"days":1,"maximum_allowed_days":400}`; el `retention-days: 14` del workflow se recortó a 1 con un aviso, y el artefacto 13171974984 caduca el 2026-11-03T19:41:55Z [C5, C13]. El log del run 41512345512 puede desaparecer igual que el del motor. Hay una copia completa en `$SCR/verify-ci-evidence-20261102/run-41512345512.log`, pero el scratchpad es temporal: los extractos de §3.3 son la copia que dura. Las releases no caducan. Las specs no fijan retención, así que no es un incumplimiento.
5. **`build/bodega` cambió de hash sin cambiar de código.** La recompilación que pedía T13 en este verify lo sustituyó: el binario de las 14:15, con el que corrieron T15, T16 y su repetición, era `e39ad46d…`; el actual, de las 15:30 y usado por el grupo headless, es `7c10f6ab…` [S5]. Las fuentes son las mismas antes, después y ahora [POST, V1], y dos compilaciones seguidas del mismo código difieren en 101 bytes con el mismo tamaño y el mismo `LC_UUID` [X8]: es falta de determinismo de `dart compile exe`, no un cambio de código.
6. **Procesos ajenos.** Durante los checks corrían procesos de tu CrossOver.app: su GUI (79727, desde el 30 de octubre), un `winedevice.exe` (77714, desde el 30 de octubre, que el check headless atribuye a CrossOver) y un `wineserver` (47400) que arrancó a las 15:32:21 hora local, en una pausa del grupo estático [POST, H6]. El código de Bodega no menciona CrossOver (`grep` → exit 1) y ninguna invocación de ese grupo llegó a resolver un runtime. Nadie los tocó. En U7 y en cualquier limpieza no hay que contarlos como de Bodega ni matarlos a ciegas.
7. **Resto fuera del scratchpad.** Queda `/private/tmp/.wine-501/server-100000d-4c4ae29`, la carpeta de sockets de Wine del prefijo ya borrado; ningún proceso la usa. Es el comportamiento normal de Wine y no se borró porque está fuera del scratchpad.
8. **Sin ejercitar (riesgos residuales).**
   - R3: el camino sin Rosetta (solo revisión del código).
   - R5: el borrado de un `.tmp-<id>` de un intento anterior.
   - R7: `run` y `wait` sin runtime desde el CLI.
   - R9: wineboot con código distinto de 0 y el tope de 10 min de `-w`.
   - R10: `run` sobre una botella que no está lista.
   - R13: una ruta Unix que existe (lo hará U5).
   - R14: `bodega run t cmd /c exit 7; echo $?` literal desde el CLI.
   - R15: el tope de 40 caracteres de la etiqueta.
   - R16: las pistas tras un `create` que falla.
   - R17: el escenario 2 (guarda con una imagen sin freetype o gnutls).
   - R18 y R19: la salida del ensayo T2 no está en esta evidencia.
   - R20: el saneado de `ref_note`.
9. **Incidencias del propio verify, no del producto.** El primer intento del `stop` en vivo esperaba un proceso titulado `ping.exe`, pero este runtime lo titula `ping -n 120 127.0.0.1` (comm `ping`); agotó 90 s y su limpieza ejecutó `bodega stop t`, que sirvió como segunda observación de §5.1 [H3]. En T13, los `BODEGA_HOME` apuntaron a carpetas nuevas del scratchpad y no a `$(mktemp -d)` en `$TMPDIR`, y el check del uso también llevó una para probar que no se crea nada [§3.1]. El check de `install` sin `.sha256` usó rutas cuyo tarball tampoco existe [X5].
10. **Correcciones al redactar** (sin efecto en ningún estado):
    - Los logs de T15 llevan `# runtime t15-rt`, no el id de la release, porque T15 apuntó `current` a la carpeta de extracción `t15-rt` [P1]. R15 no cambia: la cabecera es `# runtime <id>` del runtime resuelto.
    - En el paso `probe` del CI, `grep -ciE 'error|fail|not loaded|image not found'` da 1, no 0: es la línea del fuente de `probe.c` que el CI imprime (`if (!probe) { fprintf(stderr, "%s\n", dlerror()); return 1; }`), no una línea de salida.
    - El volcado de Ruby muestra `ref_note(type=string, …)`, pero en el YAML `ref_note` no tiene clave `type` (`build-hostlibs.yml:12-15`); en `workflow_dispatch`, una entrada sin tipo es texto, que es lo que pide R17.
11. **Informativo.** El paso `Complete job` avisa de que `actions/upload-artifact@v4` usa Node.js 20, que está obsoleto, y se fuerza a Node.js 24; no falló nada. El log de `cscript` de T16 trae `err:kerberos:kerberos_LsaApInitializePackage no Kerberos support, expect problems`, y aun así da `status=200` [P2]; ninguna spec cubre Kerberos.

## 6. Añadido tras la revisión adversarial

**R17, escenario 2 (ensayo local de la guarda, con un `brew` falso).** Se extrajo del YAML el paso `guard` y se ejecutó con `bash -e`. Es un ensayo de la lógica del paso, no una ejecución en una imagen real del runner; por eso R17 sigue como parcial.

```
--- imagen SIN freetype/gnutls
runner image lacks freetype/gnutls; would build from source
exit=1
--- imagen CON ellos
freetype 2.14.3
gnutls 3.8.13_2
exit=0
```

**Decisiones del usuario (2026-11-03):**
- `design.md` corregido: un `run` terminado por `stop` sale con 0, y se acepta.
- Comprobante de U7 en `tasks.md`: `lsof` en vez de `pgrep`.
- R17 se acepta como parcial, con el ensayo local de la guarda.
- T17 hecho: commit `de9fce1`.

## 7. Aceptación del usuario (2026-11-03, MacBook Pro M2 Pro, macOS 27.0.1)

| Prueba | Resultado | Evidencia |
|---|---|---|
| U1 install | OK | Imprime `…/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build` |
| U2 create | OK | 19,454 s, sin líneas `pista:` |
| U3 notepad | OK | El usuario confirma menús y «Caña, acción, pingüino» legibles. `lsof` muestra `…/Bodega/runtimes/…/engine/lib/wine/x86_64-unix/libfreetype.6.dylib` y su `.aot` de Rosetta. Log: `# cwd …/prefix/drive_c`, `# exit=0` |
| U4 winecfg | OK | El usuario confirma Windows 10. Log: `# exit=0` |
| U5 Cave Story | **No hecha** | Sustituida por el check de abajo: prueba la ruta, no un juego con imagen y sonido |
| U6 desacople | OK | El usuario confirma que notepad sobrevive a Ctrl-C y a cerrar la Terminal. `wait` esperó 15,735 s hasta cerrar notepad; incluye el tiempo que tardó el usuario, así que no mide los ~3 s |
| U7 parada | OK | El usuario confirma que notepad se cerró al ejecutar `stop` (0,217 s). `lsof` no muestra procesos de Bodega; `# exit=0`, como se decidió en §6 |
| U8 juego propio | **No hecha** | Opcional |

**Sustituto de U5 para R13 (rama de ruta Unix), sin ventanas:** copia de `cmd.exe` en una carpeta con espacio y ñ, con un `BODEGA_HOME` temporal ya borrado.

```
run exit=7
# cwd $SP/r13 Juegos ñ/Cave Story ñ
# argv $SP/r13 Juegos ñ/Cave Story ñ/Mi Juego ñ.exe /c exit 7
# exit=7
stop=0
```

**Límite de esta verificación:** ningún juego real se ha ejecutado todavía con Bodega. Lo probado es el motor con notepad, winecfg y cmd. La etiqueta del log sustituye cada byte no ASCII por `_` (`Mi_Juego__`), sin efecto funcional.
