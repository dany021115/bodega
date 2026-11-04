# Exploración: interfaz-botellas

## Problema

Quieres que Bodega se organice como CrossOver y recuperar lo que dejamos de lado. Hoy son dos ideas distintas:

- **CrossOver gira alrededor de la botella:** eliges una en la barra lateral y ahí mismo ves sus aplicaciones, su configuración y sus acciones.
- **Bodega gira alrededor de la aplicación:** cada botella tiene una sola, y Biblioteca y Botellas son secciones separadas.

No basta con mover pantallas. La regla de una aplicación por botella está en el motor, y Steam ya la rompe: Muck está instalado dentro de esa botella y Bodega no lo ve.

## De dónde sale la referencia

`crossover-sources-26.3.0.tar.gz` **no sirve para esto**: tiene el mismo SHA-256 que `investigacion-launcher/src/cx-26.3/`, y solo trae `wine`, `gstreamer`, `gnutls`, `moltenvk`, `ghostscript`, `busybox`, `glib`, `freetype`, `dxvk`, `vkd3d`, `po4a`, `cabextract`, `android` y `makedep`. Ninguna interfaz.

La interfaz está cerrada en `~/Applications/CrossOver.app`. De ahí salen, solo como referencia:

- Las funciones de cada pantalla, en `Contents/Resources/es.lproj/*.strings`.
- La colocación, decodificando `Base.lproj/{MainWindow,BottleView}.nib` con REA.

No se copian iconos, textos, nibs ni datos: solo organización y funciones, con código propio. La regla de `.claude/CLAUDE.md` que dice no copiar su UI sigue valiendo así entendida, y conviene escribirlo en `propose`.

## Cómo organiza CrossOver sus pantallas

**Ventana principal** (`MainWindow.nib`, 1150×800), dividida en dos:

| Zona | Tamaño | Contenido |
|---|---|---|
| Barra lateral, translúcida | 261 px de ancho | Logo arriba (100 px), una lista corta (55 px), la lista de botellas (653 px) y una franja inferior (55 px) |
| Contenido | 910 px de ancho | La vista de la botella, o la de instalar |

**Vista de botella** (`BottleView.nib`, 936×801):

| Zona | Tamaño | Contenido |
|---|---|---|
| Cabecera | 856×100 | Título grande, estrellas de calificación, y a la derecha datos cortos y dos botones |
| Centro | 626×661 | `Software instalado`: iconos, con clic derecho `Abrir` y `Ejecutar con opciones…`. Admite arrastrar. Tiene un texto para cuando está vacía |
| Columna derecha, con scroll | 270×661 | Dos botones sueltos y cuatro secciones plegables |

Las secciones de la columna derecha, en orden. La colocación es del nib; qué sección es cada una lo deduzco de sus textos y de cuántos controles tiene:

1. **Acciones de botella:** 4 botones. Entre abrir C:, salir de todas las aplicaciones, instalar dependencias que faltan y borrar.
2. **Configuración avanzada:** 2 desplegables (gráficos y otro) y 4 filas con interruptor (DLSS, msync, alta resolución y otra).
3. **Paneles de control:** lista que se llena al abrir.
4. **Detalles de botella:** estado, tipo, descripción y una tabla.

**Otras pantallas,** por sus textos:

- **Ejecutar comando:** programa, botella, argumentos, variables de entorno, HUD de Metal, no anunciar AVX, guardar como lanzador, y opciones de log.
- **Nueva botella:** nombre y tipo. También sirve para duplicar y para restaurar de un archivo.
- **Instalar** (`PackageView`, y tu captura): populares, búsqueda, detalles, notas, elegir botella, elegir instalador, opciones avanzadas, `Instalar a través de Steam` e `Instalar una aplicación no listada`.
- **Menú:** nueva botella, duplicar, renombrar, exportar, importar, borrar, abrir shell, y terminar o forzar cierre de la botella.
- **Preferencias:** carpetas de botellas y de programas, caché de instaladores con botón de vaciar.

