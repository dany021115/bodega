# Pantallas

Cada bloc se prueba con `bloc_test` y repositorios falsos (`mocktail`). Lo visual lo aceptas tú (U).

## Primer arranque

### P1 · Rosetta y runtime
`/setup`: si falta Rosetta, muestra el comando para instalarla y un botón de volver a comprobar. Si falta el runtime, deja elegir con `file_selector` los tarballs del motor y de las librerías, que deben tener su `.sha256` al lado, y los instala con indicador de carga. Un error se muestra tal cual y permite reintentar.

**Escenarios (test `SetupBloc`):** sin Rosetta; sin runtime; instalación correcta; error del motor.

## Catálogo

### P2 · Lista y búsqueda
`/catalog`: buscador, y tarjetas con icono, título y estado en español (`Probado`, `Reportado`, `Sin probar`, `Bloqueado`, y `Inestable` si tiene `flaky`). Sin estrellas. Enlace "Agregar otra aplicación". Una aplicación ya instalada lo indica.

**Escenarios (test `CatalogBloc`):** carga las 7; filtra sin distinguir mayúsculas; marca las instaladas.

### P3 · Ficha
`/catalog/:id`: estado y su nota, backend y sync, notas, problemas conocidos y procedencia. Botón según el caso:
- `Instalar`;
- `Abrir`, si está instalada;
- desactivado con su motivo, si está bloqueada;
- `Instalar <backend>`, que lleva a Backends, si falta el backend.

### P4 · Instalar con progreso
`InstallBloc` global: una instalación a la vez, que continúa aunque cambies de pantalla. Estados: descargando (porcentaje y botón cancelar), instalando (paso actual, de `onStep`), terminada (notas y botón Abrir) y fallida (mensaje, ruta del log y botón Borrar botella).

- La descarga es con `dio`, a `downloads/<id>-setup.exe.part`, y se reanuda con `Range`.
- Cancelar borra el `.part` y no deja botella.
- Sin `sha256`, muestra el aviso de que se confía en HTTPS y en el dominio.

**Escenarios (test `InstallBloc`):** progreso; cancelar; error de red sin botella; error del instalador con log; segunda instalación rechazada mientras hay una en marcha.

### P5 · Aviso de anti-cheat
En el catálogo, buscar un juego consulta la lista `db/anticheat.json` de `highball-db` en `f0bf6a2`, con `retrofit`, cacheada en `cache/anticheat.json`. Muestra el juego, su anti-cheat y su veredicto. Aclara que no aparecer no garantiza nada: POLYGON no está en la lista.

**Escenarios (test `AntiCheatRepository`):** descarga y guarda; sin red usa la caché; sin red ni caché da `NetworkError`, y el catálogo sigue funcionando.

## Biblioteca

### P6 · Lista
`/library`: tarjetas de `installedApps` con icono, o inicial si es propia, título y estado (`Abierta` o `Cerrada`). Vacía: invita a ir al Catálogo.

**Escenario (test `LibraryBloc`):** lista y estado vacío.

### P7 · Abrir y parar
`LibraryBloc` global. `Abrir` llama a `openApp` y `Parar` a `stopBottle`, con confirmación, porque cierra lo que haya abierto. Una aplicación está abierta mientras `waitBottle` no haya terminado, aunque el primer proceso ya saliera. Al arrancar la app se reconstruye el estado: `waitBottle` vuelve en menos de 1 s si no hay servidor.

**Escenarios (test `LibraryBloc`):** abrir pasa a abierta; sigue abierta aunque salga el primer proceso; pasa a cerrada al terminar `waitBottle`; estado reconstruido al arrancar.

### P8 · Avisos mientras está abierta
Cada 5 s, mientras esté abierta, comprueba `antiCheatHints` con `since` igual a la hora de abrir, y una vez al cerrarse `hintsIn` del log. Cada aviso sale una vez, como toast, y queda visible en la tarjeta.

**Escenario (test `LibraryBloc`):** un aviso se emite una sola vez.

### P9 · Agregar otra aplicación
Diálogo: elegir `.exe`, título (por defecto, el nombre del archivo), botella nueva (por defecto) o una existente sin aplicación, y la casilla "Es un instalador".
- **Sin casilla:** `addApp` con esa ruta.
- **Con casilla:** lo ejecuta en la botella, espera a que termine, y pide elegir el ejecutable instalado, con `file_selector` abierto en `drive_c`.

La ruta se valida con `winPathProblem` antes de crear nada.

**Escenarios (test `AddAppBloc`):** programa suelto; instalador; ruta inválida sin botella creada.

## Botellas

### P10 · Lista
`/bottles`: `listBottles` con nombre, aplicación y estado (`Lista`, `Incompleta` o `Abierta`). Una incompleta se puede borrar.

### P11 · Detalle
`/bottles/:name`: selector de backend (`auto` y los instalados) y de msync, con aviso de que cambiar msync cierra la botella; excepciones por programa, que se pueden quitar; `Ejecutar un programa`; lista de logs y su contenido, con los últimos 2.000 renglones; `Borrar`, con confirmación que nombra la botella.

**Escenarios (test `BottleDetailBloc`):** carga; cambiar backend y msync; borrar vuelve a la lista; error del motor.

## Backends

### P12 · Lista e instalación
`/backends`: los 4 con su estado. `dxmt` y `dxvk` se instalan con `dio`, con progreso y comprobando el SHA fijado. También `Elegir archivo…`, para usar un tarball local.

### P13 · D3DMetal
Instrucciones en la pantalla:
1. Consíguelo de Apple (enlace a developer.apple.com) o usa una copia tuya que ya tengas.
2. Elige la carpeta que contiene `wine/` y `external/`, o `lib/`.
3. Pulsa `Comprobar`.

Dice que su uso se rige por la licencia de Apple, que la copia de CrossOver no se acepta, y que solo se ha probado con las copias de Whisky y Sikarugir.

### P14 · Comprobar
`Comprobar` necesita una botella y ejecuta `backendTest`, que **cierra lo que haya abierto en ella**: lo avisa antes. Muestra `OK` o `Falla` por caso, con su log.

**Escenarios (test `BackendsBloc`):** progreso; SHA erróneo; importar con error; resultados de la comprobación.
