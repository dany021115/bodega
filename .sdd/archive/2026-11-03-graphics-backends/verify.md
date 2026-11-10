# Verification: graphics-backends

2026-11-03, M2 Pro, macOS 27.0.1, commit `414cdbe`. `H` is a temporary `BODEGA_HOME`, since deleted. D3DMetal copy: the Whisky one, unmodified.

**Limit:** all of this is headless. The probe creates the device and clears a texture, or waits for a fence, but **does not present frames**. No real game has run with DXMT, DXVK or D3DMetal: that is U2–U5, pending with the user.

| Requirement | Status | Evidence |
|---|---|---|
| B1 Install dxmt/dxvk | met | Outputs below; a tampered tarball leaves no trace; test `installBackend`. Real dxvk download done in T9 |
| B2 Import d3dmetal | met | Links to `../../external/libd3dshared.dylib`; CrossOver rejected; test `importD3DMetal` (two layouts, missing module, `.so` of a different size) |
| B3 List | met | `backend list`; test `listBackends` |
| B4 Check | met | All `OK` with the 4 backends; `FALLA` ("FAIL") with a fake Wine in `fake runtime cycle`. With the real Wine no `FALLA` has been seen since `import` recreates the links (T10 did see it before the fix) |
| S1 Settings | met | Lowercase JSON key; `foo` rejected; broken JSON gives exit code 1 and names the file; test `settings` |
| S2 Order | met | `opcion` ("option") > `exe` > `botella` ("bottle") > `auto`, below and in test `resolve` |
| S3 Auto | met | Test `resolve` with fake PEs (64/32-bit, uppercase, UTF-16, no PE); with the real probe it chose `d3dmetal` |
| S4 Environment | met | Variables read from `cmd /c set` inside Wine; no `DYLD_*`, `WINEARCH` or `LANG` |
| S5 Not installed | met | Exit code 1 with the exact command, before launching |
| S6 Traceability | met | `# backend` in the log and in the output of `run` |
| S7 Compatibility | met | `--hud` after the program reaches the program; `create` without `# backend` (test) |

## Pending with the user

- **U1:** install in the real folder and `backend test`.
- **U2:** Blur with `--hud`.
- **U3:** a DX11 game with DXMT.
- **U4:** a DX12 game with D3DMetal.
- **U5:** FPS compared with CrossOver.

## Observations

- The first D3DMetal case took about 38 s in T10 and T11. Cause unconfirmed (probably Rosetta translating the framework).
- `--hud` sets `MTL_HUD_ENABLED=1`, but the counter has not been seen: it needs a window.
- In a first pass, the S4 `grep` was written wrong and the `-> 0` for the broken JSON was the exit code of `cut`. They were run again: see block 2.
- This Mac does not have Warframe installed: its CrossOver bottle is only 310 MB.

## Outputs

