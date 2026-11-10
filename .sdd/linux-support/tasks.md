# Tasks: Linux support

Rule for every worker: the minimal change that solves the task, with no over-engineering. Do not run tests, `dart`, `flutter` or Wine (the installed SDK doesn't work for this project). Do not commit or push. Read `.sdd/linux-support/design.md` before starting: the signatures there are fixed. Code in English; UI texts and errors in Spanish with accents, like the rest of the repo.

Worktree: `/home/roilan/Documents/GitHub/bodega/.claude/worktrees/feat-linux-support`

## Waves

| Wave | Tasks | Depends on |
|---|---|---|
| 1 | T1, T2 | n/a |
| 2 | T3, T4 | T1 (T3 also on T2) |
| 3 | T5, T6 | T3, T4 (T6 only on T1) |
| 4 | T7, T8 | T5, T6 (T8 on T2, T3) |
| 5 | T9 | all |

## T1: HostPlatform interface and MacPlatform

Files: `packages/engine/lib/platform.dart` (new, `part of 'engine.dart'`), `platform_mac.dart` (new, `part of`), `engine.dart` (add the two `part` directives), `engine.dart`, `backends.dart`, `apps.dart`, `catalog.dart`, `bin/bodega.dart`.

To do:
1. Create `HostPlatform` with the exact signatures from `design.md`, the `hostPlatform` global, `HostPlatform.detect()`, and `MacPlatform` with today's behavior moved as is. Create only the skeleton of `LinuxPlatform` (`platform_linux.dart`, `part of`) with `throw UnimplementedError()` in each member, so that `detect()` compiles; T3 fills it in.
2. Replace, following the "What moves where" table: `bodegaHome`, `wineEnv`, `requiredFiles`, the tools (`shasum`, `tar`, `curl`, `xattr`), `rosettaInstalled` in `bin/bodega.dart` with `checkHost`, `backendNames`, `_pinned`, `backendEnv`, `_autoBackend`, the `d3d11.dll` check in `installBackend`, `_defaults.sync` and `_checkSync`, the `WINEMSYNC` in `_launchIn`, the `_ensureGamepads` calls in `createBottle`/`runInBottle`/`openApp`, `cases` in `backendTest`, the `reg add` calls in `setHighRes`, `entry.backend` in `installEntry`, and the "en Mac" ("on Mac") text in the EAC hint.
3. Add the `gpu` and `gamemode` fields to `BottleSettings`, with their `_with`, reading in `_settings`, writing in `_saveSettings`, and `setBottleOptions`. In `_launchIn`: `...hostPlatform.gpuEnv(settings.gpu)` and the `launchWrapper` (a new `wrapper` parameter in `_start`, which is prepended to `'$rt/engine/bin/wine'`).
4. New public top-level functions: `checkHost()` and `hostCapabilities()`. `backendEnv`, `pinnedBackend` and `listBackends` still exist and delegate.
5. The behavior on macOS must not change. `rosettaInstalled()`, `installSdl`, `x86Slice`, `importD3DMetal` and `_sdl` stay as they are.

AC: S2 (grep) with no results outside what is allowed; every member of `HostPlatform` has an implementation in `MacPlatform`; no `Platform.` from `dart:io` renamed by mistake.

## T2: installer files

Files: `packaging/linux/assets.json`, `packaging/linux/fetch_assets.sh`, `packaging/linux/cache/` (ignored by git: add it to `.gitignore`).

To do:
1. With `gh api` (read-only) or `curl`, find the latest stable version of: Kron4ek `Wine-Builds` (asset `wine-staging-<ver>-amd64-wow64.tar.xz`), DXVK (doitsujin, `dxvk-<ver>.tar.gz`), vkd3d-proton (HansKristian-Work, `.tar.zst`) and appimagetool (AppImage/appimagetool, `appimagetool-x86_64.AppImage`). Don't make up versions or URLs.
2. Download each file into its own new directory under `packaging/linux/cache/<name>/`. Compute the sha256 locally. The downloaded files are untrusted: don't run them, and don't use them as a working directory.
3. Write `assets.json` with `name`, `version`, `url`, `sha256`, `size` per file. Write `fetch_assets.sh` (it downloads whatever is missing and verifies with `sha256sum -c`; `set -euo pipefail`).
4. Unpack only to inspect (in a temporary directory in the scratchpad): write down in `packaging/linux/README.md` (a) the real directory layout of Wine and of DXVK and vkd3d-proton, (b) using `strings` on `lib/wine/x86_64-unix/ntdll.so`, which sync variables it recognizes (`WINEESYNC`, `WINEFSYNC`, `WINE_NTSYNC`, `ntsync`...), (c) the included licenses.
5. Don't run Wine.

AC: `sha256sum -c` passes on everything downloaded; `assets.json` is valid according to `python3 -m json.tool`; `bash -n fetch_assets.sh`.

## T3: LinuxPlatform

Depends on T1, T2. Files: `platform_linux.dart`, `backends.dart`, `engine.dart`, `bin/bodega.dart`.

To do: implement `LinuxPlatform` according to `design.md`, using what T2 found for `requiredFiles`, `syncModes`/`syncEnv` and the pinned URL in `pinnedBackends`. `registerBundled` (link/copy of the runtime and the layers). `_ensureLayers` with the `$home/backends/dxvk/VERSION` marker. `checkHost`. `installSdl`, `importD3DMetal` and `installBackend('d3dmetal')` throw `'no disponible en Linux'` ("not available on Linux") when `!capabilities.sdl`/`!capabilities.d3dmetal`. R18: the session's user.

AC: S2; every member implemented; `grep -n UnimplementedError packages/engine/lib` with no results.

## T4: case-insensitive paths

Depends on T1. Files: `engine.dart` (`findCI` helper), `apps.dart`, `catalog.dart`.

To do: add `findCI` according to `design.md` and apply it wherever a path inside the prefix is built with a name that Wine didn't write: `_shortcutApps` (`File('$drive/$exe')`), `_steamGames` (`_steamExe`, `apps`), `_steamIcon`, `addApp`, `appIcon`, `_launchIn` (`scan` and `cwd` in the `c:\` case), `installEntry` (`File('$prefix/drive_c/${entry.exe}')`) and `antiCheatHints`. The paths in `_shortcutFiles` too.

AC: every `File('$drive/...')`/`File('$prefix/drive_c/...')` with a variable name uses `findCI`; on macOS the result is the same because the exact path exists.

## T5: engine extras

Depends on T3, T4. Files: `backends.dart`, `bin/bodega.dart`.

To do: the `bodega option <bottle> gpu auto|discrete` and `bodega option <bottle> gamemode on|off` commands (they use `setBottleOptions`); `bodega sync` accepts the modes in `capabilities.syncModes`. Verify that `--hud` reaches `backendEnv`.

AC: `bodega` with no arguments lists the new commands in `_usage`.

## T6: Flutter app

Depends on T1. Files: under `apps/bodega/lib/` and `apps/bodega/pubspec.yaml`, according to the "App" section of `design.md`. Also `flutter create --platforms=linux --no-pub .` inside `apps/bodega` (the only Flutter command allowed; it creates `linux/`).

To do: new domain entities, `RuntimeStatus`, repository, `SetupBloc`/`SetupState`/`SetupEvent`, `RequirementCard` instead of `RosettaCard`, hiding options by capability (AVX, DLSS, D3DMetal and its `D3DMetalInstructions`, SDL, Retina), the sync list from `capabilities.syncModes`, `gpu` and `gamemode` toggles (if `capabilities.gpu`/`gameMode`), generic texts, uppercase extensions. Update the `description` in `pubspec.yaml`. Don't touch `macos/`.

AC: S1 (`apps/bodega/tool/check_layers.sh`): `domain/` doesn't import the engine.

## T7: tests

Depends on T5, T6. Write them without running them.

To do: in the engine tests that assume macOS, set `hostPlatform = MacPlatform()` in `setUp`. Update the app's tests for the `RuntimeStatus` change (`setup_bloc_test`, `router_test`, `runtime_repository_test`, `pages_test`, `bottle_detail_bloc_test`). Add `packages/engine/test/linux_test.dart`: `baseEnv` (inherited variables and the ones that aren't, and R18), `defaultHome` with and without `XDG_DATA_HOME`, `findCI`, Linux's `backendEnv`/`autoBackend`/`probeCases`, `registerBundled` with a fake package in a temporary directory, `_ensureLayers`, and `checkHost` with a simulated `os-release` if practical.

AC: no new test touches the real system outside temporary directories.

## T8: packaging

Depends on T2, T3. Files: `tool/package_linux.sh`, `packaging/linux/{bodega.desktop,build_deb.sh,build_appimage.sh,LICENSES/}`, `.github/workflows/package-linux.yml`, `.gitignore`.

To do: the script builds the app (`flutter build linux --release`) and the CLI (`dart compile exe`), prepares the package root according to `design.md` (merges DXVK and vkd3d-proton into `backends/dxvk/wine/{x64,x32}` with their `VERSION`), copies Wine to `runtime/wine-<ver>/engine`, adds `LICENSES/`, and produces the `.deb` (`dpkg-deb`), the `.tar.gz` and the AppImage (`appimagetool`). The workflow: `on: workflow_dispatch` (optional `release_tag` input), `runs-on: ubuntu-24.04`, installs dependencies, runs the script and uploads the three files as artifacts and, if there is a `release_tag`, to a draft release.

AC: S3, S4.

## T9: documentation

Linux README, and a note in `.claude/rules/architecture.md` about `HostPlatform` and the location of the bundled Wine. A line in the project's `CLAUDE.md` with the packaging command.
