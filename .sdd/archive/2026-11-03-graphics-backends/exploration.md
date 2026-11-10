# Exploration: graphics-backends

**Paths:** `P` = `bodega/packages/engine`; `BE` = `bodega-engine`; `CX` = the LGPL tree of CrossOver 26.3 (`sources/wine`, taken from `~/Documents/investigacion-launcher/src/cx-26.3/crossover-sources-26.3.0.tar.gz`); `HB` = the Highball app (GPL; copies in the session's scratchpad); `WH` = `~/Library/Application Support/com.franke.Whisky/Libraries`; `CO` = `CrossOver.app/Contents/SharedSupport/CrossOver` (read-only, to understand the mechanism).

Exploration done by reading only. **None of this has been run yet: no new backend has been tested with our runtime.**

## 1. Problem

Today everything goes through Wine's DLLs: D3D9–11 through wined3d and D3D12 through vkd3d. Blur (DX9) runs fine like that, but there is neither DXMT nor D3DMetal.

The user wants all the backends, with D3DMetal as a requirement, and to choose them as in CrossOver: the future interface will offer the selector, and this change gets the engine ready. The Flutter UI is out of scope.

## 2. What has to change

- **Environment:** `wineEnv` is a fixed map with no notion of a backend (`P/lib/engine.dart:53-71`). It is used in `_start` (`:330`), `_wineserver` (`:339`) and `installRuntime` (`:139`).
- **Launching:** `runInBottle` does not take a backend (`P/lib/engine.dart:205-244`); `_start` goes through `/bin/sh` (`:326-333`).
- **Settings:** there is no per-bottle or per-game file. The prototype decided on "no JSON" because there was nothing to store; now there is.
- **CLI:** `P/bin/bodega.dart:13-43` uses fixed list patterns, with no options.
- **Runtime:** `runtimes/<id>/engine/`. The tarball's `renderers/` folders come empty (the prototype's `exploration.md`, §2.1) and `requiredFiles` does not mention backends (`P/lib/engine.dart:75-84`).
- **Hints:** `_hints` does not cover backend failures (`P/lib/engine.dart:274-283`).

## 3. Common mechanism: layers in front of Wine's DLLs

- Patch `0003` adds `WINEDLLPATH_PREPEND`: folders that are searched **before** the engine's DLLs. It is already in our runtime (`BE/patches/0003-ntdll-winedllpath-prepend.patch:1-45`).
- Each layer has `x86_64-windows/`, `i386-windows/` and `x86_64-unix/`. If the folder level is wrong, the layer is ignored without a warning (pitfall 10 of the prototype).
- A builtin DLL from a layer only loads if the prefix has its placeholder file. `winemetal.dll` already has one because the engine includes it (`BE/.github/workflows/build.yml:96-106`), and `atidxx64`, `nvapi64` and `nvngx` are in `wine.inf` (`CX/loader/wine.inf.in:739-742`).
- The variable is set per process, but the bottle's services keep the environment of the first process (pitfall 4 of the prototype; Highball documents the case in `HB/WineRunner.swift:393`).
- `CX_ACTIVE_GRAPHICS_BACKEND`: in CrossOver the closed `cxcompatdb.so` sets it, and the LGPL tree reads it in `CX/dlls/win32u/d3dkmt.c:719-724` (WDDM for `d3dmetal`). We will have to set it ourselves.

## 4. Each backend

| Backend | What it covers | Where it comes from | Size | How it is enabled |
|---|---|---|---|---|
| **wine** (wined3d + vkd3d) | D3D9–11 through wined3d; D3D12 through vkd3d on MoltenVK | Already in the runtime (`d3d12.dll`, `d3d12core.dll`, `wined3d.dll`) | 0 | No layer |
| **DXMT** | D3D10/11, 32 and 64 bits | Official release `dxmt-v0.80-builtin.tar.gz` (3Shain/dxmt, MIT) | 17 MB | Layer, without `n,b` |
| **DXVK** | D3D10/11 on MoltenVK | `dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz` (Gcenx) | 2 MB | Layer + `WINEDLLOVERRIDES=d3d10core,d3d11=n,b`; Wine provides `dxgi` (the package only ships `d3d10core` and `d3d11`, as seen in `WH/DXVK/x64`) |
| **D3DMetal** | D3D11/12, MetalFX, DXR; **64-bit only** | A copy the user supplies, never bundled | 63 MB | See §5 |

**"vkd3d" is not a separate layer in this first version:** it is the D3D12 path of "wine". vkd3d-proton, which Highball uses, needs about 30 patches and gives 19–26 fps in Flight Simulator 2024 on an M4 (`gap-graphics-defaults-without-d3dmetal.md:42`), so it is not worth it now.

**DXMT and D3D12 do not mix well:** DXMT's `dxgi` breaks vkd3d (`gap-graphics-defaults-without-d3dmetal.md:41`), and DXMT's own D3D12 is still not ready (`:34-36`).

## 5. D3DMetal

**Pieces** (seen in `CO/lib64/apple_gptk` and in `WH/Wine/lib`):
- `external/D3DMetal.framework` and `external/libd3dshared.dylib`.
- Wine modules: `d3d11`, `d3d12`, `dxgi`, `nvapi64`, `atidxx64`, `nvngx` in `x86_64-windows/` and `x86_64-unix/`. Whisky also has `d3d10.so`, `d3d12core.dll`, and calls the DLSS module `nvngx-on-metalfx`: **the layouts are not identical**.

