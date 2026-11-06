# Tareas: soporte Linux

Regla para todo worker: cambio mínimo que resuelve la tarea, sin sobreingeniería. No ejecutar tests, `dart`, `flutter` ni Wine (el SDK instalado no sirve para este proyecto). No hacer commit ni push. Leer `.sdd/soporte-linux/design.md` antes de empezar: las firmas de ahí son fijas. Código en inglés, textos de UI y errores en español con acentos, como el resto del repo.

Worktree: `/home/roilan/Documents/GitHub/bodega/.claude/worktrees/feat-linux-support`

## Olas

| Ola | Tareas | Depende de |
|---|---|---|
| 1 | T1, T2 | n/a |
| 2 | T3, T4 | T1 (T3 también de T2) |
| 3 | T5, T6 | T3, T4 (T6 solo de T1) |
| 4 | T7, T8 | T5, T6 (T8 de T2, T3) |
| 5 | T9 | todas |

## T1: interfaz HostPlatform y MacPlatform

Archivos: `packages/engine/lib/platform.dart` (nuevo, `part of 'engine.dart'`), `platform_mac.dart` (nuevo, `part of`), `engine.dart` (añadir los dos `part`), `engine.dart`, `backends.dart`, `apps.dart`, `catalog.dart`, `bin/bodega.dart`.

Hacer:
1. Crear `HostPlatform` con las firmas exactas de `design.md`, el global `hostPlatform`, `HostPlatform.detect()` y `MacPlatform` con el comportamiento de hoy movido tal cual. Crear solo el esqueleto de `LinuxPlatform` (`platform_linux.dart`, `part of`) con `throw UnimplementedError()` en cada miembro, para que `detect()` compile; T3 lo rellena.
2. Sustituir, siguiendo la tabla "Qué sale de dónde": `bodegaHome`, `wineEnv`, `requiredFiles`, las herramientas (`shasum`, `tar`, `curl`, `xattr`), `rosettaInstalled` en `bin/bodega.dart` por `checkHost`, `backendNames`, `_pinned`, `backendEnv`, `_autoBackend`, la comprobación de `d3d11.dll` en `installBackend`, `_defaults.sync` y `_checkSync`, el `WINEMSYNC` de `_launchIn`, las llamadas a `_ensureGamepads` en `createBottle`/`runInBottle`/`openApp`, `cases` de `backendTest`, los `reg add` de `setHighRes`, `entry.backend` en `installEntry` y el texto "en Mac" de la pista de EAC.
3. Añadir a `BottleSettings` los campos `gpu` y `gamemode` con su `_with`, lectura en `_settings`, escritura en `_saveSettings` y `setBottleOptions`. En `_launchIn`: `...hostPlatform.gpuEnv(settings.gpu)` y el `launchWrapper` (parámetro nuevo `wrapper` en `_start`, que se antepone a `'$rt/engine/bin/wine'`).
4. Funciones top-level públicas nuevas: `checkHost()` y `hostCapabilities()`. `backendEnv`, `pinnedBackend` y `listBackends` siguen existiendo y delegan.
5. El comportamiento en macOS no puede cambiar. `rosettaInstalled()`, `installSdl`, `x86Slice`, `importD3DMetal` y `_sdl` se quedan como están.

AC: S2 (grep) sin resultados fuera de lo permitido; cada miembro de `HostPlatform` tiene implementación en `MacPlatform`; ningún `Platform.` de `dart:io` renombrado por error.

## T2: archivos del instalador

Archivos: `packaging/linux/assets.json`, `packaging/linux/fetch_assets.sh`, `packaging/linux/cache/` (ignorada por git: añadir a `.gitignore`).

Hacer:
1. Con `gh api` (solo lectura) o `curl`, localizar la última versión estable de: Kron4ek `Wine-Builds` (asset `wine-staging-<ver>-amd64-wow64.tar.xz`), DXVK (doitsujin, `dxvk-<ver>.tar.gz`), vkd3d-proton (HansKristian-Work, `.tar.zst`) y appimagetool (AppImage/appimagetool, `appimagetool-x86_64.AppImage`). No inventar versiones ni URLs.
2. Descargar cada archivo en su propio directorio nuevo bajo `packaging/linux/cache/<nombre>/`. Calcular sha256 localmente. Los archivos descargados no son de confianza: no ejecutarlos, no usarlos como directorio de trabajo.
3. Escribir `assets.json` con `name`, `version`, `url`, `sha256`, `size` por archivo. Escribir `fetch_assets.sh` (descarga lo que falte y verifica con `sha256sum -c`; `set -euo pipefail`).
4. Descomprimir solo para inspeccionar (en un directorio temporal del scratchpad): anotar en `packaging/linux/README.md` (a) estructura real de directorios de Wine y de DXVK y vkd3d-proton, (b) con `strings` sobre `lib/wine/x86_64-unix/ntdll.so`, qué variables de sync reconoce (`WINEESYNC`, `WINEFSYNC`, `WINE_NTSYNC`, `ntsync`...), (c) licencias incluidas.
5. No ejecutar Wine.

AC: `sha256sum -c` correcto sobre todo lo descargado; `assets.json` válido con `python3 -m json.tool`; `bash -n fetch_assets.sh`.

