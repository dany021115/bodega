# Tasks · mach9-parity

**Conventions**
- `ENG` is `packages/engine/` and `APP` is `apps/bodega/`, in the worktree `../pr22`. Work starts after `../mach9-merge-commit.sh` has run, on `feat/mach9-parity` cut from `feat/mach9-runtime`. Until then it stays uncommitted on top of the merge.
- **Engine check:** `cd ENG && dart analyze && dart test`.
- **App check:** `cd APP && dart run build_runner build --delete-conflicting-outputs && flutter gen-l10n && flutter analyze && flutter test && tool/check_layers.sh`.
- Every task ends green and names its files.
- Wine runs headless only (wineboot, `msiexec /qn`, the probe). Agents never commit or push.
- Markers: `[ ]` to do, `[x]` done, `[~]` partly, `[-]` dropped.

## M1 · Engine

- [x] **T1** Settings: `retina` and `native` (PE2, PE7 storage, design §4).
  - **Files:** `ENG/lib/backends.dart` (`BottleSettings`, `_defaults`, `_with`, read, save, `setRetina`, `setHighRes` on Mach9), `ENG/lib/failures.dart` and `ENG/lib/english.dart` (`ChoiceKind.retina`), `ENG/test/runtimes_test.dart` or `backends_test.dart`.
  - **Check:** engine check. A Rosetta bottle's `settings.json` is the same byte for byte.
- [x] **T2** `mainDisplayHiDpi` (PE3, design §1).
  - **Files:** `ENG/lib/platform.dart`, `platform_mac.dart`, `platform_linux.dart`, `ENG/test/_mac.dart`.
  - **Check:** engine check; `dart run` of the FFI call on this Mac prints the same as design §1.
