# Instalar y abrir

## I1 · Comprobaciones previas
`bodega catalog install <id> [botella]`; sin `botella`, se llama como el `id`. Antes de descargar o crear nada, da error si:
- la entrada está `blocked`, con su `statusNote`;
- su backend no está instalado, con la orden para instalarlo;
- la botella ya existe;
- no hay runtime;
- la URL no empieza por `https://` (o `file://`, solo para tests).

**Escenario (test `installEntry`):** cada caso da su error y no crea la carpeta de la botella.

## I2 · Orden
1. Comprobaciones (I1).
2. Descarga (I3).
3. `createBottle`.
4. `settings.json` con `sync`, y el programa con `backend` y `env`.
5. Registro (I5).
6. Instalador (I4).
7. Espera y parada (I6).
8. Comprobar el ejecutable (I7).
9. `app.json` (I8).

Un fallo de red no deja botella. Un fallo a partir del paso 3 deja la botella con sus logs y dice cómo borrarla (`bodega stop` y `rm -rf`). Sin `app.json`, no cuenta como instalada.

**Escenario (test `installEntry`):** un instalador que falla deja la botella y su log, sin `app.json`.

## I3 · Descarga
- A `downloads/<id>-setup.exe`, o `.msi` si `installer.msi`; el nombre no sale de la URL, porque algunas no tienen extensión.
- `curl -fLsS --proto =https,file --proto-redir =https -C - --retry 5` sobre un archivo `.part`, que se renombra al terminar.
- Con `sha256`: se comprueba, y si no coincide, error y se borra. Un archivo ya bajado que coincida no se baja otra vez.
- Sin `sha256`: imprime `sin checksum fijo: se confía en HTTPS y en <dominio>`, y se baja de nuevo salvo un `.part` por reanudar.
- Tras instalar bien, se borra el instalador sin `sha256`.

**Escenarios (test `installEntry`):**
- **Dado** un `sha256` que no coincide, **entonces** error, sin botella y sin archivo.
- **Dado** `http://…`, **entonces** error `no es https`.

## I4 · Instalador
- Se ejecuta con el backend `wine`, el `sync` de la entrada y un log `<id>-setup`, esperando su salida.
- MSI: `msiexec /i <archivo> /qn` + `args`. Si no: `<archivo>` + `args`.
- Códigos válidos: 0, 102, 194 y 105 (1638, 3010 y 1641 truncados). Otro: error con el código y el log.
- Sin tiempo máximo mientras el proceso del instalador sigue vivo, porque puede ser una ventana que espera al usuario.

**Escenarios (test `installEntry`):** MSI con `msiexec /i … /qn`; salida 194 aceptada; salida 5 da error con la ruta del log.

## I5 · Registro
Cada elemento de `registry` se aplica con `wine reg add <key> /v <name> /t <type> /d <data> /f`, antes del instalador. Una salida distinta de 0 da error.

**Escenario (test `installEntry`):** el Wine falso recibe esos argumentos; (T9) el valor queda en el registro con el Wine real.

## I6 · Espera y parada
Tras salir el instalador, espera hasta que ocurra lo primero:
- el wineserver termina;
- el ejecutable existe y pasan 60 s;
- pasan 30 min.

Después hace `wineserver -k`, para que el primer arranque sea en frío, con sus ajustes finales.

**Escenarios (test `installEntry`, con tiempos cortos por parámetro):**
- **Dado** un servidor que no termina y el ejecutable ya creado, **entonces** para tras el tiempo de gracia.
- **Dado** un servidor que termina, **entonces** sigue sin esperar.

## I7 · Comprobar
`prefix/drive_c/<exe>` debe existir; si no, error `el instalador terminó pero no está <exe>`, con el log.

## I8 · Biblioteca
`bottles/<b>/app.json` se escribe de forma atómica, solo al final: `{id, title, exe, args, installedAt}`.

`bodega apps` imprime `botella  título  exe`; sin aplicaciones no imprime nada y sale con 0. Una botella sin `app.json`, como `prueba`, no aparece.

**Escenario (test `installedApps`):** lista la instalada e ignora las demás y un `app.json` roto se nombra en un error.

## I9 · Abrir
`bodega open [--backend <b>] [--hud] <botella>` lanza `C:\<exe con \>` con sus `args`, igual que `run`: mismos ajustes, log, `# backend` y código de salida. Sin `app.json`, error que sugiere `bodega run`.

**Escenario (test `installedApps`):** con el Wine falso, recibe la ruta `C:\…` y los `args`, con el cwd del programa.

## I10 · Avance y notas
`installEntry` recibe `onStep(String)`, que la app usará para mostrar el avance, y el CLI imprime. Al terminar, el CLI imprime las `notes` de la entrada, porque avisan de cosas como los 15–25 min del primer arranque de Steam.
