# Tasks: flutter-app

**Conventions.** `P` = `packages/engine`; `A` = `apps/bodega`. **(USER)**: you do it. The agent does not commit or push. After each milestone: `dart run build_runner build`, `flutter analyze` and `flutter test` in `A`, and `dart test` in `P`.

## Milestone 1: foundation
- [x] **T1** Workspace (E1): root, `resolution: workspace`, `flutter create`, no sandbox, window (B1), `.gitignore` and `build.yaml` (B7).
  **Check:** `dart test` in `P`; `dart compile exe`; `flutter build macos --debug`.
- [x] **T2** Engine: E2–E9, with their tests.
  **Check:** `dart test` in `P`; `build/bodega catalog list` unchanged.
- [x] **T3** `device/`: theme (B3), router without screens (B4) and `AppToast` (B6). `di.dart` (B7), `AppError` (B6), breakpoints (B5) and `spider` with the 7 SVGs (B8). `ThemeBloc`.
  **Check:** test `ThemeBloc`; `flutter analyze`.
- [x] **T4** `MainShell` with the sidebar (B5) and `SetupBloc` with its screen (P1), with `Runtime` in `domain` and `data`. Redirect (B4).
  **Check:** tests `SetupBloc`, `router`, and the `MainShell` widget test.
- [x] **T5 (USER)** Commit milestone 1 with the script the agent leaves, and open the app: `flutter run -d macos`. **Expected:** a sidebar, the dark theme, and a switch to icons when the window is narrowed.

## Milestone 2: catalog and library
- [x] **T6** `Catalog`: entities, repository, `CatalogBloc`, list and detail page (P2, P3).
  **Check:** test `CatalogBloc`.
- [x] **T7** `Install`: download with `dio`, `InstallBloc` and progress (P4; `design.md` §4).
  **Check:** test `InstallBloc`; repository test with a local HTTP server: progress, cancel and `Range`.
- [x] **T8** `Library`: `LibraryBloc`, open or closed, warnings and screen (P6–P8; `design.md` §5).
  **Check:** test `LibraryBloc`.
- [x] **T9** `AntiCheat`: `RestClient`, DTO, cache and a section in the catalog (P5).
  **Check:** test `AntiCheatRepository`.
- [x] **T10 (USER)** Commit milestone 2, and open the app. **Expected:** you see your Steam, and you open it and stop it from the Library; the Catalog searches and shows detail pages.

## Milestone 3: bottles, backends and another application
- [x] **T11** `Bottle`: list and detail (P10, P11).
  **Check:** test `BottleDetailBloc`.
- [x] **T12** `Backend`: list, install, D3DMetal and check (P12–P14).
  **Check:** test `BackendsBloc`.
- [x] **T13** Add another application (P9).
  **Check:** test `AddAppBloc`.
- [x] **T14** `.claude/CLAUDE.md` and `rules/` (B9).
  **Check:** they exist and name the versions and the layer rules.

## Closing
- [x] **T15** Layer check (B2) with a script in `tool/check_layers.sh`, which fails if a rule is broken.
  **Check:** it passes; and it fails if a forbidden import is added on purpose, in a temporary copy.
- [x] **T16** Final build: `flutter build macos`, open it with `open` and confirm in a temporary log that it starts.
  **Check:** output pasted in `verify`. The agent does not judge how it looks.
- [x] **T17 (USER)** Final commit with the script the agent leaves.

## User acceptance
On your Mac, with `flutter run -d macos` or the built app.

- [x] **U1** Library: Steam shows up; open it and stop it. **Expected:** `Abierta` ("Open") until it really closes, also if Steam updates itself. A delay of about 3 s is normal.
- [x] **U2** Catalog: search, open detail pages and check the statuses. **Expected:** Epic and GOG cannot be installed.
- [ ] **U3** Install a new application, for example Rockstar. **Expected:** a real progress bar, a cancel button during the download, and the install carrying on even if you switch screens. If Rockstar fails, the reason must be visible and it must be possible to delete the bottle.
- [x] **U4** Cancel a download. **Expected:** no bottle is left.
- [x] **U5** Add another application with Blur, in a new bottle or in `prueba`, and open it. **Expected:** it shows up in the Library and opens.
- [ ] **U6** Bottles: change a bottle's backend, change msync, look at a log and delete a test bottle. **Expected:** a warning before closing or deleting.
- [x] **U7** Backends: read the D3DMetal instructions and press `Comprobar` ("Check") on a closed bottle. **Expected:** `OK` per case.
- [ ] **U8** Open a game with anti-cheat if you have one. **Expected:** a clear warning, without blocking the interface.
- [x] **U9** General: close Bodega with a game open and open it again. **Expected:** the game keeps running and `Abierta` shows. Tell me what you would improve in the look.
