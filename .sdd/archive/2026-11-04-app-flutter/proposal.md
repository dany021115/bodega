# Propuesta: app-flutter

## Por qué

Bodega ya instala y abre aplicaciones, pero solo por línea de comandos. Falta la app de escritorio, parecida a CrossOver, con la arquitectura y las herramientas de TeeShot.

## Qué

**Monorepo:** `apps/bodega` (app Flutter solo para macOS) y `packages/engine` (el motor actual), en un pub workspace.

**Arquitectura de TeeShot:** capas `domain`/`data`/`device`/`app`, `go_router` con `AppRoute` y `RouterManager`, `device/theme` con un archivo por tema, bloc con freezed, repositorios con `Either`, get_it e injectable, `responsive_framework`, `dio` y `retrofit`, toastification, spider y un widget por archivo.

**Pantallas**, con barra lateral:

| Sección | Qué hace |
|---|---|
| **Primer arranque** | Comprueba Rosetta y deja elegir los tarballs del runtime |
| **Biblioteca** | Aplicaciones instaladas, abrir y parar, estado en vivo, y "Agregar otra aplicación" |
| **Catálogo** | Las 7 aplicaciones, buscador, ficha, instalación con barra de progreso y aviso de anti-cheat |
| **Botellas** | Lista y detalle: backend, msync, logs, ejecutar un programa y borrar |
| **Backends** | Instalar DXMT y DXVK con progreso, importar D3DMetal con instrucciones, y comprobar con la sonda |

**Añadidos al motor:** listar y borrar botellas, leer sus ajustes y logs, comprobar Rosetta y el runtime, aceptar un instalador ya descargado, registrar una aplicación propia y exponer las descargas fijadas.

## Fuera de alcance

- Firebase, Sentry, RevenueCat, mapas, Phoenix y demás piezas del producto móvil de TeeShot.
- `envied`: Bodega no tiene claves. Se añade cuando haga falta.
- Las 737 fichas de juegos de `highball-db`, `legendary`, y arrastrar y soltar `.exe`.
- Actualizaciones automáticas, firma y distribución: es de uso personal.
- Medir FPS en la interfaz, y la línea arm64.

## Impacto

- **Raíz:** `pubspec.yaml` de workspace y `pubspec.lock`; `.gitignore` con los archivos generados, como TeeShot.
- **`packages/engine`:** `resolution: workspace`, funciones nuevas y sus tests. El programa `bodega` sigue igual.
- **`apps/bodega`:** nuevo.
- **`.claude/`:** `CLAUDE.md` y `rules/`.
- **`bodega-engine`:** sin cambios.

## Decisiones

| # | Duda | Decisión | Motivo |
|---|---|---|---|
| 1 | Ruta y nombre | `apps/bodega`, paquete `bodega`, bundle `com.dany021115.bodega` | Probado en el spike |
| 2 | Versiones | Las actuales: `freezed` 4, `build_runner` 2.16, `injectable` 3, `go_router` 18, `retrofit` 4.10 | Las de TeeShot se cuelgan con Dart 3.13. Estas compilaron y generaron código (`design.md` §7) |
| 3 | `dio` | Descargas con progreso y cancelación, y `retrofit` para la lista de anti-cheat | Son usos reales, y `curl` no da avance a la app |
| 4 | Primer arranque | Elegir los tarballs locales con `file_selector` | El repo del runtime es privado |
| 5 | Iconos | SVG de `simple-icons` (CC0; están los 7) con `spider` | Las marcas siguen siendo de sus dueños; uso personal |
| 6 | Aspecto | Oscuro por defecto, acento burdeos, barra lateral | Tu captura y "Bodega". Se cambia en `AppColor` |
| 7 | Secciones | Biblioteca, Catálogo, Botellas, Backends | Aprobado |
| 8 | Reglas | `.claude/CLAUDE.md` y `rules/` | Para que la arquitectura se mantenga |
| 9 | `AppError` | En `domain/entities/`, no en `data/api/` como TeeShot | TeeShot incumple ahí su propia regla: `domain` importa de `data` |
| 10 | Otra aplicación | Elegir un `.exe`, botella nueva o existente, e indicar si es un instalador | Cubre Blur y un instalador cualquiera. Una aplicación por botella |
| 11 | Abierta o cerrada | `wineserver -w` por botella | Sigue a toda la botella, no solo a un proceso: resuelve lo de Steam |
| 12 | Archivos generados | Fuera del repo, como TeeShot | Hay que correr `build_runner` tras clonar |

## Riesgos

- **Es grande:** unas 13 tareas de código. Va por hitos, cada uno compilable.
- **Interfaz sin probar por agentes:** pueden compilar, pasar tests y abrir la app, pero no juzgar cómo se ve. Eso lo pruebas tú.
- **Bloqueos de la interfaz:** el motor hace lecturas síncronas cortas. Hay que comprobarlo con el log de EAC, de unos 600 KB.
- **Launchers sin probar:** el catálogo seguirá diciendo `reportado` o `sin probar` para los demás, y puede fallar su instalación.
- **Instrucciones de D3DMetal:** la imagen actual de Apple no se ha comprobado con `import`; solo las copias de Whisky y Sikarugir. Las instrucciones lo dirán.
- **`simple-icons`:** el paquete es CC0, pero los logos son marcas. Si la app se publica algún día, hay que revisarlo.
