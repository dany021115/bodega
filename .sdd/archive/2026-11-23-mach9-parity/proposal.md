# Proposal · mach9-parity

Input: `exploration.md` and the user's answers of 2026-11-23, which approved the recommended scope and Open questions 2–4.

## Why
A game in a Bodega bottle on the Native engine (Mach9) should run as it does in Mach9.app. Bodega already gets Mach9's engine defaults and its 19 built-in rules. Four things set it apart:
- **Catalog bottles:** they turn msync off.
- **Retina:** the display's retina mode is never set.
- **Rosetta settings:** some Rosetta-only settings still reach Mach9 bottles.
- **Per-game rules:** Bodega can't send the compatdb settings that rescue single games, and can't target a game that Steam starts.

The work from #15 and #16 also meets Mach9 bottles in three places that need fixing:
- installing .NET flags Wine Mono as missing;
- proposals read the Rosetta Wine;
- the report form has no engine field.

#22 left the catalog's engine choice and the engine card's Check for this change (Q4).

## What
**In**
1. **msync in catalog bottles:** a new Mach9 bottle from the catalog keeps msync. The catalog entries' `"sync": "none"` is for Rosetta's Wine.
2. **Retina for Mach9 bottles:**
   - modes `auto` (the default), `on` and `off`;
   - `auto` follows the main display's density, as Mach9.app does;
   - the values are put in place before a session boots.
3. **A clean first session:** creating a bottle ends the session it booted, so the first launch reads the values written at creation.
4. **Rosetta-only steps:** a game fix's `ROSETTA_*`, `D3DM_*`, `DXVK_*`, `MVK_*` and `MTL_HUD_*` variables are not applied in Mach9 bottles. What's left out is named in the log.
5. **Native engine options per app**, sent as compatdb settings on that app's own rule:
   - no forced NX: `force_nx=false`;
   - 4 GB of memory: `large_address_aware=true`;
   - ignore Windows scaling: `dpi_aware=false`;
   - macOS OpenGL: `opengl=cgl`;
   - wined3d on Vulkan: `wined3d=vulkan`.
6. **Steam games' own rule:** on Mach9, a Steam game's launch-specific choices go on `exe=steam:<appid>`, not on `steam.exe`. These are its graphics option or exception, its HUD and the options of item 5.
7. **.NET and Mono:** a Mach9 bottle with .NET Framework 4 doesn't count as missing Wine Mono.
8. **What Wine lacks:** dependency proposals read the bottle's own Wine, Rosetta's or Mach9's.
9. **The report form gains the engine:** Rosetta or Native (Mach9), prefilled from the bottle.
10. **The catalog's engine choice:** for a new bottle, Native by default once Mach9 is installed and allowed, as D26 does for new bottles.
11. **Check on the engine card:** the probe for mtld3d, DXMT and wine in a ready Mach9 bottle.
12. **CLI:**
    - `bodega option <bottle> retina auto|on|off`;
    - `bodega native <bottle> <key> [<option> on|off]`.
13. **App:**
    - a Retina dropdown in Mach9 bottles' Settings;
    - "Native engine options…" in the menu of each app of a Mach9 bottle;
    - the catalog's Engine dropdown;
    - Check on the engine card;
    - all texts in English and Spanish.

