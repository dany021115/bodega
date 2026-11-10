# Design: release and experience improvements

> Written while the repository was private. It is public since 2026-11-10, under the GPL-3.0-or-later: that changes the points below about the Actions budget and about licences.

Each section covers one improvement from `proposal.md`. The signatures and paths are the proposed ones; they get adjusted during implementation.

## M1. Portability guard (X1)

- Where: `tool/package_linux.sh`, right after `flutter build linux --release`.
- What: `readelf -n apps/bodega/build/linux/x64/release/bundle/bodega` and look for `x86-64-v3` or `x86-64-v4` in the `x86 ISA needed` line. If it appears, print "this build requires an x86-64-v3/v4 CPU and does not run on older machines: use the release package (it is built on ubuntu-24.04)" and exit with 1.
- Why there: the Flutter runner executable is the one that carries the marker. On CachyOS it showed `baseline, v2, v3, v4`; the CLI (`dart compile exe`) and the `.so` files in `lib/` don't carry it.
- Escape hatch variable: `BODEGA_ALLOW_NATIVE=1` for a personal build. Without it, it fails.
- Test: `readelf` on a test executable compiled with `-march=x86-64-v3` must fail the guard; one compiled with `-march=x86-64` must pass.
- Document it in `packaging/linux/README.md`.

## M2. Checksums and provenance (X2)

