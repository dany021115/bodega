# Catálogo

## C1 · Datos
`lib/catalog_data.dart` contiene un JSON con las 7 entradas, en este orden: `steam`, `rockstar`, `ea-app`, `ubisoft-connect`, `battle-net`, `epic-games`, `gog-galaxy`. Ese es el orden que muestra la lista.

Campos de cada entrada:

| Campo | Contenido |
|---|---|
| `id`, `title` | Identificador (nombre de botella válido, R8) y título |
| `status`, `statusNote` | C2 |
| `flaky` | Opcional: por qué es inestable |
| `installer` | `url`, `sha256` (o `null`), `args`, `msi` |
| `exe`, `args` | Ejecutable relativo a `drive_c`, con `/`, y sus argumentos |
| `backend`, `sync` | Un backend de la lista, sin `auto`; `msync` o `none` |
| `env` | Variables del programa |
| `registry` | Lista de `{key, name, type, data}` |
| `notes`, `knownIssues` | En español; `knownIssues`: `{symptom, fix}` |
| `source` | `{repo, commit, path, license, verified}` |

**Escenario (test `catalog data`):**
- **Dado** el JSON embebido, **entonces** hay 7 entradas con `id` válido y único, `url` que empieza por `https://`, `backend` y `sync` conocidos, `exe` relativo y sin `..`, licencia `CC0-1.0`, y ningún `env` con `WINEPREFIX`, `WINEMSYNC`, `PATH`, `HOME` ni `DYLD_*`.

## C2 · Estados
- `tested`: probado por el usuario en Bodega; `statusNote` dice cuándo y con qué.
- `reported`: Highball lo verificó, o terceros lo reportan, sobre un motor comparable.
- `untested`: sin verificación aplicable a este motor.
- `blocked`: no se instala; `statusNote` explica por qué y qué alternativa hay.

Valores iniciales:

| Entrada | Estado |
|---|---|
| `steam` | `tested`, tras U3 (al principio, `reported`) |
| `rockstar`, `ubisoft-connect` | `reported` |
| `ea-app` | `reported`, con `flaky` |
| `battle-net` | `untested`, con `flaky` |
| `epic-games`, `gog-galaxy` | `blocked` |

Solo U3 o una prueba posterior del usuario puede poner `tested`. No hay estrellas ni valoraciones numéricas.

**Escenario (test `catalog data`):**
- **Dado** una entrada `blocked`, **entonces** su `statusNote` no está vacía.

## C3 · Listar y buscar
`bodega catalog list [texto]` imprime `id  título  estado`, una línea por entrada. El filtro no distingue mayúsculas y busca en `id` y `title`.

**Escenarios (test `catalogEntries`):**
- **Dado** `STEAM`, **entonces** una sola entrada, `steam`.
- **Dado** `zzz`, **entonces** ninguna, salida 0.
- **Dado** sin texto, **entonces** las 7 en orden.

## C4 · Detalle
`bodega catalog show <id>` imprime título, estado y nota, backend, sync, notas, problemas conocidos y procedencia. Un `id` desconocido da error y salida 1.

**Escenario (CLI, T8):** `show steam` muestra `reported` y `highball-db`; `show nope` da salida 1.