## Lo que hay en Bodega

**Una aplicación por botella, en el motor:**

- `packages/engine/lib/catalog.dart:176`: `_writeApp` escribe un solo `app.json`.
- `catalog.dart:189`: `addApp` rechaza una segunda aplicación.
- `catalog.dart:249`: `BottleInfo` tiene un solo `app`; lo llenan `_bottleInfo` (`:258`) y `installedApps` (`:269`).
- `catalog.dart:275`: `openApp(home, bottle)` abre "la" aplicación, sin decir cuál.
- `catalog.dart:84` y `engine.dart:189`: instalar y crear rechazan una botella que ya existe, así que no se puede instalar en una existente.
- `packages/engine/bin/bodega.dart:58,69`: los comandos `open` y `apps` dependen de esto.
- Hay 22 referencias en los tests del motor.

**Lo mismo en la app:**

- `domain/entities/library_app.dart:8-10` y `bottle.dart:13`: un `LibraryApp` por botella.
- `domain/repository/library_repository.dart:12`: `open(bottle)`, sin aplicación.
- `data/repository/catalog_repository_impl.dart:19,41`: lo instalado es un mapa de id a botella.
- `data/repository/add_app_repository_impl.dart:37`: `freeBottles` son las que no tienen aplicación; con varias por botella deja de tener sentido.
- `data/repository/install_repository_impl.dart:27`: la descarga falla si la botella ya existe.
- Llaman a abrir: `install_panel.dart:128`, `detail_action.dart:26` y `library_card.dart:85`.
- 35 archivos de `lib` y `test` nombran estas clases.

**Navegación y pantallas:**

- `app/shared/widgets/side_bar.dart:20-28`: Biblioteca, Catálogo, Botellas y Backends.
- `app/shared/widgets/main_shell.dart:13-15`, `app/router.dart:79-108` y `device/router/manager.dart:7-15`: rutas de esas cuatro secciones.
- `app/presentation/bottles/bottle_detail_page.dart`, `widgets/bottle_settings_card.dart` y `widgets/bottle_logs_card.dart`: casi todo lo de la columna derecha ya existe, pero en una pantalla aparte.
- `app/shared/widgets/app_icon.dart:23`: logos por id de catálogo; lo demás, una inicial.
- `LibraryBloc` ya lleva lo abierto **por botella** (`library_bloc.dart:37`), igual que el `Estado` de CrossOver. Eso no hay que cambiarlo.

**Lo que el motor ya permite y la app no ofrece:**

- `engine.dart:220`: `runInBottle` admite argumentos, backend y HUD.
- `backends.dart:44,65`: `hud` pone `MTL_HUD_ENABLED`.
- `backends.dart:261`: `programs` guarda backend y variables por programa.
- `engine.dart:185`: `createBottle` ya crea botellas vacías.

**Lo que el motor no tiene:**

- `engine.dart:58`: `winemenubuilder.exe=d`, y ninguna lectura de `.lnk`.
- `engine.dart:79`: `ROSETTA_ADVERTISE_AVX=1` fijo; `extra` puede cambiarlo, pero no quitarlo, y el informe dice que para apagarlo hay que quitarlo.
- Alta resolución, versión de Windows, duplicar, renombrar, exportar, importar, e iconos del PE (`backends.dart:431` solo lee los bits).

## Comprobado con tus archivos

Todo en solo lectura:

