# Spec: lanzamiento, entorno y logs

### R12 · Entorno hermético
Todo proceso que lanza el motor (`/bin/sh`, `wine` y `wineserver`) recibe `includeParentEnvironment: false` y exactamente el mapa que construye `wineEnv(prefix, parent)`:
- Del padre, y solo si existen: `HOME`, `USER`, `LOGNAME`, `TMPDIR` y `__CF_USER_TEXT_ENCODING`.
- Valores fijos:
  - `PATH=/usr/bin:/bin:/usr/sbin:/sbin`
  - `WINEPREFIX=<raíz>/bottles/<b>/prefix`, siempre absoluta
  - `WINEMSYNC=1`
  - `WINEDLLOVERRIDES=winemenubuilder.exe=d`
  - `ROSETTA_ADVERTISE_AVX=1`
  - `DOTNET_EnableWriteXorExecute=0`
  - `MVK_CONFIG_LOG_LEVEL=2`
- `WINEDEBUG`: el valor de `BODEGA_WINEDEBUG` del padre o, si no existe, `fixme-all`.

No entra ninguna otra variable: ni `LANG` o `LC_*`, ni `WINEARCH`, `WINEDLLPATH*`, `WINELOADER`, `WINESERVER`, `DYLD_*`, `CX_*` o `BODEGA_*`.

Escenarios:
- **Dado** un padre con `WINEARCH=win32`, `DYLD_LIBRARY_PATH`, `WINEDLLPATH`, `CX_ROOT`, `LANG`, `WINEDEBUG=+all`, `PATH=/opt/homebrew/bin`, `HOME` y `USER`, **entonces** el mapa tiene exactamente las claves de arriba y `WINEDEBUG=fixme-all`.
- **Dado** además `BODEGA_WINEDEBUG=+loaddll`, **entonces** `WINEDEBUG=+loaddll`.
- **Dado** `bodega run t cmd /c set` con el runtime real, **entonces** el log no contiene `DYLD_`, `WINEARCH`, `CX_` ni `LANG=`.

**Comprobación:** test `wineEnv is hermetic`; T16.

### R13 · Programa y directorio de trabajo
- Si `<programa>` contiene `/`, es una ruta Unix: se resuelve con `resolveSymbolicLinksSync()` (tiene que existir), tiene que pasar `winPathProblem` y se entrega a Wine como ruta absoluta. El cwd es su carpeta.
- Si empieza por `C:\` (o `c:\`), se pasa tal cual y el cwd es su carpeta traducida: `prefix/drive_c/<resto con \ → />` sin el nombre del archivo, si existe; si no, `prefix/drive_c`. Es lo normal para un juego que un instalador dejó en `C:\Program Files\…`, y Highball también usa la carpeta del exe (`HBK/WineRunner.swift#L436-L441`).
- Cualquier otro nombre (`notepad`, `cmd`, `cscript`) se pasa tal cual y el cwd es `prefix/drive_c`.
- El cwd del CLI nunca se hereda (design §4).

Escenarios:
- **Dado** que existe `prefix/drive_c/Juegos`, **cuando** se ejecuta `runInBottle(…, r'C:\Juegos\Mi Juego.exe')`, **entonces** la cabecera del log dice `# cwd <prefix>/drive_c/Juegos`.
- **Dado** `notepad`, **entonces** la cabecera dice `# cwd <prefix>/drive_c`.
- **Dado** `/ruta/a/Juego.exe` inexistente, **entonces** da error antes de lanzar nada.

**Comprobación:** test `fake runtime cycle`; U3 (`drive_c`); U5 (ruta Unix con espacio y tilde).

### R14 · Lanzamiento desacoplado y código de salida
- `run` lanza `/bin/sh -c S bodega <log> <rt>/engine/bin/wine <programa> [args…]` con `ProcessStartMode.detached` (design §2).
- El script `S` añade `# exit=N` al log y escribe `N` en `<log sin .log>.exit` de forma atómica.
- `bodega run` imprime `log: <ruta>`, consulta el `.exit` cada 250 ms y sale con `N`.
- Ctrl-C o cerrar la Terminal solo hacen que el CLI deje de esperar: el programa sigue corriendo.

Escenarios:
- **Dado** un programa falso que sale con 7 y deja un proceso nieto con el log abierto durante 5 s, **entonces** `exitOf(log)` devuelve 7 en menos de 2 s (trampa 1).
- **Dado** `bodega run t cmd /c exit 7` con el runtime real, **entonces** `echo $?` imprime 7.
- **Dado** un juego abierto, **cuando** se cierra la Terminal, **entonces** el juego sigue.

**Comprobación:** test `fake runtime cycle`; T15; U6.

### R15 · Un log por ejecución
- **Ruta:** `bottles/<b>/logs/<UTC>-<etiqueta>.log`, con la hora en ISO-8601 con microsegundos y `:` cambiado por `-`.
- **Creación:** con `createSync(exclusive: true)`.
- **Etiqueta:** `wineboot` en `create`. En `run`, el nombre base del programa (lo que va tras el último `/` o `\`), sin `.exe`, con todo lo que no sea `[A-Za-z0-9._-]` cambiado por `_` y como máximo 40 caracteres.
- **Cabecera** (la escribe Dart): `# runtime <id>`, `# cwd <dir>` y `# argv <…>`. Nunca incluye el entorno.
- **Pie** (lo escribe el script): `# exit=N`.
- **Tamaño:** sin tope ni rotación (ponytail).
- Las comprobaciones exigen que el log **contenga** `# exit=N`, no que termine en esa línea (design §3).

Escenario:
- **Dado** `C:\Juegos\Mi Juego.exe`, **entonces** el nombre del log termina en `-Mi_Juego.log`.

**Comprobación:** test `fake runtime cycle`; U3.

### R16 · Pistas
Al terminar `create` (también si falla) y `run`, el CLI recorre el log e imprime `pista: …` por stderr por cada marcador que encuentre. El código de salida no cambia.

Marcadores, solo los que pueden darse con este diseño:
- `cannot find the FreeType`
- `ailed to load libgnutls`
- `version mismatch`
- `wine: failed to open`

No hay marcadores de msync ni de Rosetta: `WINEMSYNC=1` es constante (design §4) y R3 comprueba Rosetta antes de cada verbo.

Escenarios:
- **Dado** un log con cada marcador, **entonces** sale la pista de cada uno.
- **Dado** un log limpio, **entonces** no sale ninguna.

**Comprobación:** test `hints`; T15, donde el grupo `real runtime` exige las pistas de FreeType y GnuTLS sin hostlibs.
