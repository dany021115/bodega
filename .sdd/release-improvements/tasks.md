# Tasks: release and experience improvements

Status: **plan not approved**. The order below is a proposal; it changes once decided (decision 1 of `proposal.md`).

Conventions: each PR bumps the version (`tool/version.sh bump patch|minor`) and stays under ~400 lines; if a task goes over, it is split. Workflow tests are done on a real tag or in a fork. The agent doesn't commit or push without your approval.

## Waves

| Wave | PR | Improvements | Depends on | Size | Version |
|---|---|---|---|---|---|
| 1 | P1 | M1 portability guard | — | small | patch |
| 1 | P2 | M2 `SHA256SUMS` and attestations | — | small | patch |
| 2 | P3 | M3 smoke test (Linux) | P1 | medium | patch |
| 2 | P4 | M3 smoke test (macOS) | — | small | patch |
| 3 | P5 | M4 chained release + `AGENTS.md` | P3 | small | patch |
| 3 | P6 | M5 automatic version check | — | medium | patch |
| 4 | P7 | M6 per-game fixes: data and engine | — | medium | minor |
| 4 | P8 | M6 per-game fixes: `fix show` CLI and app | P7 | medium | minor |
| 5 | P9 | M7 Windows dependencies (engine and CLI) | P7 | medium | minor |
| 5 | P10 | M7 Windows dependencies (app) | P9 | medium | minor |
| 6 | P11 | M8 phase 1: new version notice | — | medium | minor |
| 6 | P12 | M9 AUR `PKGBUILD` | P2 | small | patch |
| 7 | P13 | M10 Developer ID and notarization | Apple account | medium | minor |
| 7 | P14 | M8 phase 2: Sparkle on macOS | P13 | medium | minor |

P1 and P2 are independent and can be done at the same time. P7 to P11 don't depend on the releases and can be moved earlier if we would rather make progress on the product.

## P1. Portability guard

- [x] **T1** `tool/check_isa.sh`, called from `tool/package_linux.sh` after copying the bundle to the stage: it checks `readelf -n` of `bodega`, `bodega-cli` and the `.so` files, and fails with a clear message if they require v3 or v4. `BODEGA_ALLOW_NATIVE=1` skips it.
  **Check (done):** on CachyOS the real bundle fails with the message, and with `BODEGA_ALLOW_NATIVE=1` it passes; with a simulated `readelf`, `baseline, v2` passes and `baseline…v3` fails. New finding: on CachyOS even a `gcc -march=x86-64` build comes out with v4, so the cause is the system's objects, not the flags. In an `ubuntu:24.04` container a binary comes out with `x86 ISA needed: x86-64-baseline` and the guard passes. Documented in `packaging/linux/README.md`.

## P2. SHA256SUMS and provenance

- [x] **T2** In the `release` job of `release-linux.yml` and of `release-macos.yml`: `SHA256SUMS-linux` and `SHA256SUMS-macos` in `dist/`, uploaded with the packages, and `actions/attest@v4` (with `continue-on-error`) and its permissions.
  **Check (done):** the checksums snippet runs fine against a test `dist/` (`sha256sum -c` gives OK on all three files) and the YAML files are valid. **Pending until the first release:** that `SHA256SUMS-*` shows up in the release and that the attest step passes on a private repo; if it fails, the release still goes out with the checksums.
- [x] **T2b** The Arch package goes from `bodega-X.Y.Z-1-x86_64.pkg.tar.zst` to `Bodega-X.Y.Z-arch-x86_64.pkg.tar.zst`, so that it is clear in the release which one is the Arch package (`packaging/arch/build_arch.sh` renames it; `AGENTS.md` and the `arch-support` spec updated).
  **Check (done):** `build_arch.sh` on CachyOS with the real `.tar.gz` gives `Bodega-1.1.0-arch-x86_64.pkg.tar.zst`, and `pacman -Qip` still shows `Name: bodega`, `Version: 1.1.0-1` and the dependencies. A bug turned up along the way: `PKGDEST` can't be `./pkg`, which is makepkg's working folder.

## P3 and P4. Smoke test

- [x] **T3 (P3)** `tool/smoke_linux.sh <deb|arch|appimage> <dist>` and a `smoke` job in `release-linux.yml`, **optional** (the `smoke` input, off by default because of the GitHub Free limits). `release` runs anyway if `smoke` is skipped, and doesn't run if it fails.
  **Check (done on CachyOS, with docker):** AppImage on `ubuntu:24.04` → `wine: instalado` ("installed"), `dxvk: instalado`, OK. `.deb` (built in an Ubuntu container with `build_deb.sh`) installed with `apt` → OK, and its `postinst` doesn't fail. A package without the DXVK layer makes the check fail (`dxvk: no instalado` ("not installed")). **Not verified:** the Arch case (`pacman -U` on `archlinux:base`): `pacman -Syu` couldn't download packages from the mirror over this network ("Operation too slow"), so only the first `release-linux` run with `smoke` turned on will test that part. The job wasn't tested on GitHub either.
