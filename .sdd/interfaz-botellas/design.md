# Diseño: interfaz-botellas

Solo lo que no es obvio.

## 1. Qué se toma de CrossOver

La organización y la lista de funciones, leídas de su app instalada. No se usan sus iconos, nibs, datos ni frases propias; palabras corrientes como `Abrir` o `Gráficos` no se pueden evitar. `.claude/CLAUDE.md` lo dirá así: seguimos sin copiar su UI, y parecerse en cómo se organiza no es copiarla.

## 2. Registradas y detectadas

Una aplicación **registrada** está en `apps.json`: viene del catálogo o de `Agregar`. Una **detectada** se calcula al listar, desde `.lnk` o manifiestos de Steam, y no se guarda: así, desinstalar algo la hace desaparecer sin tener que limpiar nada.

`Ocultar` es lo único que se guarda de ellas, en `hidden`.

**Por qué no activar `winemenubuilder`** (`engine.dart:58`): crearía lanzadores en el Mac, y solo hace falta leer lo que el instalador ya deja en el prefijo.

```
bottleApps = registradas + (.lnk ∪ Steam) − hidden, sin repetir clave
```

`steam` hoy tiene un `app.json` y 3 `.lnk` a `steam.exe`: da una sola aplicación, la registrada, más Muck.

## 3. Iconos

Se reconstruye un `.ico` de un solo icono: 6 bytes de cabecera, los 16 de la entrada, y los datos del `RT_ICON` mayor. Vale igual para PNG y DIB, y Flutter lo decodifica sin conversión.

Se lee con `RandomAccessFile` y solo la sección `.rsrc`, con un tope de 64 MB; un `.rsrc` mayor da `null`. Hay juegos con exe enorme, así que el repositorio lo ejecuta en `Isolate.run`, con la caché delante.

## 4. Juegos de Steam

Heredan el entorno de Steam, así que su backend es el de `steam.exe`. No se ofrece elegir otro aquí: necesita reglas por proceso, y va en el SDD de motor. Las bibliotecas en otras carpetas (`libraryfolders.vdf`) tampoco, porque solo existe la del prefijo.

`-applaunch` con Steam abierto debería pasar la orden al que corre, pero tiene ventana y no se ha probado. El proceso lanzado sale enseguida; como lo abierto se mide por botella, no importa.

## 5. Estado

- **`BottlesBloc`,** global: pasa a alimentar la barra lateral. `ShellBody` lo recarga al terminar una instalación, y las pantallas al agregar o borrar.
- **`LibraryBloc`:** `open` sigue siendo un conjunto de botellas. El guardia pasa de "esta botella está abierta" a "esta clave se lanzó hace menos de 2 s". `_follow` admite varios a la vez: el primero que ve la botella vacía la cierra y los demás no hacen nada, como ya pasa.
- **`BottleDetailBloc`:** por página. Cada botella tiene su ruta y su página, así que no hay estado que limpiar al cambiar.
- **Secciones plegadas:** en `shared_preferences`, por sección y no por botella.

## 6. Composición

`MainShell`, con barra lateral, sigue igual y `SideBar` se rehace. La pantalla de botella decide con `LayoutBuilder`, no por breakpoint: lo que importa es el ancho del contenido, que depende de la barra.

| Ventana | Barra | Contenido | Columna |
|---|---|---|---|
| 720 | 68 | 652 | Debajo |
| 801 | 220 | 581 | Debajo |
| 1150 | 220 | 930 | Al lado, 270 |

El umbral de 760 deja al menos 490 px para las aplicaciones.

## 7. Entorno de un lanzamiento

`wineEnv` hace `...extra` al final, y no puede quitar una clave. `avx: false` necesita quitar `ROSETTA_ADVERTISE_AVX`, así que `_start` recibe `remove`, un conjunto de claves que se borran del mapa final. No se cambia `wineEnv`, que tiene sus tests.

## 8. Copiar, exportar, importar

`cp -cR` clona en APFS y, según su manual, copia normal si no se puede. `-R` copia los enlaces como enlaces. `tar` también los guarda como enlaces.

`importBottle` valida con `tar -tzf` antes de extraer. El `tar` de macOS ya rechaza `..` y rutas absolutas, pero revisarlo da un error claro y permite exigir una sola carpeta raíz. Se extrae en `.tmp-import`, que `listBottles` ignora, y solo se renombra al final.

Exportar quita `logs` e `icons`: no hacen falta y se regeneran.

## 9. Comprobado antes de escribir esto

Con un test temporal, ya borrado, y una botella temporal, también borrada. Nada con ventana.

| Prueba | Resultado |
|---|---|
| Icono de `steam.exe` desde Dart, decodificado por Flutter | PNG, 256×256, 18.652 bytes, 4 ms |
| Icono de `Blur.exe` | DIB, 32×32, 3.262 bytes, menos de 1 ms |
| Icono de `notepad.exe` del runtime | PNG, 256×256 |
| `.lnk` de `steam`, con un script | 3 archivos, los 3 a `C:\Program Files (x86)\Steam\steam.exe` |
| `appmanifest` | Muck 1625450 con `StateFlags` 4; 228980 son los redistribuibles |
| `librarycache/1625450/` | `<hash>.jpg`, `header.jpg`, `library_600x900.jpg`, `logo.png` y otras |
| `winecfg -v win7` y luego `winecfg -v` | `exit=0`, responde `win7`, sin ventana |
| `reg add … RetinaMode` | `exit=0`, y `reg query` lo devuelve |
| `LogPixels` en `HKCU\Control Panel\Desktop` | No existe de inicio: hay que crearlo |
| `cp -cR` de una botella de 537 MB | 336 ms, `z:` sigue siendo `/` y `c:` sigue siendo `../drive_c` |
| Programa en la copia | `exit=7` como se pidió, y conserva `RetinaMode` |
| `tar -czf` y `tar -xzf` | 13,3 s y 146 MB; 1,7 s; `z:` sigue siendo `/` |
| Renombrar y lanzar | Correcto |

**Sin comprobar:** `-applaunch`, el efecto visual de alta resolución, DLSS, y el HUD con DXMT. Todo tiene ventana y lo pruebas tú.

## 10. Mandos, arreglo fuera de los hitos (2026-11-05)

Tu mando de Xbox no funcionaba en Blur, y en CrossOver sí. **Causa, medida en los logs de Wine:** sin `libSDL2` (CrossOver la trae, nosotros no), `winebus` ve el mando por IOHID como `is_hidraw`, y `is_hidraw_enabled` lo descarta: `ignoring hidraw device 045e:02fd`.

**Arreglo:** `HKLM\System\CurrentControlSet\Services\WineBus` con `Enable SDL=0` y `DisableInput=1` hace que Wine prefiera IOHID para todo mando. El log pasa a `Adding device … WINEXINPUT\VID_045E&PID_02FD&XI_00`.

El motor lo pone una vez por botella: al crearla, o en el primer lanzamiento de una que ya existía. Queda guardado como `gamepads: 1` en `settings.json`.

**Sin vibración:** `bus_iohid` no la tiene. Llevar SDL2, como CrossOver, es la mejora, y queda para el SDD de motor como versión 2.
