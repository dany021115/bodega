# Prueba corta (spike): backends sobre nuestro runtime

2026-11-03, M2 Pro, macOS 27.0.1. Runtime `engine-wine-11.0-20261030T202616Z-primer-build` + hostlibs, en una botella temporal ya borrada. Sonda propia, sin ventanas: crea `dxgi` y un dispositivo real. En D3D11 crea una textura, la limpia y hace flush; en D3D12 crea cola y fence y espera la señal.

**Límite:** no presenta ningún fotograma en pantalla. Prueba que el backend arranca, no que un juego se vea bien.

| Backend | Capa | D3D | Bits | Resultado |
|---|---|---|---|---|
| Wine | ninguna | 11 | 64 | OK, nivel 10_1 (`level=a100`), adaptador "NVIDIA GeForce 8800 GTX"; un `GL_INVALID_FRAMEBUFFER_OPERATION` en el log |
| Wine (vkd3d) | ninguna | 12 | 64 | OK, fence completado |
| DXMT v0.80 | `dxmt-v0.80-builtin` | 11 | 64 | OK, nivel 11_0, adaptador "Apple M2 Pro" |
| DXMT v0.80 | igual | 11 | 32 | OK, nivel 11_0 |
| DXVK 1.10.3 | `dxvk-macOS…repack-builtin` + `d3d10core,d3d11=n,b` | 11 | 64 | OK, nivel 11_0 |
| **D3DMetal 3.0 de Sikarugir** | `Template-1.0.11` → `renderer/d3dmetal` | 11 y 12 | 64 | **OK**, adaptador "AMD Compatibility Mode" |
| D3DMetal 3.0 de Sikarugir, sin `DYLD_*` | `external/*` junto a los `.so` | 12 | 64 | **OK** |
| D3DMetal 3.0 de Whisky | `WH/Wine/lib` | 11 y 12 | 64 | **Se cae:** `Unhandled page fault on execute access to 0020019008070C10` al crear el dispositivo, con y sin `DYLD_*`, msync o esync |

**Sin probar:**
- D3DMetal con `CX_APPLEGPTK_LIBD3DSHARED_PATH` usando la copia de Sikarugir.
- La cadena `d3dmetal:dxmt` para 32 bits: el intento salió con `rc=53` por un error del propio script.
- D3DMetal de Apple o de Gcenx.
- Juegos reales y FPS con cualquiera de los backends nuevos.

**Hallazgos:**
- En D3DMetal, `d3d11.so`, `d3d12.so`, `dxgi.so`, `nvapi64.so`, `atidxx64.so`, `nvngx.so` y `libd3dshared.dylib` son **el mismo archivo** (mismo SHA-1 `6c7da2a222…`, id `@rpath/libd3dshared.dylib`).
- `D3DMetal.framework` también carga por `@rpath`: basta dejarlo junto a los `.so`.
- La copia de Whisky no es de fábrica: `WH/pre-gptk-backup` (30 de octubre) indica que se instaló a mano encima del Wine de Whisky. Con el propio Wine de Whisky tampoco funciona: `unimplemented function ntdll.dll.__wine_unix_call`.

**Tarballs guardados en `Bodega/runtimes/terceros/`:**

| Archivo | SHA-256 |
|---|---|
| `dxmt-v0.80-builtin.tar.gz` | `8f260e36b5739e68f3bad613381441385c4dc7b85b78ba8de653d5a6a264529d` |
| `dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz` | `810b1e5caf8ce975b784fae866a130ad23fa0ea233b0e5609cbc4a45f3ef6f00` |
| `Template-1.0.11.tar.xz` (Sikarugir; coincide con el SHA que fija Highball) | `9fa15479e7ff6abd99c1d07be285fb95f41fc6991586502427152b1f7d6ccb8a` |

## Corrección (durante apply, T10)

**La conclusión sobre Whisky era falsa: esa copia funciona.** La caída de la tabla no venía de la copia, sino de cómo se copió para la prueba.

- En ambas copias, `d3d11.so`, `d3d12.so`, `dxgi.so` y los demás son **enlaces simbólicos** a `../../external/libd3dshared.dylib`.
- Copiarlos sin conservar los enlaces crea archivos separados. dyld los carga como imágenes distintas y el proceso salta a `0x20019008070C10` al crear el dispositivo. Con la plantilla de Sikarugir pasa exactamente lo mismo.

Resultados con enlaces conservados y layout `wine/` + `external/`, sin `DYLD_*`:

| Copia | Caso | Resultado |
|---|---|---|
| Sikarugir | D3D12 y D3D11, 64 bits | OK |
| Sikarugir | D3D12 con `CX_APPLEGPTK_LIBD3DSHARED_PATH` | OK |
| Sikarugir | D3D12 con esa variable y cadena `d3dmetal:dxmt` | OK |
| Sikarugir | D3D11 de 32 bits por la cadena | OK |
| Whisky | D3D12 y D3D11, 64 bits, con esa variable | OK |

`pre-gptk-backup` y el fallo del propio Wine de Whisky (`__wine_unix_call`) siguen siendo ciertos, pero no dicen nada sobre esta copia.
