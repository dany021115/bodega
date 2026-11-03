# Exploración: backends-graficos

**Rutas:** `P` = `bodega/packages/engine`; `BE` = `bodega-engine`; `CX` = árbol LGPL de CrossOver 26.3 (`sources/wine`, sacado de `~/Documents/investigacion-launcher/src/cx-26.3/crossover-sources-26.3.0.tar.gz`); `HB` = app Highball (GPL; copias en el scratchpad de la sesión); `WH` = `~/Library/Application Support/com.franke.Whisky/Libraries`; `CO` = `CrossOver.app/Contents/SharedSupport/CrossOver` (solo lectura, para entender el mecanismo).

Exploración hecha solo leyendo. **Nada de esto se ha ejecutado todavía: ningún backend nuevo se ha probado con nuestro runtime.**

## 1. Problema

Hoy todo pasa por las DLL de Wine: D3D9–11 por wined3d y D3D12 por vkd3d. Blur (DX9) va bien así, pero no hay ni DXMT ni D3DMetal.

El usuario quiere todos los backends, con D3DMetal como requisito, y elegirlos como en CrossOver: la futura interfaz ofrecerá el selector, y este cambio deja el motor listo. La UI Flutter queda fuera.

## 2. Qué hay que tocar

- **Entorno:** `wineEnv` es un mapa fijo sin noción de backend (`P/lib/engine.dart:53-71`). Se usa en `_start` (`:330`), `_wineserver` (`:339`) e `installRuntime` (`:139`).
- **Lanzar:** `runInBottle` no recibe backend (`P/lib/engine.dart:205-244`); `_start` pasa por `/bin/sh` (`:326-333`).
- **Ajustes:** no existe ningún archivo por botella ni por juego. El prototipo decidió "sin JSON" porque no había nada que guardar; ahora sí lo hay.
- **CLI:** `P/bin/bodega.dart:13-43` usa patrones de listas fijos, sin opciones.
- **Runtime:** `runtimes/<id>/engine/`. Las carpetas `renderers/` del tarball vienen vacías (`exploration.md` del prototipo, §2.1) y `requiredFiles` no menciona backends (`P/lib/engine.dart:75-84`).
- **Pistas:** `_hints` no cubre fallos de backend (`P/lib/engine.dart:274-283`).

## 3. Mecanismo común: capas delante de las DLL de Wine

- El parche `0003` añade `WINEDLLPATH_PREPEND`: carpetas que se buscan **antes** que las DLL del motor. Ya está en nuestro runtime (`BE/patches/0003-ntdll-winedllpath-prepend.patch:1-45`).
- Cada capa tiene `x86_64-windows/`, `i386-windows/` y `x86_64-unix/`. Si el nivel de carpeta es incorrecto, se ignora sin avisar (trampa 10 del prototipo).
- Una DLL builtin de una capa solo se carga si el prefijo tiene su archivo de relleno. `winemetal.dll` ya lo tiene porque el motor la incluye (`BE/.github/workflows/build.yml:96-106`), y `atidxx64`, `nvapi64` y `nvngx` están en `wine.inf` (`CX/loader/wine.inf.in:739-742`).
- La variable se fija por proceso, pero los servicios de la botella conservan el entorno del primer proceso (trampa 4 del prototipo; Highball documenta el caso en `HB/WineRunner.swift:393`).
- `CX_ACTIVE_GRAPHICS_BACKEND`: en CrossOver la pone el `cxcompatdb.so` cerrado, y el árbol LGPL la lee en `CX/dlls/win32u/d3dkmt.c:719-724` (WDDM para `d3dmetal`). Tendremos que ponerla nosotros.

## 4. Cada backend

