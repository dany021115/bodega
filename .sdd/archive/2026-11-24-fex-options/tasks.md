# Tasks · fex-options

## Engine

- [x] **T1 (FE1):** in `runtimes.dart`, add `strictCodeTracking('env', 'FEX_SMCCHECKS=full')` and `fullX87Precision('env', 'FEX_X87REDUCEDPRECISION=0')` after `vulkanWined3d`, each with its doc comment and source.
- [x] **T2 (FE1):** golden tests for FE1's two lines, beside PE7's.
  - Done as `compatdb_test.dart`, "FE1 the FEX options are env fields, last and exact".
- [x] **T3 (FE2):** in `cli.dart`, add the two CLI names, and a test in `mach9_test.dart` for `native … strict-code-tracking on` and the listing.
  - Done in "PE11 option retina and native".
- [x] **T4:** `dart analyze && dart test` in `packages/engine` pass: no issues, +483 ~5.

## App

- [x] **T5 (FA1):** add both values to the domain `NativeOption`, and a mapper or repository test that maps both.
  - `bottle_repository_test.dart`, "PA2 an app's native options reach its library entry", now sets `largeAddressAware` and both new options.
- [x] **T6 (FA3):** add the four keys, with descriptions, to `app_en.arb` and `app_es.arb`; add the cases in `native_text.dart`; run `flutter gen-l10n`.
- [x] **T7 (FA2):** update the dialog's widget test in `pages_test.dart` to seven switches, with FA2's scenario.
  - The layout test counts 7.
  - "FA2 the FEX switches show their state and save" counts the dialog's own switches only, since the bottle page behind has five of its own.
- [x] **T8:** `flutter analyze && flutter test && tool/check_layers.sh` in `apps/bodega` pass: no issues, +1021, Layers OK.

## Checks and wrap-up

- [x] **T9 (FC2.1):** in a temporary `BODEGA_HOME`, run wineboot headless with FE1's fields on a `wineboot.exe` line, and paste its `compatdb:` lines into `verify.md`.
  - 2026-11-24: Mach9 0.4.0 installed from `~/Downloads/Mach9-0.4.0.dmg` and `wine-mono-11.3.0-x86.msi` in 5.4 s; `create --runtime mach9 fc2` took 39 s.
  - wineboot ran with `exe=*;dll_overrides=winemenubuilder.exe=` and `exe=wineboot.exe;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full`: exit 0, 0 `warning:`.
  - `wineboot.exe [aarch64]` got both entries `set` from `WINE_COMPATDB line 2`, and the built-in `=1` was "replaced by a later entry".
  - The processes it started show "built-in: left alone, the process has FEX_X87REDUCEDPRECISION=0": the inheritance Decision 3 counts on.
- [x] **T10 (FC2.2):** ask the user. If they agree, run the probe's exe as a library app and paste its `compatdb:` lines; if not, note that the step moved to FC3.
  - The user agreed ("Sí, córrelo").
  - `probe-64.exe` was added as library app `fc2/probe-64.exe` with both options on (`settings.json`: `"native": {"fc2/probe-64.exe": ["fullX87Precision", "strictCodeTracking"]}`), then `bodega open fc2 fc2/probe-64.exe`.
  - The log header reads `# rules exe=*;dll_overrides=winemenubuilder.exe= | exe=probe-64.exe;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full`.
  - In `probe-64.exe [x86_64 (arm64ec)]`, FEX is loaded, and both entries are `set` from `WINE_COMPATDB line 2`.
  - 0 `warning:`; the probe printed `OK`; `# exit=0`.
  - The 2.0 GB temporary home was removed after `wineserver -w`.
- [x] **T11:** run the `bump-version` skill, a minor bump since this is a feature, and leave a commit script for the user. Nothing is committed or pushed.
  - `feat/mach9-parity` was already in `main` (PR #25) and in v1.7.0. The changes moved, unchanged, to a new branch `feat/fex-options` cut from `origin/main`: none of the touched files differ between ce35b65 and `main`.
  - `tool/version.sh bump minor` gave 1.7.0+15 -> 1.8.0+16; `check` gives "OK: version 1.8.0 (tag v1.7.0)".
  - On that base:
    - engine: `dart analyze` no issues, `dart test` +483 ~5;
    - app: build_runner, gen-l10n, `flutter analyze` no issues, `flutter test` +1021, Layers OK.
  - The script is `../fex-options-commit.sh`: three commits (engine, app, docs) once the sdd is archived. No push.
