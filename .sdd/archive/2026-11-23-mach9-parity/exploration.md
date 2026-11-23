# Exploration · mach9-parity

Date: 2026-11-23. Base: the merge of #22 (`feat/mach9-runtime`) with #24's tip (`feat/game-configurations`), in the worktree `../pr22`.

## Problem

The goal is that a game run in a Bodega bottle on the Native engine (Mach9) runs as well as it does in Mach9.app, and that what #22 left for later gets done.

Today a Bodega Mach9 bottle:
- runs Mach9's Wine unmodified;
- gets every one of Mach9's built-in rules, which live in `compatdb.so` and apply whoever launches the process;
- keeps Mach9's engine defaults: msync, TSO, FEX's reduced x87 precision, the bundled Vulkan, GStreamer and vkd3d-proton.

The gaps are in what a launcher must add on top, and in how Bodega's other features (#15, #16, the catalog) treat a Mach9 bottle.

Sources:
- **Mach9 at `cc71942` (v0.4.0, 2026-11-17, Zlib, © Alexander Theißen)**, a shallow clone, read only:
  - `docs/{app,internals,compatdb,maintenance}.md`;
  - `compatdb/core/src` (the crate the docs call the spec);
  - `launcher/app/src` (Mach9.app's launcher, in Rust).
- **Bodega:** `packages/engine/lib/{engine,runtimes,mach9,backends,catalog,dependencies,fixes}.dart` and `.sdd/mach9-runtime/`.

Below, `M/` is Mach9's tree and `ENG/` is `packages/engine/`.

## A. Launch parity with Mach9.app (ranked by likely effect on games)

1. **msync is off in Mach9 bottles made from the catalog.**
   - All 7 catalog entries (steam, rockstar, ea-app, ubisoft-connect, battle-net, epic-games and gog-galaxy) carry `"sync": "none"`. That was written for Rosetta's Wine, where Steam's window hangs with msync.
   - `installEntry` saves `entry.sync` into a new bottle of either runtime (`ENG/lib/catalog.dart:186-196`), and `syncEnv('none')` then sends `WINEMSYNC=0` (`ENG/lib/platform_mac.dart:153-154`).
   - Mach9.app always sets `WINEMSYNC=1` (`M/launcher/app/src/wine_env.rs:60`), runs Windows Steam that way, and documents msync as a default that "saves wineserver round trips" (`M/docs/internals.md:143-160`).
   - Today this reaches only `bodega catalog install --runtime mach9`, because the app's catalog makes Rosetta bottles (D25). M3's engine choice in the catalog would spread it.
2. **Game Mode and the app's identity.**
   - Mach9.app is started by Launch Services and turns its own process into Wine with `execv`. Its comment: "macOS gives Game Mode to the app Launch Services started … a game running in [a child] never gets Game Mode" (`M/launcher/app/src/launch.rs:62-70`).
   - Mach9 also gives `wine.app` the games category, `LSSupportsGameMode` and `GCSupportsGameMode`, "so a game the launcher starts gets Game Mode" (`M/bin/bundle-wine.sh:2964-2986`).
   - Bodega starts `wine` as a detached grandchild through `/bin/sh -c` (`ENG/lib/engine.dart:620-645`), and Bodega.app's `Info.plist` has no games category or Game Mode keys.
   - Whether a Bodega Mach9 game gets Game Mode is unknown. It is the "Game Mode turns on" line of #22's V6 (USER).
3. **Retina and DPI.**
   - Mach9.app sets `RetinaMode` and `LogPixels` to "auto" on every launch: on when the main display is high-density, with 192 DPI (`M/launcher/app/src/retina.rs:1-7`, `registry.rs:1-12, 54-112`).
   - Bodega's `highRes` is off by default for both runtimes (`ENG/lib/backends.dart:489`), so a Mach9 game draws in points and is scaled up.
   - This changes how sharp the game looks more than its speed: retina draws four times the pixels.
4. **The registry is in place before the session boots.**
   - Mach9.app writes `RetinaMode`, `LogPixels`, `ShowCrashDialog` and `EmulateModeset` into `user.reg` under the wineserver lock before a session starts. It boots the session again when the running one doesn't match (`M/launcher/app/src/session.rs:62-157`, `registry.rs:152-206`).
   - Bodega writes the last two with `reg add` into a running session at creation (`ENG/lib/engine.dart:246-285`).
   - Mach9 says the desktop computes its mode list when the session starts. So the first session after creation may switch the real display mode (guess; it lasts until that session ends).
5. **Rosetta-era settings reach Mach9 bottles.**
   - Fix steps are filtered by host, not by runtime (`ENG/lib/fixes.dart:49, 169-174`). Examples: VKD3D_*/DXVK_CONFIG for MSFS 2024, D3DM_* for Forza Horizon 6, the `AppDefaults` DLL overrides (csgo `d3d9=n,b`, RDR2 `vulkan-1=n,b`) and `WINE_SIMULATE_WRITECOPY` for Ubisoft Connect.
   - #24's configurations also carry these, but their backend is ignored on Mach9 (V8).
   - Bodega's own NFS13 reverb fix exists for Rosetta's slow x87, which FEX's reduced precision already makes fast on Mach9 (`M/compatdb/core/src/builtin.rs:177-181`).
   - Which of these help or hurt on Mach9 is not known per game.

## B. What compatdb offers that Bodega's writer can't send

Bodega writes `exe` (a basename or `*`), `dxgi`, `d3d9`, `metal_hud` and `dll_overrides` (`ENG/lib/runtimes.dart:214-308`). compatdb accepts 16 setting keys plus matchers (`M/compatdb/core/src/key.rs:90-199`).

**Matchers**
- `steam:<appid>`, and the fingerprints `company`, `product` and `original_filename`.

**Settings**
- `wined3d` (gl or vulkan);
- `opengl` (egl or cgl);
- `dpi_aware`;
- `large_address_aware`;
- `gcmouse`;
- `force_nx`;
- `vulkan_capture` and `metal_capture`;
- the lists `arguments`, `arguments_override` and `debug_channels`;
- `env`.

**What a game would gain from each, per program:**
- **`force_nx = false`:** the default keeps no-execute on in every 32-bit process. Launchers and configurators built with the ATL of Visual Studio 2003 then crash on their first window (`builtin.rs:215-236`).
- **`large_address_aware = true`:** a 32-bit game under FEX shares its 2 GB with Wine and the Direct3D layers. Only WoW has a built-in rule (`builtin.rs:473-494`).
- **`dpi_aware = false`:** for fixed-pixel interfaces (`builtin.rs:432-471`).
- **`opengl = cgl` and `wined3d = vulkan`:** renderer fallbacks. With EGL, a process gets no OpenGL at all when EGL fails (`builtin.rs:191-205`).
- **`env`, per process:** FEX settings for one game, such as full x87 precision (`FEX_X87REDUCEDPRECISION=`), TSO or AFP (`M/docs/internals.md:182-196`). Today a bottle or program variable reaches the whole process tree.
- **`steam:<appid>`:** matches a game Steam starts, whatever its exe is called, and beats a built-in program rule (`M/compatdb/core/src/lib.rs:253-262, 303-311`). The catalog and #24's configurations already know Steam app ids.
- **`WINE_COMPATDB_FILE`:** rules that change while Steam runs. A running Steam keeps its value otherwise (`lib.rs:174-194, 517-523`).

**Launcher responsibilities Bodega doesn't meet yet** (`M/compatdb/core/src/lib.rs:476-526`):
- refuse user variables that a setting replaces (`WINEDLLOVERRIDES`, `WINEDEBUG`, `WINE_CMDLINE_APPEND`, `WINE_MAC_OPENGL`, `WINE_FORCE_NX`); #22's MG6 lets `WINEDLLOVERRIDES` through;
- add the rules' `debug_channels` to `WINEDEBUG`;
- put `metal_hud` on the game, not on `exe=*`. D19 puts it on `exe=*`; the built-ins turn it off again for the CEF helpers.

**Built-in rules.** There are 19: 9 defaults for every process and 10 for one program each.
- The fold order is: built-in `*`, then the launcher's `*`, then built-in per program, then the launcher's per program (`lib.rs:290-317`).
- So Bodega's `exe=*` lines never undo a built-in program fix.
- Its `exe=<key>` exceptions, which carry no fingerprint and are sent on every launch, can (`runtimes.dart:279-287`). For example, a saved exception for one game's `launcher.exe` also matches Rockstar's `Launcher.exe` (guess; follows from the documented order).

**Engine defaults Bodega keeps.**
- msync is kept except for the catalog case in A1, and `none` takes effect only for a new session (`M/docs/internals.md:149-171`).
- TSO, AFP off, x87 reduced precision, the bundled Vulkan, GStreamer, vkd3d-proton, force_nx, egl, gcmouse, dpi_aware, Gecko off and native d3dx are all kept.
- Only a user's own variables can switch one off.

**Updates.**
- A newer Mach9 reaches existing prefixes on its own: the first process of a session reinstalls `wine.inf` when its date differs from `.update-timestamp` (`M/docs/maintenance.md:525-545`).
- `ditto` keeps the dates and Bodega writes no `.update-timestamp`, so #22's MR8 meets the checklist.
- The first launch after an update is slower, and Bodega says nothing about it.

## C. What #22 left for later

From `.sdd/mach9-runtime/proposal.md` §Out, D31, and the answers of 2026-11-23:
- **M3:**
  - copy an existing bottle to Native (an arm64 prefix can't be converted: a new Mach9 bottle with the programs moved);
  - the library tip;
  - the catalog's engine choice (with A1 fixed first);
  - a Check button on the engine card (the probe on Mach9 already works from the CLI, D28).
- **M4:** setup without Rosetta. Setup and the CLI still require it.
- **The Later list:**
  - `WINE_COMPATDB_FILE` and `steam:<appid>` rules (B);
  - `runtime use|remove` and keeping two Mach9 versions;
  - 0xAA64 in `exeGraphics`;
  - DLSS on Mach9;
  - a Launch Services launch for Game Mode (A2);
  - Gecko.
- **dxvk9 (Q2):** it has no recipe in `wine/` and no pin, only a copy placed by hand. A pin needs a build workflow and a release. It serves DirectX 9 games on the Rosetta engine, and #24's S7.
- **V6 (USER):** real games in a Mach9 bottle. It is still open, and it answers A2.

## D. Where #15 and #16 meet Mach9 bottles

- **.NET 4.8 against Wine Mono:**
  - `replacesMono` takes Wine Mono out before .NET installs (`ENG/lib/dependencies.dart:1426-1431`);
  - `monoMissing` then holds for that Mach9 bottle (`ENG/lib/mach9.dart:530-537`);
  - so the bottle shows "Install Wine Mono" while .NET 4.8 is installed.
- **What Wine lacks:** proposals read the DLLs of `runtimes/current`, Rosetta's Wine, even for a Mach9 bottle (`ENG/lib/dependencies.dart:1264-1267`). Mach9's own tree should be read. Its layout for x64 (ARM64X in `aarch64-windows`) needs checking.
- **Runtimes into an ARM64EC prefix:**
  - nothing has installed VC++, the DirectX extras, XACT, PhysX or .NET into a Mach9 bottle yet, so this is untested;
  - installs go through `_launchIn(backend: 'wine')`, which works on Mach9;
  - the status checks look in `system32`/`syswow64` (guess: they hold).
- **#24's configurations:**
  - their env, registry and DLL-override steps do apply on Mach9: the overrides become rules;
  - the backend is ignored (V8);
  - highball-db's `dxmt` and `wine` exist on Mach9 too and could be kept, mapped by runtime.
- **The report form:** it has no engine field (`.github/ISSUE_TEMPLATE/game-report.yml`), so a report from a Mach9 bottle looks like one from Rosetta.

## Constraints

From `.claude/CLAUDE.md`:
- Mach9's tree is never modified, re-signed or moved, and nothing is bundled.
- Agents run Wine only headless (wineboot, `msiexec /qn`, the probe), and games are the user's.
- No anti-cheat bypass.
- Only `data/` imports the engine.
- Everything in git is in English.

**Mach9's license (Zlib)** allows copying with its notice kept and altered versions marked. Bodega is Dart, so this is about porting logic and test vectors, such as compatdb's wire tests and the retina "auto" rule, not about copying Rust.

compatdb's writer is Rust only. Bodega's Dart writer must follow the format of the pinned version, and the "not checked" newer versions (D7) can drift.

## Open questions (for the proposal)

1. **Scope of this change.** My recommendation:
   - In:
     - A1 (msync on Mach9);
     - A3 and A4 (retina "auto" for Mach9 bottles, and the registry before the session boots);
     - A5 (steps filtered by runtime);
     - B's per-program keys (`force_nx`, `large_address_aware`, `dpi_aware`, `opengl`, `wined3d`, `env`) and `steam:<appid>`;
     - the launcher responsibilities;
     - all of D;
     - M3's catalog engine choice and engine-card Check.
   - Later, as their own changes:
     - copying a bottle to Native;
     - M4;
     - the dxvk9 pin;
     - `WINE_COMPATDB_FILE`;
     - two Mach9 versions.
2. **Game Mode (A2):** wait for V6. If Game Mode doesn't turn on, a Launch Services launch goes in. That is a bigger change to how Bodega starts and watches games.
3. **Retina "auto" for Mach9 bottles only, or for both engines?** Rosetta bottles keep their `highRes` switch today.
4. **Rosetta-era steps on Mach9:** drop them by kind (ROSETTA_*, D3DM_*, DXVK_*), or keep everything until a game's V6 shows otherwise?