| Backend | Qué cubre | De dónde sale | Tamaño | Cómo se activa |
|---|---|---|---|---|
| **wine** (wined3d + vkd3d) | D3D9–11 por wined3d; D3D12 por vkd3d sobre MoltenVK | Ya está en el runtime (`d3d12.dll`, `d3d12core.dll`, `wined3d.dll`) | 0 | Sin capa |
| **DXMT** | D3D10/11, 32 y 64 bits | Release oficial `dxmt-v0.80-builtin.tar.gz` (3Shain/dxmt, MIT) | 17 MB | Capa, sin `n,b` |
| **DXVK** | D3D10/11 sobre MoltenVK | `dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz` (Gcenx) | 2 MB | Capa + `WINEDLLOVERRIDES=d3d10core,d3d11=n,b`; `dxgi` lo pone Wine (el paquete solo trae `d3d10core` y `d3d11`, visto en `WH/DXVK/x64`) |
| **D3DMetal** | D3D11/12, MetalFX, DXR; **solo 64 bits** | Copia que aporte el usuario, nunca empaquetada | 63 MB | Ver §5 |

**"vkd3d" no es una capa aparte en esta primera versión:** es la ruta D3D12 de "wine". vkd3d-proton, que usa Highball, exige unos 30 parches y da 19–26 fps en Flight Simulator 2024 en un M4 (`gap-graphics-defaults-without-d3dmetal.md:42`), así que no compensa ahora.

**DXMT y D3D12 no se mezclan bien:** el `dxgi` de DXMT rompe vkd3d (`gap-graphics-defaults-without-d3dmetal.md:41`), y el D3D12 propio de DXMT sigue sin estar listo (`:34-36`).

## 5. D3DMetal

**Piezas** (vistas en `CO/lib64/apple_gptk` y en `WH/Wine/lib`):
- `external/D3DMetal.framework` y `external/libd3dshared.dylib`.
- Módulos de Wine: `d3d11`, `d3d12`, `dxgi`, `nvapi64`, `atidxx64`, `nvngx` en `x86_64-windows/` y `x86_64-unix/`. Whisky además tiene `d3d10.so`, `d3d12core.dll` y llama `nvngx-on-metalfx` al módulo DLSS: **los layouts no son idénticos**.

**Cómo se carga, según lo leído:**
- `d3d12.so` enlaza `@rpath/libd3dshared.dylib`, con `LC_RPATH @loader_path` (`otool` sobre `WH`).
- También contiene la ruta `@rpath/D3DMetal.framework/D3DMetal` y el error `Failed to dlopen D3DMetal`.
- `ntdll` puede cargar `libd3dshared` antes si `CX_APPLEGPTK_LIBD3DSHARED_PATH` está definida y es macOS 14+ (`CX/dlls/ntdll/unix/loader.c:1323-1331`); registra regiones de código no nativo (`:1331-1352`). CrossOver la pone siempre (`CO/bin/wine:679-684`).
- Highball usa `DYLD_FALLBACK_LIBRARY_PATH` y `DYLD_FALLBACK_FRAMEWORK_PATH` (`HB/Bottle.swift:65-66`), lo que choca con nuestro `/bin/sh`, porque SIP borra `DYLD_*` al arrancarlo (trampa 2).
- **Hipótesis sin probar:** dejar `libd3dshared.dylib` y `D3DMetal.framework` junto a los `.so` de la capa, para que `@loader_path` los encuentre sin `DYLD_*`. Si falla, `export` dentro del script `_launch` también evita el borrado de SIP.

**Glue que ya tenemos en el árbol LGPL:** `CX/dlls/winemac.drv/d3dmetal*.{c,m,h}`, `CX/dlls/setupapi/devinst.c:5251-5321` y `CX/dlls/ntdll/loader.c:4018`.

**Solo 64 bits:** Highball encadena DXMT detrás para que un juego D3D10/11 de 32 bits no caiga en wined3d (`HB/Bottle.swift:61-63`).

**Limitación conocida:** D3DMetal 3.0 no tiene timestamp queries; Highball añade un shim para Guardians of the Galaxy (`HB/Bottle.swift:51-59`).

**De dónde sacar la copia:**
- **Whisky en este Mac (`WH/Wine/lib`):** versión 3.0 (`version.plist`), 0 MB de descarga. La misma versión que CrossOver 26.3. Su framework tiene una firma sin Team ID, y no se sabe si sus módulos encajan con el árbol CX.
- **Gcenx/game-porting-toolkit 3.0-3:** 228 MB; su propia nota remite a la licencia de Apple.
- **Apple (developer.apple.com):** la fuente oficial; requiere cuenta y mirar la licencia.
- **CrossOver:** descartada por las reglas del proyecto.