14. **Moving a bottle to Native** (added in apply, by the user's word of 2026-11-23: "quiero poder cambiar el motor en una que ya tenga … con la vieja de respaldo y cuando la pases borra la botella vieja"):
    - A Rosetta bottle becomes a Native one under the same name: a new Mach9 bottle gets its programs, its Windows user's files, its library and its settings.
    - The old bottle stays untouched until the new one is complete, so a failure leaves it as it was. Once the move succeeds, the old one is deleted, after the app's confirmation.

**Out (each its own change later)**
- setup without Rosetta (M4);
- a pin and a build for dxvk9;
- `WINE_COMPATDB_FILE`;
- two Mach9 versions side by side;
- per-program `env` rules and fingerprints;
- a Launch Services launch for Game Mode, decided after #22's V6;
- changing #24's configurations on Mach9: their backend stays ignored there (V8).

## Decisions
| # | Question | Decision | Reason |
|---|---|---|---|
| P1 | Catalog sync on Mach9 | `installEntry` saves `entry.sync` only into a new Rosetta bottle. A new Mach9 bottle keeps the host default (`msync`), and an existing bottle keeps its own, as today. | Mach9.app runs Windows Steam with `WINEMSYNC=1`, and Mach9 documents msync as its default. The Steam hang that made the catalog say `none` is Rosetta's. |
| P2 | Retina setting | A new setting `retina` (`auto`, `on`, `off`), written to `settings.json` only for a Mach9 bottle and only when not `auto`. Rosetta bottles keep `highRes`. On a Mach9 bottle, `setHighRes(v)` is `setRetina(v ? on : off)`. | It mirrors Mach9.app's `retina_mode` and keeps Rosetta bottles byte for byte the same. |
| P3 | Display density | `HostPlatform.mainDisplayHiDpi()`. On the Mac it uses CoreGraphics through `dart:ffi`: the main display's current mode has more pixels than points. Linux gives false. | It is Mach9.app's own rule (`retina.rs`). FFI is part of the Dart SDK and costs about 0.2 s. On this Mac today: 2048 points and 2048 pixels, so `off`. |
| P4 | When the values are written | Before a Mach9 launch of a program, the wanted `RetinaMode` and `LogPixels` (192 or 96) are compared with `prefix/user.reg`. If they differ and the bottle has no wineserver, Bodega writes them with `reg add`, ends that session (`-k`, then `-w`) and launches. If a session runs, it launches as is, and the log says the values wait for the next session. | Wine reads them when a session boots (Mach9's `registry.rs`, `session.rs`). Stopping a running session would stop a running game. A match costs nothing but a file read. |
| P5 | Rosetta-only steps | On Mach9, `env` steps whose name starts with `ROSETTA_`, `D3DM_`, `DXVK_`, `MVK_` or `MTL_HUD_` are left out. The `# skipped` header line names them, and `gamePlan` omits them. The other steps, registry values and DLL overrides stay. | The user's answer to Open question 4: only what is clearly Rosetta's, D3DMetal's or DXVK's. Mach9 has none of them, and `metal_hud` replaces `MTL_HUD_*`. |
| P6 | Where per-app options live | `settings.json` gains `native`: app key → the list of options that are on, saved only when not empty. This is #24's pattern for `configOff` and `verdicts`. | `programs` is keyed by exe name, so every Steam game would share `steam.exe`'s entry. |
| P7 | The options and their fields | `noForceNx` → `force_nx=false`, `largeAddressAware` → `large_address_aware=true`, `notDpiAware` → `dpi_aware=false`, `cglOpenGl` → `opengl=cgl`, `vulkanWined3d` → `wined3d=vulkan`. Each is on or off; off sends nothing. | Each is the documented fix for one kind of failure (`builtin.rs`). The defaults stay Mach9's. |
| P8 | The app's rule | `openApp` on Mach9 adds one line, `exe=<target>`, with the options in compatdb's `Key::ALL` field order. `<target>` is `steam:<appid>` for a Steam app, otherwise the program's exe key. | compatdb folds a program rule after the `*` rules and after the built-in program rules (`lib.rs:290-317`), so the app's own options win. |
| P9 | Steam games | When the launched app is a Steam app: the `exe=steam.exe` line D17 writes for an option or exception becomes `exe=steam:<appid>`, and the HUD goes on that line instead of `exe=*`. The `exe=*` line keeps the graphics fields. | Responsibilities in `lib.rs:499-503`: put `metal_hud` on the game, not the store client. Steam itself stays on Mach9's defaults and built-in rules. |
| P10 | Mono with .NET | `monoMissing` is false when `windows/Microsoft.NET/Framework/v4.0.30319/clr.dll` exists, which is dotnet48's own marker. | #23's .NET recipe takes Mono out on purpose (S3). |
| P11 | What Wine lacks | `appNeeds` reads `<runtime>/engine/lib/wine/<dir>` of the bottle's runtime. `<dir>` is `x86_64-windows` or `i386-windows` on Rosetta, and `aarch64-windows` or `i386-windows` on Mach9, where x64 programs load ARM64X modules (`M/docs/building.md` bundle layout). | The architecture rules say to resolve a bottle's Wine with `runtimeDir(home, bottleRuntime(...))`, never with `currentRuntime` alone. |
| P12 | Report engine | `game-report.yml` gains a dropdown `engine` (`Rosetta`, `Native (Mach9)`), and `reportUrl` fills it from the bottle's runtime. | Reports from the two engines must not mix. |
| P13 | Catalog engine | The detail page's target "a bottle of its own" gets an Engine dropdown when Mach9 is installed and allowed: Native by default, or Rosetta. Installs into an existing bottle keep its runtime, as today. | Q1's default for new bottles also holds for catalog bottles, now that P1 keeps msync. |
| P14 | Engine Check | The engine card's Check picks a ready Mach9 bottle and runs `backendTest` for `mtld3d`, `dxmt` and `wine`, in the dialog the backend cards use. | D28: the probe already works in Mach9 bottles from the CLI. |
| P15 | Version | It stays 1.7.0+15: no tag `v1.7.0` exists yet, and `tool/version.sh check` passes. | One minor version covers every unreleased feature. |
| P17 | What a move carries | `drive_c` minus `windows/` (each entry the new prefix lacks is copied whole; a folder both have is merged the same way; a file or link the new prefix has stays as it is, and a link there is never written through), `apps.json` and `icons/`, and the settings: backend and exceptions kept where Mach9 has the name, else `auto`; HUD, variables, Windows version, Windows user, verdicts and configurations kept; `highRes` on becomes `retina: on`; sync, `avx`, `dlss`, `dxvkAsync` and `gamepads` go back to defaults. Not carried: the registry of the old prefix and its installed runtimes; the move returns the runtimes it had, for the user to install again. | The Windows inside a prefix is built for one architecture (D1, D2), so only what the user and their programs wrote can move. A prefix's `users/<user>/Documents` and the like are links to the Mac's own folders: writing through them would change the user's files. |
| P18 | Order and safety | The old bottle must be stopped. A new Mach9 bottle is made under a free temporary name, filled, and only then is the old one deleted and the new one renamed to the old name. Any failure before that removes the temporary bottle and leaves the old one as it was. | The user's "with the old one as backup". |
| P19 | Copying | `HostPlatform.copyTree`, which is `ditto` on the Mac: links stay links, nothing is followed, and APFS clones the files, so Steam's games take no extra space. | It is what #22 already uses for Mach9's own tree. |
| P16 | Branch | `feat/mach9-parity`, from `feat/mach9-runtime` once `../mach9-merge-commit.sh` has run, with its pull request against that branch. | It is stacked like #20 → #21 → #23 → #24 → #22. |

## Impact
- **Engine:**
  - `catalog.dart` (P1);
  - `backends.dart` (`retina`, `native` and `setRetina` in `BottleSettings`);
  - `platform*.dart` (`mainDisplayHiDpi`);
  - `engine.dart` (`_launchIn`'s Mach9 branch, `createBottle`);
  - `runtimes.dart` (rule fields and lines);
  - `apps.dart` (`openApp`);
  - `fixes.dart` (`gamePlan`, skipped steps);
  - `mach9.dart` (`monoMissing`);
  - `dependencies.dart` (`appNeeds`);
  - `cli.dart` and `bin/bodega.dart`;
  - tests.
- **App:**
  - domain: `BottleDetail.retina`, the native options, and the engine in `AppGame` or the report;
  - repositories;
  - blocs: bottle detail, library, the catalog install, backends;
  - screens: Settings, the library menu and its dialog, the catalog detail, the engine card;
  - the ARBs and `pages_test`.
- **Other:** `.github/ISSUE_TEMPLATE/game-report.yml`.
- **Data:** a Mach9 bottle's `settings.json` may gain `retina` and `native`. A Rosetta bottle's stays byte for byte the same.

## Risks
| Risk | Mitigation |
|---|---|
| A launch on a Retina display now draws 4× the pixels | The Retina dropdown's `off`; `auto` behaves as Mach9.app does. |
| Steam was set to `none` for a reason on Rosetta, and might hang on Mach9 too | A USER check: Steam from the catalog in a Native bottle. Its Settings keep the msync switch. |
| `steam:<appid>` needs `SteamAppId` in the game's environment, which Steam sets | A headless probe with `SteamAppId` set, plus a USER check with a Steam game. |
| The Dart writer drifts from compatdb's format | Golden lines in the order of `Key::ALL`, and the headless check that `compatdb:` logs each field with no `warning:`. |
| A `reg add` before a launch costs a Wine start | Only when the values change, such as after switching displays. |
