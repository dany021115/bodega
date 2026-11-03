# Tareas: backends-graficos

**Convenciones.** `P` = `bodega/packages/engine`; `T` = `Bodega/runtimes/terceros`. **(USUARIO)**: lo haces tú. El agente no hace commit ni push. Tests sin Wine: `cd P && dart test -N '<nombre>'`.

## Motor
- [x] **T1** `P/lib/backends.dart`: nombres, tabla de URL y SHA-256, `backendEnv` (S4) y test `backendEnv`.
  **Comprobación:** `dart test -N 'backendEnv'`.
- [x] **T2** `installBackend` (B1), con tarballs falsos y test `installBackend` (bueno, alterado, repetido, sin `.tmp-*`). El SHA-256 esperado es parámetro con valor por defecto.
  **Comprobación:** `dart test -N 'installBackend'`.
- [x] **T3** `importD3DMetal` (B2) y test `importD3DMetal` (dos layouts, falta un módulo, ruta y enlace a `CrossOver.app`).
  **Comprobación:** `dart test -N 'importD3DMetal'`.
- [x] **T4** Ajustes (S1, escritura atómica) y `resolveBackend` (S2, S3, S5), con PE falsos en tests `settings` y `resolve`.
  **Comprobación:** `dart test -N 'settings'` y `dart test -N 'resolve'`.
- [x] **T5** Integrar en `P/lib/engine.dart`: `_start` con mapa extra, `runInBottle` con `backend` y `hud`, cabecera `# backend` (S6). `wineboot` sigue con `wine` (S7).
  **Comprobación:** `dart test`; el test `fake runtime cycle` sigue pasando y comprueba la cabecera.
- [x] **T6** Sonda: `P/tool/probe.c` (copia de `.sdd/backends-graficos/spike-files/probe.c`), `P/tool/build_probe.sh` y `P/lib/probe_data.dart` generado.
  **Comprobación:** `bash tool/build_probe.sh` termina y `dart analyze` no da avisos; los PE resultantes son 64 y 32 bits (`file`).
- [x] **T7** `backendTest` (B4) y `listBackends` (B3), con test `listBackends`.
  **Comprobación:** `dart test -N 'listBackends'`.
- [x] **T8** CLI en `P/bin/bodega.dart`: `backend install|import|list|set|test`, y `run --backend --hud` (S7). Usos incorrectos dan 64.
  **Comprobación:** `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`; `build/bodega backend; echo $?` da 64; test de `--hud` tras el programa.

## Checks sin ventanas con el runtime real
Cada uno con un `BODEGA_HOME` nuevo en el scratchpad; primero `stop`, luego `rm -rf`.

- [x] **T9** Instalar el runtime, `create t`, `backend install dxmt T/dxmt…tar.gz`, `backend install dxvk T/dxvk…tar.gz`, `backend test t wine|dxmt|dxvk`.
  **Comprobación:** todos los casos `OK`.
- [x] **T10** Extraer `renderer/d3dmetal` de `T/Template-1.0.11.tar.xz` en una carpeta temporal, `backend import d3dmetal`, `backend test t d3dmetal`. Incluye `CX_APPLEGPTK_LIBD3DSHARED_PATH` y la cadena de 32 bits con DXMT.
  **Comprobación:** todos `OK`. Si la cadena de 32 bits o la variable fallan, **parar** y proponer cambio al spec.
- [x] **T11** En otro `BODEGA_HOME`, importar la copia de Whisky (`lib/` en `WH/Wine`), sin modificarla, y `backend test`.
  **Comprobación:** todos los casos `OK` y salida 0, y no deja procesos colgados.
- [x] **T12** `backend set t dxmt --exe probe.exe` más un `run` sin opción, y comprobar `# backend dxmt (exe)`; `run --backend dxvk` da `(opcion)`; con `backends/d3dmetal` borrado, `--backend d3dmetal` falla con la instrucción (S5).
  **Comprobación:** salida pegada en `verify`.
- [x] **T13 (USUARIO)** Commit en `bodega`. El agente deja `~/Documents/GitHub/Bodega/t13.sh`, sin atribución de IA y sin push.
  **Comprobación:** `git -C bodega log --oneline -1`.

## Aceptación del usuario
Con ventanas, en tu Mac, sobre tu botella.

- [x] **U1** Instalar los tres backends en tu carpeta real (D3DMetal desde tu Whisky) y `backend test prueba d3dmetal`. **Se espera:** `OK`.
- [~] **U2 (corrió; contador no visto)** `run --backend wine --hud prueba ".../Blur.exe"`. **Se espera:** Blur igual que antes y, si el contador aparece, anota los FPS. Con wined3d (OpenGL) puede no aparecer.
- [ ] **U3 (aplazada)** Un juego DX11 con `--backend dxmt --hud`. **Se espera:** arranca, se ve bien y el log dice `dxmt`.
- [ ] **U4 (aplazada)** Un juego DX12 con `--backend d3dmetal --hud`. **Se espera:** arranca y se ve bien.
- [ ] **U5 (aplazada)** Comparar la misma escena de U3 o U4 con CrossOver, usando el mismo backend. **Se espera:** una tabla de FPS. Esto es lo que dirá si vamos a la par, por encima o por debajo.
