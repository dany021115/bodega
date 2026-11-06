# Mejoras de releases y experiencia (macOS y Linux)

Estado: propuesta, **sin decidir**. Nada de esto está implementado. Al decidir el orden se actualiza `tasks.md`.

## Por qué

Los releases de v1.1.0 funcionan, pero la revisión del repo y un caso real (el binario compilado en CachyOS que no arrancó en Manjaro: "CPU ISA level is lower than required") mostraron huecos:

- Nada comprueba que un paquete arranca en un sistema limpio. `package_linux.sh` puede producir un `bodega` que exige CPU x86-64-v4.
- Los releases no publican checksums ni procedencia.
- Dos pasos manuales encadenados: el tag lo crea `tag-version` solo, pero `release-linux` y `release-macos` se lanzan a mano.
- La app no avisa de versiones nuevas.
- Wine, DXVK y vkd3d-proton se suben revisando a mano; hoy están en lo último (Wine 11.21, DXVK 3.1.1, vkd3d-proton 3.1).
- No hay arreglos por juego (variables, overrides, redistribuibles) fuera del catálogo, ni instalación de dependencias de Windows (vcredist, .NET, fuentes).
- macOS va firmado ad hoc, sin Developer ID ni notarización.

## Alcance

Diez mejoras, independientes salvo donde se indica. Cada una es una PR propia (o menos de 400 líneas por PR, ver `tasks.md`).

| ID | Mejora | Plataforma |
|---|---|---|
| M1 | Guarda de portabilidad del binario (nivel de ISA) | Linux |
| M2 | `SHA256SUMS` y attestations de procedencia en cada release | Ambas |
| M3 | Prueba de humo de cada paquete en un sistema limpio | Ambas |
| M4 | Release encadenado tras `tag-version` | Linux (macOS opcional) |
| M5 | Revisión automática de versiones de Wine, DXVK, vkd3d-proton | Linux |
| M6 | Base de arreglos por juego | Ambas |
| M7 | Dependencias de Windows con winetricks | Ambas |
| M8 | Aviso de versión nueva en la app, y después actualización | Ambas |
| M9 | `PKGBUILD` para el AUR | Linux (Arch) |
| M10 | Developer ID y notarización | macOS |

Fuera: Flatpak, más tiendas (Heroic: Epic, GOG, Amazon), gestor de varias versiones de Wine por botella, DMG con fondo, y todo lo relacionado con anti-cheat (las reglas del proyecto lo prohíben).

## Límites de GitHub Free

La cuenta es GitHub Free y el repositorio es privado. Según la documentación de GitHub (*GitHub Actions billing*):

- **Cómputo incluido:** 12 USD al mes. Un runner Linux de 2 núcleos cuesta 0,006 USD/min (unos 2 000 min); uno de macOS, 0,062 USD/min (unos 190 min). Sin método de pago registrado, al agotarlo los workflows se bloquean.
- **Artefactos:** 500 MB, compartidos con GitHub Packages. Un release de Linux los pasa entre jobs: `.tar.gz` (247 MB) y AppImage (220 MB), más el `.deb`, y 167 MB del paquete de Arch. Es más que la cuota.

Reglas para todo workflow nuevo o cambiado:

1. Lo que se pueda queda **opcional y apagado por defecto**, con un input booleano de `workflow_dispatch` (como `build_engine` en `release-macos`).
2. **macOS solo a mano**: cuesta diez veces más que Linux. Nada lo encadena a otro workflow.
3. Los artefactos llevan `retention-days: 1`.
4. Las pruebas de PR cancelan la corrida anterior de la misma rama (`concurrency`) y tienen un `timeout-minutes` corto.
5. Idea sin decidir (M11): subir los paquetes como assets de un release en borrador desde `build`, en vez de pasarlos entre jobs como artefactos. Según tengo entendido, los assets de un release no cuentan en el almacenamiento de Actions.

## Requisitos (EARS)

| ID | Requisito |
|---|---|
| X1 | Cuando `package_linux.sh` construya el ejecutable `bodega`, lo rechazará con un error claro si `readelf -n` declara `x86-64-v3` o `x86-64-v4` como ISA necesaria. |
| X2 | Cuando se publique un release, subirá `SHA256SUMS-linux` o `SHA256SUMS-macos` con el sha256 de cada archivo, y una attestation de procedencia (`actions/attest`) por archivo, si el repositorio lo permite. |
| X3 | Cuando se pida (`smoke` en `release-linux`; en macOS, un input igual), antes de publicar el workflow instalará el `.deb` en Ubuntu 24.04, el `.pkg.tar.zst` en `archlinux` y desempacará el AppImage, y en cada uno ejecutará `bodega backend list` (CLI, sin ventana). Si falla, no se publica. Por defecto está apagado. |
| X4 | Cuando `tag-version` cree un tag, lanzará `release-linux` con ese tag por `workflow_dispatch`. El release de macOS sigue a mano mientras dependa de tags `engine-*` y `hostlibs-*`. |
| X5 | Cada semana, un workflow comparará `packaging/linux/assets.json` con las últimas releases estables y abrirá una PR con la versión nueva y su sha256, o un issue si no puede calcularlo. Nunca fijará un pre-release. |
| X6 | El motor aplicará, al crear o lanzar, los arreglos de `packages/engine/lib/fixes_data.dart` del juego detectado por ID, sin sobrescribir lo que el usuario puso por programa. |
| X7 | El motor instalará dependencias de Windows (`vcredist`, `dotnet`, fuentes) en una botella con `winetricks`, solo con verbos de una lista permitida, en un proceso de Wine sin ventana. |
| X8 | La app consultará los releases de GitHub una vez por sesión, y si hay una versión mayor mostrará un aviso con el enlace al release. Nunca instalará sin que el usuario lo pida. |
| X9 | El `PKGBUILD` del AUR bajará el `.tar.gz` del release y verificará su sha256. |
| X10 | El DMG de macOS irá firmado con Developer ID y notarizado, si hay cuenta de Apple Developer. Si no, se mantiene la firma ad hoc y las instrucciones de `LEEME.txt`. |

## Decisiones que hay que tomar

1. **Orden.** Propuesta: M1, M2, M3 (seguridad de los releases) → M4 → M6 → M7 → M8 → resto. Choca con la lista anterior (UI en Linux, hito 3 de la interfaz, ntsync): hay que decidir si va antes o después.
2. **M4 y macOS.** `release-macos` necesita los tags `engine-*` y `hostlibs-*`, que se crean a mano en otros workflows. ¿Se deja manual o se automatiza con un tag fijo?
3. **M10.** Exige cuenta de Apple Developer (de pago). [INFERENCIA] Desde Cuba puede no ser accesible. Sin ella, M10 se descarta y M8 en macOS solo avisa.
4. **M6, de dónde salen los arreglos.** Opciones: un JSON propio que se va llenando con lo que se prueba; o partir de datos abiertos de otros proyectos (por ejemplo `umu-database`, cuya licencia hay que revisar antes de copiar nada). No se copia nada de CrossOver.
5. **M7.** ¿winetricks se incluye en el paquete, o se pide al usuario? Incluirlo añade una dependencia (LGPL, ya listado en `wine/NOTICE.md` para macOS) y descargas desde servidores de Microsoft.

## Criterios de aceptación

- Cada mejora trae su prueba (ver `design.md`) y, si toca workflows, se prueba con un tag real o en un fork antes de dar la PR por buena.
- `tool/version.sh check` pasa; cada PR sube la versión según `AGENTS.md`.
- Los cambios de proceso (M4) actualizan `AGENTS.md`, porque hoy dice "run them by hand".
