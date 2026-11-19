# Tasks · mach9-runtime

**Conventions**
- Paths: `ENG` is `packages/engine/`, where `fvm dart` runs; `APP` is `apps/bodega/`, where `fvm flutter` runs; other paths start at the repo root. Flutter and Dart run through FVM (Flutter 3.47.9).
- Three workstreams after the prologue. **Engine** (E) owns `ENG/**`, `tool/package_macos.sh` and `.sdd/mach9-runtime/spike.md`; **App** (A) owns `APP/**`; they never edit the same file and run in parallel. **Verification** (V) joins them and owns the docs, the version and `verify.md`. A6 is the only app task that needs an engine task (E1).
- Every task ends green and names its files. Engine check: `cd ENG && fvm dart analyze && fvm dart test`, existing tests unedited (`design.md` §8). App check: `cd APP && fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter gen-l10n && fvm flutter analyze && fvm flutter test && tool/check_layers.sh`.
- Kept as is: the uncommitted dxvk9 backend (`ENG/lib/platform_mac.dart`, `platform.dart` `BackendRole.dx9to11`, `tool/probe.c` mode 9, `lib/probe_data.dart`, `test/backends_test.dart`, the app's ARBs, `backend_text.dart`, `backend_role.dart`, `code_mapper.dart`) and `APP/macos/Runner/MainFlutterWindow.swift`.
- Wine is run headless only (wineboot, `msiexec /qn`, the probe); games and launchers are the user's (USER). Agents never commit or push.
- Markers: `[ ]` to do, `[x]` done, `[~]` partly, `[-]` dropped.

## J0 · Prologue

- [x] **J0** This spec: `proposal.md`, `design.md`, `specs/{runtimes,bottles,graphics,cli,app,docs}.md`, `tasks.md` (MD1).
  **Check:** the files exist; the user answers proposal §Open questions (Q1 D26, Q2 dxvk9 pin, Q3 `.fvmrc`, Q4 M3).

## Engine stream

- [x] **E0** Spike, scratchpad only, no repo edits (MG8, MG10, MB5, MB6, MB7, MR5): **S1** `exe=*;dll_overrides=winemenubuilder.exe=` shows in the compatdb log with no warning and no winemenubuilder runs during wineboot (else D20's fallback); **S2** `exe=*;dxgi=wined3d;d3d9=wined3d` plus `exe=probe-32.exe;d3d9=mtld3d` gives probe-32 mtld3d; **S3** `exe=*;metal_hud=true` takes effect; **S4** Mono's exit code, `drive_c/windows/mono/mono-2.0`, its time; **S5** the probe in modes 9, 11, 12 under auto, mtld3d, dxmt, wine; **S6** wineboot time under FEX and `codesign --deep` time on the mounted DMG (> 30 s: skip `--deep` when the DMG hash equals the pin); **S7** both registry values with `reg add`; **S8** `VKD3D_SHADER_CACHE_PATH` is used; measure `bytes` and `diskBytes`.
  Files: `.sdd/mach9-runtime/spike.md` (+ `spike-files/`).
  **Check:** S1–S8 recorded in `spike.md`.
- [x] **E1** Contract surface, the gate for A6 (MR13, MR1, MR2, MR3, MR10, MR11, MB1, MB2, MG1, MG2, MB8): every type, enum value, record field, failure and signature of design §3.1–§3.2; implemented: `runtime` in settings, `bottleRuntime`, `runtimeDir`, `listRuntimes`, the four HostPlatform seams (Mac, Linux, TestMac), `findMach9App`, `backendNamesFor`, `listBackends(runtime:)`, `backendFitsFor`, `mapBackendFor`, `monoMissing`, `mach9Release`, `BottleInfo.runtime`; stubbed with `UnimplementedError`: `installMach9`, `installMono`, `compatdbRules`, the Mach9 path of `createBottle`; English for the new enums and failures.
  Files: new `ENG/lib/runtimes.dart`, `ENG/lib/mach9.dart`; `ENG/lib/engine.dart` (`part` lines `:14-24`, `BottleInfo`, `createBottle` signature), `ENG/lib/backends.dart` (`BottleSettings`, `_defaults`, `_with`, `_settings`, `_saveSettings`, `listBackends`, `BadChoice` use), `ENG/lib/catalog.dart` (`installEntry` signature, `InstallStepKind`), `ENG/lib/failures.dart`, `ENG/lib/english.dart`, `ENG/lib/platform.dart`, `ENG/lib/platform_mac.dart`, `ENG/lib/platform_linux.dart`, `ENG/test/_mac.dart`, `ENG/test/english_test.dart`, new `ENG/test/runtimes_test.dart` (items 1, 2, 5, 6).
  **Check:** engine check; `english_test` counts 41 failures and 8 unique markers.
- [x] **E2** Each bottle on its own runtime (MB3, MB4, MR12): the bottle's runtime replaces `currentRuntime` at `engine.dart:179, 246, 336, 344, 640-643, 655-667`, `fixes.dart:136`, `catalog.dart:124`; `_prepareBottle` by kind replaces `hostPlatform.prepareBottle` at `engine.dart:200, 217, 659` and `apps.dart:385`; `_syncSdl` and `installSdl` guarded.
  Files: `ENG/lib/engine.dart`, `ENG/lib/fixes.dart`, `ENG/lib/catalog.dart`, `ENG/lib/apps.dart`, `ENG/lib/platform_mac.dart`, `ENG/test/runtimes_test.dart` (items 3–4), `ENG/test/bundle_test.dart`.
  **Check:** engine check.
- [x] **E3** Environment and rules (MG4, MG5, MG6, MG7, MG8, MG9, MG11, MG13): `wineEnv` by kind (`engine.dart:67-83`); the rule writer and `compatdbRules`; the Mach9 branch of `_launchIn` (`:289-323`) with the VKD3D cache folder, the user's `WINE_COMPATDB` appended and a private `dllOverrides` parameter; the `# rules` line in `_newLog`; the three LogHints.
  Files: `ENG/lib/engine.dart`, `ENG/lib/runtimes.dart` (writer), `ENG/lib/fixes.dart`, new `ENG/test/compatdb_test.dart`, new `ENG/test/mach9_test.dart` (items 1–2).
  **Check:** engine check.
- [x] **E4** Backends by kind (MG3, MG10, MB2): `_checkChoiceFor` with `BackendNotForRuntime` and `BadChoice` with its list (`backends.dart:381-385`); `setBackend` (`:556`); `resolveBackend` (`:737-765`), auto not scanning on Mach9; `backendTest` (`:895-938`) with the cases per kind and the probe override as a rule on Mach9; `_peMachine` factored out of `_peBits` (`:815-832`).
  Files: `ENG/lib/backends.dart`, `ENG/lib/runtimes.dart`, `ENG/test/mach9_test.dart` (item 3).
  **Check:** engine check.
  Done E2–E4 together: 342 tests (3 skipped), analyze clean. `compatdbRules` is real now (no longer a stub). Mach9 bottles skip the host preparation and the `ROSETTA_*`/`MVK_*`/`DOTNET_*` base variables; a launch on a blocked host throws `RuntimeUnavailable`. `installSdl` returns its path untouched when `current` has no `x86_64-unix`. Not covered here: `installEntry` into a Mach9 bottle (its backend mapping is E6), and `createBottle(runtime: mach9)` (still E6's stub).
- [x] **E5** Installing Mach9 (MR4–MR9): `_attach`/`_detach` moved out of `installD3DMetalDmg` (`backends.dart:139-163, 223-233`; its tests at 510-578 still pass); `installMach9` with D4's sources, D5's checks, `copyTree`, `runtime.json`, the link, old-version removal, the `BottleOpen` checks and cancel.
  Files: `ENG/lib/mach9.dart`, `ENG/lib/backends.dart`, `ENG/test/mach9_test.dart` (items 6–8).
  **Check:** engine check; on this Mac, `BODEGA_TEST_MACH9=/Applications/Mach9.app fvm dart test test/mach9_test.dart`.
- [x] **E6** Bottles, Mono and the catalog (MB5, MB6, MB7, MB8, MB9, MB10): `createBottle(runtime, mono, onStep)` writing settings first, then the registry values, then Mono; `installMono`; `installEntry(runtime)`, the `installingMono` step, auto stored as null, installers with auto on Mach9.
  Files: `ENG/lib/engine.dart`, `ENG/lib/mach9.dart`, `ENG/lib/catalog.dart`, `ENG/test/mach9_test.dart` (items 4–5), `ENG/test/catalog_test.dart` (new cases only).
  **Check:** engine check.
- [x] **E7** CLI (MC1–MC8): the verbs of design §6, the usage text, parsing tests.
  Files: `ENG/bin/bodega.dart`, `ENG/test/mach9_test.dart`.
  **Check:** engine check; `tool/smoke_linux.sh`'s expected output unchanged.
- [x] **E8** Packaging guard (MR12): the skip list at `tool/package_macos.sh:138-143` becomes `case "$name" in current|mach9|mach9-*|.tmp-*)`.
  Files: `tool/package_macos.sh`.
  **Check:** `bash -n tool/package_macos.sh`; `grep -n 'mach9' tool/package_macos.sh`.
  Done E5–E8 together: 373 tests (4 skipped: the 3 old ones and the opt-in real import), analyze and format clean; `BODEGA_TEST_MACH9=/Applications/Mach9.app fvm dart test test/mach9_test.dart` passes (real `codesign --deep`, ditto, `wine --version` = `wine-11.21…`). `_attach`/`_detach` are top-level in `backends.dart`. The CLI's usage and the new verbs live in a new part `ENG/lib/cli.dart` (`bodegaUsage`, `runtimeVerb`, `parseCreate`, `parseCatalogInstall`, `parseRuntimeInstall`, `parseRules`, `describeRuntime`), so they are tested without a process. The Mach9 catalog cases are in `mach9_test.dart`, not `catalog_test.dart` (left unedited). `LSMinimumSystemVersion` above the host's macOS gives `RuntimeUnavailable(mach9, macosTooOld)`; it is skipped where `sw_vers` is missing. `installMono` takes a `limit` (default 10 minutes); a re-downloaded MSI stays in `downloads/` (nothing is written into the runtime). On Mach9, catalog `auto` is stored as no exception and installers run with `--backend auto`.

## App stream

- [x] **A0** Start green (MA1, MG12): add `dx9to11` to the role map.
  Files: `APP/test/app/text_test.dart` (`:2928-2942`).
  **Check:** `fvm flutter test test/app/text_test.dart`.
- [x] **A1** Domain (MA2, MA3): entities, enums and `AppError`, `WineTool`, `LogHint`, `InstallStep` cases of design §3.3; repository interfaces. No engine needed.
  Files: new `APP/lib/domain/entities/{runtime_kind,runtime_block,mach9_step,bottle_step,runtime_info}.dart`; `APP/lib/domain/entities/{bottle,bottle_detail,app_error,wine_tool,log_hint,install_step}.dart`; `APP/lib/domain/repository/{backend_repository,bottle_repository}.dart`.
  **Check:** app check.
- [x] **A2** Text (MA9, MA3): keys in both ARBs; `runtime_text.dart`; cases in `error_text.dart`, `hint_text.dart`, `step_text.dart`; the parity allowlist.
  Files: `APP/lib/l10n/app_en.arb`, `APP/lib/l10n/app_es.arb`, new `APP/lib/app/shared/text/runtime_text.dart`, `APP/lib/app/shared/text/{error_text,hint_text,step_text}.dart`, `APP/test/l10n_parity_test.dart`, `APP/test/app/text_test.dart`.
  **Check:** app check.
- [x] **A3** Blocs (MA5, MA6, MA7): `BackendsBloc` (runtimes, installRuntime events, `busy: 'mach9'`, step, cancel, `_load`); `NewBottleBloc` (runtime, `runtimeChanged`, step, Mono-failed outcome); `BottleDetailBloc` (`installMono`). Mocks in tests.
  Files: `APP/lib/app/bloc/backends/*`, `APP/lib/app/bloc/new_bottle/*`, `APP/lib/app/bloc/bottle_detail/*`, `APP/test/app/{backends_bloc_test,new_bottle_bloc_test,bottle_detail_bloc_test}.dart`.
  **Check:** app check.
- [x] **A4** Screens (MA5, MA6, MA7, MA8): the engine card and Rosetta heading on Backends; the Engine dropdown and keyed Graphics in the new bottle dialog; the Engine fact, Mono warning and hidden AVX/DLSS in the bottle column; AVX hidden in run with options.
  Files: new `APP/lib/app/presentation/backends/widgets/engine_card.dart`; `APP/lib/app/presentation/backends/backends_page.dart`, `APP/lib/app/presentation/bottles/new_bottle_dialog.dart`, `APP/lib/app/presentation/bottles/widgets/bottle_column.dart`, `APP/lib/app/presentation/bottles/widgets/run_options_dialog.dart`.
  **Check:** app check.
- [x] **A5** Widget and page tests (MA5–MA8): engine card states, the Mach9 bottle detail and the dialog at 720/801/1150/1921 in en and es; copy-details for the new errors; `new_bottle_dialog_test` fit and single "Automatic".
  Files: `APP/test/app/pages_test.dart`, `APP/test/app/new_bottle_dialog_test.dart`.
  **Check:** app check; `setup_page_test` unedited.
- [x] **A6** Data layer, after E1 is in the app's tree (MA3, MA4, MA10): `code_mapper.dart`; `repository_call.dart` five cases and `WineToolFailed(mono)`; `logHintOf`, `installStepOf`; `backend_repository_impl.dart` (`runtimes`, `installRuntime` with the Downloader, `readyBottles` by kind, `graphics` by kind); `bottle_repository_impl.dart` (`list`, `create`, `installMono`, `_detail`).
  Files: `APP/lib/data/service/{code_mapper,repository_call}.dart`, `APP/lib/data/repository/{backend_repository_impl,bottle_repository_impl,library_repository_impl,install_repository_impl}.dart`, `APP/test/data/{repository_call_test,step_mapper_test,host_codes_test,backend_repository_test,bottle_repository_test}.dart`.
  **Check:** app check.
  Done: the mappers, the five `appErrorOf` cases and the `logHintOf` cases came with A1–A5; `code_mapper.dart` also gained `engineRuntimeOf` (domain to engine kind). `runtimes()` maps `listRuntimes` and fills `pinnedVersion`, `backends` (`backendNamesFor`), `downloadBytes` (DMG + MSI), `diskBytes` and `minimumMacos` from `mach9Release` on the mach9 entry. `installRuntime(mach9)` fetches the MSI and, without a file or a Mach9.app at the pinned version, the DMG into `downloads/` (reusing a whole file already there, without a download step), then calls `installMach9(source, pinned, mono, cancelled)` with the same CancelToken; a cancel gives false and keeps `downloads/`, success and any other engine failure delete them; `installRuntime(bodega)` is `unknown`. `readyBottles` keeps bodega bottles only; `graphics` uses `bottleRuntime`, `listBackends(runtime:)` and `backendFitsFor`. `create` runs `createBottle(runtime, mono: false)` → `setWindowsVersion` → `setBackend` → `installMono` (Mach9, after `BottleStep.mono`); `installMono` calls the engine; `list` and `_detail` fill `runtime`, `monoMissing` and `installedBackends` by kind. `install_repository_impl`/`library_repository_impl` needed no change (a catalog install keeps an existing bottle's kind in the engine; new catalog bottles stay bodega). Tests: new helper `APP/test/data/_mach9.dart` (`Mach9Mac`, fake runtime with fake wine and MSI, `readyBottle`, `useHost`); `repository_call_test` gains the five failures (count 36 → 41); `step_mapper_test` gains `installingMono` and the runtime enums.
- [x] **A7** Optional end-to-end data test on a fake Mach9 runtime (MA11), after E5 and E6.
  Files: `APP/test/data/bottle_repository_test.dart`.
  **Check:** app check.
  Done: `create(runtime: mach9)` against `_mach9.dart`'s fake runtime gives the steps prefix then mono, `winecfg -v win10`, the runtime's MSI through `msiexec /qn`, and a detail with runtime mach9, backend dxmt, Mono present and ready; also `installMono` and `create` without the runtime (`runtimeNotInstalled`, no folder left).

## Verification stream

- [x] **V1** Join (all requirements): both streams in one tree; full engine check, full app check (`build_runner`, `gen-l10n`, `analyze`, `test`, `check_layers.sh`).
  Files: none new.
  **Check:** each command passes; output into `verify.md`.
- [x] **V2** Real install, headless (MR2, MR3, MR4, MR5, MR6, MR7, MC1, MC2): in a temporary `BODEGA_HOME`, `bodega runtime install mach9` from `/private/tmp/claude-501/-Users-arian-Documents-GitHub-Arian/f188f218-9d3d-4541-abcc-87e4489a3e8b/scratchpad/mach9/Mach9.dmg` with `--mono /private/tmp/claude-501/-Users-arian-Documents-GitHub-Arian/f188f218-9d3d-4541-abcc-87e4489a3e8b/scratchpad/winemono/wine-mono-11.3.0-x86.msi` (or a fresh pinned download if the scratchpad was cleared), then again in a second home from `/Applications/Mach9.app`; `runtime list`; `codesign --verify --strict` on the copied `wine.app`; the tampered-copy check of MR5; the Mono hash in `appwiz.cpl`.
  Files: `.sdd/mach9-runtime/verify.md`.
  **Check:** outputs in `verify.md`.
- [x] **V3** Real bottle and probes, headless (MB5, MB6, MB7, MG5, MG8, MG10, MC3, MC5): `create --runtime mach9 m9t` timed; Mono and the two registry values present; `rules m9t <program>`; `backend test m9t mtld3d`, `dxmt`, `wine`, each log's `compatdb:` lines from `WINE_COMPATDB line N` with no `warning:`; then stop and remove `m9t`.
  Files: `.sdd/mach9-runtime/verify.md`, `.sdd/mach9-runtime/spike.md`.
  **Check:** outputs in `verify.md`.
- [x] **V4** Nothing broken, headless (MR7, MB2, MD1): `runtimes/current` unchanged in the user's real home; an existing x86 bottle still passes `backend test <x86> dxmt`; its settings.json byte for byte the same.
  Files: `.sdd/mach9-runtime/verify.md`.
  **Check:** `shasum` of the settings before and after; the probe output.
- [x] **R1** Review fixes (MR5, MR6, MR7, MR8, MR9, MB1, MB3): the link is switched before the DMG is detached, and a `mach9-<v>` the link does not name is replaced, not `AlreadyInstalled`; the whole app is copied and its deep signature checked on the copy; installs run one at a time under `runtimes/.mach9.lock` (fcntl, plus an in-process queue) and remove `.tmp-mach9-*` left by a killed one; an old `mach9-*` an open bottle still runs on is kept for the next install; the app deletes its downloads only after `ChecksumMismatch`, `RuntimeNotTrusted` or `IncompleteArchive`; MB1 tests cover all eight saves, MB3 tests show `removeBottle` and `createBottle` reach Mach9's Wine.
  Files: `ENG/lib/mach9.dart`, `ENG/test/{mach9_test,runtimes_test}.dart`, `APP/lib/data/repository/backend_repository_impl.dart`, `APP/test/data/backend_repository_test.dart`, `design.md` §2, `specs/runtimes.md`.
  **Check:** engine check; app check; headless installs in a temporary `BODEGA_HOME` (outputs in `verify.md`).
- [x] **V5** Docs and version (MD2, MD3, MD4, MD5): README, `.claude/CLAUDE.md`, `AGENTS.md`, `.claude/rules/architecture.md`, `wine/NOTICE.md`; `tool/version.sh bump minor` (1.7.0+15) and `tool/version.sh check`; `tasks.md` ticks.
  Files: `README.md`, `.claude/CLAUDE.md`, `AGENTS.md`, `.claude/rules/architecture.md`, `wine/NOTICE.md`, `APP/pubspec.yaml` (by the script), `.sdd/mach9-runtime/tasks.md`.
  **Check:** MD2–MD5's checks.
- [ ] **V6 (USER)** Real games (MD7, MG7): MW3 through Plutonium in a Mach9 bottle from "/Volumes/Satechi HD"; CPU and GPU against Mach9.app and the Rosetta bottle; the HUD inside iw5mp.exe; Game Mode and the Dock name; existing Rosetta bottles still open and play.
  Files: `.sdd/mach9-runtime/verify.md`.
  **Check:** the user's notes and numbers in `verify.md`.
- [ ] **V7 (USER)** Delivery (MD8): commit from a script beside the repo on `feat/mach9-runtime` (`git switch --no-track -c`), no AI attribution, `tool/version.sh check` before each commit; the agent leaves the script unrun.
  **Check:** `git log --format=%B` of the branch holds no attribution line.
