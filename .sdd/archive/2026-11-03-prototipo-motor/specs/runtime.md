# Spec: runtime

### R4 · Verificación antes de extraer
`install` exige un `<tarball>.sha256` junto a cada tarball y lo comprueba con `/usr/bin/shasum -a 256 -c`, ejecutado en la carpeta del tarball. El CLI nunca descarga nada.

Escenarios:
- **Dado** un `.sha256` alterado, **cuando** se ejecuta `install`, **entonces** da error y no aparece nada nuevo en `runtimes/`, tampoco `.tmp-*`.
- **Dado** que falta el `.sha256`, **entonces** el error incluye `gh release download <tag> -R dany021115/bodega-engine`.

**Comprobación:** test `installRuntime`, y `grep -n HttpClient lib/` no devuelve nada.

### R5 · Extracción en un único staging
`install` sigue estos pasos:
1. Extrae con `/usr/bin/tar -xzf` primero el motor y luego las hostlibs, los dos en `runtimes/.tmp-<id>`. Si ese directorio quedó de un intento anterior, lo borra antes.
2. Quita la cuarentena con `/usr/bin/xattr -dr com.apple.quarantine`, sin mirar su código de salida.
3. Exige las 8 rutas de `requiredFiles`: las 6 de `HBK/EngineStore.swift#L637-L646` más `libfreetype.6.dylib` y `libgnutls.30.dylib`, ambas en `engine/lib/wine/x86_64-unix/`.
4. Ejecuta `engine/bin/wine --version`, cuya salida debe empezar por `wine-`.
5. Renombra el staging a `runtimes/<id>`, donde `<id>` es el nombre del tarball del motor sin `.tar.gz`.

Si algo falla, borra el staging.

Escenarios:
- **Dado** unas hostlibs sin `libgnutls.30.dylib`, **entonces** da el error `runtime incompleto: falta …` y no queda ningún `.tmp-*`.
- **Dado** unos tarballs correctos, **entonces** existe `runtimes/<id>/engine/lib/wine/x86_64-unix/libgnutls.30.dylib` y el CLI imprime la carpeta del runtime.

**Comprobación:** test `installRuntime` (con el runtime falso); T16 y U1 con los tarballs reales.

### R6 · Runtimes inmutables
Es lo primero que mira `install`, antes de R4 y R5: si `runtimes/<id>` ya existe, falla al momento y da instrucciones: `bodega stop` de las botellas, `rm -rf` del runtime y volver a instalar desde los tarballs locales. Es también la forma de cambiar las hostlibs, así que el tarball del motor y su `.sha256` se conservan en `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/`: sin ellos, cambiar las hostlibs obligaría a volver a bajar 335 MB.

Escenario:
- **Dado** un runtime ya instalado, **cuando** se repite `install`, aunque falte el `.sha256`, **entonces** da el error `ya instalado` y no cambia nada.

**Comprobación:** test `installRuntime`.

### R7 · Runtime actual
`install` crea el symlink `runtimes/current.tmp` → `<id>` (borrando antes uno que haya quedado) y lo renombra encima de `runtimes/current`. rename(2) sustituye el enlace anterior de forma atómica; `Link.updateSync` no sirve porque borra y vuelve a crear (`DSDK/lib/io/link.dart:279-285`). Todas las botellas usan ese runtime, resuelto con `resolveSymbolicLinksSync()`. Si no hay ninguno instalado, `create`, `run`, `wait` y `stop` fallan con `no hay runtime: bodega install …`.

Escenarios:
- **Dado** una instalación correcta, **entonces** `currentRuntime(home)` devuelve la carpeta `runtimes/<id>` resuelta.
- **Dado** el runtime A instalado, **cuando** se instala B, **entonces** `currentRuntime(home)` devuelve B.

**Comprobación:** test `installRuntime`.
