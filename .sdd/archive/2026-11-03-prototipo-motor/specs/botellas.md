# Spec: botellas

### R8 · Nombre y estructura
- El nombre de la botella es el nombre de su carpeta y cumple `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`.
- Estructura:
  - `bottles/<b>/prefix`: es el `WINEPREFIX` y lo crea Wine.
  - `bottles/<b>/logs/`.
- No hay UUID ni `bottle.json`.
- `run`, `wait` y `stop` sobre una botella que no existe fallan con `no existe la botella <b>`.

Escenarios:
- **Dado** `prueba` o `cave-story_2`, **entonces** se aceptan.
- **Dado** `''`, `.x`, `-x`, `a.`, `a b`, `a/b`, `a:b` o un nombre de 65 caracteres, **entonces** se lanza `FormatException`.

**Comprobación:** test `names and windows paths`.

### R9 · Crear
`create <b>`:
1. Exige que haya un runtime actual y que no exista `bottles/<b>`. APFS no distingue mayúsculas, así que `Prueba` choca con `prueba`.
2. Crea `logs/`.
3. Lanza en modo adjunto `<rt>/engine/bin/wine wineboot`, sin banderas, con el script de design §2, el cwd en `bottles/<b>` y el log `<UTC>-wineboot.log`.
4. Si wineboot sale con un código distinto de 0: ejecuta `wineserver -k` y da error.
5. Si sale con 0: ejecuta `wineserver -w` con un tope de 10 min. Si se agota, ejecuta `-k` y da error.

Escenarios:
- **Dado** el runtime falso, **cuando** se ejecuta `createBottle('t')`, **entonces** devuelve la ruta del log, que contiene `# exit=0`.
- **Dado** que `bottles/t` ya existe, **entonces** da el error `ya existe` y sugiere `rm -rf <ruta>`.

**Comprobación:** test `fake runtime cycle`; T15; U2 (tiempo).

### R10 · Botella lista
- Una botella está lista si, después de `-w`, existen `prefix/drive_c/windows/syswow64/kernel32.dll` y `prefix/system.reg`. wineboot puede devolver 0 aunque falte syswow64 (trampa 7), y el registro solo llega a disco cuando el servidor lo guarda.
- Si la botella no queda lista, `create` falla. No la repara ni la borra: la carpeta y el log se quedan para diagnosticar.
- `run` exige que la botella esté lista.

Escenario:
- **Dado** la botella falsa `broken`, cuyo wineboot da 0 sin crear syswow64, **entonces** da un error con la ruta del log, y la carpeta y el log siguen ahí.

**Comprobación:** test `fake runtime cycle`; T15.

### R11 · Esperar y parar
- `wait <b>` ejecuta `<rt>/engine/bin/wineserver -w` y devuelve su código. Si no hay servidor, vuelve al instante.
- `stop <b>` ejecuta `wineserver -k`. Los códigos 0 y 1 (1 = no había servidor) se devuelven como 0; cualquier otro se propaga.
- Los dos usan el entorno de la botella, es decir, el mismo `WINEPREFIX` (trampa 5).
- No hay reaper.

Escenarios:
- **Dado** el runtime falso, donde `-k` sale con 1, **entonces** `stopBottle` devuelve 0 y `waitBottle` también.
- **Dado** notepad abierto, **cuando** se ejecuta `bodega stop prueba`, **entonces** notepad se cierra en unos 11 s como mucho y termina el `run` que lo lanzó.

**Comprobación:** test `fake runtime cycle`; T15; U6 y U7.