- [ ] **T4 (P4)** `smoke` job in `release-macos.yml`: mount the DMG and run `bodega-cli --help` and `bodega create prueba`.
  **Check:** same as T3.

## P5. Chained release

- [ ] **T5** In `tag-version.yml`, after creating the tag, `gh workflow run release-linux.yml --ref "$tag"` (the release is built from the tag it runs from; there is no `tag` input anymore), with `permissions: actions: write`. Update `AGENTS.md`.
  **Check:** a merge to `main` with a new version creates the tag and starts `release-linux` without touching anything; a merge without a new version starts nothing.

## P6. Automatic version check

- [ ] **T6** `tool/check_assets.sh` and `.github/workflows/check-versions.yml` (weekly and manual), which open a PR with the updated `assets.json`.
  **Check:** with an `assets.json` holding a made-up old version, it opens the PR with the correct sha256; with everything up to date, it opens nothing.

## P7 and P8. Per-game fixes

- [x] **T7 (P7)** `tool/import_fixes.py` and `fixes_data.dart` (20 games, 32 steps from `highball-db` at `7a008d5`), `fixes.dart` in the engine, the merge in `_launchIn` and `openApp`, and `bodega fix list|show`.
  **Check (done):** `fixes_test.dart` (precedence, platform, overrides, registry, opt-in, bundled data) and the full `dart test`: 117 pass. Real test on CachyOS with headless Wine: a `linux` registry step is written (`reg query` returns `native,builtin`) and a `mac` one is not. **Not tested:** none of the `mac` steps on a Mac; nor with a real Steam opening a game.
- [ ] **T8 (P8)** In the app, an "Arreglos aplicados" ("Fixes applied") note on the bottle screen and on the game detail (the CLI is already in T7).
  **Check:** repository and widget tests; `pages_test.dart` at the 4 widths.

## P15. Controllers on Linux

- [x] **T17 (P15)** `gamepads.dart`, `HostPlatform.gamepads()` and `bodega pads`: lists the controllers, whether Wine will be able to open them and whether SDL2 is missing, with the distro's package.
  **Check (done):** `gamepads_test.dart` (5 tests); full `dart test`: 122 pass. On CachyOS, a virtual controller and a real one (8BitDo) show up in `bodega pads` and Wine creates them as XInput. **Not tested:** the missing-permission warning on a real controller (the container for testing it with another user didn't respond); the app.
- [x] **T18 (P15b)** In the app, a "Mandos" ("Controllers") section in the bottle's column: `GamepadRepository`, `GamepadsBloc` and `GamepadsSection`.
  **Check (done):** `gamepads_bloc_test.dart` (3) and `gamepads_section_test.dart` (5, at 380 px); `pages_test.dart` and `bottle_detail_page_test.dart` with the new bloc; `flutter test`: 242 pass; `flutter analyze` and `check_layers.sh` clean. **Not tested:** the real window with a controller connected.

## P9 and P10. Windows dependencies

- [ ] **T9 (P9)** `winetricks` in the package (with its sha256 in `assets.json`), the allowlist of verbs and `bodega deps install`. Only in headless processes.
  **Check:** in a real temporary bottle, headless, `deps install <b> corefonts` leaves the mark in `settings.json` and a log. A verb outside the list is rejected.
- [ ] **T10 (P10)** A dependencies screen in the bottle, with confirmation and the download's source.
  **Check:** bloc and widget tests.

## P11. New version notice

- [-] **T11** (superseded by `.sdd/archive/2026-11-09-app-updates`) Service in `data/`, state in `domain/`, notice in `app/`. One query per session; without network it shows nothing.
  **Check:** tests with a fake client (higher, same, error); `flutter analyze` and `check_layers.sh` pass.

## P12. AUR

- [ ] **T12** `packaging/aur/PKGBUILD` and its publishing guide.
  **Check:** `makepkg` on CachyOS against the published release installs, and the binary starts.
- [ ] **T13 (USER)** Create the AUR account, upload the SSH key and publish.

## P13 and P14. Signed macOS build and Sparkle

- [ ] **T14 (USER)** Decide whether there is an Apple Developer account. Without it, P13 and P14 are closed and only `README.txt` is improved.
- [ ] **T15 (P13)** Developer ID signing, hardened runtime, entitlements and notarization in `tool/package_macos.sh` and `release-macos.yml`.
  **Check:** on a clean Mac, the DMG opens without the Gatekeeper warning and Wine starts a bottle.
- [-] **T16 (P14)** (superseded by `.sdd/archive/2026-11-09-app-updates`: no Sparkle) Sparkle with an appcast and EdDSA signing.
  **Check:** an installed version detects a newer one and updates to it.

## User acceptance

- [ ] **U1** A Linux release goes out on its own after a merge, with `SHA256SUMS` and no manual steps.
- [ ] **U2** The Manjaro case: the release package starts on a machine without AVX-512.
- [ ] **U3** A game with a fix in `fixes.json` launches with its variables, and `bodega fix show` explains it.
- [ ] **U4** A new bottle installs `vcrun2022` from the app.
- [ ] **U5** With a newer version published, the app shows a notice and the link opens the release.
