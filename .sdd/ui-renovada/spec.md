# Spec: UI renovada

Cambio visual y de flujo sobre la app de macOS y Linux. Lo que ya existe
(botellas, backends, catalogo, instalaciones, ejecucion) sigue igual; cambian
las pantallas por donde se entra y se navega.

## Requisitos

R1. Biblioteca como primera pantalla. Al abrir la app (con el runtime listo)
se llega a `/library`. Muestra en grid o lista (alternable con `ViewToggle`,
preferencia `libraryViewGrid`) solo las apps marcadas "en biblioteca". Una
app fuera de la biblioteca sigue dentro de su botella.

R2. Crear botella sin .exe. "Nueva botella" pide solo el nombre. El .exe se
agrega despues, desde la botella.

R3. Botella con panel de detalles. `/bottles/:name` muestra las apps de la
botella al centro, y a la derecha un panel con estado, backend, sincronia,
acciones, ajustes y registros. Por debajo de `DESKTOP` (801 px) el panel baja
debajo de las apps.

R4. Agregar app con dos alternativas: "Populares" (catalogo) y "Desde un
.exe". Ambas acaban en la botella elegida.

R5. Agregar o quitar de la biblioteca no saca la app de la botella. Quitar
marca la app como "fuera de biblioteca"; volver a marcarla la muestra de nuevo.

R6. Nada de lo existente se pierde. Macos y Linux se comportan igual. El
catalogo (`/catalog`) sigue existiendo como ruta, sin enlace en la barra
lateral; se alcanza desde el dialogo "Agregar app".

## Modelo de datos

- `apps.json` gana `offLibrary`: lista de claves de app que no se muestran en
  la biblioteca. Si falta, se trata como vacia. Lo lee y escribe el engine
  (`packages/engine/lib/apps.dart`).
- `renameBottle(home, from, to)`: cambia el nombre de una botella y sus apps.
- `setInLibrary(home, bottle, key, value)`: marca o desmarca una app de la
  biblioteca escribiendo `offLibrary`.

## Paleta y tokens

Tema oscuro unico. Colores en `device/theme/color.dart` (`AppColor`) y
gradiente en `device/theme/gradient.dart` (`AppGradient`).

- Fondos: `background` (070B1A), `sidebar` (0B1126), `bottlePanel` (0A1030),
  `surface` (10183A), `surface2` (172250). En `ColorScheme`: `surfaceContainer`
  es la barra, `surfaceContainerHigh` las tarjetas y toasts.
- Bordes: `border` (222F66).
- Texto: `text` (EAF0FF), `textSecondary` (8C9BC8).
- Acentos: `cyan` (22D3EE) primario, `blue` (3B82F6), `violet` (8B5CF6),
  `error` (F87171).
- Estados del catalogo: `statusTested`, `statusReported`, `statusUntested`,
  `statusBlocked`, `statusFlaky`.
- Gradiente de marca: cyan, azul, violeta (`AppGradient.brand`).

Espaciado en `AppSpacing`, radios en `AppRadius`, texto en `AppTextStyle`.

## Toasts

`AppToast` usa fondo `surfaceContainerHigh`, texto `onSurface`, borde y
acento por tipo: exito `statusTested`, error `colorScheme.error`, aviso
`statusFlaky`, info `colorScheme.primary`.

## Fuera de alcance

- Tema claro (se quita `PreferenceKey.darkTheme`).
- Cambios de engine fuera de `offLibrary`, `renameBottle` y `setInLibrary`.