| Pregunta | Resultado | Qué significa |
|---|---|---|
| ¿Se detectan las aplicaciones por sus `.lnk`? | 3 en `steam`, en `Public/Desktop`, `ProgramData` y `users/quasar`. Los 3 dan `C:\Program Files (x86)\Steam\steam.exe`. Un lector de 30 líneas basta | Viable. Hay que quitar duplicados por destino. `games` tiene 0, porque Blur no se instaló |
| ¿Se sacan iconos reales? | `steam.exe`: 39 iconos, el mayor PNG de 256 px. `Blur.exe`: 1 DIB de 32 px | Viable, sin dependencias. El PNG va directo; el DIB necesita cabecera BMP |
| ¿Se ven los juegos de Steam? | `steamapps/appmanifest_*.acf`: Muck (1625450) y Steamworks Common Redistributables (228980) | Viable, ocultando los redistribuibles. Falta probar si `-applaunch` funciona bien |
| ¿Duplicar es caro? | APFS; `steam` ocupa 2,7 GB y `games` 538 MB | Con `cp -c` es casi instantáneo. `dosdevices/z:` apunta a `/`, así que nunca se puede seguir ese enlace |
| ¿Están las herramientas de Wine? | `winecfg`, `regedit`, `taskmgr`, `control`, `cmd`, `wineconsole`, `uninstaller` y `explorer` están | Los paneles de control salen casi gratis |

**Sin comprobar:** ningún `.lnk` o icono se ha abierto todavía desde Dart, y las herramientas de Wine tienen ventana, así que las pruebas tú.

## Ajustes por botella y por aplicación

Según `INFORME-FINAL.md` §5.3 y §6.1:

- **Alta resolución:** `RetinaMode=y` más `LogPixels` ×2. Afecta a todo el prefijo y exige reiniciar la botella.
- **DLSS:** `D3DM_ENABLE_METALFX` (macOS 26+) con D3DMetal; `DXMT_ENABLE_NVEXT=1` con DXMT.
- **AVX:** quitar `ROSETTA_ADVERTISE_AVX`.
- **HUD:** ya existe `hud`, pero `--hud` no mostró contador en Blur. **Sin resolver:** un interruptor que no haga nada sería engañoso.

## Restricciones

- Arquitectura y herramientas de TeeShot; solo `data/` importa `package:engine`; `tool/check_layers.sh` lo vigila.
- UI en español. `test/app/pages_test.dart` debe cubrir toda pantalla nueva.
- Ventana mínima de 720×480: **no caben** barra de 261, centro y columna de 270. Por debajo de `DESKTOP`, la barra pasa a iconos y la columna debe ir debajo o plegada.
- Sin romper datos: `steam` y `games` ya tienen `app.json`, y deben seguir funcionando sin reinstalar.
- El CLI no debe romperse: `open <botella>` y `apps`.
- Agentes: Wine solo sin ventana, sin commit ni push, sin seguir enlaces dentro de una botella.
- Sin nada que ayude a saltarse anti-cheat. D3DMetal sigue siendo importado por ti.

## Fuera de este cambio

Para el SDD siguiente, de motor: GStreamer (0 `libgst*` frente a 83 en CrossOver), SDL2 para mandos (0 frente a 2), dependencias tipo VC++/.NET, y Epic y GOG. Sin propósito aquí: registro, calificaciones, publicar botellas y estrellas.

## Dudas abiertas

Para resolver en `propose`, con mi recomendación:

1. **¿Biblioteca sigue existiendo?** CrossOver no tiene vista de todas las aplicaciones, según sus archivos. **Recomiendo** dejarla como primera entrada de la barra lateral: es más cómodo y es de lo poco en que Bodega ya es mejor.
2. **¿Juegos de Steam como aplicaciones?** **Recomiendo** sí, leyendo los manifiestos: es lo que más se nota en el uso diario. Depende de probar `-applaunch`.
3. **¿Cuánto en este cambio?** **Recomiendo** por hitos: primero varias aplicaciones y la pantalla principal; después ajustes y `Ejecutar con opciones`; al final duplicar, renombrar, exportar, importar y Preferencias.
4. **¿Dónde van los Backends?** CrossOver no los gestiona porque los trae dentro. **Recomiendo** dejarlos en Preferencias o al fondo de la barra lateral.
5. **¿Cuánto se parece el aspecto?** **Recomiendo** copiar la organización y mantener nuestra paleta burdeos.
6. **Capturas:** ya no bloquean, porque el nib da la colocación, pero no la apariencia. Si quieres que se parezca más, pásame una de la ventana principal con una botella elegida.
