# Tasks: graphics-backends

**Conventions.** `P` = `bodega/packages/engine`; `T` = `Bodega/runtimes/terceros`. **(USER)**: you do it. The agent does not commit or push. Tests without Wine: `cd P && dart test -N '<nombre>'`.

## Engine
- [x] **T1** `P/lib/backends.dart`: names, URL and SHA-256 table, `backendEnv` (S4) and test `backendEnv`.
  **Check:** `dart test -N 'backendEnv'`.
- [x] **T2** `installBackend` (B1), with fake tarballs and test `installBackend` (good, tampered, repeated, no `.tmp-*`). The expected SHA-256 is a parameter with a default value.
  **Check:** `dart test -N 'installBackend'`.
- [x] **T3** `importD3DMetal` (B2) and test `importD3DMetal` (two layouts, a missing module, a path and a link to `CrossOver.app`).
  **Check:** `dart test -N 'importD3DMetal'`.
- [x] **T4** Settings (S1, atomic write) and `resolveBackend` (S2, S3, S5), with fake PEs in tests `settings` and `resolve`.
  **Check:** `dart test -N 'settings'` and `dart test -N 'resolve'`.
- [x] **T5** Integrate into `P/lib/engine.dart`: `_start` with an extra map, `runInBottle` with `backend` and `hud`, `# backend` header (S6). `wineboot` stays on `wine` (S7).
  **Check:** `dart test`; the `fake runtime cycle` test still passes and checks the header.
- [x] **T6** Probe: `P/tool/probe.c` (a copy of `.sdd/graphics-backends/spike-files/probe.c`), `P/tool/build_probe.sh` and the generated `P/lib/probe_data.dart`.
  **Check:** `bash tool/build_probe.sh` finishes and `dart analyze` gives no warnings; the resulting PEs are 64-bit and 32-bit (`file`).
- [x] **T7** `backendTest` (B4) and `listBackends` (B3), with test `listBackends`.
  **Check:** `dart test -N 'listBackends'`.
- [x] **T8** CLI in `P/bin/bodega.dart`: `backend install|import|list|set|test`, and `run --backend --hud` (S7). Wrong usage gives 64.
  **Check:** `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`; `build/bodega backend; echo $?` gives 64; test of `--hud` after the program.

## Headless checks with the real runtime
Each one with a new `BODEGA_HOME` in the scratchpad; first `stop`, then `rm -rf`.

- [x] **T9** Install the runtime, `create t`, `backend install dxmt T/dxmt…tar.gz`, `backend install dxvk T/dxvk…tar.gz`, `backend test t wine|dxmt|dxvk`.
  **Check:** every case `OK`.
- [x] **T10** Extract `renderer/d3dmetal` from `T/Template-1.0.11.tar.xz` into a temporary folder, `backend import d3dmetal`, `backend test t d3dmetal`. Includes `CX_APPLEGPTK_LIBD3DSHARED_PATH` and the 32-bit chain with DXMT.
  **Check:** all `OK`. If the 32-bit chain or the variable fails, **stop** and propose a change to the spec.
- [x] **T11** In another `BODEGA_HOME`, import the Whisky copy (`lib/` in `WH/Wine`), without modifying it, and `backend test`.
  **Check:** every case `OK` and exit code 0, and no hung processes left behind.
- [x] **T12** `backend set t dxmt --exe probe.exe` plus a `run` without the option, and check `# backend dxmt (exe)`; `run --backend dxvk` gives `(opcion)` ("option"); with `backends/d3dmetal` deleted, `--backend d3dmetal` fails with the instruction (S5).
  **Check:** output pasted in `verify`.
- [x] **T13 (USER)** Commit in `bodega`. The agent leaves `~/Documents/GitHub/Bodega/t13.sh`, with no AI attribution and no push.
  **Check:** `git -C bodega log --oneline -1`.

## User acceptance
With windows, on your Mac, in your bottle.

- [x] **U1** Install the three backends in your real folder (D3DMetal from your Whisky) and `backend test prueba d3dmetal`. **Expected:** `OK`.
- [~] **U2 (ran; counter not seen)** `run --backend wine --hud prueba ".../Blur.exe"`. **Expected:** Blur the same as before and, if the counter appears, write down the FPS. With wined3d (OpenGL) it may not appear.
- [ ] **U3 (postponed)** A DX11 game with `--backend dxmt --hud`. **Expected:** it starts, looks right and the log says `dxmt`.
- [ ] **U4 (postponed)** A DX12 game with `--backend d3dmetal --hud`. **Expected:** it starts and looks right.
- [ ] **U5 (postponed)** Compare the same scene from U3 or U4 with CrossOver, using the same backend. **Expected:** an FPS table. This is what will tell whether we are on par, ahead or behind.
