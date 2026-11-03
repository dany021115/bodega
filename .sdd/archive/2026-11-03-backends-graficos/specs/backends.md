# Instalar y comprobar backends

Raíz: `$HOME_B/backends/<nombre>/wine/{x86_64-windows,i386-windows,x86_64-unix}`, donde `HOME_B` es `bodegaHome`. `wine` no ocupa carpeta.

## B1 · Instalar `dxmt` y `dxvk`
- `bodega backend install <dxmt|dxvk> [tarball]`.
- Sin `tarball`, descarga con `/usr/bin/curl -fL -C - --retry 5` a `$HOME_B/downloads/`, desde la URL fijada.
- URL y SHA-256 fijados en el código. El SHA-256 se comprueba siempre, también con un tarball local.
- Extrae en `backends/.tmp-<nombre>`, normaliza a `wine/` y renombra. Si falla, no queda `.tmp-*` ni instalación parcial.
- Si ya está instalado, error `ya instalado` con la orden para quitarlo.

**Escenarios**
- **Dado** el tarball correcto, **cuando** se instala `dxmt`, **entonces** existen `wine/x86_64-windows/d3d11.dll` y `wine/x86_64-unix/winemetal.so`. (test)
- **Dado** un tarball alterado, **cuando** se instala, **entonces** da error de checksum y no crea `backends/dxmt`. (test)
- **Dado** `dxvk`, **entonces** existen `wine/x86_64-windows/d3d11.dll` y `wine/i386-windows/d3d11.dll`. (test)

## B2 · Importar `d3dmetal`
- `bodega backend import d3dmetal <carpeta>`.
- Acepta `wine/x86_64-{unix,windows}` + `external/`, o `lib/wine/x86_64-{unix,windows}` + `lib/external/`.
- Exige `x86_64-windows/{d3d11,d3d12,dxgi}.dll`, `x86_64-unix/{d3d11,d3d12,dxgi}.so`, `external/libd3dshared.dylib` y `external/D3DMetal.framework`.
- Copia solo esos módulos, más `atidxx64`, `nvapi64`, `nvngx` y `d3d12core.dll` si existen, y conserva el layout `wine/` + `external/`.
- Cada `.so` queda como enlace simbólico a `../../external/libd3dshared.dylib`, aunque el origen haya perdido los enlaces. Si un `.so` no pesa lo mismo que esa biblioteca, da error y no crea nada.
- Rechaza cualquier ruta que, resuelta, contenga `/CrossOver.app/`.
- Bodega nunca descarga D3DMetal.
- Al terminar imprime que hay que comprobarlo con `bodega backend test` y que su uso se rige por la licencia de Apple.

**Escenarios**
- **Dado** un layout `wine/+external/` falso con archivos normales, **cuando** se importa, **entonces** `libd3dshared.dylib` y el framework quedan en `external/`, y cada `.so` es un enlace a esa biblioteca. (test)
- **Dado** un `.so` de otro tamaño, **cuando** se importa, **entonces** da error y no crea nada. (test)
- **Dado** el layout `lib/…`, **cuando** se importa, **entonces** queda igual. (test)
- **Dado** una ruta bajo `CrossOver.app`, o un enlace a ella, **entonces** error y nada creado. (test)
- **Dado** que falta `d3d12.dll`, **entonces** error que la nombra y nada creado. (test)

## B3 · Listar
`bodega backend list` imprime una línea por backend, `nombre: instalado|no instalado`, siempre con `wine` instalado. (test)

## B4 · Comprobar
- `bodega backend test <botella> <backend>` ejecuta la sonda, sin ventanas, con ese backend y un log por ejecución.
- Casos: `wine` → 11 y 12 en 64 bits. `dxmt` → 11 en 64 y 32. `dxvk` → 11 en 64 y 32. `d3dmetal` → 11 y 12 en 64; y, si `dxmt` está instalado, 11 en 32.
- La sonda (`tool/probe.c`) se escribe a `backends/probe/` desde `lib/probe_data.dart` y solo crea dispositivos.
- Imprime `OK` o `FALLA` por caso, con la ruta del log. El código de salida es 0 solo si todos pasan.

**Escenarios**
- **Dado** cada backend instalado, **cuando** se comprueba, **entonces** todos los casos dan `OK`. (headless T9, T10)
- **Dado** D3DMetal importado de Whisky, **cuando** se comprueba, **entonces** todos los casos dan `OK`. (headless T11)
- **Dado** un programa que sale con error, **cuando** se comprueba, **entonces** da `FALLA` y salida distinta de 0. (test con Wine falso)
