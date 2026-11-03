# Propuesta: prototipo-motor

Fase **propose** del SDD · 2026-11-02 · parte de `exploration.md` (aprobada) y usa sus alias de rutas (`CX`, `BE`, `HBK`, `SP`, `DSDK`, `INV`, `RT`).

**Origen.** Diseño *minimal-first* (empató a 14,5 con *encaje con la app*; desempata tu política de minimalismo) con los injertos de los jueces: runtime falso en los tests, `wineboot` sin `-u`, `run` que espera un `.exit`, sondas sin ventana, sonda de carga en el CI, `MVK_CONFIG_LOG_LEVEL=2` y comprobación de Rosetta.

## Por qué

El runtime `engine-wine-11.0-…-primer-build` ya está descargado y verificado, pero nada lo usa: el repo `bodega` está vacío (exploration §1). Además le faltan FreeType y GnuTLS (§2.1), así que sin ellos no hay fuentes ni TLS. Este cambio valida, sin UI, el contrato completo del motor que después importará la app Flutter.

## Qué

**Alcance**
1. Paquete Dart puro `packages/engine` con una biblioteca, un CLI y un archivo de tests. Cinco verbos: `install`, `create`, `run`, `wait` y `stop`.
2. Un log por ejecución con cabecera y pie `# exit=N`, más un archivo `.exit` con el código.
3. Workflow nuevo `build-hostlibs.yml` en `bodega-engine`. Empaqueta FreeType, GnuTLS y MoltenVK de Homebrew Intel, con su cierre, en un tarball aparte de unos 6–10 MB. No compila Wine, y si la imagen del runner deja de traer freetype y gnutls, falla al momento en vez de compilarlos.
4. Tests sin Wine, con un runtime falso hecho de scripts `sh`, y un grupo opcional que usa el runtime real.

**Fuera de alcance:** la UI Flutter, la gamedb, las tiendas, DXMT, arm64, SDL2, el vídeo (FFmpeg y GStreamer), un reaper de procesos, las descargas desde el CLI, `bottle.json`, y el tope o la rotación de logs.

## Impacto

| Repo | Archivo (todos nuevos) | Contenido |
|---|---|---|
| `bodega` | `.gitignore` | `.dart_tool/`, `build/` |
| | `packages/engine/pubspec.yaml` y `pubspec.lock` | `name: engine`, sdk `^3.13.0`; única dependencia, `test` (dev), resuelta con `dart pub get --offline` |
| | `packages/engine/lib/engine.dart` | todo el motor en funciones de nivel superior (~200 líneas) |
| | `packages/engine/bin/bodega.dart` | el CLI (~40 líneas) |
| | `packages/engine/test/engine_test.dart` | 5 tests sin Wine y el grupo `real runtime` |
| `bodega-engine` | `.github/workflows/build-hostlibs.yml` | workflow manual; no toca `build.yml`, los parches ni Wine |

**Fuera de los repos**
- Disco: `~/Library/Application Support/Bodega`. El runtime ocupa ~1,1 GB y cada botella ~300 MB.
- CI: 3–5 min por ejecución, que en un repo privado se facturan ×10. Tope de 15 min.
- Descargas: solo el tarball de hostlibs. El motor de 335 MB no se vuelve a bajar.

## Decisiones sobre las dudas (§7)

