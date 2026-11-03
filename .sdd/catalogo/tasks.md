# Tareas: catalogo

**Convenciones.** `P` = `bodega/packages/engine`; `T` = `Bodega/runtimes/terceros`. **(USUARIO)**: lo haces tú. El agente no hace commit ni push, y no ejecuta instaladores descargados. Tests sin Wine: `cd P && dart test -N '<nombre>'`.

## Motor
- [x] **T1** `lib/backends.dart`: pin del fork de DXMT, `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN` (A3) y regla de `d3d9.dll` en `auto` (A4), con tests `backendEnv` y `resolve`.
  **Comprobación:** `dart test -N backendEnv` y `dart test -N resolve`.
- [x] **T2** Ajustes: `_settings` con `sync` y `env` por programa; `setBackend` los conserva; `setSync` (A1, A2), con test `settings`.
  **Comprobación:** `dart test -N settings`.
- [x] **T3** `_launchIn` aplica el orden de A2 y `WINEMSYNC`, con comprobación en `fake runtime cycle` (el Wine falso guarda su entorno).
  **Comprobación:** `dart test -N 'fake runtime'`.
- [x] **T4** `lib/catalog_data.dart`: las 7 entradas, leídas de `HBDB/recipes/launchers/*.json` en `f0bf6a2`, con notas en español y `source` (C1, C2). `lib/catalog.dart`: tipos, `catalogEntries` (C3). Tests `catalog data` y `catalogEntries`.
  **Comprobación:** `dart test -N catalog`.
- [x] **T5** `_download` con HTTPS, `.part` y sin `sha256` (I3; `design.md` §5), conservando `installBackend`.
  **Comprobación:** `dart test -N installBackend`.
- [x] **T6** `installEntry` (I1, I2, I4–I8, I10) y test `installEntry` con Wine falso: bloqueada, backend ausente, botella existente, `http://`, SHA erróneo, MSI, salida 194, salida 5, sin exe, registro, servidor que no termina y servidor que termina.
  **Comprobación:** `dart test -N installEntry`.
- [x] **T7** `installedApps` y `openApp` (I8, I9), con test `installedApps`.
  **Comprobación:** `dart test -N installedApps`.
- [x] **T8** CLI: `catalog list|show|install`, `apps`, `open`, `sync`, y uso actualizado. Usos incorrectos dan 64.
  **Comprobación:** `dart analyze`; `dart test`; `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`; `build/bodega catalog list` muestra las 7 con su estado; `catalog list STEAM` da una; `catalog show steam`; `catalog show nope; echo $?` da 1; `catalog install epic-games; echo $?` da 1 con su motivo; `catalog; echo $?` da 64.

## Check sin ventanas con el runtime real
Con un `BODEGA_HOME` temporal: primero `stop`, luego `rm -rf`.

- [x] **T9** Runtime, `create t`, `backend install dxmt T/dxmt-highball-20261017T231707Z-331c552.tar.gz` y `backend test t dxmt`. `sync t none`; `run --backend dxmt t cmd /c set`: el log tiene `WINEMSYNC=0` y `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`. `sync t msync`: otro `run` va bien. Una prueba del grupo `real runtime` llama a `installEntry` con la sonda como "instalador" (`file://`), un valor de registro y `exe` `windows/system32/notepad.exe`: queda `app.json`, el valor está en el registro con `reg query` y no quedan procesos.
  **Comprobación:** salida pegada en `verify`. La sonda sale de inmediato, así que no ejercita un instalador real; eso es U3.
- [ ] **T10 (USUARIO)** Commit en `bodega`. El agente deja `~/Documents/GitHub/Bodega/catalogo-commit.sh`, sin atribución de IA y sin push.
  **Comprobación:** `git -C bodega log --oneline -1`.

## Aceptación del usuario
Con ventanas, en tu Mac. Te pasaré los comandos listos para copiar.

- [ ] **U1** Cambiar DXMT en tu carpeta real: `rm -rf ".../Bodega/backends/dxmt"`, `backend install dxmt T/dxmt-highball-…tar.gz` y `backend test prueba dxmt`. **Se espera:** `OK` en 64 y 32 bits.
- [ ] **U2** Blur sin opciones: `run prueba ".../Blur.exe"`. **Se espera:** imprime `backend wine (auto)` y va como antes.
- [ ] **U3** **La prueba que decide:** `catalog install steam` y `open steam`. El primer arranque puede tardar 15–25 min y parecer colgado. **Se espera:** instala, y se abre la ventana de Steam sin quedar en negro; puedes iniciar sesión. Si puedes, instala un juego gratis pequeño y ábrelo.
- [ ] **U4** Opcional: `catalog install rockstar` o `ea-app`, y `open`. **Se espera:** ventana de inicio de sesión visible.
- [ ] **U5** `catalog list`, `catalog show steam` y `apps`. **Se espera:** la información se entiende y `apps` lista lo instalado.

## Tras las pruebas
- [ ] **T11** Con el resultado de U3 y U4, actualizar `status` y `statusNote` en `lib/catalog_data.dart` (`tested` con fecha, o la causa si falló), y dejar el script de commit.
  **Comprobación:** `dart test -N 'catalog data'`.
