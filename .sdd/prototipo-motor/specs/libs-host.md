# Spec: bibliotecas del host

### R17 · Workflow manual y barato
Archivo: `bodega-engine/.github/workflows/build-hostlibs.yml`.

**Configuración**
- Disparo: solo `workflow_dispatch`, con dos entradas: `publish_release` (booleano) y `ref_note` (texto).
- `permissions: contents: write`.
- `runs-on: macos-15-intel`: el mismo Homebrew Intel que `BE/.github/workflows/build.yml:22,45`.
- `timeout-minutes: 15`.
- Sin checkout y sin compilar Wine.
- Variables de entorno: `HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_UPGRADE=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`, `HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1` y `ROOTS="libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib"`, la única lista de raíces, que usan `bundle` y `probe`.
- Guarda antes de instalar: `brew list --versions freetype gnutls || { echo 'runner image lacks freetype/gnutls; would build from source'; exit 1; }`. Sin ellos preinstalados, `brew install` compilaría desde fuente (no hay bottle Intel, design §1) y quemaría el tope ×10.
- Instala `freetype`, `gnutls` y `molten-vk`.
- El paso `install` lleva `timeout-minutes: 5`: un bottle se vierte en segundos, y así cualquier fórmula que pase a compilarse desde fuente corta a los 5 min.

Escenarios:
- **Dado** un dispatch, **entonces** el job termina en verde en menos de 10 min.
- **Dado** una imagen del runner sin freetype o gnutls, **entonces** el job falla en segundos con ese mensaje y no compila nada.

**Comprobación:** T1 (YAML válido) y T3 (job real).

### R18 · Cierre y nombres
Un script de `python3` es un port de `BE/.github/workflows/build-arm64.yml:223-268` sin la parte de SDL3:
- Recibe como argumentos las raíces de `$ROOTS`.
- Recorre `otool -L` y sigue las rutas de Homebrew y las `@rpath/`.
- Copia cada hoja a `out/engine/lib/wine/x86_64-unix/`.
- Reescribe el id y las dependencias de cada una a `@loader_path/<hoja>` y la firma ad hoc.
- Falla si queda alguna referencia a `$(brew --prefix)` o a `@rpath/`.

No incluye SDL2, FFmpeg ni GStreamer.

Escenario:
- **Dado** el cierre copiado, **entonces** `otool -L` de cada `.dylib` solo muestra `@loader_path/…`, `/usr/lib/…` o `/System/…`.

**Comprobación:** aserción del paso en el CI; T2 (ensayo en arm64); T16.

### R19 · Sonda de carga por nombre hoja
Montaje:
- Un módulo compilado con `-Wl,-rpath,@loader_path/` se coloca en la carpeta de destino.
- Lo carga un ejecutable sin `LC_RPATH`.
- Con `env -i`, cwd `/` y `DYLD_PRINT_LIBRARIES=1`, el módulo abre las raíces de `$ROOTS` por nombre hoja.
- Su stderr va a `$RUNNER_TEMP/probe.log`, una ruta absoluta redirigida fuera del `cd /` (design §1).

La sonda pasa si cada raíz se carga desde la carpeta de destino y ninguna imagen viene de `$(brew --prefix)`.

Escenario:
- **Dado** macos-15-intel, el piso del proyecto, **entonces** la sonda pasa.

**Comprobación:** paso `probe` en el CI (T3); T2 en arm64.

### R20 · Artefacto
- **Nombre:** `hostlibs-x86_64-<UTC>-<ref_note>.tar.gz`, con `<ref_note>` saneada: todo carácter fuera de `[A-Za-z0-9_-]` se cambia por `-`, y la nota llega al script por `env`, sin interpolarla en el shell.
- **Contenido:** solo archivos, sin entradas de directorio:
  - `hostlibs.txt`, con el nombre, la imagen del runner (`$ImageOS` y `$ImageVersion`), las versiones de brew y la lista de archivos;
  - `engine/lib/wine/x86_64-unix/*.dylib`.
- **Tamaño:** menos de 30 MiB, con aserción en el CI.
- **`.sha256`:** con el mismo formato que el del motor, `<hex>  <nombre>`.
- **Release:** si se activa `publish_release`, el tag es el nombre del archivo y se crea con `gh release create`, usando `GH_TOKEN` y `GH_REPO`.

Escenario:
- **Dado** `tar -tzf` del tarball, **entonces** ninguna línea termina en `/` ni empieza por `./`.

**Comprobación:** aserciones del CI; T4 (`shasum -c`).

### R21 · Consumo sin variables
Una vez instaladas con `install`, las hostlibs se cargan desde `x86_64-unix/` gracias al `LC_RPATH @loader_path/` de los módulos de Wine. No hace falta ninguna variable, y esto vale para cualquier proceso de la botella.

Escenarios:
- **Dado** un runtime con hostlibs, **cuando** se ejecutan `create`, `rundll32 dwrite.dll,BodegaProbe` y `rundll32 bcrypt.dll,BodegaProbe`, **entonces** ningún log da pistas de FreeType o GnuTLS ni contiene `[mvk-info]` o `Failed to load libMoltenVK`. Esa línea sale si MoltenVK o su cierre no cargan (`CX/dlls/win32u/vulkan.c:3013-3016`), y sin ella el `[mvk-info]` ausente no probaría nada.
- **Dado** un runtime sin hostlibs, **cuando** se ejecutan las mismas sondas, **entonces** salen las pistas de FreeType y GnuTLS.
- **Dado** un `.js` que usa `WinHttp.WinHttpRequest.5.1` contra `https://example.com/`, **cuando** se ejecuta `bodega run t cscript //nologo 'C:\https.js'`, **entonces** el log contiene `status=200`.
- **Dado** notepad abierto en el M2 Pro, **entonces** `lsof` de su proceso muestra las hostlibs cargadas desde `runtimes/<id>/engine/lib/wine/x86_64-unix/`: prueba directa del `LC_RPATH` bajo Rosetta.

**Comprobación:** T15 y T16 (headless); U3 (glifos dibujados con FreeType y `lsof`).
