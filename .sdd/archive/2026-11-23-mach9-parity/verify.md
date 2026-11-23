# Verify · mach9-parity

Date: 2026-11-23. Tree: the worktree `../pr22`, holding the staged merge of #22 with #24 and this change unstaged on top. Machine: M2 Pro, macOS 27.0.

## Checks (PC1), run for this report

`packages/engine`:

```
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed lib test bin
Changed lib/backends.dart
Changed lib/fixes.dart
Changed test/backends_test.dart
Changed test/fixes_test.dart
Formatted 39 files (4 changed) in 0.26 seconds.
$ dart test
01:11 +482 ~5: All tests passed!
```

The four files `dart format` would change are the same four #24's own tip leaves unformatted. Every file this change added or touched elsewhere is formatted. CI runs no format check.

`apps/bodega`:

```
$ dart run build_runner build --delete-conflicting-outputs
  Built with build_runner/aot in 1s; wrote 0 outputs.
$ flutter gen-l10n
$ flutter analyze
No issues found! (ran in 2.2s)
$ flutter test
00:32 +1020: All tests passed!
$ tool/check_layers.sh
Layers OK
```

Repo root:

```
$ python3 tool/test_import_fixes.py
import_fixes: ok
$ tool/version.sh check
OK: version 1.7.0 (tag v1.6.0).
```

## Requirements

