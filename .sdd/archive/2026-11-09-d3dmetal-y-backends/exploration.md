# Exploración · d3dmetal-y-backends

## Problema

1. **El usuario no sabe qué backend le sirve a cada juego.** Pasó con Blur: la botella
   forzada a `d3dmetal` y el juego (32 bits, DirectX 9) se cerraba. D3DMetal solo sirve
   para 64 bits con DX11/DX12; DXVK no tiene d3d9; DXMT es D3D10/11. Nada en la app lo dice.
2. **Instalar D3DMetal es una guía de texto** ("elige una carpeta con `wine/` y `external/`").
   El usuario quiere: lista de versiones del Game Porting Toolkit → elegir → instalar.
   Bodega no puede descargarlo ella misma (login de Apple ID + licencia de Apple; regla
   B2 "Bodega nunca descarga D3DMetal"). Lo acordado: Bodega abre la descarga oficial en el
   navegador, el usuario inicia sesión y baja el `.dmg`, y Bodega hace todo lo demás.

## Código implicado

### Motor (`packages/engine/lib`)
- `platform_mac.dart:170` `autoBackend(home, exePath)`: ya lee el exe; busca
  `d3d12.dll`, `d3d11.dll`, `d3d10`, `dxgi.dll`, `d3d9.dll` (sin NULs) y usa `_peBits`.
  Devuelve solo el nombre del backend; lo que detecta (bits + DirectX) se pierde. Hay que
  sacarlo a una función reutilizable (p. ej. `exeGraphics(path) → (bits, directx)`).
- `platform_linux.dart:233` `autoBackend`: dxvk si está, si no wine (no mira el exe).
  `mapBackend` convierte dxmt/d3dmetal en dxvk.
- `backends.dart:521` `_peBits(path)`: 64/32/null desde la cabecera PE.
- `backends.dart:486` `resolveBackend(...)`: opción → excepción del programa → botella → auto.
- `backends.dart:66` `importD3DMetal(home, folder)`: acepta carpeta con `wine/`+`external/`
  **o con `lib/`** (`src = '$real/lib'`), rechaza `/CrossOver.app/`, exige
  `wine/x86_64-windows/{d3d11,d3d12,dxgi}.dll`, sus `.so`, `external/libd3dshared.dylib`,
  `external/D3DMetal.framework`, y rehace los `.so` como symlinks.
- `engine.dart:465-513` `installSdl(home, {dmg})`: patrón ya probado de
  `hdiutil attach -nobrowse -readonly -mountpoint` + copiar + `hdiutil detach`. Sirve de
  molde para montar el dmg de Apple.
- `backends.dart:601` `backendTest(home, name, backend)`: el "Comprobar" de después.
- Versión instalada: no se guarda en ningún sitio. Se puede leer de
  `backends/d3dmetal/external/D3DMetal.framework/.../Info.plist`
  (`CFBundleShortVersionString`; hoy da `3.0` en esta Mac).

### App (`apps/bodega/lib`)
- `app/presentation/backends/widgets/d3dmetal_instructions.dart:7`: la guía actual (se va).
- `app/presentation/backends/widgets/backend_card.dart:37` "Elegir carpeta…" →
  `BackendsEvent.importD3DMetal(folder)` (`backends_event.dart:10`,
  `backends_bloc.dart:58`, `backend_repository.dart:22`, `backend_repository_impl.dart:81`).
- `app/presentation/backends/backends_page.dart`: aquí iría la tabla "qué backend para qué".
- Selector de la botella: `bottles/widgets/bottle_column.dart:341` (dropdown "Gráficos",
  `BottleDetailEvent.setBackend`).
- Selector por ejecución: `bottles/widgets/run_options_dialog.dart:146` (dropdown "Gráficos").
- Nueva botella: `bottles/new_bottle_dialog.dart:178` (dropdown "Gráficos"; aquí aún no hay apps).
- Etiqueta por app: `shared/widgets/app_card.dart:27` (ya pinta un chip en el pie:
  `footerChip`/`bottleLabel`) y `shared/widgets/app_row.dart:12`.
- `domain/entities/library_app.dart:16` `exe`: ruta del exe de cada app (para analizarlo).

## Datos del Game Porting Toolkit (investigado)

| GPTK | D3DMetal | Estado | Probado en Bodega |
|---|---|---|---|
| 1.x (2023) | 1.x | viejo | no |
| 2.x (2024–25) | 2.x | viejo | no |
| 3.0 (WWDC25, actualizado 5-dic-2025) | 3.0 | estable | **sí** (Comprobar OK) |
| 4.0 (WWDC26) | 4.0 | beta | no |

- Descarga directa (pide sesión de Apple ID de desarrollador, gratis):
  `https://download.developer.apple.com/Developer_Tools/Game_Porting_Toolkit_3.0/Game_Porting_Toolkit_3.0.dmg`.
  Página pública: `https://developer.apple.com/games/game-porting-toolkit/`.
- Dentro: `Game_Porting_Toolkit_3.0.dmg` contiene **otro dmg**,
  `Evaluation environment for Windows games 3.0.dmg`, que **muestra la licencia de Apple al
  abrirlo**. Dentro de ese: `redist/lib/{external,wine}` → justo lo que `importD3DMetal`
  ya acepta pasándole `<volumen>/redist`.
- Licencia (GPTK 4 License.pdf): solo los componentes de `/redist` son redistribuibles, uso
  no comercial. Requiere no estar "ubicado en" un país embargado (Cuba): cada usuario baja
  el suyo con su cuenta; Bodega no lo aloja ni lo descarga.

## Restricciones del proyecto
- D3DMetal nunca se empaqueta, descarga ni se copia de CrossOver (B2, `importD3DMetal`).
- Wine solo headless desde el agente; no seguir symlinks dentro de una botella.
- En Linux no hay D3DMetal (`capabilities.d3dmetal == false`): la sección no se muestra.
- Clean architecture (domain/data/device/app), bloc + freezed, tests con Mac simulado en
  Linux (`test/_mac.dart`): la detección del exe no puede depender del SO real.
- Steam (`steam.exe`): sin etiqueta ni aviso (el exe del juego real no es ese).

## Dudas abiertas
1. **Licencia del dmg interno**: `hdiutil attach` se para pidiendo aceptar la licencia.
   Propuesta: Bodega muestra "Al instalar aceptas la licencia de Apple" y el usuario la
   acepta con un botón (Bodega responde `Y` a hdiutil), o que el usuario abra el dmg él
   mismo en Finder. Me inclino por lo primero, con el texto de la licencia visible.
2. **Esperar la descarga**: vigilar `~/Downloads` buscando `Game_Porting_Toolkit_*.dmg`
   (sondeo cada pocos segundos mientras la pantalla está abierta) + botón manual
   "Ya lo tengo: elegir dmg…". Sin servicio en segundo plano.
3. **Lista de versiones**: fija en el código (4 filas). Solo 3.0 marcada "Probada";
   4.0 "Beta"; 1.x/2.x ¿se muestran o se ocultan? Propongo mostrar solo 3.0 y 4.0.
4. **Reemplazar versión**: importar encima ya funciona (rehace la carpeta); falta mostrar
   la versión instalada leyendo el `Info.plist`.
5. **Aviso de backend**: solo cuando el usuario **elige** algo que no encaja (no en
   Automático). Analizar el exe es leer el archivo entero: hacerlo una vez y guardar el
   resultado, no en cada repintado.
