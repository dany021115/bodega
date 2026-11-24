# Tasks · engine-resilience

## Part A

- [x] **T1 (ER2, D1):** `HostPlatform.processesIn` (Mac with `lsof` and `ps`, Linux with `/proc`), `serverDirOf(prefix)` and `bottleProcesses`, with tests on fake outputs.
  - Done as `HostPlatform.wineProcesses(prefix)` and `orphanWineProcesses(home)` in `lib/processes.dart`, with `programName`, `isWineserver`, `parsePs` and `bottleProcesses`.
  - The Mac's method changed in T8 (design D1).
  - Tests in `test/processes_test.dart`.
- [x] **T2 (ER3, D2):** the reaper after `stopBottle` and `removeBottle`, and `reapOrphans(home)` with the `BODEGA_HOME` rule, with tests, the Whisky case among them.
  - Tested with real processes, one of them ignoring SIGTERM.
  - `lsofNamesUnder` keeps Whisky's paths and a `home-backup` sibling out.
- [x] **T3 (ER1, D7):** `_syncGamepads` before Mach9 sessions; `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1` in Mach9's `wineEnv`; `moveToNative` drops `gamepads`. With tests.
  - `moveToNative` already built the new bottle's settings without `gamepads`.
  - The test helper `mach9Bottle` now has the values, as a prepared bottle would, and "ER1 SDL3 pads before the session boots" has three tests.
- [x] **T4 (ER4, D3):** the third line of `.pid` and `appStillRunning`, with tests.
- [x] **T5 (ER7, D6):** `retina` for both runtimes, `_syncRetina` before Rosetta sessions, the `highRes` migration, and `setHighRes` as a shim. Update the CLI and its tests.
  - `_syncRetina` compares only the values the platform writes: Linux has no `RetinaMode`.
  - A new Rosetta bottle on the Mac starts on `auto`.
  - MB1's legacy file still round-trips byte for byte (design D6, "Older readers").
- [x] **T6 (EA1, EA2, EA3, EA7):** the dropdown for both engines, apps that stay open, the orphans toast, and the texts. With bloc, widget and `pages_test` cases.
  - The new capability `retina` (Mac only) is plumbed from the engine to the app.
  - `RunHint.orphans(count)` and `hintOrphans` in both ARBs.
  - `LibraryBloc` reaps once on its first load and follows a relaunch every `relaunchPoll`.
- [x] **T7 (EC1):** all checks pass.
  - engine: `dart analyze` no issues, `dart test` +497 ~5;
  - app: build_runner, gen-l10n, `flutter analyze` no issues, `flutter test` +1023, Layers OK.
  - A disk image left mounted by an earlier interrupted test run (`bodega-update…/Bodega.dmg`) failed `update_repository_test` until it was detached. That is unrelated to this change.
- [x] **T8 (EC2):** the real checks in a temporary `BODEGA_HOME`, with outputs in `tasks.md`.
  - 2026-11-24, Mach9 0.4.0 from the DMG, bottle `pa`.
  - **ER1:**
    - after `create`, no winebus values;
    - the first probe (`backend test pa mtld3d`, both OK) wrote `DisableHidraw=1`, `DisableInput=0` and `Enable SDL=1`, and `gamepads: 3`;
    - `probe-32`'s header has `# pads sdl3`, and `probe-64`'s, the second run, has none.
  - **ER2:**
    - the first listing, with `lsof +d`, saw only the wineserver of a live session;
    - with D1's new method it lists all six: wineserver, `services.exe`, two `winedevice.exe`, `plugplay.exe` and `svchost.exe`, each named;
    - the folder name `server-100000d-52ebd49` matches `stat` of the prefix.
  - **ER3:**
    - after `stopBottle`: 0 processes, and `lsof +d` on the folder is empty;
    - read-only, on the real home: `orphanWineProcesses` lists exactly pid 26464 (`winedevice.exe`, alive 5 days, the old Games bottle) and nothing of the live bottles. Nothing was ended.
  - The 2.0 GB temporary home was removed.
- [x] **T9 (EC3):** stop. The user tries part A; their result goes in `tasks.md`. Part B starts only after.
  - 2026-11-24: the user chose to go on with part B and try both parts together ("sigue con el b y después pruebo todo"). EC3's runs join EC4 at the end.

## Part B

- [x] **T10 (ER5, D4):** `LogHint.stuckLock` and `runHung`, with tests.
  - `runHung(log, samples)` and `appCpu(home, bottle, log)` in `lib/processes.dart`. The app keeps the samples.
  - Tests in "ER5 a hang". `english_test` counts 9 markers.
- [x] **T11 (ER6, D5):** `openWithRosetta`, with tests.
  - The backend stays `auto`: Rosetta's `autoBackend` already picks D3DMetal for a 64-bit DX12 game (`platform_mac.dart:237`).
  - A new `ChoiceKind.app` refuses an app inside its bottle. `rosettaBottleName` makes the name.
  - Tests in `options_test.dart`, "ER6".
- [x] **T12 (ER8, D8):** `bodega measure` and `metal4`, with tests.
  - New CLI verbs: `bodega measure <bottle> [seconds]` and `bodega option <bottle> metal4 on|off`.
  - `HostPlatform.gpuUtilization()` reads ioreg on the Mac and gives null on Linux.
  - Real and read-only, 2026-11-24: `bodega measure Games 3`, while the user played Blur on Native, gave `average  cpu 235.2%  top blur.exe 207.9%  gpu 74%`.
- [x] **T13 (EA4, EA5, EA6, EA7):** the hang hint and its actions, the menu item and its steps, the Metal 4 switch, and the texts. With tests.
  - **The hang hint:** it is `RunHint.log(LogHint.stuckLock)`, on the bottle's chip and as a toast. Its text names the actions instead of holding buttons: close with the card's ■, and "Open with the Rosetta engine" in the app's menu (spec EA4 changed accordingly).
  - **"Open with the Rosetta engine":** the move shows two toasts, "making the bottle" and "now opens from …", then opens the game there.
  - **The Native entry:** it goes through the existing `hideApp`. For an app added by hand that forgets it, so showing it again means adding it again.
  - `LibraryApp.outsideBottle` comes from the mapper.
- [x] **T14 (EC1):** all checks pass.
  - engine: `dart analyze` no issues, `dart test` +506 ~5;
  - app: build_runner, gen-l10n, `flutter analyze` no issues, `flutter test` +1027, Layers OK.
  - Once, under load, ER1's first test failed: the fake `wineserver -w` took over the 1 s that `_serverRunning` waits, so Bodega thought a session ran. It passes alone and in the next full run. PE4's retina tests share that heuristic.
- [ ] **T15 (EC4):** the user's hang and "Open with Rosetta" runs, and the three measurements, in `tasks.md`.
- [ ] **T16:** `bump-version`, and a commit script in the order fex-options, Visual C++ fix, progress bar, part A, part B. Nothing committed or pushed.
