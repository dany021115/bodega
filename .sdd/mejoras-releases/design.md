# Diseño: mejoras de releases y experiencia

Cada sección cubre una mejora de `proposal.md`. Las firmas y rutas son las propuestas; se ajustan al implementar.

## M1. Guarda de portabilidad (X1)

- Dónde: `tool/package_linux.sh`, justo después de `flutter build linux --release`.
- Qué: `readelf -n apps/bodega/build/linux/x64/release/bundle/bodega` y buscar `x86-64-v3` o `x86-64-v4` en la línea `x86 ISA needed`. Si aparece, imprimir "este build exige CPU x86-64-v3/v4 y no corre en equipos más viejos: usa el paquete del release (se construye en ubuntu-24.04)" y salir con 1.
- Por qué ahí: el ejecutable del runner de Flutter es el que lleva la marca. En CachyOS salió `baseline, v2, v3, v4`; la CLI (`dart compile exe`) y las `.so` de `lib/` no la llevan.
- Variable de escape: `BODEGA_ALLOW_NATIVE=1` para un build personal. Sin ella, falla.
- Prueba: `readelf` sobre un ejecutable de prueba compilado con `-march=x86-64-v3` debe fallar la guarda; uno `-march=x86-64` debe pasar.
- Documentar en `packaging/linux/README.md`.

## M2. Checksums y procedencia (X2)

- En el job `release` de `release-linux.yml` y de `release-macos.yml`: después de descargar los artefactos a `dist/`, `cd dist && sha256sum * > SHA256SUMS`, y subir `SHA256SUMS` junto con los demás.
- Procedencia: `actions/attest-build-provenance@v2` con `subject-path: dist/*`. Requiere `permissions: id-token: write, attestations: write` en ese job.
- Verificación del usuario: `sha256sum -c SHA256SUMS` y `gh attestation verify <archivo> -R dany021115/bodega`.
- Esto no firma el DMG para Gatekeeper (eso es M10); solo prueba qué workflow produjo el archivo.

## M3. Prueba de humo de paquetes (X3)

Un job `smoke` que depende de `build`/`arch`/`package` y bloquea a `release`:

| Paquete | Entorno | Comando |
|---|---|---|
| `.deb` | `ubuntu:24.04` limpio | `apt install ./Bodega-*.deb`; `bodega --help`; `BODEGA_HOME=$(mktemp -d) bodega backend list` |
| `.pkg.tar.zst` | `archlinux:base` | `pacman -U --noconfirm bodega-*.pkg.tar.zst`; los mismos dos comandos |
| `.AppImage` | `ubuntu:24.04` | `APPIMAGE_EXTRACT_AND_RUN=1 ./Bodega-*.AppImage --version` si existe; si no, solo que arranque y salga |
| `.dmg` | `macos-15` | `hdiutil attach`; `Bodega.app/Contents/MacOS/bodega-cli --help`; `bodega create prueba` (sin ventana) |

- La CLI y `backend list` no abren ventana ni ejecutan Wine, así que cumplen la regla de "Wine solo sin ventana" del proyecto.
- El caso de Manjaro se reproduce en CI instalando el paquete en una imagen mínima: el ejecutable gráfico no se puede abrir sin pantalla, pero la guarda M1 ya cubre su ISA.
- Prueba de la prueba: forzar un paquete roto (sin `bodega-cli`) y comprobar que el job falla.

## M4. Release encadenado (X4)

- Problema: un push de tag hecho con `GITHUB_TOKEN` no dispara otros workflows, salvo `workflow_dispatch` y `repository_dispatch`.
- Diseño: en `tag-version.yml`, tras `git push origin refs/tags/$tag`, añadir `gh workflow run release-linux.yml --ref "$tag"` (el flujo construye el tag desde el que corre; ya no tiene input `tag`) con `permissions: actions: write` y `GH_TOKEN: ${{ github.token }}`.
- Solo si el tag se acaba de crear (el `exit 0` de "ya existe" lo evita en los demás pushes).
- macOS: `release-macos` queda manual (decisión 2 de la propuesta).
- Actualizar `AGENTS.md`: "Only the `tag-version` workflow creates tags ... `release-linux` runs by itself after it; `release-macos` is run by hand".
- Riesgo: un release roto sale solo. Mitigación: M3 bloquea la publicación.

