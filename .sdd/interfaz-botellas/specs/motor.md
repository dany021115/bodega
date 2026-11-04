# Motor

Todo en `packages/engine`, con tests con el Wine falso que ya existe. Una ruta de bottle nunca sigue enlaces: `dosdevices/z:` apunta a `/`.

## Hito 1

### M1 · `apps.json` sin perder datos
`bottles/<b>/apps.json` guarda `{"apps": [{id, title, exe, args, installedAt}], "hidden": [clave]}`.

- Sin `apps.json`, un `app.json` existente cuenta como la única aplicación.
- La primera escritura crea `apps.json` y solo después borra `app.json`.
- Escritura atómica, como todo JSON del motor. Un archivo roto da error, no se ignora.

**Escenarios (test `apps.json`):** una botella antigua lista su aplicación; al añadir otra quedan las dos y desaparece `app.json`; roto, error con la ruta.

### M2 · Clave de aplicación
Cada aplicación tiene una `key`: la ruta del exe relativa a `drive_c` en minúsculas y con `/`, o la absoluta si está fuera, o `steam:<appid>`.

**Escenario (test `appKey`):** `C:\Program Files\X\A.EXE` y `Program Files/X/a.exe` dan la misma clave.

### M3 · Leer `.lnk`
`readLnk(ruta)` devuelve `{target, args, workingDir}` o `null`, nunca un error. Admite ruta local en `LinkInfo` y cadenas ANSI o Unicode.

**Escenarios (test `readLnk`):** bytes con la forma real de `Steam.lnk`; con argumentos; truncado o sin cabecera, `null`.

### M4 · Detección
`bottleApps(home, botella)` devuelve primero las registradas y luego las detectadas en `users/*/Desktop`, `users/*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs` y `ProgramData/Microsoft/Windows/Start Menu/Programs`, en orden alfabético.

- Título: el nombre del `.lnk` sin extensión.
- Solo destinos `.exe` que existen dentro de `drive_c`.
- Fuera: las de `hidden`, y `unins*.exe` y `uninstall*.exe`.
- Sin duplicados por clave. Gana la registrada.

**Escenarios (test `bottleApps`):** tres `.lnk` al mismo exe dan una; uno al exe registrado no duplica; un desinstalador y uno a una URL no salen; un `z:` en el árbol no se recorre.

### M5 · Juegos de Steam
Si existe `Program Files (x86)/Steam/steam.exe`, cada `steamapps/appmanifest_*.acf` con el bit 4 en `StateFlags` da una aplicación:

- `key` igual a `steam:<appid>`, `title` igual a `name`, `exe` el de Steam y `args` `-applaunch <appid>`.
- Fuera: el `228980`, Steamworks Common Redistributables.

**Escenarios (test `steam games`):** Muck sale y los redistribuibles no; una instalación a medias no sale; sin Steam, ninguna.

### M6 · Abrir y registrar
- `openApp(home, botella, {key, backend, hud})`: sin `key`, abre la primera registrada, o la primera si no hay registradas.
- `addApp` admite varias, y rechaza el mismo exe por clave.
- `hideApp(home, botella, key)`: una registrada se quita; una detectada va a `hidden`.
- `listBottles` da `apps` en vez de `app`. `installedApps` da las de todas las botellas, y sigue siendo la base de `bodega apps`.
- `bodega open <botella> [clave]`.

**Escenarios (tests `addApp`, `openApp`, `hideApp`):** dos aplicaciones abren su programa; `open steam` sin clave abre Steam; un mismo exe, error; ocultar no vuelve a listar; el CLI en `steam` da lo mismo que antes.

### M7 · Iconos
`appIcon(home, app)` devuelve la ruta de una imagen o `null`, nunca un error.

- **Con exe:** extrae el mayor icono del `.rsrc` a `bottles/<b>/icons/<hash de clave>.ico`. Si el `.ico` es más nuevo que el exe, no vuelve a leerlo.
- **Juegos de Steam:** `appcache/librarycache/<appid>/` con su `<hash>.jpg` de 40 caracteres, o `logo.png`.

