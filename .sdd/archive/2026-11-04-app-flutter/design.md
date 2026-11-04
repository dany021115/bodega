# Diseño: app-flutter

Solo lo que no es obvio. `TS` = TeeShot.

## 1. El motor como fuente de datos

Solo `data/` importa `package:engine`. `data/repository/*_impl.dart` convierte tipos del motor en entidades de `domain/` y atrapa lo que lanza, que son `String` y `FormatException`, para devolver `Left(EngineError)`. El motor no sabe nada de Flutter y el CLI sigue funcionando. `data/service/engine_home.dart` guarda el resultado de `bodegaHome(Platform.environment)` como singleton.

**Repositorios:** `Runtime`, `Catalog`, `Install`, `Library`, `Bottle`, `Backend` y `AntiCheat`.

## 2. `AppError` en `domain`

En TeeShot, `AppError` vive en `data/api/catch_error.dart` y `domain/repository` lo importa (`TS/.claude/skills/create-feature`), lo que contradice su regla de capas. Aquí va en `domain/entities/app_error.dart`. Es la única desviación deliberada de su estructura, junto a que no hay Phoenix, auth ni nada del producto móvil.

## 3. Freezed moderno

TeeShot escribe `@freezed class X with _$X`. Con `freezed` 4 es `abstract class` para estados y entidades, y `sealed class` para eventos. El resto del patrón no cambia: estado único con `@Default` y `copyWith`, `part` de evento y estado (probado en §7).

## 4. Descargas con `dio`

**Cambio en `apply`:** se pensó en `dio.download`, pero hay que ver el estado y la URL final antes de escribir nada, así que `Downloader` lee el stream a mano. Pide los bytes sin comprimir porque, con gzip, `Content-Length` y `Range` cuentan otra cosa: contra HTTPS real, una descarga buena fallaba con "se cortó en 251114 de 30766 bytes".

```
Downloader.fetch(url, dest, cancel, onProgress)
  dio.get en stream, con Accept-Encoding: identity y Range si hay .part → <dest>.part → rename
→ installEntry(setup: ruta) o installBackend(tarball: ruta)
```

- **El motor sigue con `curl`** para el CLI, y comprueba el SHA en ambos caminos.
- **Solo HTTPS:** `dio` sigue redirecciones por su cuenta. Se comprueba `response.realUri.scheme == 'https'` y que la URL del catálogo empiece por `https://`.
- **Si el servidor ignora `Range`:** responde 200 en vez de 206, y hay que empezar de cero.
- **Lista de anti-cheat:** `raw.githubusercontent.com` sirve `text/plain`, así que `retrofit` la pide con `ResponseType.plain` y se decodifica aparte (probado en §7).

## 5. Abierta o cerrada

`waitBottle` (`wineserver -w`) termina cuando se va el último proceso y vuelve al instante si no hay servidor (medido: 0,03–0,04 s). Con eso, por botella:

```
final wait = waitBottle(...);
abierta = (Future.any([wait, delay(1 s)]) no terminó por wait)
wait.then(cerrada)
```

Resuelve el `exit=42` de Steam: lo que importa es la botella, no el primer proceso. Un servidor sigue vivo 3 s tras el último proceso (medido: 3.104 ms), así que "Cerrada" tarda eso en aparecer. Un `wineserver -w` por botella abierta es un proceso pequeño.

// ponytail: sin vigilar cambios hechos fuera de la app (por ejemplo, abrir con el CLI). Se reconstruye al arrancar y al volver a Biblioteca.

## 6. La interfaz no es dueña de los programas

Los programas corren desacoplados: cerrar Bodega no los cierra, y volver a abrirla reconstruye el estado desde `listBottles` y `waitBottle`. Si se cierra durante una instalación, el instalador sigue, pero queda una botella sin `app.json`, que aparece sin aplicación y se puede borrar en su detalle. `Incompleta` queda para un prefijo sin terminar (`ready` falso, E2).

Lecturas síncronas en la interfaz: `antiCheatHints` lee un log de unos 600 KB cada 5 s como mucho, mientras sea más nuevo que la hora de abrir (medido con 614 KB: mediana de 3,8 ms y máximo de 12,5 ms, por debajo de un fotograma). Si se notara en U, se pasa a `Isolate.run`. No se hace antes de medir.

## 7. Comprobado antes de escribir esto

En un workspace temporal, ya borrado, con el runtime real de este Mac (M2 Pro, macOS 27.0.1, Flutter 3.47.0, Dart 3.13.0):

| Prueba | Resultado |
|---|---|
| `flutter pub add` con todo el stack | Resuelve: `freezed` 4.0.1, `build_runner` 2.16.1, `injectable` 3.0.0, `go_router` 18.1.2, `retrofit` 4.10.0, `retrofit_generator` 10.3.3, `dio` 5.11.1 |
| `dart run build_runner build` en `apps/bodega` | Correcto, 24 s: freezed, json, retrofit e injectable |
| Motor dentro del workspace | Sus tests y `dart compile exe` funcionan |
| `flutter build macos --debug` sin sandbox | Correcto, 40 s; 115 MB en debug |
| App abierta con `open` (como desde Finder) | `HOME`, `USER`, `LOGNAME`, `TMPDIR` y `__CF_USER_TEXT_ENCODING` presentes |
| Desde la app: `runInBottle` con `cmd /c set` | `exit=0`, `WINEMSYNC=1`, `CX_ACTIVE_GRAPHICS_BACKEND=wined3d` |
| Desde la app: bloc + freezed + injectable | Correcto |
| Desde la app: `retrofit` + JSON | 1.166 juegos, parseados |
| Desde la app: `Dio.download` | Correcto |
| Desde la app: `installedApps`, `listBackends`, `catalogEntries` | `steam`; los 4 backends; 7 entradas |
| `wineserver -w` sin servidor | 0,03–0,04 s |

**Sin comprobar:** cómo se ve nada de esto. La app de prueba no dibujaba ninguna pantalla.
