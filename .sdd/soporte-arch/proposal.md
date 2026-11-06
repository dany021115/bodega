# Soporte Arch (Arch Linux, CachyOS, Manjaro…)

Bodega ya corre en Linux x86_64 (`.sdd/soporte-linux/`), pero el empaquetado es solo para Ubuntu/Debian: `tool/package_linux.sh` exige `dpkg-deb` y falla en Arch, y el aviso de "Falta Vulkan" sugiere `vulkan-radeon` aunque la GPU no sea AMD.

## Alcance

- Paquete de pacman (`bodega-X.Y.Z-1-x86_64.pkg.tar.zst`) hecho con `makepkg`, a partir del `.tar.gz` que ya arma `package_linux.sh`. Mismo contenido que el `.deb`: `/opt/bodega`, `/usr/bin/bodega`, `.desktop`, icono y ntsync.
- `package_linux.sh` funciona en Arch: el `.deb` y el paquete de pacman se generan solo si su herramienta existe.
- El workflow `release-linux` sube también el paquete de pacman, construido en un contenedor `archlinux` a partir del `.tar.gz` (sin recompilar, así la glibc de Ubuntu 24.04 sigue siendo la base).
- `checkHost` sugiere en Arch el paquete de Vulkan de la GPU real.

Fuera: publicar en el AUR, repositorio propio de pacman, paquetes de 32 bits (el Wine WoW64 no los necesita), otras distros.

## Requisitos (EARS)

| ID | Requisito |
|---|---|
| A1 | Cuando `package_linux.sh` corra sin `dpkg-deb`, avisará y seguirá: `.tar.gz` y AppImage se generan igual. |
| A2 | Cuando `package_linux.sh` corra con `makepkg` y sin ser root, generará `dist/bodega-X.Y.Z-1-x86_64.pkg.tar.zst`; si no, avisará y seguirá. |
| A3 | El paquete de pacman instalará lo mismo que el `.deb`: `/opt/bodega`, `/usr/bin/bodega` → `/opt/bodega/bodega-cli`, `bodega.desktop` con `Exec=/opt/bodega/bodega`, el icono 512 y la carga de ntsync (`modules-load.d` y regla udev `uaccess`). |
| A4 | El paquete dependerá de `gtk3`, `vulkan-icd-loader` y `libpulse`; sugerirá `nvidia-utils`, `vulkan-radeon`, `vulkan-intel`, `gamemode` y `mangohud`. |
| A5 | `makepkg` no quitará símbolos (`!strip`): Wine y el bundle de Flutter llegan al disco como se construyeron. |
| A6 | Si falta Vulkan en una distro con `ID` o `ID_LIKE` `arch`, `checkHost` sugerirá `vulkan-icd-loader` más el controlador de cada fabricante de GPU detectado en `/sys/class/drm/card*/device/vendor` (`0x10de` → `nvidia-utils`, `0x1002` → `vulkan-radeon`, `0x8086` → `vulkan-intel`), sin repetir. Sin ninguna GPU conocida (una VM) sugerirá `vulkan-swrast`. |
| A7 | `release-linux` construirá el paquete de pacman en un contenedor `archlinux:base-devel` desde el `.tar.gz` de `build`, y `release` lo subirá junto a los demás. |

## Criterios de aceptación

- `dart analyze && dart test` en `packages/engine` (A6, con una prueba de `archVulkanPackages`).
- `bash -n` de cada script; los workflows son YAML válido.
- `package_linux.sh` y `build_arch.sh` en CachyOS: el `.pkg.tar.zst` existe; `pacman -Qlp` lista `/opt/bodega/bodega`, `/usr/bin/bodega`, el `.desktop`, el icono, la regla udev y el `modules-load.d`; `pacman -Qip` muestra las dependencias de A4.
- Manual (lo corre el usuario): `sudo pacman -U dist/bodega-*.pkg.tar.zst`, abrir Bodega desde el menú y ver el runtime incluido; `bodega` en la terminal.
- No verificable aquí: el job `arch` del workflow (solo corre en GitHub).