- In the `release` job of `release-linux.yml` and of `release-macos.yml`: after downloading the artifacts to `dist/`, `SHA256SUMS-linux` or `SHA256SUMS-macos` is written (one file per platform, because both workflows upload to the same release and a shared name would be overwritten with `--clobber`). It is generated outside `dist/` and moved inside, so that it doesn't list itself.
- Provenance: `actions/attest@v4` (the one GitHub's documentation recommends; `attest-build-provenance` is a wrapper around it) with `subject-path: dist/*`, and `permissions: contents: write, id-token: write, attestations: write` in that job.
- The attest step has `continue-on-error: true`: provenance comes on top of the checksums and must not bring down a release. The repository is **private**: the documentation says private ones use GitHub's Sigstore instance (with no public transparency log), but it doesn't confirm whether the current plan allows it. We will know at the first release; if it fails, the checksums remain and it gets noted here.
- User verification: `sha256sum -c SHA256SUMS-linux --ignore-missing` and, if provenance was generated, `gh attestation verify <file> -R dany021115/bodega` (with `gh` authenticated, because the repo is private).
- This does not sign the DMG for Gatekeeper (that is M10); it only proves which workflow produced the file.

## M3. Package smoke test (X3)

A `smoke` job that depends on `build`/`arch`/`package` and, when it is on, blocks `release`. **Optional and off by default** (the `smoke` input of `workflow_dispatch`, see "GitHub Free limits" in `proposal.md`): it is about 20 min of Linux per release, and on macOS ten times more expensive. `release` runs anyway if `smoke` is skipped (`always()` with an explicit check that it didn't fail). The script is `tool/smoke_linux.sh <deb|arch|appimage> <dist>`, which can also be run locally with docker.

| Package | Environment | Command |
|---|---|---|
| `.deb` | clean `ubuntu:24.04` | `apt install ./Bodega-*.deb`; `bodega --help`; `BODEGA_HOME=$(mktemp -d) bodega backend list` |
| `.pkg.tar.zst` | `archlinux:base` | `pacman -U --noconfirm Bodega-*-arch-x86_64.pkg.tar.zst`; the same two commands |
| `.AppImage` | `ubuntu:24.04` | `APPIMAGE_EXTRACT_AND_RUN=1 ./Bodega-*.AppImage --version` if it exists; if not, just that it starts and exits |
| `.dmg` | `macos-15` | `hdiutil attach`; `Bodega.app/Contents/MacOS/bodega-cli --help`; `bodega create prueba` (headless) |

- The CLI and `backend list` don't open a window or run Wine, so they comply with the project's "Wine only headless" rule.
- The Manjaro case is reproduced in CI by installing the package in a minimal image: the graphical executable can't be opened without a display, but the M1 guard already covers its ISA.
- Testing the test: force a broken package (without `bodega-cli`) and check that the job fails.

## M4. Chained release (X4)

- Problem: a tag push made with `GITHUB_TOKEN` doesn't trigger other workflows, except `workflow_dispatch` and `repository_dispatch`.
- Design: in `tag-version.yml`, after `git push origin refs/tags/$tag`, add `gh workflow run release-linux.yml --ref "$tag"` (the workflow builds the tag it runs from; it no longer has a `tag` input) with `permissions: actions: write` and `GH_TOKEN: ${{ github.token }}`.
- Only if the tag was just created (the "already exists" `exit 0` prevents it on the other pushes).
- macOS: `release-macos` stays manual (decision 2 of the proposal).
- Update `AGENTS.md`: "Only the `tag-version` workflow creates tags ... `release-linux` runs by itself after it; `release-macos` is run by hand".
- Risk: a broken release goes out on its own. Mitigation: M3 blocks publishing.

## M5. Automatic version check (X5)

- Workflow `check-versions.yml`: weekly `schedule` (Mondays) and `workflow_dispatch`.
- Script `tool/check_assets.sh` (uses `gh api repos/<repo>/releases` and `jq`): for each `name` in `assets.json` it looks for the first release with `prerelease == false && draft == false` and compares it with `version`.
  - Wine: Kron4ek/Wine-Builds. The asset name is `wine-<ver>-staging-amd64-wow64.tar.xz`.
  - DXVK: doitsujin/dxvk (`dxvk-<ver>.tar.gz`). vkd3d-proton: HansKristian-Work/vkd3d-proton (`.tar.zst`).
  - appimagetool: a tagged version is pinned; the `continuous` tag is ignored on purpose.
- If there is a new version: it downloads the file, computes the sha256 and opens a PR with the updated `assets.json` (with `peter-evans/create-pull-request` or `gh pr create`), with the before/after table and the link to the release notes.
- It doesn't merge or release: a person reviews it. Wine's notes may contain regressions (11.x staging changes often).
- Test: run the script against an `assets.json` with a made-up old version and check that it detects the difference.

## M6. Per-game fixes database (X6)

- Data: `packages/engine/lib/fixes_data.dart`, **generated** by `tool/import_fixes.py` from `recipes/games/` in `gauthierpiarrette/highball-db` (CC0-1.0) at a pinned commit (`7a008d5`), just as `catalog_data.dart` is Dart source rather than a data file. One entry per game: `id`, `title`, `steam` (appid, from `db/games/<id>.json`), `optIn`, `steps`, `notes`, `knownIssues`, `source`, `verified`.
- Steps (`steps`), each one with `platforms`: `env` (variable), `registry` (registry value under `HKCU\` or `HKLM\Software\`) and `dlloverride`. A machine applies only the steps marked for it (`hostPlatform.id`: `mac` or `linux`). The importer marks everything as `mac`, because Highball only verified it on Mac. What the engine doesn't understand is not imported (`file`, `copy`, `sync`, `renderer`, `dxvkconfig`), nor are foreign variables (`HB_*` from Highball's engine, `FEX_*` and `MVK_*` from the arm64 line, `CX_*` from CrossOver): the script counts them and lists them. Allowed variables: `ROSETTA_ADVERTISE_AVX`, `D3DM_*`, `VKD3D_*`, `DXVK_CONFIG`.
- Identification: the application key `steam:<appid>`, which `apps.dart` already produces when reading `appmanifest_*.acf`. It is only applied when opening a Steam game with `openApp`.
- Applying: variables and overrides go into `_launchIn` after the backend and the GPU and before the bottle, program and launch settings, so what the user set by hand wins (and `avx: false` still removes `ROSETTA_ADVERTISE_AVX`). Registry values are written with `reg add` before launching; if one fails, the launch stops. An `optIn` fix is shown but not applied automatically.
- Limit: Steam launches the game. If Steam is already open in the bottle, `-applaunch` hands the game to the running Steam and the new variables don't reach it: the bottle has to be closed first. The registry values do get written.
- CLI: `bodega fix list [text]` and `bodega fix show <id|appid>` (which steps apply on this machine and which don't, with the source); `bodega open` warns if the game has a fix.
- Notes and known issues are stored in English, as Highball wrote them, and the CLI says so.
- Linux gets no steps until there are fixes verified on Linux. `umu-database` (GPL-3.0) is not copied: its license doesn't fit a closed-source project.
- Overlap with M7: a `winetricks` step would be added with M7's mechanism.
- Engine tests (`fixes_test.dart`): the bundled data parses, with no repeated ids or appids; an unknown step is rejected; each machine applies only its own steps; precedence with the bottle and launch environment; `avx: false`; added overrides; registry written before launching, and a failure that stops the launch; and that an opt-in fix, or one for another machine or another game, does nothing. Real test on Linux with headless Wine: a `linux` registry step is written and a `mac` one is not.

## M7. Windows dependencies (X7)

- Allowlist of verbs: `vcrun2019`, `vcrun2022`, `dotnet48`, `corefonts`, `d3dcompiler_47`, `xact`. It is extended only by editing the list.
- `bodega deps install <bottle> <verb...>`: runs winetricks with the bottle's Wine, headless (`WINETRICKS_GUI=none`, `-q`), with a timeout, and leaves the log in `bottles/<b>/logs/`.
- Where winetricks lives: in the package, in `runtime/winetricks/` (an LGPL script). On Linux it is added to `assets.json` with a version and sha256 (decision 5).
- To avoid blind downloads, verbs that download from Microsoft show the source before running, and the app asks for confirmation.
- The state is kept in `bottles/<b>/settings.json` (`deps: [...]`), so nothing is installed twice.
- Limit: some verbs open installers with a window. Those don't go on the allowlist.

## M8. New version notice (X8)

- Phase 1 (in the app, `data/` layer): a service that calls `https://api.github.com/repos/dany021115/bodega/releases/latest` once per session (with `dio`, which is already in the project), compares it with the installed version (`package_info_plus` or the `pubspec` constant) and exposes a "version X is available" state. Without network or on error, it shows nothing.
- UI: a bar or toast on the main screen with "Hay una versión nueva (X.Y.Z)" ("A new version is available (X.Y.Z)") and a button that opens the release URL. It never downloads or installs.
- Phase 2 (optional, macOS): Sparkle (through the `auto_updater` package) with an appcast published in the releases and updates signed with EdDSA. It doesn't require a Developer ID to sign the feed, but it does for Gatekeeper not to get in the way (M10).
- Linux: package managers (`pacman`, AUR) already handle updates; phase 1 is enough.
- Tests: bloc with a fake client (higher version, same version, network error).

## M9. AUR (X9)

- A `PKGBUILD` separate from the one in `packaging/arch/`: that one wraps a local tarball. The AUR one uses `source=("https://github.com/dany021115/bodega/releases/download/v$pkgver/Bodega-$pkgver-linux-x86_64.tar.gz")` and real `sha256sums`, which come from M2's `SHA256SUMS`.
- Publishing it requires an AUR account and an SSH key: the decision of whoever maintains the project. The file is left in `packaging/aur/PKGBUILD`, along with the command to update `pkgver` and `sha256sums` with `updpkgsums`.

## M10. Developer ID and notarization (X10)

- Steps if there is an account: a Developer ID Application certificate in a repository secret; `codesign --options runtime --timestamp` on each binary and on the app; `xcrun notarytool submit --wait`; `xcrun stapler staple`.
- Changes: `tool/package_macos.sh` (today `codesign --sign -`), secrets in `release-macos.yml`, and `packaging/macos/README.txt` (the right-click explanation is no longer needed).
- Risk: the packaged Wine contains many x86_64 binaries and dylibs; notarization requires signing all of them with the hardened runtime, and Wine may need entitlements (`allow-jit`, `allow-unsigned-executable-memory`, `disable-library-validation`). It has to be tested on a Mac before promising it.
- Without an account: it is left as it is and `README.txt` is improved.

## M11. Controllers on Linux (extra, requested later)

- How it works: there is nothing to configure in the bottle. Wine 11.21's `winebus` links `libudev` and loads the system's `libSDL2-2.0.so.0`. With SDL2, Wine sees the controller as `is_gamepad 1` and creates the XInput device. Without it, Wine uses the `udev` path (hidraw and evdev). On macOS the layer is a different one (`_ensureGamepads`, IOHID or the bundled SDL2) and doesn't change.
- Measured on CachyOS with headless Wine: a virtual controller (`uinput`, Xbox 360 `045e:028e`) and a real one (8BitDo Ultimate 2, `2dc8:310b`, through its USB receiver) show up in the log as `sdl_add_device controller … is_gamepad 1` and then `WINEXINPUT\VID_…&XI_00`. Wine also warns `Unable to open udev device "/dev/hidraw0": Permission denied` for the hidraw devices owned by root: it is noise, not a failure.
- What really fails: without permission on `/dev/input/event*` there is no controller; without SDL2, it falls back to the `udev` path. Neither of the two gave the user any hint.
- `HostPlatform.gamepads()` returns `GamepadReport` (controllers, SDL2, warnings), or `null` on Mac. A controller is a block of `/proc/bus/input/devices` with a `jsN`; its node is the `eventN` of the same block, and it is checked by opening it. The warnings don't go into `checkHost`, because they don't prevent playing.
- Packages: udev rules, `steam-devices` (Debian and Ubuntu: multiverse/non-free; Arch: multilib; Fedora: no command); SDL2, `libsdl2-2.0-0`, `SDL2` and `sdl2-compat`.
- CLI: `bodega pads` (exits with 1 if there are warnings).
- App: the collapsible "Mandos" ("Controllers") section of the bottle's column (`GamepadsSection`, `id: 'gamepads'`) shows each controller with its status ("Listo" ("Ready") or "Sin permiso" ("No permission")), each warning as a `RequirementCard` with its copyable command, and a "Volver a comprobar" ("Check again") button. On Mac, where `gamepads()` returns `null`, it takes up no space. `GamepadsBloc` is provided by `BottleDetailPage` and reads `GamepadRepository` (`data/` calls the engine's `checkGamepads()`).
- Not tested: the app with a real controller connected (tested with widget tests at 380 px, the panel's width), the path without SDL2 on a real machine, and a game using the controller.
