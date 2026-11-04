# Añadidos al motor

Todo en `packages/engine/lib`, con tests sin Wine. El CLI no cambia su comportamiento.

## E1 · Workspace
Raíz con `pubspec.yaml` de workspace; el motor con `resolution: workspace`; su `pubspec.lock` pasa a la raíz.

**Escenario:** `dart test` en `packages/engine` pasa y `dart compile exe bin/bodega.dart` genera el programa.

## E2 · `listBottles(home)`
Devuelve `{name, ready, app}` por nombre, con `app` nula si no hay `app.json`. `ready` es la misma comprobación que usa `runInBottle`. Un `app.json` roto da el mismo error que `installedApps`.

**Escenario (test `listBottles`):** una botella lista con aplicación, otra sin ella y otra incompleta salen con esos valores.

## E3 · `bottleSettings(home, botella)`
Versión pública de `_settings`: `backend`, `sync` y `programs`.

**Escenario (test `settings`):** devuelve lo guardado con `setBackend` y `setSync`, y los valores por defecto si no hay archivo.

## E4 · `removeBottle(home, botella)`
Para la botella si hay runtime y borra su carpeta sin seguir enlaces (`dosdevices/z:` apunta a `/`).

**Escenarios (test `removeBottle`):**
- **Dado** una botella con un enlace a una carpeta externa, **entonces** se borra la botella y la carpeta externa sigue ahí.
- **Dado** una que no existe, **entonces** error `no existe la botella`.

## E5 · `rosettaInstalled()` y `hasRuntime(home)`
`rosettaInstalled` sale del CLI, que pasa a usarla. `hasRuntime` no lanza error.

**Escenario (test `hasRuntime`):** `false` sin runtime o con `current` roto; `true` con runtime.

## E6 · Instalador ya descargado
`installEntry(…, setup: <ruta>)` omite la descarga y usa ese archivo. Si la entrada fija `sha256`, lo comprueba igual. El resto del flujo no cambia, y tras instalar bien borra el archivo si no tiene `sha256`.

**Escenarios (test `installEntry`):** con `setup` no se llama a `curl`, porque la URL inválida no molesta; con un `sha256` que no coincide, error y sin botella.

## E7 · `bottleLogs(home, botella)`
Logs de más nuevo a más viejo: `{path, name, modified, exitCode}`. `exitCode` sale del `.exit`, y es nulo si aún no existe.

**Escenario (test `bottleLogs`):** orden correcto, y `exitCode` nulo o con su valor.

## E8 · `addApp(home, botella, title, exe)`
Registra una aplicación propia en `app.json`, con `id` igual a `custom`. `exe` es relativo a `drive_c` o una ruta absoluta de Unix, y `openApp` admite las dos. Error si el archivo no existe o la botella ya tiene aplicación.

**Escenarios (test `addApp`):** ruta dentro y fuera de `drive_c` se abren con su programa; sin archivo, error; segunda aplicación, error.

## E9 · `pinnedBackend(nombre)`
Devuelve `url` y `sha256` de `dxmt` y `dxvk`, y nulo para los demás, para que la app descargue con `dio`.

**Escenario (test `backendEnv`):** `dxmt` da la URL y el SHA del fork, y `d3dmetal` da nulo.
