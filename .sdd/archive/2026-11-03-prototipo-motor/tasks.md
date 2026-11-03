# Tareas: prototipo-motor

**Convenciones**
- **(USUARIO)**: lo haces tú, en tu Terminal. El agente no hace commit, push ni dispatch: prepara los comandos y después solo comprueba el resultado. El resto lo hace el agente en `apply`, en este orden.
- Cada tarea nombra la comprobación que la cierra.
- Rutas: `B` = `/Users/quasar/Documents/GitHub/Bodega/bodega`, `BE` = `/Users/quasar/Documents/GitHub/Bodega/bodega-engine`, `P` = `B/packages/engine`, `RT` = el tarball del motor (`exploration.md`).
- Los tests sin Wine se lanzan con `cd P && dart test -N '<nombre>'`.

## Bibliotecas del host
El workflow va primero para que el CI corra mientras se escribe el paquete.

- [x] **T1** Escribir `BE/.github/workflows/build-hostlibs.yml` según R17–R20 y design §1, con los pasos guarda e `install`, `bundle`, `probe`, `tarball`, artefacto y `publish`.
  **Comprobación:** `/usr/bin/ruby -ryaml -e 'YAML.load_file(ARGV[0])' BE/.github/workflows/build-hostlibs.yml` termina sin error, y `git -C BE status --short` muestra solo ese archivo.
- [x] **T2** Ensayo local en arm64, sin gastar CI.
  1. Extraer con `ruby` los bloques `run:` de `bundle` y `probe` a un script del scratchpad.
  2. Ejecutarlo con `bash -e` en un directorio temporal del scratchpad, contra `/opt/homebrew`, con `ROOTS='libfreetype.6.dylib libgnutls.30.dylib'` (aquí no hay MoltenVK) y `RUNNER_TEMP` apuntando a otra carpeta del scratchpad.

  **Comprobación:** sale con 0; la sonda carga `libfreetype.6.dylib` y `libgnutls.30.dylib` desde el `out/` temporal, y `otool -L` del resultado no muestra `/opt/homebrew`.
- [x] **T3 (USUARIO)** Commit, push y dispatch en tu Terminal. El mensaje lo prepara el agente, sin atribución de IA:
  ```sh
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine add .github/workflows/build-hostlibs.yml
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine commit -m 'build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball'
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine push origin main
  gh workflow run build-hostlibs.yml -R dany021115/bodega-engine -f publish_release=true -f ref_note=primer-hostlibs
  ```
  **Comprobación (agente, solo lectura):** `gh run list -R dany021115/bodega-engine -w build-hostlibs.yml -L 1` y `gh run view <id> -R dany021115/bodega-engine --log`: el job sale verde en menos de 10 min, el paso `probe` muestra las 3 raíces y el tarball pesa menos de 30 MiB.
  No bloquea T5–T15.
- [x] **T4 (USUARIO)** `gh release download <tag> -R dany021115/bodega-engine -D /Users/quasar/Documents/GitHub/Bodega/runtimes/<tag>`.
  **Comprobación:** `shasum -a 256 -c` da OK en esa carpeta.

## Paquete Dart
- [x] **T5** Crear el esqueleto: `B/.gitignore` (`.dart_tool/`, `build/`), `P/pubspec.yaml`, `P/lib/engine.dart`, `P/bin/bodega.dart` y `P/test/engine_test.dart`. Después, `dart pub get --offline`.
  **Comprobación:** `dart analyze` sin avisos y existe `P/pubspec.lock`.
- [x] **T6** `wineEnv` (R12) y el test `wineEnv is hermetic`.
  **Comprobación:** `dart test -N 'wineEnv'`.
- [x] **T7** `bottleDir` (validación del nombre), `winPathProblem` y `bodegaHome` (R1, R8), con el test `names and windows paths`.
  **Comprobación:** `dart test -N 'names'`.
- [x] **T8** El helper de test que genera los tarballs del runtime falso (design §6), con el id como parámetro, más `requiredFiles`, `installRuntime` y `currentRuntime` (R4–R7). Test `installRuntime` con cinco casos:
  - instala bien;
  - la reinstalación da `ya instalado` aunque falte el `.sha256` (R6 va antes que R4);
  - un `.sha256` alterado o ausente da error;
  - sin `libgnutls` da error sin dejar `.tmp-*`;
  - instalar A y después B deja `currentRuntime` en B.

  **Comprobación:** `dart test -N 'installRuntime'`.
- [x] **T9** El lanzamiento:
  - `_start`, con el script `S` de design §2 en modo adjunto o desacoplado;
  - `_newLog`, que pone nombre, etiqueta y cabecera (R15);
  - `exitOf` (R14).

  **Comprobación:** no tiene test propio; la cubren T10 y T11.
- [x] **T10** `createBottle` (R9, R10), con la parte `create` del test `fake runtime cycle`:
  - `t` queda lista y su log contiene `# exit=0`;
  - `broken` da error y conserva la carpeta y el log.

  **Comprobación:** `dart test -N 'fake runtime'`.