## M5. Revisión automática de versiones (X5)

- Workflow `check-versions.yml`: `schedule` semanal (lunes) y `workflow_dispatch`.
- Script `tool/check_assets.sh` (usa `gh api repos/<repo>/releases` y `jq`): para cada `name` de `assets.json` busca el primer release con `prerelease == false && draft == false` y compara con `version`.
  - Wine: Kron4ek/Wine-Builds. El nombre del asset es `wine-<ver>-staging-amd64-wow64.tar.xz`.
  - DXVK: doitsujin/dxvk (`dxvk-<ver>.tar.gz`). vkd3d-proton: HansKristian-Work/vkd3d-proton (`.tar.zst`).
  - appimagetool: se fija una versión con etiqueta; el tag `continuous` se ignora a propósito.
- Si hay versión nueva: descarga el archivo, calcula el sha256 y abre una PR con `assets.json` actualizado (con `peter-evans/create-pull-request` o `gh pr create`), con la tabla antes/después y el enlace a las notas.
- No hace merge ni release: una persona revisa. Las notas de Wine pueden traer regresiones (la 11.x staging cambia a menudo).
- Prueba: ejecutar el script contra un `assets.json` con una versión vieja inventada y comprobar que detecta la diferencia.

## M6. Base de arreglos por juego (X6)

- Datos: `packages/engine/lib/fixes_data.dart`, generado desde `packages/engine/data/fixes.json`, con la misma forma que usa hoy `catalog_data.dart`. Una entrada por juego:
  `{ "id": "steam:1234", "title": "...", "platforms": ["linux","mac"], "env": {...}, "dllOverrides": "...", "winetricks": ["vcrun2022"], "backend": "dxvk", "notes": "..." }`.
- Identificación: ID de Steam (de `steamapps/appmanifest_*.acf`, que `apps.dart` ya parsea para los juegos de Steam) o nombre del exe como respaldo.
- Aplicación: al crear la botella (`createBottle`) y al lanzar (`_launchIn`), mezclando en este orden: valores por defecto, arreglo del juego, ajustes de la botella, ajustes del programa, opción de la línea de comandos. El último gana, así que el usuario nunca pierde lo que puso a mano.
- `bodega fix show <botella> <programa>` muestra qué arreglo se aplicaría y por qué.
- Fuente de datos: solo lo que se pruebe en equipos reales, o datos con licencia compatible. Cada entrada anota su origen en `notes`/`source`. No se copia nada propietario.
- Cruce con M7: el campo `winetricks` se ejecuta con el mecanismo de M7.
- Pruebas del motor: precedencia de la mezcla, y que una entrada de otra plataforma no se aplica.

## M7. Dependencias de Windows (X7)

- Lista permitida de verbos: `vcrun2019`, `vcrun2022`, `dotnet48`, `corefonts`, `d3dcompiler_47`, `xact`. Se amplía solo editando la lista.
- `bodega deps install <botella> <verbo...>`: ejecuta winetricks con el Wine de la botella, sin ventana (`WINETRICKS_GUI=none`, `-q`), con tiempo límite, y deja el log en `bottles/<b>/logs/`.
- Dónde vive winetricks: en el paquete, en `runtime/winetricks/` (script LGPL). En Linux se añade a `assets.json` con versión y sha256 (decisión 5).
- Para evitar descargas a ciegas, los verbos que bajan de Microsoft muestran el origen antes de ejecutar, y la app pide confirmación.
- El estado queda en `bottles/<b>/settings.json` (`deps: [...]`), para no repetir.
- Límite: algunos verbos abren instaladores con ventana. Esos no entran en la lista permitida.

## M8. Aviso de versión nueva (X8)

