# Tasks · mach9-updates

## Engine

- [x] **T1 (MU1, D1):** `mach9Identity` replaces `mach9Release`. Its readers (`platform_mac.dart:501`, the checks in `mach9.dart`) use it.
- [x] **T2 (MU2, D2):** `mach9Latest()`, `NoMach9Release`, the cache `runtimes/.mach9-latest.json`, and `BODEGA_GITHUB_API` for tests. Tests with fake JSON and appcast files.
- [x] **T3 (MU3, D3):** `monoVersionOf` and `monoRelease`. The install takes Wine Mono after the copy. Tests.
- [x] **T4 (MU4, D4):** the source order with the latest; the probe after the switch; the rollback; the cleanup; the new steps. Adapt the install tests of `mach9_test`.
- [x] **T5 (MU5, D5, D7):** `RuntimeInfo.latest` and `updateAvailable`; `checked` from `runtime.json`; `bodega runtime check mach9`; `install` with no file. Tests.
- [x] **T6 (MC1):** `dart analyze && dart test`.

## App

- [x] **T7 (MA1, MA2, MA3, D6):** the look-up at start and hourly; the notice once per version; the card's button and its "checked" text; the update flow with the probe and its failure. Bloc, widget and `pages_test` cases.
- [x] **T8 (MA4):** the `AppError` codes and the texts in both ARBs.
- [x] **T9 (MC1):** all app checks.

## Rules and checks

- [x] **T10:** `CLAUDE.md`, "Lines not to cross": Mach9 comes from its latest GitHub release, checked against GitHub's digest and Apple's signature with its team; Wine Mono from the release that Mach9's `appwiz.cpl` names.
- [x] **T11 (MC2):** the real checks, with output in `tasks.md`.
- [x] **T12:** `bump-version`. The release goes with the Rosetta Game Mode change: the user decides the PR.

## Notes from apply (2026-11-24)

- **Tests can swap two things:** `githubApi` (GitHub's API, or a `file://` folder laid out as its paths) and `mach9Probe` (the new version's check).
- **Offline:** with no answer from GitHub, the install takes the last cached release, or with none, the user's `Mach9.app`. The app does the same.
- **The app's Wine Mono:** it comes through `fetchMono`, the app's Downloader with progress, after the copy names it.
- **The probe's bottle:** `mach9-check`, without Mono, removed either way. It can show for a minute in the bottle list.
- **The 24 h notice:** `BackendsBloc` (a lazy singleton) asks at start and every hour, and the repository asks GitHub only past 24 h. "Once per version" is per run of the app.
- **Shell tests:** three tests that mount `ShellBody` got a quiet `BackendsBloc`.
- **Checks (T6, T9):**
  - engine: `dart analyze` no issues, `dart test` +516 ~5;
  - app: build_runner, gen-l10n, `flutter analyze` no issues, `flutter test` +1029, Layers OK.
  - Under load, two older timing tests (PE4 retina, MG8 Steam) failed once and passed alone, twice each. They share the 1 s `_serverRunning` wait.
- **Real (T11), 2026-11-24:**
  - `bodega runtime check mach9` against GitHub gave `installed none` and `latest 0.4.0`, and cached `bytes 200499232`, `sha256 3b5dd83e…`, `minimumMacos 26.4` (from the appcast);
  - `monoVersionOf` on the real Mach9 0.4.0 gave `11.3.0`, and `monoRelease` gave `wine-mono-11.3.0-x86.msi 83348992 df2dfc16…`, both equal to the former pins;
  - `bodega runtime install mach9 ~/Downloads/Mach9-0.4.0.dmg --mono ~/Downloads/wine-mono-11.3.0-x86.msi` ran its steps, "Checking the new version" among them, in 1 min 31 s;
  - the resulting `runtime.json` is `{kind: mach9, version: 0.4.0, source: dmg, checked: true, mono: wine-mono-11.3.0-x86.msi, checkedAt: …}`;
  - no bottle was left, `runtime list` says `mach9: installed 0.4.0 (mach9-0.4.0)`, and a second install says already installed.
  - The temporary home was removed, and no dmg stayed mounted.
- **Version (T12):** `tool/version.sh bump minor` gave 1.8.0+16 -> 1.9.0+17, for this change and the Rosetta Game Mode change together.

## Added after archive (2026-11-25, the user's ask)

- **Installers do not stay:** after a good install, the engine deletes Mach9's dmgs and Wine Mono's MSIs in `downloads/`, older tries' and partial ones included; the runtime keeps the MSI it uses. A leftover of 200 MB from 2026-11-23 had been found there.
- **The user's own `.dmg`:** it goes only with the card's "Delete the chosen .dmg when done" box, ticked by default (`installMach9(deleteSource:)`, `installRuntime(deleteFile:)`, `BackendsEvent.setDeleteDmg`). A `Mach9.app` is never deleted. The box is not saved between runs.
- **Checks:** engine `dart test` +518 ~5; app `flutter test` +1030, analyze clean, Layers OK.
