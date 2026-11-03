# Ajustes y backends

## A1 · msync por botella
- `settings.json` admite `"sync": "msync" | "none"`; si falta, `msync`. Otro valor da error que nombra el archivo.
- `none` añade `WINEMSYNC=0` a todo lo que se lanza en esa botella. `wineboot` de `create` sigue igual, porque su servidor termina antes.
- `bodega sync <botella> <msync|none>`. Si el valor cambia, primero para la botella e imprime `botella detenida`, porque el modo es fijo mientras corre y un proceso con el otro modo sale con 1. Si no cambia, no para nada.

**Escenarios (test `settings`):**
- **Dado** `sync none`, **entonces** `run` lleva `WINEMSYNC=0`.
- **Dado** `sync foo`, **entonces** error y archivo intacto.
- **Dado** una botella con `backend` y excepciones, **cuando** cambia `sync`, **entonces** se conservan.
- **Dado** el mismo valor, **entonces** el Wine falso no recibe `-k`.

## A2 · Variables por programa
- `programs.<exe>` admite `env`, además de `backend`.
- Orden de aplicación: `wineEnv` < `backendEnv` < `env` del programa < `WINEMSYNC` del ajuste.
- `backend set … auto --exe x` quita solo el backend y conserva `env`; la entrada desaparece si queda vacía.

**Escenarios (test `settings`):**
- **Dado** `env` en un programa, **entonces** el proceso la recibe, y otro programa no.
- **Dado** `env` que coincide con una variable del backend, **entonces** gana `env`.

## A3 · DXMT parcheado
- `_pinned['dxmt']` pasa a `dxmt-highball-20261017T231707Z-331c552.tar.gz` de `gauthierpiarrette/highball-engine`, SHA-256 `89e731b81cc1ef741accb2e707159f121ed822a083f14f16da445cd8dbbf4703`.
- `backendEnv` de `dxmt` y `d3dmetal` añade `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`. En `d3dmetal` solo si DXMT está en la cadena.
- `backend install` sigue rechazando reinstalar sobre lo que ya hay; quien tenga el oficial lo borra antes (U1).

**Escenarios:**
- **Dado** `backendEnv`, **entonces** contiene la variable en esos casos y no en `wine` ni `dxvk`. (test `backendEnv`)
- **Dado** el tarball real, **cuando** se instala, **entonces** queda `wine/x86_64-unix/winemetal.so`, y `backend test` da `OK` en 64 y 32 bits. (T9)

## A4 · Auto y D3D9
En `auto` (S3 de `backends-graficos`): si aparece `d3d9.dll` y no aparecen `d3d11.dll` ni `d3d12.dll`, el resultado es `wine`, aunque el binario mencione `d3d10` o `dxgi.dll`.

**Escenarios (test `resolve`):**
- **Dado** un PE con `d3d9.dll`, `d3d10` y `dxgi.dll`, **entonces** `wine`.
- **Dado** un PE con `d3d9.dll` y `d3d11.dll`, **entonces** `dxmt`.
- **Dado** un PE con solo `d3d10`, **entonces** `dxmt`.
- **Dado** el `Blur.exe` real, **entonces** `wine (auto)`. (U2)
