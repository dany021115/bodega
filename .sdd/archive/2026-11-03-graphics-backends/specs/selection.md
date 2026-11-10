# Choosing and applying a backend

## S1 · Settings
- Optional file `bottles/<b>/settings.json`: `{"backend":"auto","programs":{"blur.exe":{"backend":"wine"}}}`.
- Key in `programs`: the exe's name in lowercase, without a path.
- If the file is missing, it is the same as `auto`.
- It is written atomically. Invalid JSON gives an error that names the file; it is not ignored.
- `bodega backend set <botella> <backend> [--exe <nombre.exe>]`. The value `auto` on an exception removes it.

**Scenarios**
- **Given** `set t dxmt --exe Blur.exe`, **then** the key is `blur.exe` and the bottle's `backend` does not change. (test)
- **Given** an unknown name (`foo`), **then** an error and the file untouched. (test)
- **Given** broken JSON, **when** `run` is launched, **then** an error that names `settings.json`. (test)

## S2 · Resolution order
The first one defined wins: `run --backend` → the exe's exception → the bottle's backend → `auto`. Only `auto` looks at the exe.

**Scenario**
- **Given** bottle `dxvk`, exception `dxmt` and `--backend wine`, **then** it uses `wine`; without the option, `dxmt`; without the exception, `dxvk`. (test)

## S3 · Auto
Reads the exe as a stream, case-insensitively, looking for `d3d12.dll`, `d3d11.dll`, `d3d10`, `dxgi.dll`. The bitness comes from the PE header. It only chooses among what is installed:

| Found | 64-bit | 32-bit |
|---|---|---|
| `d3d12.dll` | `d3dmetal`, otherwise `wine` | `wine` |
| `d3d11`, `d3d10` or `dxgi` | `dxmt`, otherwise `dxvk`, otherwise `wine` | same |
| Nothing, or no PE header | `wine` | `wine` |

A program without a path (`notepad`, `cmd`) is `wine`.

**Scenarios**
- **Given** a fake 64-bit PE with `D3D12.DLL` and `d3dmetal` installed, **then** `d3dmetal`; if it is not installed, `wine`. (test)
- **Given** a fake 32-bit PE with `d3d11.dll` and `dxmt` installed, **then** `dxmt`. (test)
- **Given** a PE without those strings, **then** `wine`. (test)

## S4 · Environment
`wineEnv` stays hermetic; only the following is added, depending on the backend:

| Backend | `CX_ACTIVE_GRAPHICS_BACKEND` | `WINEDLLPATH_PREPEND` | Others |
|---|---|---|---|
| `wine` | `wined3d` | — | — |
| `dxmt` | `dxmt` | `backends/dxmt/wine` | — |
| `dxvk` | `dxvk` | `backends/dxvk/wine` | adds `d3d10core,d3d11=n,b` to `WINEDLLOVERRIDES` |
| `d3dmetal` | `d3dmetal` | `backends/d3dmetal/wine`, plus `:backends/dxmt/wine` if DXMT is installed | `CX_APPLEGPTK_LIBD3DSHARED_PATH=backends/d3dmetal/external/libd3dshared.dylib` |

`--hud` adds `MTL_HUD_ENABLED=1`. Never `DYLD_*`.

**Scenarios**
- **Given** each row, **then** the map contains those values and `WINEDLLOVERRIDES` keeps `winemenubuilder.exe=d`. (test)
- **Given** `wine`, **then** there is no `WINEDLLPATH_PREPEND`. (test)

## S5 · Backend not installed
If a setting or an option resolves to a backend that is not installed, `run` fails before launching, with the exact command to install it. It never silently falls back to another one. (test)

## S6 · Traceability
- The log carries `# backend <nombre> (<origen>)`, where the source is `opcion` ("option"), `exe`, `botella` ("bottle") or `auto`.
- `run` prints the same line before `log:`.

**Scenario**
- **Given** a per-exe exception, **then** the header says `(exe)`. (test)

## S7 · Compatibility
- `create`, `wait`, `stop` and `install` do not change.
- `wineboot` always runs with `wine`, with no layers.
- `bodega run <botella> <programa> [args…]` still works without options.
- The `--backend` and `--hud` options go before the bottle, and whatever follows the program is passed through as is.

**Scenario**
- **Given** `run t cmd /c echo --hud`, **then** `--hud` reaches the program. (test)