| Req | Result | Evidence |
|---|---|---|
| PE1 msync in new catalog bottles on Mach9 | Met | `mach9_test`, MB9 "a new Mach9 bottle gets Mono between creation and installer" (`sync` is `msync`, `syncEnv` empty) and "PE1 a new Rosetta bottle still takes the entry's sync" (`none`) |
| PE2 the retina setting | Met | `runtimes_test`, "PE2 the retina setting" (three tests); MB1 "mach9 survives every save" (`setHighRes` on Mach9 → `retina: on`) |
| PE3 main display density | Met | `mach9_test`, PE4 "auto follows the display: on with a HiDPI main display". Real: `MacPlatform().mainDisplayHiDpi()` printed `false` on this Mac (2048 points, 2048 pixels; tasks T2) |
| PE4 retina values before the session boots | Met | `mach9_test`, "PE4 retina before the session boots" (five tests: written then `-k`/`-w`, nothing when matching, auto, a running session waits, Rosetta untouched). Real (T16): `user.reg` went from `"LogPixels"=dword:00000060` to `"RetinaMode"="y"`, `"LogPixels"=dword:000000c0`; two `retina` `reg` runs before the first probe, none before the second; header `# retina on (on)` |
| PE5 creation ends its session | Met | `mach9_test`, MB5 "settings first, registry values, then Mono": a `wineserver -w` comes between the last `wine reg` and `wine msiexec`, and the last call is `wineserver -w` |
| PE6 Rosetta-only steps left out | Met | `mach9_test`, "PE6 Rosetta-only variables stay out, and the log names them" (env, `# skipped D3DM_ENABLE_METALFX, DXVK_ASYNC`, `gamePlan`); `fixes_test`, "PE6 a Rosetta bottle keeps every variable" |
| PE7 native options per app | Met | `compatdb_test`, "PE7 and PE8 the app's own line" (golden lines in `Key::ALL` order, joined with an exception, `setNativeOption` sorted and removed, a Rosetta bottle sends no rules); `runtimes_test`, "PE7 the native options in settings.json". Real (T16): `probe-32.exe [i386]` logged `wined3d = vulkan`, `dpi_aware = false`, `large_address_aware = true`, `force_nx = false`, `opengl = cgl`, each from `WINE_COMPATDB line 2`, with no `warning:` |
| PE8 a Steam game's own line | Met | `compatdb_test`, "a Steam game gets steam:<id>, with the HUD there"; `mach9_test` MG8 (`exe=steam:9;dxgi=dxmt`). Real (T16): `steam.exe [i386]` logged `SteamAppId = 220`, `metal_hud = true, WINE_COMPATDB line 2`, `opengl = cgl, WINE_COMPATDB line 2`, and the built-in `-noassert` for steam:220 |
| PE9 Mono with .NET | Met | `runtimes_test`, "PE9 .NET Framework 4 in the prefix is no missing Mono". Real (T16): false with Mono; false without it and with `clr.dll`; true without either |
| PE10 what Wine lacks, from the bottle's Wine | Met | `dependencies_test`, "PE10 a Mach9 bottle reads Mach9's own Wine, ARM64X for x64" (recommended, then optional once `aarch64-windows/mfc140.dll` exists) |
| PE11 CLI | Met | `mach9_test`, "PE11 option retina and native" (exit 0 and 64, outputs) and "the usage lists every new verb" |
| PE12 moving a bottle to Native | Met | `mach9_test`, "PE12 moving a bottle to Native" (five tests: the move with files, `apps.json` and mapped settings, the old folder gone; a link of the new prefix never written through; a failed copy leaving the old bottle byte for byte; the refusals; `native-move`'s output). Real (T21): the user moved "Games" from the app; it is `"runtime": "mach9"` with its programs, its HUD and its Windows user |
| PA1 retina in a Mach9 bottle's Settings | Met | `pages_test`, "PA1 a Native bottle sets its retina mode" and the native bottle's fit case (dropdown there, switch absent); `bottle_detail_bloc_test` (setRetina); `bottle_repository_test`, "PA1 the retina mode is kept and read back" |
| PA2 native options per app | Met, wording changed (tasks M2) | `pages_test`, "PA2 a Native app has its options in the menu" and "PA2 a Rosetta app has no such item"; `library_bloc_test`, "PA2 a native option is saved and the library reloads"; `bottle_repository_test`, "PA2 an app's native options reach its library entry" |
| PA3 the catalog's engine | Met | `pages_test`, "PA3 a bottle of its own can take the Rosetta engine"; `catalog_bloc_test`, "PA3 knows when the Native engine can take a bottle of its own"; `install_bloc_test`, "PA3 the engine of a bottle of its own reaches the install" |
| PA4 Check on the engine card | Met | `pages_test`, "PA4 the engine card checks a Native bottle" and the "installed, checked" and "installed" fit cases; `backends_bloc_test`, "PA4 the engine check probes mtld3d, dxmt and wine in turn" and "PA4 the ready Native engine bottles load apart"; `backend_repository_test`, "PA4 readyBottles of the Native engine gives its own" |
| PA5 the engine in a game report | Met | `game_repository_test`, "the report form is prefilled, encoded" (`engine: Rosetta`, and `engine=Native+%28Mach9%29`) and "the issue form has the fields the URL fills" (`id: engine`) |
| PA6 text | Met | `l10n_parity_test` (in the 1020); `text_test`, "PA6 each retina mode and native option has words, in both" (also the move's steps) |
| PA7 fit | Met | `pages_test` at 720, 801, 1150 and 1921 px, in `en` and `es`: the native bottle, the options dialog, the catalog detail with its engine, the engine card checked, and the bottle that can move and that is moving |
| PA8 "Move to the Native engine…" | Met | `pages_test`, "PA8 confirming the move asks the bottle" and the two fit cases; `bottle_detail_bloc_test`, "PA8 a move shows its steps, counts once and reloads" and "PA8 a failed move says why and counts nothing"; `bottle_repository_test`, "PA8 a Rosetta bottle moves to the Native engine" |
| PC1 suites | Met | Above |
| PC2 real, headless | Met (PC2.1 by design) | tasks T16: Mach9 installed from the pinned DMG and MSI (both hashes equal to the pins); PC2.2, 2.3a, 2.3b and 2.4 as above; `grep -c 'warning:'` over every log gave 0; the 2 GB temporary home was removed |
| PC3 USER | Partly | Done (tasks T21): the move of "Games", and MW3 through Plutonium on the Native engine with the HUD, Game Mode On and 126 FPS against Rosetta's ~23. Not reported yet: the Dock's name; Blur, NFS13 and Steam after the move; whether the move asked to install a runtime again; Retina on a HiDPI display (this Mac's display is 1.0x now); the report form with Engine filled |
| PC4 delivery | Ready, not run | `../mach9-parity-commit.sh`, after `../mach9-merge-commit.sh`; `bash -n` passes; no attribution lines |

## Found while checking
- **MW3's frame cap was the game's own.** At 62.6 FPS the HUD showed a GPU time of 3.8 ms a frame. The prefix's `config_mp.cfg`, carried from the Rosetta bottle, held `com_maxfps "60"`, and IW5 rounds a frame to whole milliseconds (60 → 16 ms → 62.5 FPS). At the user's word it is now `"120"`, which IW5 runs as 8 ms, about 125 FPS. The original is at `config_mp.cfg.before-maxfps-125`.
- **Proposal Open question 2 is answered.** A game Bodega starts gets Game Mode (HUD: "Game Mode On"), so a Launch Services launch is not needed.

## Known limits (in tasks M2)
- **The catalog's backend gate:** a catalog app whose Rosetta backend is missing still asks for it before its install options, even when the Native engine is installed.
- **`bodega rules`** takes a program, not an app key, so it doesn't print an app's native options. The golden tests and the real run cover them.

## Verdict
Every requirement the agent can check is met, with the outputs above. PC3 is partly done, with the items listed still to report. PC4 waits for the user to run the two scripts.
