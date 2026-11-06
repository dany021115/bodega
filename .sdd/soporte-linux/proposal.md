# Soporte Linux (Ubuntu/Debian 24.04+)

Bodega corre hoy solo en macOS. Esto añade Linux x86_64 sin cambiar nada de macOS.

## Alcance

- Interfaz `HostPlatform` en el motor, con `MacPlatform` (lo de hoy, movido tal cual) y `LinuxPlatform`.
- Wine staging WoW64 (Kron4ek), DXVK y vkd3d-proton van dentro del paquete. DXVK y vkd3d-proton forman un solo backend `dxvk` (D3D9 a D3D12).
- Paquetes `.deb`, `.tar.gz` y AppImage, con `tool/package_linux.sh` y un workflow que solo se lanza a mano (`workflow_dispatch`).
- Extras: HUD con `DXVK_HUD`, DPI con `LogPixels`, selector de sync, GPU por botella, GameMode.
- El usuario de Wine hereda el nombre de usuario de Linux.

Fuera: Gamescope, DLSS/NVAPI, aarch64, Flatpak/Snap, compilar Wine, `wineboot -u` automático tras actualizar Wine, reetiquetar el estado del catálogo.

Regla de trabajo de esta entrega: se escribe el código, no se prueba nada (ni tests, ni `flutter build`, ni Wine) hasta que el usuario instale Flutter 3.47. Las pruebas se escriben pero no se ejecutan.

## Requisitos (EARS)

| ID | Requisito |
|---|---|
| R1 | El motor elegirá `MacPlatform` en darwin y `LinuxPlatform` en linux; en otro sistema fallará con "sistema no soportado". |
| R2 | En macOS el motor se comportará como hoy (entorno, herramientas, rutas, backends, ajustes, mensajes de error de Wine). |
| R3 | En Linux la raíz de datos será `$XDG_DATA_HOME/bodega`, o `~/.local/share/bodega`. |
| R4 | Al lanzar un proceso de Wine en Linux, el entorno heredará `DISPLAY`, `WAYLAND_DISPLAY`, `XAUTHORITY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, `LANG`, `LC_ALL`, `PULSE_SERVER`, `PULSE_COOKIE`, `XDG_SESSION_TYPE`, `VK_ICD_FILENAMES`, `VK_DRIVER_FILES` y `PATH` del padre. No llevará variables de Rosetta, MoltenVK ni CrossOver. |
| R5 | Al arrancar en Linux con un runtime incluido, el motor lo registrará en `runtimes/<id>` (enlace; copia si existe `$APPIMAGE`) y lo dejará como `current` si no hay uno válido. Igual con las capas de `backends/`. |
| R6 | En Linux los backends serán `wine` y `dxvk`. `dxmt`, `d3dmetal`, `sdl install` e `import d3dmetal` darán un error claro. |
| R7 | Al crear una botella, o al lanzar si la capa `dxvk` incluida cambió respecto a la anotada, el motor copiará sus DLL a `system32` y `syswow64` y lo anotará. |
| R8 | Cuando un lanzamiento resuelva a `dxvk`, el motor pondrá los overrides `n,b` solo en ese proceso; las excepciones por exe siguen funcionando. |
| R9 | Al buscar un archivo dentro de un prefijo el motor ignorará mayúsculas. En macOS el resultado es el de hoy. |
| R10 | Al comprobar el equipo en Linux, el motor informará si falta x86_64, Vulkan o audio, con el comando de `apt`, `dnf` o `pacman` según la distro. El setup se bloquea hasta resolverlo. |
| R11 | La UI ocultará lo que la plataforma no tiene (AVX, DLSS, D3DMetal, SDL, Retina) y ofrecerá los modos de sync de la plataforma. |
| R12 | En Linux el Wine incluido (11.21 staging) no tiene variables de esync ni fsync: usa ntsync solo si existe `/dev/ntsync`, sin forma de forzarlo por entorno. Por eso `syncModes = ['none']`, `syncEnv` devuelve `{}` y la UI oculta el selector cuando solo hay una opción. Para ntsync el usuario carga el módulo (`sudo modprobe ntsync`) y da permisos a `/dev/ntsync`. |
| R13 | `--hud` pondrá `DXVK_HUD` en Linux. El ajuste de DPI cambiará solo `LogPixels`. |
| R14 | Cada botella tendrá `gpu` (`auto` o `discrete`) y `gamemode`. `discrete` pone las variables de offload. `gamemode`, si `gamemoderun` está instalado, envuelve el lanzamiento. |
| R15 | Los selectores de archivos aceptarán `.EXE`, `.MSI` y `.GZ` en mayúscula. |
| R16 | Los paquetes llevarán avisos LGPL y la referencia al código fuente de Wine. |
| R17 | `tool/package_linux.sh` generará `.deb`, `.tar.gz` y AppImage. El workflow solo tendrá `workflow_dispatch`. |
| R18 | En Linux el usuario de Wine será el de la sesión: `USER` y `LOGNAME` se pasan siempre, con `id -un` como respaldo. |

## Criterios de aceptación

Estáticos (se comprueban sin SDK):

- S1: `app/tool/check_layers.sh` pasa.
- S2: fuera de `platform_mac.dart` y de las pruebas, no queda `/usr/bin/`, `.dylib` ni `Library/Application Support` en `packages/engine/lib`, salvo en las funciones solo-Mac (`rosettaInstalled`, `installSdl`, `x86Slice`, `importD3DMetal`) y la tabla `_sdl`.
- S3: `sha256sum -c` de lo descargado y `bash -n` de cada script.
- S4: `assets.json` es JSON válido; el workflow es YAML válido y su único disparador es `workflow_dispatch`.
- S5: cada R1 a R18 aparece cubierta en el diff.

Manuales (los corre el usuario con el SDK instalado):

- M1: `dart analyze && dart test` en `packages/engine`; `flutter analyze && flutter test && tool/check_layers.sh` en `apps/bodega`.
- M2: `bodega create prueba` y `bodega run prueba notepad` abren ventana y suenan; `users/<tu usuario>` existe en el prefijo.
- M3: `bodega backend list` muestra `wine` y `dxvk` instalado.
- M4: `bodega backend test prueba dxvk` da OK en D3D11 (64 y 32 bits) y D3D12.
- M5: los tres paquetes arrancan y muestran el runtime incluido.
- M6: en macOS, `dart test` igual que antes.