## 6. Elección por botella y por juego

- **CrossOver** guarda `CX_GRAPHICS_BACKEND` en `[EnvironmentVariables]` de `cxbottle.conf` (`02-graphics.md` §4) y resuelve las capas al cargar con código cerrado. Tenemos el mismo efecto con `WINEDLLPATH_PREPEND`.
- **Highball** modela un enum `wined3d | vkd3d | dxmt | d3dmetal | dxvk` que devuelve el entorno (`HB/Bottle.swift:20-82`), y guarda ajustes por programa (`HB/Bottle.swift:445`). Es la forma que mejor encaja con la futura interfaz. GPL: se puede reutilizar mientras sea de uso personal.
- **Auto:** el informe propone mirar los imports PE (`02-graphics.md`, estrategia 2). Falla con juegos que cargan D3D dinámicamente o con un launcher delante, así que el ajuste manual siempre debe mandar.

## 7. Restricciones

- **Decisión del usuario (2026-11-03): D3DMetal entra, y quiere todos los backends.**
- Advertencia ya comunicada: la licencia del GPTK limita el uso a desarrollar, probar o evaluar juegos, y exige no estar en un país embargado (`INFORME-FINAL.md` §9.6). Aceptarla es decisión del usuario.
- D3DMetal nunca va en el repo ni en un tarball nuestro, y no se copia de CrossOver. El usuario lo importa desde una copia suya.
- **Decisión del usuario:** lo instala quien use la app, y la interfaz explicará cómo hacerlo. Esa pantalla es de la app Flutter, fuera de este cambio. Aquí solo hace falta el comando de importar y un mensaje claro si falta. Matiz: Whisky no pide instalarlo a mano, lo trae en el runtime que descarga (`WhiskyWineInstaller.swift`, `WH/Wine/lib/external`).
- Si algún día la app se publica, esto se revisa: redistribuirlo es otro problema.
- Lo demás sigue igual: entorno hermético, sin atribución de IA, commits y push con OK del usuario, minimalismo.
- DXMT y DXVK pesan poco y se bajan de GitHub directamente, sin gastar minutos de CI.

## 8. Trampas

1. Si cambias de backend con la botella en marcha, los servicios conservan el entorno anterior: hay que hacer `stop` antes.
2. Una capa mal anidada se ignora sin avisar: hay que comprobar el backend realmente activo en cada prueba. `DXMT_LOG_PATH` sirve para DXMT; para D3DMetal y DXVK hay que definir la prueba.
3. D3DMetal y DXMT sustituyen `dxgi`; un proceso solo carga uno.
4. Cambiar de backend en un juego con Denuvo puede bloquearlo por cambio de hardware (`07-store-clients.verify.md` C14).
5. `D3DM_*`, `DXMT_*` y `MTL_HUD_ENABLED` no pasan hoy porque el entorno es hermético (`P/lib/engine.dart:53-71`): sin eso no se pueden medir los FPS.
6. Los módulos de Whisky están compilados para su Wine, no para el árbol CX. Es el mayor riesgo técnico.

## 9. Dudas para la propuesta

1. **Copia de D3DMetal para las pruebas.** El motor importará una carpeta que aporte el usuario. Para probar: ¿la copia local de Whisky (sin descarga), o la de Gcenx/Apple si sus módulos no encajan?
2. **Carga sin `DYLD_*`.** Ejecutar primero una prueba corta (spike) antes de escribir el diseño definitivo.
3. **Ajustes.** ¿`settings.json` por botella, con overrides por exe?
4. **Auto.** ¿D3D12 → D3DMetal, D3D10/11 → DXMT, D3D9 → wine, leyendo los imports PE del exe?
5. **Versiones.** ¿DXMT v0.80 oficial o un commit más nuevo compilado por nosotros (LGPL, gasta CI)?
6. **FPS.** ¿Añadir `--hud` para `MTL_HUD_ENABLED`? Sin medir no se puede afirmar "mejor que CrossOver".
7. **Juegos de prueba.** Blur cubre DX9. Falta uno DX11 y otro DX12: en este Mac solo está claro Warframe, que tiene los dos modos pero añade su launcher.
