# Settings and backends

## A1 · Per-bottle msync
- `settings.json` accepts `"sync": "msync" | "none"`; if missing, `msync`. Any other value gives an error that names the file.
- `none` adds `WINEMSYNC=0` to everything launched in that bottle. The `wineboot` from `create` stays as it is, because its server exits beforehand.
- `bodega sync <botella> <msync|none>`. If the value changes, it first stops the bottle and prints `botella detenida` ("bottle stopped"), because the mode is fixed while the bottle runs and a process with the other mode exits with 1. If it does not change, nothing is stopped.

**Scenarios (test `settings`):**
- **Given** `sync none`, **then** `run` carries `WINEMSYNC=0`.
- **Given** `sync foo`, **then** an error and the file untouched.
- **Given** a bottle with `backend` and exceptions, **when** `sync` changes, **then** they are kept.
- **Given** the same value, **then** the fake Wine does not receive `-k`.

## A2 · Per-program variables
- `programs.<exe>` accepts `env`, besides `backend`.
- Order of application: `wineEnv` < `backendEnv` < the program's `env` < the setting's `WINEMSYNC`.
- `backend set … auto --exe x` removes only the backend and keeps `env`; the entry disappears if it ends up empty.

**Scenarios (test `settings`):**
- **Given** `env` on a program, **then** the process receives it, and another program does not.
- **Given** an `env` that matches a backend variable, **then** `env` wins.

## A3 · Patched DXMT
- `_pinned['dxmt']` becomes `dxmt-highball-20261017T231707Z-331c552.tar.gz` from `gauthierpiarrette/highball-engine`, SHA-256 `89e731b81cc1ef741accb2e707159f121ed822a083f14f16da445cd8dbbf4703`.
- `backendEnv` for `dxmt` and `d3dmetal` adds `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`. For `d3dmetal`, only if DXMT is in the chain.
- `backend install` still refuses to reinstall over what is already there; whoever has the official one deletes it first (U1).

**Scenarios:**
- **Given** `backendEnv`, **then** it contains the variable in those cases and not for `wine` or `dxvk`. (test `backendEnv`)
- **Given** the real tarball, **when** it is installed, **then** `wine/x86_64-unix/winemetal.so` is in place, and `backend test` gives `OK` in 64 and 32 bits. (T9)

## A4 · Auto and D3D9
In `auto` (S3 of `graphics-backends`): if `d3d9.dll` appears and neither `d3d11.dll` nor `d3d12.dll` does, the result is `wine`, even if the binary mentions `d3d10` or `dxgi.dll`.

**Scenarios (test `resolve`):**
- **Given** a PE with `d3d9.dll`, `d3d10` and `dxgi.dll`, **then** `wine`.
- **Given** a PE with `d3d9.dll` and `d3d11.dll`, **then** `dxmt`.
- **Given** a PE with only `d3d10`, **then** `dxmt`.
- **Given** the real `Blur.exe`, **then** `wine (auto)`. (U2)