| # | Duda | Decisión | Motivo | Referencia |
|---|---|---|---|---|
| 1a | ¿Dónde van las libs del host? | En `engine/lib/wine/x86_64-unix/`, con ids `@loader_path/<hoja>`. Sin `DYLD_*` y sin tocar Wine | Los 31 `.so` ya tienen `LC_RPATH @loader_path/`. Funciona en todo proceso, también a través de `/bin/sh` | `otool -l` sobre RT; dlopen(3); `SP/dyldtest` |
| 1b | ¿Qué libs? ¿Basta sin fuentes ni TLS? | No basta: van FreeType y GnuTLS, más MoltenVK. Quedan fuera SDL2, FFmpeg y GStreamer | Son los nombres hoja que abren los módulos. sdl2-compat puede colgar winebus. winedmo y winegstreamer fallan sin romper nada | `strings` sobre RT; `BE/.github/workflows/build-arm64.yml:217-222`; `CX/dlls/ntdll/unix/virtual.c:851-853` |
| 2 | ¿Adjunto o `sh` desacoplado? | `run`: `sh` desacoplado que escribe el pie y el `.exit`; el CLI espera el `.exit` y sale con su código. `create`: el mismo script, adjunto | El juego sobrevive a la Terminal y el código de salida es el real. Sin tuberías (trampa 1) | `SP/dartplat/exp/detached_footer.dart:4-7`; `INV/INFORME-FINAL.md:638` |
| 3 | ¿Entorno hermético o heredado? | Hermético: `includeParentEnvironment: false` y un mapa fijo. Del padre solo se copian `HOME`, `USER`, `LOGNAME`, `TMPDIR` y `__CF_USER_TEXT_ENCODING`, y se lee `BODEGA_WINEDEBUG` | Igual desde Terminal y desde Finder. `WINEARCH`, `DYLD_*` y `CX_*` nunca entran | `DSDK/lib/io/process.dart:318-320`; `CX/dlls/ntdll/unix/server.c:1615-1620` |
| 4 | ¿Entra DXMT? | No. DX9–11 van por wined3d | No está entre las cinco operaciones. El overlay es otro artefacto (trampa 10) | `BE/.github/workflows/build.yml:96-106` |
| 5 | ¿msync activo? | `WINEMSYNC=1`, constante | Es lo recomendado. Al ser constante, la trampa 3 no puede darse. CEF queda fuera de alcance | `INV/INFORME-FINAL.md:320`; `CX/dlls/ntdll/unix/msync.c:587-601` |
| 6 | ¿`-u` o `--init`? ¿Y syswow64? | `wine wineboot` sin banderas y luego `wineserver -w`. La botella está lista si existen `syswow64/kernel32.dll` y `system.reg`; si no, error, sin reparar ni borrar | El `--init` automático ya instala el prefijo. `-u` repite `wine.inf` y `--init` arranca un segundo services.exe | `CX/dlls/ntdll/unix/env.c:1908`; `CX/programs/wineboot/wineboot.c:1959-1965` |
| 7 | ¿Nombre o UUID? | El nombre es la carpeta: `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`. Sin JSON | Hace imposible la trampa 11 y no hay nada que guardar por botella | `HBK/Paths.swift#L95-L110` |
| 8 | ¿Dónde van los logs? | `bottles/<b>/logs/<UTC>-<etiqueta>.log` más su `.exit`. Creación exclusiva y sin tope (ponytail) | `BODEGA_HOME` aísla los tests. El parche 0014 quitó la causa conocida de los logs gigantes | `BE/patches/README.md:65`; `WH/Wine/Wine.swift#L279-L281` |
| 9 | ¿Instalar con descarga? | No: solo tarballs locales con su `.sha256`, con `install <engine> <hostlibs>`. Tú los bajas con `gh release download` y conservas el del motor | El repo es privado y la conexión es Starlink: sin token ni reanudación. Cambiar las hostlibs es reinstalar desde el tarball guardado, sin bajar 335 MB | `HBK/EngineStore.swift#L286-L348` |
| 10 | ¿Basta `-k`/`-w`? | Sí. `stop` = `wineserver -k`, y su 1 (no había servidor) se devuelve como 0. `wait` = `-w`. Sin reaper | `-k` ya pasa a SIGKILL a los ~10,5 s | `CX/server/main.c:86-103`; `CX/server/request.c:697-756` |
| 11 | ¿Qué prueba real? | El agente, sin ventanas: `cmd /c echo ok`, `cmd /c exit 7`, sondas `rundll32` con y sin hostlibs, y HTTPS con `cscript`. Tú: notepad (con `lsof`), winecfg, Cave Story en una ruta con espacio y tilde, el desacople y la parada | Sin descargas grandes. Cubren fuentes, TLS, MoltenVK, WoW64 y el ciclo de vida, y las sondas hacen deterministas las pistas | `CX/programs/rundll32/rundll32.c:317-331` |

**Además**
- El runtime actual lo marca el symlink `runtimes/current`, que `install` sustituye con un rename atómico.
- Un programa `C:\…` se lanza con su carpeta dentro de `drive_c` como cwd, si existe; un nombre suelto, con `drive_c`.
- La raíz de datos es `BODEGA_HOME` o, si no está definida, `~/Library/Application Support/Bodega`.
- Antes de cada verbo se comprueba Rosetta con `/usr/bin/arch -x86_64 /usr/bin/true` (`INV/INFORME-FINAL.md:321`).