- [x] **T11** `runInBottle`, `waitBottle` y `stopBottle` (R11, R13, R14), con el resto del test `fake runtime cycle`, que lanza `C:\Juegos\Mi Juego.exe` con `prefix/drive_c/Juegos` ya creada:
  - el exit 7 llega en menos de 2 s aunque un proceso nieto retenga el log;
  - el log contiene `# exit=7` y la cabecera `# cwd <prefix>/drive_c/Juegos`;
  - la etiqueta sale `-Mi_Juego.log`;
  - `stop` devuelve 0 y `wait` devuelve 0.

  **Comprobación:** `dart test -N 'fake runtime'`.
- [x] **T12** `hintsIn` (R16) y el test `hints`, que usa un log enlatado con los 4 marcadores y otro limpio.
  **Comprobación:** `dart test -N 'hints'`.
- [x] **T13** El CLI en `P/bin/bodega.dart` (R1–R3): un `switch` con patrones de listas, la comprobación de Rosetta, la línea `log:`, la espera del `.exit`, las pistas y los códigos 0, 1, 64 y N. Añadir los `ponytail:` de las simplificaciones: sin tope de log, `BODEGA_WINEDEBUG`, sin reaper, sin reparar syswow64 y runtime global.
  **Comprobación:**
  - `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`;
  - `build/bodega; echo $?` muestra el uso y 64;
  - `BODEGA_HOME=$(mktemp -d) build/bodega create 'a b'; echo $?` da 1;
  - `BODEGA_HOME=$(mktemp -d)/a./b build/bodega stop x; echo $?` da 1 y el mensaje nombra `a.`;
  - `cat lib/engine.dart bin/bodega.dart | grep -c 'ponytail:'` da 5 o más.
- [x] **T14** El grupo `real runtime` (design §6): se salta si no está definida `BODEGA_TEST_RUNTIME`, tiene un timeout de 15 min, corre siempre las dos sondas `rundll32` y exige las pistas de FreeType y GnuTLS si no hay hostlibs, y ninguna si las hay. Su `tearDownAll` hace `stopBottle` y borra su `BODEGA_HOME` con `deleteSync(recursive: true)`, que no sigue enlaces.
  **Comprobación:** `dart test` lo marca como saltado y todo lo demás pasa.

## Checks headless con el runtime real
Los ejecuta el agente, sin ventanas (decisión 6).
- **Tiempos.** T15 va en segundo plano: el grupo puede pasar de los 10 min que admite una llamada en primer plano, y su `tearDownAll` limpia aunque falle. Cada paso de T16 va en primer plano con un timeout explícito de 10 min: `create` está sin medir (Highball tarda unos 90 s con `-u`, y la primera vez se suman Rosetta, Mono y Gecko).
- **Si una llamada se corta**, antes de repetir: `BODEGA_HOME=$H build/bodega stop t` (o `wineserver -k` con ese `WINEPREFIX`) y `rm -rf "$H"`. Si no, quedan wineboot y wineserver huérfanos y el reintento falla con `ya existe` (R9), que no es un bug.
- **Limpieza.** Primero `stop`, después `rm -rf`, que borra el enlace `dosdevices/z:` → `/` sin seguirlo. Nada recorre una botella con `find -L` ni con un listado `followLinks: true`.

- [x] **T15** Sin hostlibs; no espera a T3.
  1. Extraer `RT` con `/usr/bin/tar -xzf` en un directorio nuevo del scratchpad.
  2. Ejecutar en segundo plano `BODEGA_TEST_RUNTIME=<dir> dart test -N 'real runtime'`.
  3. Borrar la extracción con `rm -rf <dir>` (~1,1 GB).

  **Comprobación:** `create` termina bien e imprime su tiempo; `cmd /c echo ok` da 0 y `ok` en el log; `cmd /c exit 7` da 7; las sondas dan las pistas de FreeType y GnuTLS (lo exige el test); `stop` da 0.
- [x] **T16** Con hostlibs; requiere T4. `H` es una carpeta nueva del scratchpad, escrita literal en cada llamada porque las variables de shell no pasan de una llamada a otra. Cada paso se ejecuta como `BODEGA_HOME=$H build/bodega …`:
  1. `install <RT> <hostlibs>`.
  2. `create t`.
  3. `run t cmd /c set`: el log no contiene `DYLD_`, `WINEARCH`, `CX_` ni `LANG=`.
  4. `run t rundll32 dwrite.dll,BodegaProbe` y `run t rundll32 bcrypt.dll,BodegaProbe`: no dan pistas.
  5. Escribir `$H/bottles/t/prefix/drive_c/https.js` con:
     ```js
     try{var r=new ActiveXObject("WinHttp.WinHttpRequest.5.1");r.Open("GET","https://example.com/",false);r.Send();WScript.Echo("status="+r.Status)}catch(e){WScript.Echo("error="+(e.number>>>0).toString(16)+" "+e.message)}
     ```
     y ejecutar `run t cscript //nologo 'C:\https.js'`: el log contiene `status=200`. Si falla, la línea `error=` va a `verify`. Sin el `catch`, cscript se tragaría el error (`CX/programs/wscript/main.c:123-128`) y `fixme-all` ocultaría hasta eso.
  6. `cat "$H"/bottles/t/logs/*.log | grep -cE 'mvk-info|Failed to load libMoltenVK'` da 0.
  7. `otool -L` de las `.dylib` instaladas solo muestra `@loader_path`, `/usr/lib` y `/System`.
  8. `stop t` da 0.
  9. `rm -rf "$H"` (~1,4 GB).

  **Comprobación:** la salida se pega en `verify`.