- [x] **T3** Retina before the session (PE4, design §2).
  - **Files:** `ENG/lib/engine.dart` (`_launchIn`'s Mach9 branch, header lines, a `_userReg` read), `ENG/test/mach9_test.dart`.
  - **Check:** engine check.
- [x] **T4** Creation ends its session (PE5).
  - **Files:** `ENG/lib/engine.dart` (`createBottle`), `ENG/test/mach9_test.dart`.
  - **Check:** engine check.
- [x] **T5** msync in catalog bottles (PE1).
  - **Files:** `ENG/lib/catalog.dart`, `ENG/test/mach9_test.dart`.
  - **Check:** engine check.
- [x] **T6** Rosetta-only steps (PE6, design §7).
  - **Files:** `ENG/lib/fixes.dart` (`FixStep`, `gamePlan`), `ENG/lib/engine.dart`, `ENG/test/fixes_test.dart`.
  - **Check:** engine check.
- [x] **T7** Rule lines: field order, the app's options and Steam's line (PE7, PE8, design §3).
  - **Files:** `ENG/lib/runtimes.dart` (`_compatdbLine`, `_mach9Rules`, `NativeOption`), `ENG/lib/apps.dart` (`openApp`, `setNativeOption`, `nativeOptions`), `ENG/test/compatdb_test.dart` (golden lines).
  - **Check:** engine check; every existing golden line stays the same.
- [x] **T8** Mono with .NET and what Wine lacks (PE9, PE10).
  - **Files:** `ENG/lib/mach9.dart`, `ENG/lib/dependencies.dart`, `ENG/test/mach9_test.dart`, `ENG/test/dependencies_test.dart`.
  - **Check:** engine check.
- [x] **T9** CLI (PE11).
  - **Files:** `ENG/lib/cli.dart`, `ENG/bin/bodega.dart`, `ENG/test/mach9_test.dart`.
  - **Check:** engine check; `tool/smoke_linux.sh`'s expected output unchanged.

**M1, 2026-11-23**
- **Check:** in `ENG`, `dart analyze` reports no issues, and `dart test` gives 477 passed, 5 skipped. `dart format` still leaves the four files #24's own tip leaves (`lib/backends.dart`, `lib/fixes.dart`, `test/backends_test.dart`, `test/fixes_test.dart`); every other file touched is formatted.
- **T2, real:** `MacPlatform().mainDisplayHiDpi()` run on this Mac prints `false`. Its main display's current mode is 2048 points and 2048 pixels.
- **T3:** the tests found a real bug in the first `user.reg` reader, which compared section names with single backslashes. Wine writes them doubled (`[Control Panel\\Desktop]`).
- **Existing tests changed, as requirements say:**
  - `runtimes_test` MB1 "mach9 survives every save": `setHighRes` on a Mach9 bottle now sets `retina: on` (PE2).
  - `mach9_test` MG11: the header has `# retina off (auto)` before `# rules`, which stays last.
  - `mach9_test` MG8: a Steam game's line is `exe=steam:9`, not `exe=steam.exe` (PE8).
- **Spec wording changed** (same behaviour, less code):
  - **PE3:** `mainDisplayHiDpi` is synchronous, because the FFI calls are.
  - **PE4:** the header's retina lines come before `# rules`, so MG11's "rules last" holds.
  - **PE7:** the options are saved in a bottle of either runtime, and only a Mach9 launch sends them, so `setNativeOption` throws only `AppNotFound`.
  - **PE7 and PE8:** `compatdbRules` gains `appKey`, so the golden tests reach the app's own line. `bodega rules` still takes a program only.

## M2 · App

- [x] **T10** Domain and data (PA1, PA2, PA3, PA4 and PA5, data side).
  - **Does:**
    - `RetinaMode` and `NativeOption`;
    - `BottleDetail.retina` and `LibraryApp.nativeOptions`;
    - repository methods `setRetina` and `setNativeOption`;
    - `InstallEvent.start(runtime)`;
    - `readyBottles(runtime)`;
    - `reportUrl`'s `engine`.
  - **Files:** `APP/lib/domain/**`, `APP/lib/data/repository/{bottle,library,install,backend,game}_repository_impl.dart`, `APP/lib/data/service/code_mapper.dart`, and the matching `APP/test/data/*` tests.
  - **Check:** app check.
- [x] **T11** Blocs (PA1–PA4).
  - **Does:** `BottleDetailBloc.setRetina`, `LibraryBloc.setNativeOption`, the catalog install's runtime and `BackendsBloc.checkEngine`.
  - **Files:** `APP/lib/app/bloc/{bottle_detail,library,install,catalog,backends}/*` and their tests.
  - **Check:** app check.
- [x] **T12** Screens and text (PA1–PA4, PA6).
  - **Does:**
    - the Retina dropdown;
    - the menu item and the Native engine options dialog, which is new (`APP/lib/app/presentation/library/widgets/native_options_dialog.dart`);
    - the item in the bottle's Games section;
    - the catalog's Engine dropdown;
    - the engine card's Check;
    - the ARBs and `app/shared/text/*`.
  - **Check:** app check; `text_test.dart` covers each enum in `en` and `es`.
- [x] **T13** Fit (PA7).
  - **Files:** `APP/test/app/pages_test.dart`.
  - **Check:** app check.
- [x] **T14** The report form (PA5).
  - **Files:** `.github/ISSUE_TEMPLATE/game-report.yml`, and its test in `APP/test/data/game_repository_test.dart`.
  - **Check:** app check.

**M2, 2026-11-23**
- **Checks:**
  - in `APP`: `build_runner` and `gen-l10n` run, `flutter analyze` reports no issues, `flutter test` gives 1000 passed, and `tool/check_layers.sh` says `Layers OK`;
  - in `ENG`: `dart analyze` reports no issues, and `dart test` gives 477 passed, 5 skipped;
  - `python3 tool/test_import_fixes.py` prints `import_fixes: ok`.
- **New cases:**
  - **data:**
    - `bottle_repository_test`: PA1's retina mode, kept and read back, and PA2's options reaching the library entry;
    - `backend_repository_test`: PA4's `readyBottles(runtime: mach9)`;
    - `game_repository_test`: PA5's `engine` in the URL and in the form.
  - **blocs:** setRetina, setNativeOption, `checkEngine` (three probes, results keyed `mach9:<name>`), `nativeBottles`, the catalog's `nativeUsable`, and the install's `runtime`.
  - **`pages_test`:**
    - fit at 720, 801, 1150 and 1921 px, in `en` and `es`: the Native options dialog, the catalog detail with its engine, and the engine card checked in a bottle;
    - the native bottle shows the retina dropdown and no switch;
    - interaction: PA1 (Off sends `setRetina`), PA2 (the menu item and a switch send `setNativeOption`, and a Rosetta app has no item), PA3 (Rosetta reaches `InstallEvent.start`), PA4 (Check sends `checkEngine`).
  - **`text_test`:** every `RetinaMode` and `NativeOption` worded in both languages, with the Spanish different.
- **Existing tests changed:**
  - `backends_bloc_test`: a load also reads the ready Native bottles;
  - `install_bloc_test`: the install takes `runtime`;
  - `catalog_bloc_test`: the bloc takes the backends repository;
  - `game_repository_test`: the URL carries `engine`.
- **Spec wording changed** (same intent, less code):
  - **PA2:** the "Native engine options…" item is in the app menu that the library and the bottle's page share, where the HUD switch also lives. It is not in #24's Games section, which has no per-app menu. The dialog keeps what was switched, and a failed save shows as the library's error.
  - **PA1:** the auto option reads "Follow the display" / "Según la pantalla", so the panel never shows two "Automatic"s (L12).
  - **PE4:** `winecfg` is also one of Bodega's own runs, so `winecfg -v` never waits for the retina values.
- **Known limit:**
  - A catalog app whose Rosetta backend is not installed still shows "Install <backend>" before its install options. That holds even when the Native engine, which doesn't need that backend, is installed.
  - Lifting this goes with the next catalog change.

## M2b · Moving a bottle to Native (added in apply, PE12, PA8)

- [x] **T19** Engine: `moveToNative`, `NativeMoveStep`, the merge, `native-move` (PE12).
  - **Files:** `ENG/lib/mach9.dart`, `ENG/lib/cli.dart`, `ENG/test/mach9_test.dart`.
  - **Check:** engine check.
- [x] **T20** App: `BottleDetail.nativeInstalled`, `BottleRepository.moveToNative`, the bloc's event and step, the button, the confirmation, the progress and the toast, and the text (PA8).
  - **Check:** app check.
  - **2026-11-23:**
    - **Engine:** `dart analyze` reports no issues, and `dart test` gives 482 passed, 5 skipped. The new `mach9_test` group "PE12" covers:
      - the move: files, `apps.json`, settings mapped, and the old folder gone;
      - a link of the new prefix that is never written through;
      - a failed copy that leaves the old bottle byte for byte;
      - the refusals;
      - `native-move`'s output.
    - **App:** `build_runner`, `gen-l10n` and `flutter analyze` report no issues, `flutter test` gives 1000 + 20 = 1020 passed, and `Layers OK`. The new cases cover:
      - the data move against the fake Mach9 runtime;
      - the bloc's steps, count, `reinstall` and failure;
      - in `pages_test`, the button, the confirmation sending the event, and the panel with the button and mid-move at the four widths in `en` and `es`;
      - `text_test` for the steps.
    - **The user's real bottle:** "Games" has Blur, Plutonium, LanLauncher and NFS13 outside the prefix (`~/Documents/Games`), Steam inside it, and the Windows user `ElChupaCabra3mil`. The move is the user's to run from the app (T21). The agent does not move or delete it.
- [~] **T21** **(USER)** Moving "Games" to Native from the app, then playing its games (PC3).
  - **2026-11-23**, from the user's runs and HUD screenshots, on an M2 Pro with macOS 27.0 and the display at 2048×1330, 1.0x, 120 Hz:
    - **The move:** "Games" was moved from the app. It is now `"runtime": "mach9"` with `"sync": "msync"`, its programs and `"user": "ElChupaCabra3mil"` kept, and its HUD kept for `plutonium.exe` and `blur.exe`.
    - **MW3 (Plutonium) runs:** `plutonium-bootstrapper-win32.exe [i386]` gets `d3d9 = mtld3d` and `metal_hud = true, WINE_COMPATDB line 1`, and the HUD shows mtld3d v0.15.5, presentation Direct, and **Game Mode On**.
    - **First run, 62.6 FPS steady:**
      - The GPU took 3.8 ms a frame, and the frame interval held at 15.97 ms.
      - The game's own `config_mp.cfg`, carried over from the Rosetta bottle, held `seta com_maxfps "60"`. IW5 rounds a frame to whole milliseconds, so 60 gives 62.5 FPS.
      - The user turned vsync off and the refresh rate up to 120 Hz in the game.
      - The agent, at the user's word ("hazlo tu") and with the game closed, changed that one line to `"125"`, after a copy to `config_mp.cfg.before-maxfps-125`.
    - **Second run, 126.06 FPS steady:**
      - the GPU takes 4.10 ms a frame, and the frame interval holds at 7.93 ms;
      - Game Mode is on, and the thermals are Nominal.
    - **Against the other engines:** Mach9.app gave 100–120 FPS (the user), and the Rosetta engine gave about 23 FPS (#22's measure).
    - **Proposal Open question 2 (A2) answered:** a game started by Bodega gets Game Mode, because `wine.app` carries the keys (`M/bin/bundle-wine.sh`). A Launch Services launch is not needed.
    - **Still to report:** the Dock's name, Blur, NFS13, Steam, and whether the move asked to install any runtime again.

## M3 · Checks and delivery

- [x] **T15** Suites (PC1). See `verify.md` (2026-11-23): engine 482 passed, 5 skipped; app 1020 passed; `Layers OK`; `import_fixes: ok`. The output goes in `verify.md`.
- [x] **T16** Real and headless (PC2), once Mach9 is installed in a temporary `BODEGA_HOME`:
  - from `/Applications/Mach9.app` if the user puts 0.4.0 there;
  - otherwise from one `Mach9.dmg` download of 283 MB, which the agent asks about first.

  PC2.3's library-app probe runs only with the user's agreement. The outputs go in `verify.md`.
  - **2026-11-23**, by the user's word ("bajala y corre"), in a temporary `BODEGA_HOME` with the CLI compiled from this tree:
    - **The downloads:** `Mach9.dmg` v0.4.0 (200,499,232 bytes, sha256 `3b5dd83e…e6d9`) and `wine-mono-11.3.0-x86.msi` (83,348,992 bytes, `df2dfc16…18d3`), both equal to the pins. They are kept in `~/Downloads` for the user's own install.
    - **Install and bottle:**
      - `runtime install mach9 <dmg> --mono <msi>` takes 8.9 s;
      - `create --runtime mach9 pc2` takes 34 s, and leaves `mono-2.0` in place and `"sync": "msync"`.
    - **PC2.2:**
      - `option pc2 retina on`, then `backend test pc2 mtld3d`, gives `OK D3D9 32 bits` and `OK D3D9 64 bits`;
      - two `retina` `reg` runs come before the first probe, and none before the second;
      - `user.reg` holds `"RetinaMode"="y"` and `"LogPixels"=dword:000000c0` (it held `00000060` before);
      - the header has `# retina on (on)` before `# rules …`.
    - **PC2.3a:** the probe's own `probe-32.exe` is added as a library app and opened, with all five options on (exit 0). Its compatdb block (`probe-32.exe [i386]`) shows all of these from `WINE_COMPATDB line 2`:
      - `wined3d = vulkan`;
      - `dpi_aware = false`;
      - `large_address_aware = true`;
      - `force_nx = false … (same as unset: Wine's behaviour)`;
      - `opengl = cgl`;
      - `env WINE_D3D_CONFIG=renderer=vulkan … set`.
    - **PC2.3b:** a Steam app 220, whose `steam.exe` is a copy of the probe, is opened with `SteamAppId=220` and the HUD (exit 0). Its block:
      - shows `SteamAppId = 220`, `metal_hud = true, WINE_COMPATDB line 2` and `opengl = cgl, WINE_COMPATDB line 2`;
      - has the built-in `arguments = -noassert (built-in for steam:220, appended)`, which shows the id matches.
    - **Warnings:** `grep -c 'warning:'` over every log gives 0.
    - **PC2.4:** `monoMissing` gives false with Mono; false without Mono and with `clr.dll`; true without either; false with Mono back.
    - **Seen in passing:** `wined3d = vulkan` sets `WINE_D3D_CONFIG` in that process, so the `explorer.exe` it starts inherits it ("from the inherited WINE_D3D_CONFIG"). That is Mach9's own behaviour for the option.
    - **Cleanup:** the bottle was stopped and waited on (exit 0), and the 2 GB temporary home was deleted. The three logs are kept in the scratchpad.
- [~] **T17** **(USER)** PC3, with the debug app built from this tree.
- [~] **T18** Delivery (PC4):
  - a script beside the repo that cuts `feat/mach9-parity` and makes one commit per milestone, with no attribution and `tool/version.sh check` before each one;
  - the `.claude/rules/architecture.md` line on `retina` and the native options;
  - this change's `.sdd/` folder.

  The agent leaves the script unrun.