## T3: LinuxPlatform

Depende de T1, T2. Archivos: `platform_linux.dart`, `backends.dart`, `engine.dart`, `bin/bodega.dart`.

Hacer: implementar `LinuxPlatform` según `design.md`, usando lo que T2 descubrió para `requiredFiles`, `syncModes`/`syncEnv` y la URL fijada de `pinnedBackends`. `registerBundled` (enlace/copia de runtime y capas). `_ensureLayers` con la marca `$home/backends/dxvk/VERSION`. `checkHost`. `installSdl`, `importD3DMetal` e `installBackend('d3dmetal')` lanzan `'no disponible en Linux'` cuando `!capabilities.sdl`/`!capabilities.d3dmetal`. R18: usuario de la sesión.

AC: S2; cada miembro implementado; `grep -n UnimplementedError packages/engine/lib` sin resultados.

## T4: rutas sin mayúsculas

Depende de T1. Archivos: `engine.dart` (helper `findCI`), `apps.dart`, `catalog.dart`.

Hacer: añadir `findCI` según `design.md` y aplicarlo donde se construye una ruta dentro del prefijo con un nombre que no escribió Wine: `_shortcutApps` (`File('$drive/$exe')`), `_steamGames` (`_steamExe`, `apps`), `_steamIcon`, `addApp`, `appIcon`, `_launchIn` (`scan` y `cwd` del caso `c:\`), `installEntry` (`File('$prefix/drive_c/${entry.exe}')`) y `antiCheatHints`. Las rutas de `_shortcutFiles` también.

AC: cada `File('$drive/...')`/`File('$prefix/drive_c/...')` con nombre variable usa `findCI`; en macOS el resultado es el mismo porque la ruta exacta existe.

## T5: extras del motor

Depende de T3, T4. Archivos: `backends.dart`, `bin/bodega.dart`.

Hacer: comando `bodega option <botella> gpu auto|discrete` y `bodega option <botella> gamemode on|off` (usa `setBottleOptions`); `bodega sync` acepta los modos de `capabilities.syncModes`. Verificar que `--hud` llega a `backendEnv`.

AC: `bodega` sin argumentos lista los comandos nuevos en `_usage`.

## T6: app Flutter

Depende de T1. Archivos: bajo `apps/bodega/lib/` y `apps/bodega/pubspec.yaml`, según la sección "App" de `design.md`. También `flutter create --platforms=linux --no-pub .` dentro de `apps/bodega` (único comando de Flutter permitido; crea `linux/`).

Hacer: nuevas entidades de dominio, `RuntimeStatus`, repositorio, `SetupBloc`/`SetupState`/`SetupEvent`, `RequirementCard` en lugar de `RosettaCard`, ocultar opciones por capacidades (AVX, DLSS, D3DMetal y su `D3DMetalInstructions`, SDL, Retina), lista de sync desde `capabilities.syncModes`, toggles `gpu` y `gamemode` (si `capabilities.gpu`/`gameMode`), textos genéricos, extensiones en mayúscula. Actualizar `pubspec.yaml` `description`. No tocar `macos/`.

AC: S1 (`apps/bodega/tool/check_layers.sh`): `domain/` no importa el motor.

## T7: pruebas

Depende de T5, T6. Escribir sin ejecutar.

Hacer: en las pruebas del motor que asumen macOS, fijar `hostPlatform = MacPlatform()` en `setUp`. Actualizar las de la app por el cambio de `RuntimeStatus` (`setup_bloc_test`, `router_test`, `runtime_repository_test`, `pages_test`, `bottle_detail_bloc_test`). Añadir `packages/engine/test/linux_test.dart`: `baseEnv` (variables heredadas y las que no, y R18), `defaultHome` con y sin `XDG_DATA_HOME`, `findCI`, `backendEnv`/`autoBackend`/`probeCases` de Linux, `registerBundled` con un paquete falso en un directorio temporal, `_ensureLayers`, `checkHost` con `os-release` simulado si es práctico.

AC: ningún test nuevo toca el sistema real fuera de directorios temporales.

## T8: empaquetado

Depende de T2, T3. Archivos: `tool/package_linux.sh`, `packaging/linux/{bodega.desktop,build_deb.sh,build_appimage.sh,LICENSES/}`, `.github/workflows/package-linux.yml`, `.gitignore`.

Hacer: el script compila la app (`flutter build linux --release`) y la CLI (`dart compile exe`), prepara la raíz del paquete según `design.md` (fusiona DXVK y vkd3d-proton en `backends/dxvk/wine/{x64,x32}` con su `VERSION`), copia Wine a `runtime/wine-<ver>/engine`, añade `LICENSES/` y genera `.deb` (`dpkg-deb`), `.tar.gz` y AppImage (`appimagetool`). El workflow: `on: workflow_dispatch` (input opcional `release_tag`), `runs-on: ubuntu-24.04`, instala dependencias, corre el script y sube los tres archivos como artefactos y, si hay `release_tag`, a un borrador de release.

AC: S3, S4.

## T9: documentación

README de Linux y nota en `.claude/rules/architecture.md` sobre `HostPlatform` y la ubicación del Wine incluido. Línea en `CLAUDE.md` del proyecto con el comando de empaquetado.
