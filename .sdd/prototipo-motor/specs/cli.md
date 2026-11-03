# Spec: CLI y raíz de datos

Los tests citados están en `packages/engine/test/engine_test.dart`. Las tareas `Tn` y los pasos `Un` están en `tasks.md`.

### R1 · Raíz de datos
- La raíz es `BODEGA_HOME`, si está definida, o `$HOME/Library/Application Support/Bodega`.
- Se crea y se canonicaliza con `resolveSymbolicLinksSync()`.
- La raíz se valida también antes de crearla (sin contar `.` ni `..`), para no dejar en disco una raíz rechazada.
- Ningún componente de la ruta puede acabar en `.` o en espacio, ni contener `<>:"|?*` (trampa 11). Lo comprueba `winPathProblem`.
- Dentro van `runtimes/` y `bottles/`.

Escenarios:
- **Dado** `BODEGA_HOME=/tmp/b`, **cuando** corre un verbo, **entonces** todo queda bajo `/private/tmp/b`.
- **Dado** `BODEGA_HOME=/tmp/a./b`, **cuando** corre un verbo, **entonces** sale con 1 y el mensaje nombra el componente `a.`.

**Comprobación:** test `names and windows paths` y T13 (headless).

### R2 · Verbos y códigos de salida
Verbos: `bodega install <engine.tar.gz> <hostlibs.tar.gz>`, `create <b>`, `run <b> <programa> [args…]`, `wait <b>` y `stop <b>`.

Códigos de salida:
- Sin argumentos o con un verbo desconocido: imprime el uso por stderr y sale con 64.
- Ante cualquier error: escribe `bodega: <mensaje>` por stderr y sale con 1.
- `run` sale con el código del programa; `wait` y `stop`, con el suyo (R11).

Se compila con `dart compile exe` y produce `build/bodega` (arm64, firma ad hoc). No tiene dependencias de ejecución.

Escenarios:
- **Dado** `bodega` sin argumentos, **entonces** imprime el uso y sale con 64.
- **Dado** `bodega create 'a b'`, **entonces** sale con 1 y no crea `bottles/a b`.

**Comprobación:** T13 (`build/bodega; echo $?`).

### R3 · Rosetta
Antes de crear la raíz y de ejecutar cualquier verbo válido, el CLI corre `/usr/bin/arch -x86_64 /usr/bin/true`. Si falla, escribe `bodega: falta Rosetta: softwareupdate --install-rosetta --agree-to-license` y sale con 1 (`INV/INFORME-FINAL.md:321`).

Escenario:
- **Dado** un Mac sin Rosetta, **cuando** se ejecuta `bodega create x`, **entonces** sale con 1, muestra ese mensaje y no existe `bottles/x`.

**Comprobación:** revisión del código en verify, porque no se desinstala Rosetta para probarlo. El caso positivo lo ejercitan T13 y T16, que usan el CLI.