**Escenarios (test `appIcon`):** PNG y DIB de un PE construido en el test; sin `.rsrc`, `null`; no es PE, `null`; la segunda vez usa la caché.

## Hito 2

### M8 · Ajustes de botella
`settings.json` gana `highRes` (falso), `dlss` (falso), `avx` (verdadero), `windows` (`win10`) y `env` (vacío). Sin ellos, los valores por defecto.

- `avx` falso **quita** `ROSETTA_ADVERTISE_AVX` del entorno.
- `dlss` añade `D3DM_ENABLE_METALFX=1` y `DXMT_ENABLE_NVEXT=1`.
- Orden del entorno: backend, botella, programa, y lo de ese lanzamiento.

**Escenarios (test `settings`):** una botella sin estos campos los da por defecto; el entorno cambia como se indica, comprobado en el log del Wine falso.

### M9 · Alta resolución
`setHighRes(home, botella, valor)` para la botella si cambia, y con `reg add` escribe `HKCU\Software\Wine\Mac Driver\RetinaMode` (`y` o `n`) y `HKCU\Control Panel\Desktop\LogPixels` (192 o 96). Devuelve si la paró, como `setSync`.

**Escenario (test `setHighRes`):** con el Wine falso, las dos órdenes y el ajuste guardado; repetir el valor no para nada.

### M10 · Versión de Windows
`setWindowsVersion(home, botella, version)` ejecuta `winecfg -v <version>` y lo guarda. Admite `win11`, `win10`, `win81` y `win7`; otra, error.

**Escenario (test `setWindowsVersion`):** la orden con el Wine falso; `foo`, error sin cambiar nada. **Real, sin ventana:** `winecfg -v` responde lo que se puso.

### M11 · Lanzar con opciones
`runInBottle` y `openApp` ganan `env` y `avx`. `addApp` gana `args` y `env`, este último en `programs` del exe.

**Escenario (test `runInBottle`):** `env` llega al programa; `avx: false` quita la variable solo en ese lanzamiento.

### M12 · Instalar en una botella existente
`installEntry(…, bottle: b, intoExisting: true)` no crea botella ni cambia su backend ni su sync: añade la excepción del programa, el registro y la aplicación. Sin `intoExisting`, sigue rechazando una que exista. Si la entrada pide otro sync, devuelve el aviso por `onStep`.

**Escenarios (test `installEntry`):** dos entradas en una botella quedan las dos; el sync de la botella no cambia; una botella sin preparar, error.

## Hito 3

### M13 · Duplicar y renombrar
- `duplicateBottle(home, origen, destino)`: para el origen y hace `cp -cR`. Un destino existente o con nombre inválido, error sin tocar nada.
- `renameBottle(home, origen, destino)`: para la botella y renombra.

**Escenarios (test `duplicateBottle`, `renameBottle`):** los enlaces siguen siendo enlaces y `z:` apunta donde apuntaba; la copia es independiente. **Real, sin ventana:** un programa corre en la copia y en la renombrada.

### M14 · Exportar e importar
- `exportBottle(home, botella, archivo)`: para la botella y crea un `.tar.gz` con `tar`, sin `logs` ni `icons`.
- `importBottle(home, archivo)`: lista el contenido antes de extraer; exige una sola carpeta raíz con `prefix/`, sin rutas absolutas ni `..`; extrae a `bottles/.tmp-import`; y renombra. Si el nombre ya existe, añade `-2`. Devuelve el nombre. Un fallo no deja restos.
- `listBottles` ignora lo que empiece por punto.

**Escenarios (test `exportBottle`, `importBottle`):** ida y vuelta conservando `z:`; un archivo con dos raíces o con `..`, error y sin restos; nombre repetido, `-2`.

### M15 · Caché de instaladores
`downloadsSize(home)` y `clearDownloads(home)`, que borra lo de `downloads/` sin seguir enlaces.

**Escenario (test `downloads`):** el tamaño, y vacía.
