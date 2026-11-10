# Proposal: graphics-backends

## Why

Bodega only has Wine's DLLs. Blur (DX9) runs fine, but DX10/11 games go through wined3d and DX12 through vkd3d, which is the weakest path. The user wants all the backends and to choose them as in CrossOver, with D3DMetal as a requirement. The short test (`spike.md`) confirms that all four start on our runtime.

## What

- **Backends:** `wine` (wined3d + vkd3d, already included), `dxmt`, `dxvk`, `d3dmetal`, and `auto`, which picks one.
- **Install:** `dxmt` and `dxvk` are downloaded from GitHub with a pinned URL and SHA-256. `d3dmetal` is imported by whoever uses the app, from a folder of their own; Bodega never downloads or bundles it.
- **Check:** `bodega backend test` creates a real device with the probe. It is needed because a badly made copy of D3DMetal loads, answers `dxgi` and only crashes when it creates the device.
- **Choose:** a per-bottle setting, a per-exe exception and a one-off option on `run`. It is stored in `settings.json`.
- **Measure:** `run --hud` turns on the Metal counter.

## Out of scope

- The Flutter app and the screen that will explain how to install D3DMetal.
- vkd3d-proton, d9vk, MetalFX, DLSS, Highball's timestamp shim and other `D3DM_*` variables.
- DXMT later than v0.80, and building backends in CI.
- Game dependencies (vcredist, etc.) and a game database.
- Claiming "better than CrossOver": this change provides what is needed to measure it, and the comparison is U5.

## Impact

- **`bodega/packages/engine`:**
  - new `lib/backends.dart`;
  - generated `lib/probe_data.dart` (the probe in base64, about 170 KB);
  - changes in `lib/engine.dart` and `bin/bodega.dart`;
  - `tool/probe.c` and `tool/build_probe.sh`;
  - tests.
- **On disk:** `$BODEGA_HOME/backends/{dxmt,dxvk,d3dmetal}/` and `bottles/<b>/settings.json`.
- **`bodega-engine`:** no changes. No CI minutes spent.

## Decisions

| # | Question | Decision | Reason |
|---|---|---|---|
| 1 | D3DMetal copy for testing | **The one from your Whisky** (no download) or `renderer/d3dmetal` from the Sikarugir template | Both pass the probe with the links preserved (`spike.md`, Correction) |
| 2 | Loading without `DYLD_*` | `wine/` + `external/` layout, with each `.so` as a link to `libd3dshared.dylib` | Tested; it respects the current design and avoids SIP's stripping |
| 3 | Settings | `bottles/<b>/settings.json`: backend and per-exe exceptions | What the interface will need |
| 4 | Auto | Searches the exe for text, not only imports: `d3d12.dll` → d3dmetal (64-bit) or wine; `d3d11`/`d3d10`/`dxgi` → dxmt; everything else → wine. Only uses what is installed | It also sees dynamically loaded DLLs. It has limits (launchers), and that is why the manual setting always wins |
| 5 | Versions | Official DXMT v0.80 and DXVK-macOS 1.10.3 | Already built and tested; they use no CI. They can be updated in another change |
| 6 | FPS | `run --hud` | Without measuring there is no comparison with CrossOver |
| 7 | Backend requested but not installed | Error with the instruction to install it; it never silently falls back to another one | A manual choice must not change without a warning |
| 8 | 32-bit with D3DMetal | If DXMT is installed, it is chained behind | Highball does it (`HB/Bottle.swift:61-63`); tested in `spike.md` (Correction), T10 repeats it |
| 9 | Copying from CrossOver | `import` rejects paths inside `CrossOver.app` | Project rule |

## Risks

- The probe does not present frames: a backend can pass it and still look wrong in a game. U3–U5 close this gap.
- D3DMetal 3.0 has no timestamp queries; some DX12 game may fail (`HB/Bottle.swift:51-59`).
- `auto` gets it wrong with launchers and with exes that do not mention D3D.
- Apple's license (`exploration.md` §7): a decision the user has already made. If the app is ever published, this has to be revisited.
- Only Warframe seems usable for DX11/DX12 on this Mac, and it adds its launcher.
