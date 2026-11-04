# Pantallas

Como hasta ahora: bloc con `bloc_test` y repositorios falsos; cada pantalla en `pages_test.dart` a 720, 801, 1100 y 1921 px; lo visual lo aceptas tú. Las operaciones con ventana las pruebas tú.

## Hito 1

### V1 · Barra lateral
De arriba abajo: `Biblioteca`, `Instalar` (`/catalog`), el título `Botellas` con su lista, y al fondo `Backends` y el tema.

- Cada botella: nombre, punto si está abierta, y aviso si está incompleta.
- La botella de la ruta actual queda marcada.
- Con muchas botellas, solo su lista hace scroll.
- Por debajo de `DESKTOP`: solo iconos, con la inicial de cada botella y tooltip.

**Escenarios (test de widget `SideBar`):** a 1000 px se ven los nombres; a 600 px, iniciales; marca la botella actual, y el punto si está abierta; 50 botellas no desbordan.

### V2 · Rutas
`/bottles/:name` es la pantalla de botella. `/bottles` lleva a `/library`, y borrar una botella también. Una botella que no existe muestra un aviso con vuelta a Biblioteca.

**Escenario (test `router`):** esas redirecciones, y las de `/setup` siguen igual.

### V3 · Pantalla de botella
Cabecera con el nombre y el estado (`Abierta`, `Cerrada` o `Incompleta`); centro con sus aplicaciones; columna derecha de 270 px con secciones plegables, que recuerdan si estaban abiertas.

- Si el contenido mide menos de 760 px, la columna pasa debajo de las aplicaciones.
- En este hito, la columna lleva lo que ya existe: Ejecutar un programa, Parar y Borrar; Gráficos, msync y excepciones; y Logs.
- Los logs se abren en un diálogo, con sus últimas 2.000 líneas.

**Escenarios (`BottleDetailBloc` y `pages_test`):** carga aplicaciones y ajustes; una botella vacía invita a instalar; cambia a una columna a menos de 760 px.

### V4 · Aplicaciones de una botella
Rejilla de iconos con título. Doble clic o Intro abre. Clic derecho o el botón `⋯`: `Abrir` y `Ocultar`.

El icono es el real del programa; si no hay, el logo del catálogo; si no, la inicial. Una imagen rota cae al siguiente.

**Escenarios (widget `AppTile` y `AppIcon`):** doble clic abre; un clic no; Intro abre; `⋯` ofrece las dos; las tres caídas del icono.

### V5 · Biblioteca
Las aplicaciones de todas las botellas, con icono, título, nombre de la botella, estado de la botella, `Abrir` y, si está abierta, `Parar botella`. Vacía, invita a `Instalar`.

**Escenarios (test `LibraryBloc`):** lista las de varias botellas, incluidas las detectadas; una botella sin aplicaciones no sale.

### V6 · Abrir varias
`LibraryEvent.open` lleva botella y clave.

- Con la botella abierta, se puede abrir otra aplicación suya.
- La misma aplicación no se lanza dos veces en 2 s: lanzar tarda milisegundos, y un doble clic en `Abrir` pasaría si solo se mirara mientras se lanza.
- `Abierta` sigue siendo por botella, con todo lo de P7 y P8 de `app-flutter`.

**Escenarios (test `LibraryBloc`):** dos aplicaciones en una botella; doble clic una vez; sigue abierta hasta que se vacía; cerrada al terminar.

### V7 · Lo que ya existe, adaptado
- **Ficha del catálogo:** `Abrir` usa la botella y la aplicación.
- **Agregar otra aplicación:** elige botella nueva o cualquiera lista.
- **Botellas:** la lista de la barra se recarga al instalar, agregar y borrar.
- **Ventana:** 1150×800 por defecto; el mínimo sigue en 720×480.

**Escenarios (tests `CatalogRepository`, `AddAppBloc`):** con dos aplicaciones en `steam`, el catálogo sigue marcando Steam; agregar a una botella con aplicación funciona.

## Hito 2

### V8 · Acciones
`Ejecutar con opciones…`, `Instalar en esta botella`, `Abrir unidad C:` (en Finder), `Abrir terminal`, `Parar` y `Borrar botella`.

**Escenario (widget):** `Parar` solo con la botella abierta. Borrar confirma nombrando la botella.

### V9 · Configuración avanzada
Gráficos, versión de Windows, msync, alta resolución, DLSS y AVX.

- msync y alta resolución avisan de que cierran la botella.
- DLSS dice que necesita un juego compatible y que no se ha probado.

**Escenarios (test `BottleDetailBloc`):** cada ajuste llama al repositorio y recarga; cancelar el aviso no cambia nada; un error se muestra.

### V10 · Paneles de control
Configuración de Wine, Editor del registro, Administrador de tareas, Panel de control, Mandos (`control joy.cpl`) y Desinstalar programas.

**Escenario (widget):** cada uno lanza su programa con `LibraryEvent.run`.

### V11 · Ejecutar con opciones
Diálogo con programa, argumentos, variables de entorno, backend de ese lanzamiento, HUD de Metal, sin AVX y `Guardar como lanzador` con su título. También desde el `⋯` de cada aplicación, ya rellenado.

Las variables se escriben una por línea como `NOMBRE=valor`. Una línea inválida se señala y no se lanza. `WINEDEBUG` se pone aquí: no hay otra pantalla de canales de log.

**Escenarios (test `RunOptionsBloc`):** lanza con lo escrito; guardar crea la aplicación; una variable inválida no lanza; una ruta que Wine no admite se avisa.

### V12 · Instalar con opciones
En la ficha: `Botella nueva` por defecto, o una lista; e `Instalador`: descargar por defecto, o elegir un archivo local.

Con botella existente, avisa si la entrada pide otro sync. Desde `Instalar en esta botella` llega ya elegida.

**Escenarios (test `InstallBloc`):** en existente no descarga si hay archivo local; rechaza la existente que no esté lista; sigue el resto de P4.

## Hito 3

### V13 · Nueva botella e importar
Al pie de la lista de botellas: `+` con `Nueva botella…` (nombre y versión de Windows, con el nombre validado al escribir) e `Importar…`.

**Escenarios (test `NewBottleBloc`):** crea y lleva a ella; nombre inválido o repetido, sin crear.

### V14 · Duplicar, renombrar y exportar
En Acciones. Las tres avisan de que cierran la botella, y muestran que trabajan sin bloquear la interfaz. Exportar pide dónde guardar. Al renombrar, la app va a la nueva ruta.

**Escenarios (test `BottleDetailBloc`):** cada una llama al repositorio y navega; un error se muestra y la botella sigue.

### V15 · Preferencias
Entrada al fondo de la barra lateral. Carpeta de datos con `Abrir en Finder`; caché de instaladores con su tamaño y `Vaciar`, que confirma; y el tema, que sale de la barra.

**Escenarios (test `PreferencesBloc`):** tamaño; vaciar lo deja en cero.
