# Elegir y aplicar un backend

## S1 · Ajustes
- Archivo opcional `bottles/<b>/settings.json`: `{"backend":"auto","programs":{"blur.exe":{"backend":"wine"}}}`.
- Clave de `programs`: nombre del exe en minúsculas, sin ruta.
- Si falta el archivo, equivale a `auto`.
- Se escribe de forma atómica. Un JSON inválido da error que nombra el archivo; no se ignora.
- `bodega backend set <botella> <backend> [--exe <nombre.exe>]`. El valor `auto` en una excepción la borra.

**Escenarios**
- **Dado** `set t dxmt --exe Blur.exe`, **entonces** la clave es `blur.exe` y el `backend` de la botella no cambia. (test)
- **Dado** un nombre desconocido (`foo`), **entonces** error y archivo intacto. (test)
- **Dado** JSON roto, **cuando** se lanza `run`, **entonces** error que nombra `settings.json`. (test)

## S2 · Orden de resolución
Gana el primero definido: `run --backend` → excepción del exe → backend de la botella → `auto`. Solo `auto` mira el exe.

**Escenario**
- **Dado** botella `dxvk`, excepción `dxmt` y `--backend wine`, **entonces** usa `wine`; sin la opción, `dxmt`; sin la excepción, `dxvk`. (test)

## S3 · Auto
Lee el exe en streaming, sin distinguir mayúsculas, buscando `d3d12.dll`, `d3d11.dll`, `d3d10`, `dxgi.dll`. Los bits salen de la cabecera PE. Elige solo entre lo instalado:

| Hallado | 64 bits | 32 bits |
|---|---|---|
| `d3d12.dll` | `d3dmetal`, si no `wine` | `wine` |
| `d3d11`, `d3d10` o `dxgi` | `dxmt`, si no `dxvk`, si no `wine` | igual |
| Nada, o sin cabecera PE | `wine` | `wine` |

Un programa sin ruta (`notepad`, `cmd`) es `wine`.

**Escenarios**
- **Dado** un PE falso de 64 bits con `D3D12.DLL` y `d3dmetal` instalado, **entonces** `d3dmetal`; sin instalar, `wine`. (test)
- **Dado** un PE falso de 32 bits con `d3d11.dll` y `dxmt` instalado, **entonces** `dxmt`. (test)
- **Dado** un PE sin esos textos, **entonces** `wine`. (test)

## S4 · Entorno
`wineEnv` sigue hermético; solo se añade lo siguiente, según el backend:

| Backend | `CX_ACTIVE_GRAPHICS_BACKEND` | `WINEDLLPATH_PREPEND` | Otras |
|---|---|---|---|
| `wine` | `wined3d` | — | — |
| `dxmt` | `dxmt` | `backends/dxmt/wine` | — |
| `dxvk` | `dxvk` | `backends/dxvk/wine` | añade `d3d10core,d3d11=n,b` a `WINEDLLOVERRIDES` |
| `d3dmetal` | `d3dmetal` | `backends/d3dmetal/wine`, y `:backends/dxmt/wine` si DXMT está instalado | `CX_APPLEGPTK_LIBD3DSHARED_PATH=backends/d3dmetal/external/libd3dshared.dylib` |

`--hud` añade `MTL_HUD_ENABLED=1`. Nunca `DYLD_*`.

**Escenarios**
- **Dado** cada fila, **entonces** el mapa contiene esos valores y `WINEDLLOVERRIDES` conserva `winemenubuilder.exe=d`. (test)
- **Dado** `wine`, **entonces** no hay `WINEDLLPATH_PREPEND`. (test)

## S5 · Backend no instalado
Si se resuelve por ajuste o por opción un backend no instalado, `run` falla antes de lanzar, con la orden exacta para instalarlo. Nunca cae en otro en silencio. (test)

## S6 · Trazabilidad
- El log lleva `# backend <nombre> (<origen>)`, con origen `opcion`, `exe`, `botella` o `auto`.
- `run` imprime la misma línea antes de `log:`.

**Escenario**
- **Dado** una excepción por exe, **entonces** la cabecera dice `(exe)`. (test)

## S7 · Compatibilidad
- `create`, `wait`, `stop` e `install` no cambian.
- `wineboot` corre siempre con `wine`, sin capas.
- `bodega run <botella> <programa> [args…]` sigue funcionando sin opciones.
- Las opciones `--backend` y `--hud` van antes de la botella, y lo que sigue al programa se pasa tal cual.

**Escenario**
- **Dado** `run t cmd /c echo --hud`, **entonces** `--hud` llega al programa. (test)
