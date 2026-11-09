# Diseño · d3dmetal-y-backends

## 1. La licencia la acepta el usuario en la ventana de Apple
`hdiutil attach` en la terminal se para pidiendo la licencia; contestarle "Y" sería aceptar
por el usuario. Mejor `open <Evaluation environment….dmg>`: macOS abre su propia ventana
de licencia (DiskImageMounter), el usuario la acepta y el volumen aparece en `/Volumes`.
Bodega solo espera ese volumen. Cero código para leer o mostrar licencias.

## 2. Un bloc para los gráficos de los exes
`GraphicsBloc` (uno para toda la app) guarda `Map<exe, ExeGraphics>`. Las pantallas que
pintan apps le piden `load(exes)`; lo que ya tiene no se vuelve a leer. `ExeGraphics` trae
la etiqueta y los avisos ya calculados para cada backend instalado
(`misfits: {backend: aviso}`): los desplegables solo consultan el mapa, sin esperar.
Así no se toca `LibraryBloc` ni `BottleDetailBloc`, y leer exes grandes no retrasa la lista.

## 3. Reglas por plataforma
`Platform.backendFits(backend, exe) → bool` y `backendUse(backend)`. Mac tiene la tabla G3;
Linux dice siempre que sí. Los textos de aviso los arma la app, que sabe el título. Son reglas puras (no miran el SO real), así que los tests con Mac
simulado en Linux siguen valiendo.

## 4. Leer el exe sin bloquear
La lectura actual (decodificar a latin1 y quitar NULs) pasa a `exeGraphics` y corre en
`Isolate.run`. La caché es el mapa de `GraphicsBloc` (§2): una caché por fecha en el motor
fallaba con exes reescritos en el mismo milisegundo. `autoBackend` la reusa.

## 5. Esperar la descarga
Un `Timer.periodic` de 3 s en el bloc de Backends, solo mientras la tarjeta está
"esperando". macOS pedirá una vez permiso para Descargas: va
`NSDownloadsFolderUsageDescription` en el `Info.plist`.
