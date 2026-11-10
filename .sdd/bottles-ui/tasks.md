# Tasks: bottles-ui

**Conventions.** `P` = `packages/engine`; `A` = `apps/bodega`. **(USER)**: you do it. The agent does not commit or push. After each milestone: `dart run build_runner build`, `flutter analyze`, `flutter test` and `tool/check_layers.sh` in `A`, and `dart analyze` and `dart test` in `P`.

## Milestone 1: multiple applications and main screen
- [x] **T1** `apps.json` and migration (M1), key (M2), `addApp`, `hideApp`, `openApp` and `listBottles` (M6), with the CLI.
  **Check:** tests for M1, M2 and M6. On a copy of `steam` in a temporary `BODEGA_HOME`, `bodega apps` and `open` give the same as before.
- [x] **T2** `readLnk` (M3), detection (M4), Steam games (M5) and icons (M7).
  **Check:** their tests, and a temporary test against your `steam` and your `Blur.exe`: Steam, Muck and icons.
- [x] **T3** Domain, data and `LibraryBloc`: applications per bottle, open by key (V5, V6), with the catalog and the add flow adapted (V7).
  **Check:** tests for `LibraryBloc`, `CatalogRepository` and `AddAppBloc`.
- [x] **T4** `SideBar` with bottles (V1) and routes (V2). 1150×800 window.
  **Check:** tests for `SideBar` and `router`.
- [x] **T5** Bottle screen (V3), `AppTile` and `AppIcon` (V4), logs in a dialog. Library (V5).
  **Check:** widget tests and `pages_test.dart` at the 4 widths.
- [x] **T6 (USER)** Commit milestone 1 with the script the agent leaves, and `flutter run -d macos`. **Expected:** `steam` with Steam and Muck and their icons; `games` with its application; Library with the applications of all bottles. **Test U1 to U4.**

## Milestone 2: settings and options
- [x] **T7** Settings (M8), high resolution (M9), Windows version (M10), launch with options (M11) and install into an existing bottle (M12).
  **Check:** their tests; and on a real temporary bottle, headless, `winecfg -v` answers with what was set and `reg query` returns `RetinaMode` and `LogPixels`.
- [x] **T8** Actions (V8), advanced settings (V9) and control panels (V10).
  **Check:** tests for `BottleDetailBloc` and widget tests; `pages_test.dart`.
- [x] **T9** Run with options (V11) and install with options (V12).
  **Check:** tests for `RunOptionsBloc` and `InstallBloc`; `pages_test.dart`.
- [ ] **T10 (USER)** Commit milestone 2, and **test U5 to U8.**

## Milestone 3: management
- [x] **T11** Duplicate and rename (M13), export and import (M14), cache (M15).
  **Check (done on CachyOS):** `duplicateBottle`, `exportBottle`/`importBottle` and `downloads` tests in `apps_test.dart`; full `dart test`: 156 pass. CLI: `bodega duplicate`, `export`, `import`, `downloads [clear]`. Real, headless, in a temporary `BODEGA_HOME` with the bundled Wine 11.21: `cmd /c echo` runs in the original, the copy, the renamed copy and two imports (`t11c-2`, `t11c-3`), and in every one `z:` is still `/` and `c:` is still `../drive_c`; the 371 MB archive has no `logs` or `icons`; `downloads` counts 3.0 MB and not a link to `/opt/bodega`, which `clear` leaves alone. The check found a bug, fixed with its test: an imported bottle had no `logs` folder, and its first run failed. Rename was already in M1. **Not tested:** `cp -cR` on a Mac.
- [ ] **T12** New bottle and import (V13), duplicate, rename and export (V14), Preferences (V15).
  **Check:** tests for `NewBottleBloc`, `BottleDetailBloc` and `PreferencesBloc`; `pages_test.dart`.
- [ ] **T13** `.claude/CLAUDE.md` and `rules/`: what is taken from CrossOver, the new classes and `AppTile`.
  **Check:** those texts exist, and `check_layers.sh` passes.
- [ ] **T14** Final build: `flutter build macos`, open it with `open` in a temporary folder and confirm that it starts and calls the engine, as in `flutter-app`.
  **Check:** output pasted into `verify`. The agent doesn't judge how it looks.
- [ ] **T15 (USER)** Final commit with the script the agent leaves, and **test U9 to U11.**

## User acceptance
On your Mac, with `flutter run -d macos`.

- [ ] **U1** Sidebar: Library, Install, your bottles and Backends. Make the window narrower. **Expected:** below 800 px, icons only; nothing overflows.
- [ ] **U2** Open `steam` and then `games`. **Expected:** real icons for Steam, Muck and Blur. A double click on Blur opens it; a single click doesn't.
- [ ] **U3** Double-click Muck. **Expected:** Steam launches it. If not, tell me what it does. **This is the most uncertain part of the milestone.**
- [ ] **U4** Hide something and go back in; open another application with the bottle already open. **Expected:** it doesn't show up again, and `Abierta` ("Open") stays until everything closes.
- [ ] **U5** Install Rockstar in a new bottle, and another catalog application in an existing one, if you want. **Expected:** real progress, cancel works, and it appears in its bottle. This is the pending U3 from `flutter-app`.
- [ ] **U6** Open drive C:, the terminal and each control panel. **Expected:** they open.
- [ ] **U7** `Ejecutar con opciones` ("Run with options") on Muck, with the HUD. **Expected:** a counter on screen. If it doesn't show up, the switch is removed.
- [ ] **U8** In a test bottle: high resolution and Windows version. **Expected:** it warns before closing, it looks sharp, and `winver` confirms it.
- [ ] **U9** Create a bottle, duplicate it, rename it and delete it. **Expected:** it warns, and each step works.
- [ ] **U10** Export one and import it. **Expected:** it appears and opens.
- [ ] **U11** Preferences: folder, cache and theme. **Expected:** `Vaciar` ("Empty") leaves it at zero. Tell me what you would improve about the look.
