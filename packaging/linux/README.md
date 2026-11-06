# Paquete Linux: archivos de terceros

`assets.json` fija las versiones, URLs y sha256 de lo que el paquete Linux trae de fuera: Wine, DXVK, vkd3d-proton y appimagetool. `fetch_assets.sh` los baja a `cache/<nombre>/` y verifica cada uno. `cache/` está en `.gitignore`.

```
cd packaging/linux && ./fetch_assets.sh
```

Requiere `curl`, `sha256sum` y `python3`.

## Portabilidad del binario (CPU)

`tool/check_isa.sh` revisa con `readelf -n` el ejecutable `bodega`, la CLI y las `.so` del bundle, y falla si alguno declara `x86-64-v3` o `x86-64-v4` como ISA necesaria. Esa marca la ponen las librerías de una distro tuneada para CPUs nuevas (CachyOS): aunque compiles con `-march=x86-64`, el enlazado hereda la marca de los objetos del sistema. El resultado es un `bodega` que en un equipo más viejo muere con `CPU ISA level is lower than required` (pasó en Manjaro).

- Los releases se construyen en `ubuntu-24.04`, que no la lleva. Pasa de ahí a los demás.
- Un paquete que solo correrá en la máquina que lo construyó: `BODEGA_ALLOW_NATIVE=1 tool/package_linux.sh`.

## Versiones

| name | versión | archivo | bytes (descarga) | sha256 |
|---|---|---|---|---|
| wine | 11.21 | `wine-11.21-staging-amd64-wow64.tar.xz` (Kron4ek) | 99958200 | `a70a9691...fa503ab` |
| dxvk | 3.1.1 | `dxvk-3.1.1.tar.gz` | 18041512 | `40565b4a...f54e608` |
| vkd3d-proton | 3.1 | `vkd3d-proton-3.1.tar.zst` | 5665978 | `b85ea821...f02120b` |
| appimagetool | 1.9.1 | `appimagetool-x86_64.AppImage` | 15092216 | `ed4ce84f...6eb0` |

Origen y comprobación:

- Los cuatro son releases publicados con etiqueta estable (no pre-releases).
- El digest que GitHub publica para DXVK, vkd3d-proton y appimagetool coincide con el sha256 calculado localmente.
- El sha256 de Wine coincide con la tabla SHA256 del cuerpo de la release 11.21 de Kron4ek (GitHub no lo publica como digest del asset).
- appimagetool: GitHub marca como "latest" el tag `continuous`, un build móvil sin versión. Se fija el release etiquetado `1.9.1` (2025-11-18).

## Estructura de los tarballs (inspeccionados, no ejecutados)

Extraídos en el scratchpad, nunca en el repo.

**Wine** (`wine-11.21-staging-amd64-wow64/`, raíz única del tar):

- `bin/wine`, `bin/wineserver`: presentes.
- `lib/wine/x86_64-unix/ntdll.so`: presente.
- `lib/wine/x86_64-windows/kernel32.dll` y `ntdll.dll`: presentes.
- `lib/wine/i386-windows/kernel32.dll` y `ntdll.dll`: presentes.
- No hay `lib/wine/i386-unix/`. La parte WoW64 de 32 bits corre sobre `x86_64-unix`.
- Otros: `bin/` con winecfg, regedit, msiexec, wineboot y demás; `share/wine/wine.inf`, `share/applications/wine.desktop`, `share/man/`.
- No hay `.dylib` ni enlaces que haya que seguir.

**DXVK** (`dxvk-3.1.1/`): `x64/` y `x32/`. Cada uno trae `d3d8.dll`, `d3d9.dll`, `d3d10core.dll`, `d3d11.dll`, `dxgi.dll`. No trae `d3d12`.

**vkd3d-proton** (`vkd3d-proton-3.1/`): `x64/` y `x86/` (no `x32/`). Cada uno trae `d3d12.dll` y `d3d12core.dll`. Trae también `setup_vkd3d_proton.sh`, que no se ejecuta.

## Sync de Wine (strings)

Búsqueda de `sync`, `ntsync`, `ESYNC`, `FSYNC`, `WINE_*` en los binarios:

- `lib/wine/x86_64-unix/ntdll.so`: no contiene `WINEESYNC`, `WINEFSYNC`, `WINE_NTSYNC` ni `ntsync`. Las coincidencias de `fsync` y `msync` son símbolos de glibc (`fsync@@GLIBC_2.2.5`, `msync@@GLIBC_2.2.5`), no variables de Wine.
- `bin/wineserver`: contiene `/dev/ntsync`. Ahí está el soporte ntsync; no aparece ningún nombre de variable de entorno.
- `bin/wine`: solo `WINEDLLPATH`.

Conclusión: los strings no muestran qué variable de entorno activa esync, fsync o ntsync en este build. Hay que probarlo en un equipo real (sin ejecutar Wine desde el agente). Hasta entonces, `syncModes` en el código solo puede contar con `none` como seguro. Los modos `esync`, `fsync` y `ntsync` quedan pendientes de esa prueba.

## Licencias

- Wine: el tar no trae archivo de licencia ni NOTICE. Hay que añadir el texto LGPL y la referencia al código fuente desde el paquete (R16), no desde el tar.
- DXVK: el tar no trae licencia.
- vkd3d-proton: el tar no trae licencia.
- appimagetool: no se empaqueta; solo se usa para construir el AppImage.

## Tamaños descomprimidos (`du -sb`)

- Wine: 853115842 bytes (~814 MiB)
- DXVK: 45666444 bytes (~44 MiB)
- vkd3d-proton: 14222247 bytes (~14 MiB)

## Contradicciones con design.md y tasks.md

1. Nombre del asset de Wine: tasks.md dice `wine-staging-<ver>-amd64-wow64.tar.xz`, pero el nombre real es `wine-<ver>-staging-amd64-wow64.tar.xz`. Se usa el real.
2. Carpetas de vkd3d: design.md y `_ensureLayers` suponen `x64/` y `x32/`. vkd3d-proton trae `x86/`, no `x32/`. Copiar a `syswow64` tiene que mapear `x86/` para vkd3d.
3. D3D12 viene de vkd3d-proton, no de DXVK. La capa `dxvk` del paquete debe copiar las DLL de ambos (`d3d12.dll`, `d3d12core.dll` incluidas). design.md lo implica al pedir overrides para `d3d12,d3d12core`, pero no lo dice al describir `backends/dxvk/`.
4. Sin licencias en los tarballs: design.md pide `LICENSES/`, y ese contenido hay que escribirlo desde las fuentes oficiales, no desde estos archivos.
5. `syncModes` (design.md: `none`, `esync`, `fsync`, `ntsync`): no verificable por strings (ver arriba).