- Fase 1 (en la app, capa `data/`): un servicio que llama a `https://api.github.com/repos/dany021115/bodega/releases/latest` una vez por sesión (con `dio`, ya está en el proyecto), compara con la versión instalada (`package_info_plus` o la constante del `pubspec`) y expone un estado "hay versión X". Sin red o con error, no muestra nada.
- UI: una barra o toast en la pantalla principal con "Hay una versión nueva (X.Y.Z)" y un botón que abre la URL del release. Nunca descarga ni instala.
- Fase 2 (opcional, macOS): Sparkle (vía el paquete `auto_updater`) con un appcast publicado en los releases y las actualizaciones firmadas con EdDSA. No exige Developer ID para firmar el feed, pero sí para que Gatekeeper no moleste (M10).
- Linux: los gestores de paquetes (`pacman`, AUR) ya actualizan; la fase 1 basta.
- Pruebas: bloc con un cliente falso (versión mayor, igual, error de red).

## M9. AUR (X9)

- Un `PKGBUILD` distinto del de `packaging/arch/`: ese envuelve un tarball local. El del AUR usa `source=("https://github.com/dany021115/bodega/releases/download/v$pkgver/Bodega-$pkgver-linux-x86_64.tar.gz")` y `sha256sums` reales, que salen del `SHA256SUMS` de M2.
- Publicarlo exige una cuenta en el AUR y una clave SSH: decisión de quien mantenga el proyecto. Se deja el archivo en `packaging/aur/PKGBUILD` y el comando para actualizar `pkgver` y `sha256sums` con `updpkgsums`.

## M10. Developer ID y notarización (X10)

- Pasos si hay cuenta: certificado Developer ID Application en un secreto del repositorio; `codesign --options runtime --timestamp` sobre cada binario y la app; `xcrun notarytool submit --wait`; `xcrun stapler staple`.
- Cambios: `tool/package_macos.sh` (hoy `codesign --sign -`), secretos en `release-macos.yml`, y `packaging/macos/LEEME.txt` (ya no hace falta la explicación de clic derecho).
- Riesgo: el Wine empaquetado contiene muchos binarios x86_64 y dylibs; la notarización exige firmar todos con el runtime endurecido, y Wine puede necesitar entitlements (`allow-jit`, `allow-unsigned-executable-memory`, `disable-library-validation`). Hay que probarlo en un Mac antes de prometerlo.
- Sin cuenta: se deja como está y se mejora `LEEME.txt`.

## M11. Mandos en Linux (extra, pedida después)

- Cómo funciona: no hay nada que configurar en la botella. El `winebus` de Wine 11.21 enlaza `libudev` y carga `libSDL2-2.0.so.0` del sistema. Con SDL2, Wine ve el mando como `is_gamepad 1` y crea el dispositivo XInput. Sin ella usa el camino de `udev` (hidraw y evdev). En macOS la capa es otra (`_ensureGamepads`, IOHID o SDL2 incluida) y no cambia.
- Medido en CachyOS con Wine sin ventana: un mando virtual (`uinput`, Xbox 360 `045e:028e`) y uno real (8BitDo Ultimate 2, `2dc8:310b`, por su receptor USB) salen en el log como `sdl_add_device controller … is_gamepad 1` y luego `WINEXINPUT\VID_…&XI_00`. Wine también avisa `Unable to open udev device "/dev/hidraw0": Permission denied` para los hidraw de root: es ruido, no un fallo.
- Qué falla de verdad: sin permiso sobre `/dev/input/event*` no hay mando; sin SDL2, se cae al camino de `udev`. Ninguna de las dos cosas daba pista al usuario.
- `HostPlatform.gamepads()` devuelve `GamepadReport` (mandos, SDL2, avisos), o `null` en Mac. Un mando es un bloque de `/proc/bus/input/devices` con un `jsN`; su nodo es el `eventN` del mismo bloque, y se comprueba abriéndolo. Los avisos no entran en `checkHost`, porque no impiden jugar.
- Paquetes: reglas udev, `steam-devices` (Debian y Ubuntu: multiverse/non-free; Arch: multilib; Fedora: sin comando); SDL2, `libsdl2-2.0-0`, `SDL2` y `sdl2-compat`.
- CLI: `bodega pads` (sale con 1 si hay avisos).
- Sin probar: la app (no hay pantalla), la ruta sin SDL2 en un equipo real, y un juego usando el mando.
