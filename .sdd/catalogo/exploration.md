# Exploración: catalogo

**Rutas:** `P` = `bodega/packages/engine`; `BE` = `bodega-engine`; `HBDB` = `gauthierpiarrette/highball-db` (commit `f0bf6a2`, 2026-11-03); `HB` = `gauthierpiarrette/highball` (GPL; uso personal). Lectura de código y comprobaciones locales de solo lectura. **No se ha instalado ningún launcher en Bodega.**

## 1. Problema y alcance

El usuario quiere una pantalla como "Install a Windows Application" de CrossOver: buscador, aplicaciones populares con su valoración, e instalar con un clic. También "instalar otra aplicación" para cualquier `.exe`.

Este cambio cubre solo el **motor**: formato del catálogo, instalación, ajustes por programa y CLI (`bodega catalog …`). La pantalla va en el cambio `app-flutter`, sobre este motor.

**Lo que no se reutiliza:** los perfiles, la lista y las estrellas de CrossOver (`crossover.tie`, CrossTie) son datos propietarios. Regla del proyecto: ni copiarlos ni extraerlos.

## 2. De dónde salen los datos

`HBDB` tiene licencia CC0 para datos curados y recetas (`db/derived` es ODbL; `db/anticheat.json`, MIT; `README.md:22-25`).

- `recipes/launchers/`: 7 recetas (Steam, Epic, Battle.net, EA, GOG Galaxy, Rockstar, Ubisoft).
- `recipes/games/`: 44 recetas.
- `db/games/`: 737 fichas con `status` (`verified-local`, `reported-upstream`, `community`, `blocked-anticheat`), `rendererResults` y `anticheat`. No se han leído todas.

**Forma de una receta.** Pasos en orden: `sync`, `environment`, `registry`, `winetricks`, `installer` (`url`, `sha256`, `arguments`, `msi`), `pin` (`path`, `arguments`, `environment`, `renderer`), `note`. Además `kind`, `renderer`, `knownIssues`, `lastVerified`, `blocked` y `flaky`. El motor de Highball admite más pasos (`winver`, `file`, `copy`, `dlloverride`…; `HB/Sources/HighballKit/Recipe.swift:8-54`), que estas 7 recetas no usan.

**Lo que usan las 7:** `sync` ×7, `installer` ×7, `pin` ×7, `environment` ×4, `registry` ×2 (solo Rockstar), `winetricks` ×1 (solo GOG Galaxy).

**Copiar el catálogo con criterio:** esas recetas se probaron con motores y parches de Highball. Sirven como punto de partida, no como garantía para Bodega.

## 3. Estado de cada launcher según `HBDB`

Todo es autorreporte de Highball, no reproducido aquí.

| Launcher | Última verificación | Estado en la receta | Motor | Backend del programa |
|---|---|---|---|---|
| Steam | 2026-08-24, motor Wine 10 de Sikarugir | Sin bloqueo | No fija | `dxmt` |
| Rockstar | 2026-09-18, CX 26.3 r15 | Sin bloqueo | CX 26.3 r15 o superior | `dxvk` |
| EA app | 2026-10-05, CX 26.3 r15 | `flaky` | CX 26.3 r15 o superior | `dxmt` |
| Battle.net | 2026-09-18, motor Wine 10 r5 | `flaky`; negro en motores Wine 11 r8–r10, según una nota | Wine 10 r5 | `dxmt` |
| Ubisoft | 2026-09-05, CX 26.3 r4 | `blocked` en Wine 10; funciona en Wine 11 r15+ con el arreglo entre procesos | No fija | `d3dmetal` |
| Epic | 2026-08-25, motor Wine 10 | **`blocked`:** el instalador audita ACL que Wine no guarda. Highball usa Legendary | No fija | `dxvk` |
| GOG Galaxy | Sin dato | **`blocked`:** ventana de inicio de sesión negra o caída; los instaladores offline sí funcionan | No fija | `dxmt` |

**Conclusión:** de las 7, solo **Rockstar, EA y Ubisoft** tienen verificación de Highball sobre un motor como el nuestro (árbol CX 26.3). La receta de Steam se verificó en otro motor, aunque otros proyectos reportan Steam funcionando en este árbol (`gap-cx-tree-build-and-smoke.md`). Una lista con cinco estrellas como la de CrossOver no se sostiene hoy, y Epic y GOG Galaxy no se pueden prometer.

## 4. Lo que tiene ya el runtime

Comprobado en `~/Library/Application Support/Bodega/runtimes/current`:

- **`0006` (argumentos por exe):** presente en `kernelbase.dll` de 64 y 32 bits. Lee `HKCU\Software\Wine\AppDefaults\<exe>\CommandLineAppend` (`BE/patches/0006-*.patch:17,33-35`).
- **`0007` (ventanas de Chromium entre procesos):** presente en `winemac.so` (cadenas `CALayerHost`/`CAContext`). Es la pieza que evita la ventana negra en launchers (`BE/patches/0007-*.patch:1-12`).
- **`tools/`:** vacía, sin winetricks.

## 5. Lo que falta en el motor