**How it loads, from what we read:**
- `d3d12.so` links `@rpath/libd3dshared.dylib`, with `LC_RPATH @loader_path` (`otool` on `WH`).
- It also contains the path `@rpath/D3DMetal.framework/D3DMetal` and the error `Failed to dlopen D3DMetal`.
- `ntdll` can load `libd3dshared` earlier if `CX_APPLEGPTK_LIBD3DSHARED_PATH` is set and it is macOS 14+ (`CX/dlls/ntdll/unix/loader.c:1323-1331`); it registers regions of non-native code (`:1331-1352`). CrossOver always sets it (`CO/bin/wine:679-684`).
- Highball uses `DYLD_FALLBACK_LIBRARY_PATH` and `DYLD_FALLBACK_FRAMEWORK_PATH` (`HB/Bottle.swift:65-66`), which clashes with our `/bin/sh`, because SIP strips `DYLD_*` when it starts (pitfall 2).
- **Untested hypothesis:** put `libd3dshared.dylib` and `D3DMetal.framework` next to the layer's `.so` files, so that `@loader_path` finds them without `DYLD_*`. If that fails, an `export` inside the `_launch` script also avoids SIP's stripping.

**Glue we already have in the LGPL tree:** `CX/dlls/winemac.drv/d3dmetal*.{c,m,h}`, `CX/dlls/setupapi/devinst.c:5251-5321` and `CX/dlls/ntdll/loader.c:4018`.

**64-bit only:** Highball chains DXMT behind it so that a 32-bit D3D10/11 game does not fall back to wined3d (`HB/Bottle.swift:61-63`).

**Known limitation:** D3DMetal 3.0 has no timestamp queries; Highball adds a shim for Guardians of the Galaxy (`HB/Bottle.swift:51-59`).

**Where to get the copy:**
- **Whisky on this Mac (`WH/Wine/lib`):** version 3.0 (`version.plist`), 0 MB to download. The same version as CrossOver 26.3. Its framework has a signature with no Team ID, and it is not known whether its modules fit the CX tree.
- **Gcenx/game-porting-toolkit 3.0-3:** 228 MB; its own note refers to Apple's license.
- **Apple (developer.apple.com):** the official source; it requires an account and reading the license.
- **CrossOver:** ruled out by the project's rules.

## 6. Choosing per bottle and per game

- **CrossOver** stores `CX_GRAPHICS_BACKEND` in the `[EnvironmentVariables]` of `cxbottle.conf` (`02-graphics.md` §4) and resolves the layers at load time with closed code. We get the same effect with `WINEDLLPATH_PREPEND`.
- **Highball** models an enum `wined3d | vkd3d | dxmt | d3dmetal | dxvk` that returns the environment (`HB/Bottle.swift:20-82`), and stores per-program settings (`HB/Bottle.swift:445`). It is the shape that best fits the future interface. GPL: it can be reused as long as it is for personal use.
- **Auto:** the report suggests looking at the PE imports (`02-graphics.md`, strategy 2). It fails with games that load D3D dynamically or that have a launcher in front, so the manual setting must always win.

## 7. Constraints

- **User's decision (2026-11-03): D3DMetal is in, and they want all the backends.**
- Warning already given: the GPTK license limits use to developing, testing or evaluating games, and it has export-control terms that each user accepts when they download it themselves (`INFORME-FINAL.md` §9.6). Accepting it is the user's decision.
- D3DMetal never goes into the repo or into a tarball of ours, and it is not copied from CrossOver. The user imports it from their own copy.
- **User's decision:** whoever uses the app installs it, and the interface will explain how. That screen belongs to the Flutter app, outside this change. Here we only need the import command and a clear message if it is missing. Nuance: Whisky does not ask you to install it by hand; it ships it in the runtime it downloads (`WhiskyWineInstaller.swift`, `WH/Wine/lib/external`).
- If the app is ever published, this gets revisited: redistributing it is a different problem.
- Everything else stays the same: hermetic environment, no AI attribution, commits and pushes with the user's OK, minimalism.
- DXMT and DXVK are small and are downloaded straight from GitHub, without spending CI minutes.

## 8. Pitfalls

1. If you switch backends while the bottle is running, the services keep the previous environment: you have to `stop` first.
2. A wrongly nested layer is ignored without a warning: every test has to check which backend is really active. `DXMT_LOG_PATH` works for DXMT; for D3DMetal and DXVK the check is still to be defined.
3. D3DMetal and DXMT both replace `dxgi`; a process only loads one.
4. Switching backends on a game with Denuvo can lock it because of a hardware change (`07-store-clients.verify.md` C14).
5. `D3DM_*`, `DXMT_*` and `MTL_HUD_ENABLED` do not get through today because the environment is hermetic (`P/lib/engine.dart:53-71`): without them, FPS cannot be measured.
6. Whisky's modules are built for its Wine, not for the CX tree. It is the biggest technical risk.

## 9. Questions for the proposal

1. **D3DMetal copy for the tests.** The engine will import a folder the user supplies. For testing: the local Whisky copy (no download), or the Gcenx/Apple one if its modules do not fit?
2. **Loading without `DYLD_*`.** Run a short test (spike) first, before writing the final design.
3. **Settings.** A per-bottle `settings.json`, with per-exe overrides?
4. **Auto.** D3D12 → D3DMetal, D3D10/11 → DXMT, D3D9 → wine, by reading the exe's PE imports?
5. **Versions.** The official DXMT v0.80, or a newer commit built by us (LGPL, uses CI)?
6. **FPS.** Add `--hud` for `MTL_HUD_ENABLED`? Without measuring, we cannot claim "better than CrossOver".
7. **Test games.** Blur covers DX9. We still need one DX11 game and one DX12 game: on this Mac only Warframe is a clear option, and it has both modes but adds its launcher.