### Block 1
```
$ git log -1
414cdbe Daniel Medina <danielmedina151102@gmail.com> engine: graphics backends with per-bottle and per-exe selection (SD
0
       0
$ dart analyze
No issues found!
$ dart format check
Formatted 5 files (0 changed) in 0.02 seconds.
$ dart test
00:03 +12 ~1: All tests passed!
$ compile
Generated: build/bodega
$ usage
backend -> 64
backend test -> 64
$ install + create
H/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
log: 2026-11-03T14-36-30.664099Z-wineboot.log
create -> 0
$ B1 tampered tarball
bodega: checksum incorrecto en /private/tmp/claude-501/-Users-quasar/c
       0
$ B1 d3dmetal is not downloaded
bodega: d3dmetal no se descarga: bodega backend import d3dmetal <carpeta>
-> 1
$ B3 list before
wine: instalado
dxmt: no instalado
dxvk: no instalado
d3dmetal: no instalado
$ S5 not installed
bodega: dxmt no está instalado: bodega backend install dxmt
-> 1
$ B1 install
H/backends/dxmt
H/backends/dxvk
bodega: ya instalado: /private/tmp/claud
$ B2 rejects CrossOver
bodega: no se importa desde CrossOver.app: usa tu propia copia de D3DMetal
-> 1
       0
$ B2 import Whisky
H/backends/d3dmetal
compruébalo: bodega backend test <botella> d3dmetal
su uso se rige por la licencia de Apple del Game Porting Toolkit
atidxx64.so -> ../../external/libd3dshared.dylib
d3d11.so -> ../../external/libd3dshared.dylib
d3d12.so -> ../../external/libd3dshared.dylib
dxgi.so -> ../../external/libd3dshared.dylib
nvapi64.so -> ../../external/libd3dshared.dylib
$ B4 test
[wine] exit=0
OK    D3D11 64 bits  
OK    D3D12 64 bits  
[dxmt] exit=0
OK    D3D11 64 bits  
OK    D3D11 32 bits  
[dxvk] exit=0
OK    D3D11 64 bits  
OK    D3D11 32 bits  
[d3dmetal] exit=0
OK    D3D11 64 bits  
OK    D3D12 64 bits  
OK    D3D11 32 bits  
$ S4 d3dmetal + hud environment
backend d3dmetal (opcion)
WINEDLLOVERRIDES=winemenubuilder.exe=d
WINEDLLPATH_PREPEND=H/backends/d3dmetal/wine:H/backends/dxmt/wine
DYLD/WINEARCH/LANG: 0
$ S4 wine without a layer
0
CX_ACTIVE_GRAPHICS_BACKEND=wined3d
$ S7 args after the program
backend wine (auto)
--hud
$ S1 S2 S6
backend d3dmetal (auto)
backend dxvk (botella)
backend dxmt (exe)
backend wine (opcion)
bodega: backend desconocido: foo (auto, wine, dxmt, dxvk, d3
{
  "backend": "dxvk",
  "programs": {
    "probe.exe": {
      "backend": "dxmt"
    }
  }
}
bodega: /private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratch
{roto
 ^

-> 0
$ cleanup
stop -> 0
0
```

### Block 2
```
$ S4 d3dmetal --hud
CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
CX_APPLEGPTK_LIBD3DSHARED_PATH=H/backends/d3dmetal/external/libd3dshared.dylib
MTL_HUD_ENABLED=1
$ S4 dxvk
WINEDLLOVERRIDES=winemenubuilder.exe=d;d3d10core,d3d11=n,b
WINEDLLPATH_PREPEND=H/backends/dxvk/wine
$ S1 broken JSON
exit=1
bodega: H/bottles/t/settings.json no es válido: FormatException: Unexp
$ cleanup
stop=0
```

## User acceptance (in progress)

**U1: OK.** Real folder: `backend install dxmt`, `backend install dxvk`, `backend import d3dmetal` from Whisky and `backend test prueba`, with all 9 cases `OK`.

**U2: still to find out whether the counter appears.** Blur with `--backend wine --hud` ended with `exit=0` after 77 s, with no new errors in the log.

**Probe times in the real bottle (`run`, from start to `.exit`):**

| Case | Time |
|---|---|
| d3dmetal D3D12, cold bottle | 5.2 s |
| d3dmetal D3D12, right after | 0.7 s |
| d3dmetal D3D11, right after | 30.7 s |
| d3dmetal D3D11, after 6 s | 32.5 s |
| d3dmetal D3D11, cold bottle | 35.2 s |
| dxmt D3D11, cold bottle | 2.2 s |
| wine D3D11, cold bottle | 3.0 s |
| wine `cmd`, cold bottle | 1.5 s |

With D3DMetal, D3D11 takes about 30 s **every time**, not only the first, and D3D12 does not. Cause not investigated: it may be D3D11 initialization or something in the probe itself, which has no window. It has to be looked at in a real game. `auto` is not affected, because it sends D3D11 to DXMT. This replaces the observation above, which put it down to the first run.

## Closing (2026-11-03)

**U2:** Blur ran with `--backend wine --hud`, but the user did not see the FPS counter. `--hud` sets `MTL_HUD_ENABLED=1` (block 2) and its on-screen effect is still unconfirmed: with wined3d it may not appear, and with DXMT or D3DMetal it has not been tested.

**U3, U4 and U5: postponed by the user's decision.** No real game has been run with DXMT, DXVK or D3DMetal, there are no FPS numbers and there is no comparison with CrossOver. That is why this change does not allow claiming "the same as or better than CrossOver". D3DMetal's delay of about 30 s on D3D11 is still not investigated.

Archived with 11 of 11 requirements met in headless tests, and with those game tests pending.
