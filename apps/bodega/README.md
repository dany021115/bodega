# bodega

Windows games on Apple Silicon

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Linux

Bodega corre en Linux x86_64 con Ubuntu o Debian 24.04 o más nuevo. En otras distros usa el `.tar.gz`.

### Requisitos

- Arquitectura x86_64.
- Vulkan con una GPU real.
- Audio con PulseAudio o PipeWire (`pipewire-pulse`).
- Ubuntu o Debian 24.04+.

### Instalar

- `.deb`: `sudo apt install ./Bodega-<ver>-linux-amd64.deb`. Instala en `/opt/bodega`, añade el comando `bodega` y una entrada en el menú.
- `.tar.gz` (`Bodega-<ver>-linux-x86_64.tar.gz`): extráelo y ejecuta `./bodega` desde la carpeta extraída.
- AppImage: `chmod +x Bodega-<ver>-linux-x86_64.AppImage` y ejecútalo. Si falla por FUSE, instala `libfuse2t64` (Ubuntu 24.04) o ejecútalo con `--appimage-extract-and-run`.

### Datos

Las botellas, el runtime y las capas de backends viven en `~/.local/share/bodega` (o `$XDG_DATA_HOME/bodega`).

### Wine y backends

- El paquete trae Wine 11.21 staging WoW64 (Kron4ek). No hace falta instalar Wine.
- Backends: `wine` (sin capas) y `dxvk`, que trae DXVK para D3D8 a D3D11 y vkd3d-proton para D3D12.

### CLI

```
bodega create prueba
bodega run prueba notepad
bodega backend list
bodega backend test prueba dxvk
bodega option prueba gpu discrete
bodega option prueba gamemode on
```

### Opciones de Linux

- HUD: `--hud` muestra fps y tiempos de cuadro. Si está instalado MangoHud (`sudo apt install mangohud`), lo usa y guarda un CSV en `<botella>/logs/perf/` al cerrar el juego. Si no, muestra el HUD de DXVK, sin registro.
- Registros de Wine: en Linux van en `-all` por defecto, como en Proton. Para depurar, usa `BODEGA_WINEDEBUG`, por ejemplo `BODEGA_WINEDEBUG=fixme-all`.
- Alta densidad: cambia solo `LogPixels` de Wine.
- GPU por botella: `auto` o `discrete`. `discrete` usa las variables de offload de PRIME (NVIDIA y Mesa).
- GameMode: si `gamemoderun` está instalado, envuelve el lanzamiento.

### ntsync

El Wine incluido no tiene variables de esync ni fsync, así que no hay forma de forzarlos. Wine usa ntsync solo si existe `/dev/ntsync` y tu usuario puede acceder a él.

- `.deb`: ya queda configurado. Carga el módulo al arrancar y da acceso al usuario de la sesión activa, sin `chmod`.
- `.tar.gz` y AppImage: hazlo una vez a mano:

```
echo ntsync | sudo tee /etc/modules-load.d/bodega-ntsync.conf
echo 'KERNEL=="ntsync", MODE="0660", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/70-bodega-ntsync.rules
sudo modprobe ntsync
sudo udevadm control --reload-rules
sudo udevadm trigger --sysname-match=ntsync
```

Para comprobarlo, `ls -l /dev/ntsync` debe mostrar el dispositivo. Con un juego abierto, `sudo lsof /dev/ntsync` debe mostrar el wineserver. Si tu kernel no trae el módulo, Wine funciona igual, pero más lento.

### Fuera de Linux

No existen en Linux: DXMT, D3DMetal, DLSS y AVX. La app los oculta.

### Construir

`tool/package_linux.sh` se corre desde la raíz del repo en Ubuntu 24.04. Deja `.deb`, `.tar.gz` y AppImage en `dist/`. Para releases usa el workflow `release-linux`, que se lanza a mano con una etiqueta `vX.Y.Z`. Las etiquetas las crea `tag-version` al hacer push a main. Un binario compilado en una Ubuntu más nueva no corre en 24.04.

### Licencias

Wine es LGPL. Los avisos y la referencia al código fuente vienen en `LICENSES/` del paquete (ver `LICENSES/NOTICE.md`).