- [x] **T17 (USUARIO)** Commit en `bodega`, en tu Terminal. El mensaje lo prepara el agente, sin atribución de IA:
  ```sh
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega add .gitignore packages/engine .sdd
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega commit -m 'engine: prototype Dart engine package and bodega CLI (SDD prototipo-motor)'
  ```
  Sin push: el repo aún no tiene remoto. Si lo quieres, lo pides.
  **Comprobación (agente):** `git -C B log --oneline -1` muestra el commit y `git -C B status --short` sale vacío.

## Aceptación del usuario
En el M2 Pro, con ventanas. Requiere T4 y `build/bodega` en el PATH o con ruta completa.

- [x] **U1** `bodega install <engine…tar.gz> <hostlibs…tar.gz>`.
  **Se espera:** en menos de 2 min imprime `…/Application Support/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build`, y `ls "$HOME/Library/Application Support/Bodega/runtimes/current/engine/lib/wine/x86_64-unix/"*.dylib` muestra `libfreetype.6`, `libgnutls.30`, `libMoltenVK` y su cierre. Después, **no borres** `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (tarball y `.sha256`): cambiar las hostlibs es reinstalar desde ahí (R6), y sin él serían 335 MB de descarga.
- [x] **U2** `time bodega create prueba`.
  **Se espera:** sale con 0 y sin líneas `pista:`. Anota el tiempo (Highball tarda unos 90 s con `-u`). `du -sh` de la botella da unos 300 MB. Si macOS avisa de una app Intel o de Rosetta, no es un fallo.
- [x] **U3** `bodega run prueba notepad` y escribe «Caña, acción, pingüino». Con notepad abierto, en otra Terminal: `lsof -p $(pgrep -n -f notepad) | grep -E 'libfreetype|libgnutls|libMoltenVK'`.
  **Se espera:** los menús y los glifos se ven bien, lo que prueba FreeType. `lsof` muestra al menos `libfreetype.6.dylib`, y todas sus líneas están bajo `…/Bodega/runtimes/<id>/engine/lib/wine/x86_64-unix/`: es la prueba directa del `LC_RPATH` bajo Rosetta en tu macOS. Al cerrar notepad, `echo $?` da 0 y el log impreso contiene `# exit=0` y la cabecera de 3 líneas (`# cwd …/prefix/drive_c`), sin variables de tu entorno.
- [x] **U4** `bodega run prueba winecfg`.
  **Se espera:** se abre, muestra Windows 10 y se cierra sin errores.
- [ ] **U5** Cave Story freeware (`Doukutsu.exe`, unos 2 MB, 32 bits, DirectDraw), en una carpeta con espacio y tilde a propósito: `bodega run prueba "$HOME/Juegos/Cave Story ñ/Doukutsu.exe"`.
  **Se espera:** se abre la ventana con imagen y sonido y responde al teclado; la cabecera `# cwd` termina en `Cave Story ñ`. Al salir, `bodega run` termina con su código.
- [x] **U6** Desacople, con notepad o Cave Story:
  1. Pulsa Ctrl-C en la Terminal donde corre `bodega run`. **Se espera:** el programa sigue abierto.
  2. Cierra el programa, vuelve a lanzarlo con `bodega run` y cierra esa ventana de Terminal (⌘W y «Terminar»). **Se espera:** el programa sigue abierto.
  3. En otra Terminal lanza `bodega wait prueba` y cierra el programa. **Se espera:** `wait` vuelve unos 3 s después.
- [x] **U7** Parada: `bodega run prueba notepad` en una Terminal y `bodega stop prueba` en otra.
  **Se espera:** `stop` sale con 0, notepad se cierra en unos 11 s como mucho y el primer `run` termina. El `run` sale con 0 (design §2). Después, `lsof 2>/dev/null | grep "Application Support/Bodega" | awk '{print $2}' | sort -u` no imprime nada; si queda algún PID, anótalo, porque no hay reaper. `pgrep -fl wine` no sirve: no ve los procesos de la botella, que llevan nombres de Windows, y lista los de CrossOver.
- [ ] **U8** Opcional: un juego DX9 o DX11 tuyo, como `.exe` suelto y sin launcher.
  **Se espera:** arranca con wined3d. Anota los FPS y los errores para el cambio de DXMT.