| Falta | Hoy | Por qué hace falta | Ref |
|---|---|---|---|
| **DXMT con `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN`** | El DXMT oficial v0.80 no contiene esa variable (0 coincidencias en `dxgi.dll`, `d3d11.dll` y `winemetal.so`) | `0007` solo dibuja si DXMT acepta el swapchain de otro proceso. Sin esto, Steam, Rockstar, EA, Battle.net y Ubisoft pueden quedar en negro con `dxmt` | `INFORME-FINAL.md` §7.2; `HBDB/recipes/launchers/battle-net.json`. Tarball público: `gauthierpiarrette/highball-engine`, release `dxmt-highball-20261017T231707Z-331c552` (18 MB, LGPL) |
| **msync por programa** | `WINEMSYNC=1` fijo (`P/lib/engine.dart:75`) | Recetas con `sync none`; Steam apaga msync para su propia ventana. Mismo modo en toda la sesión: otro distinto sale con 1 (trampa 3) | `HBDB/recipes/launchers/steam.json` |
| **Reinicio del servidor al cambiar de modo** | No existe | Si la botella sigue en msync tras un juego, la ventana de Steam sale vacía | `steam.json`, `knownIssues` |
| **Variables por programa** | `settings.json` solo guarda backend (`P/lib/backends.dart:227-245`) | `WINE_SIMULATE_WRITECOPY`, `DXMT_ALLOW_…` | Recetas |
| **Argumentos por programa** | No existe en ajustes; el parche `0006` sí | Epic, GOG y launchers con Chromium | §4 |
| **Registro** | No existe | Rockstar: `ServicesPipeTimeout` y `GlobalFlag`; Warframe: `dwrite` | `rockstar.json`, `recipes/games/warframe.json` |
| **Ejecutar un instalador** | `_launchIn` lanza un programa, con ajustes de juego (`P/lib/engine.dart:227`) | Códigos de salida, MSI, esperar y parar los restos | Abajo |
| **Descargar sin SHA fijo** | `_download` exige SHA-256 (`P/lib/backends.dart:193`) | 6 de los 7 instaladores no fijan SHA (son enlaces que cambian) | Recetas |
| **Biblioteca** | No existe | Saber qué hay instalado y qué lanzar | Para la app |

**Cómo instala Highball** (`HB/…/Recipe.swift:567-600`):
1. Baja el instalador; lo verifica si la receta trae SHA.
2. MSI: `msiexec /i <archivo> /qn` + argumentos; si no: `<archivo>` + argumentos.
3. Lo ejecuta siempre con `wined3d`.
4. Si la botella estaba libre, termina los procesos que quedan, porque Battle.net y Rockstar dejan servicios con el entorno de instalación, que luego lanzan el cliente con la configuración equivocada.

Eso último importa: sin ello, el primer "Jugar" hereda un entorno erróneo (trampa 4 del prototipo).

**Tiempos:** Steam descarga su cliente en el primer arranque, y bajo WoW64 + Rosetta tarda 15–25 min y puede parecer colgado (`steam.json`). La pantalla debe avisarlo.

## 6. Seguridad

- **Sin SHA fijo no se puede comprobar el instalador.** Lo único es HTTPS y el dominio oficial. Bodega no valida la firma Authenticode.
- Las recetas son datos ejecutables: una receta decide qué se descarga y se ejecuta. Si el catálogo se actualiza por red, tiene que ir firmado.
- `winetricks` acepta hashes erróneos en modo desatendido (`INFORME-FINAL.md` §12.2). Solo lo usa GOG Galaxy, que está bloqueada.

## 7. Restricciones

- Sin datos ni imágenes de CrossOver. Procedencia en cada receta (`HBDB`, commit, CC0).
- Las valoraciones no se inventan.
- Logos: son marcas de terceros. Con uso personal hay margen, pero es mejor sacar el icono del `.exe` tras instalar.
- Código GPL de Highball reutilizable mientras sea de uso personal. **Si algún día se publica, hay que reescribirlo o publicar el código.**
- Sin atribución de IA; commits y push con OK del usuario; minimalismo.
- Los agentes no pueden comprobar ventanas ni iniciar sesión en tiendas: eso lo prueba el usuario.

## 8. Dudas para la propuesta

1. **Catálogo:** ¿JSON empaquetado en la app (recomendado para empezar) o bajado de la red? Bajado exige firma.
2. **Primera lista:** ¿las 7, marcando Epic y GOG Galaxy como no instalables por ahora, o solo las que tienen opciones reales?
3. **Estado:** ¿los tres niveles propuestos (probado por ti, reportado, sin probar) más "bloqueado"?
4. **Botellas:** ¿una por aplicación (recomendado, aísla los fallos) o compartida?
5. **DXMT con parches:** ¿sustituir el oficial por el fork de Highball (18 MB) o tenerlo como backend aparte? Sin esto, los launchers probablemente salgan en negro.
6. **msync:** ¿ajuste por botella (recomendado), o también por programa, con reinicio del servidor como Highball?
7. **Epic y GOG:** ¿añadir `legendary` e instaladores offline ahora o en otro cambio? Yo lo dejaría para otro.
8. **Prueba real:** Steam con cuenta del usuario, en una botella nueva (el primer arranque tarda 15–25 min). Es la prueba que decide si esto funciona.
