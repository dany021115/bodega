# Release and experience improvements (macOS and Linux)

> Written while the repository was private. It is public since 2026-11-10, under the GPL-3.0-or-later: that changes the points below about the Actions budget and about licences.

Status: proposal, **undecided**. None of this is implemented. Once the order is decided, `tasks.md` gets updated.

## Why

The v1.1.0 releases work, but the repo review and a real case (the binary built on CachyOS that didn't start on Manjaro: "CPU ISA level is lower than required") showed gaps:

- Nothing checks that a package starts on a clean system. `package_linux.sh` can produce a `bodega` that requires an x86-64-v4 CPU.
- Releases publish neither checksums nor provenance.
- Two chained manual steps: `tag-version` creates the tag on its own, but `release-linux` and `release-macos` are started by hand.
- The app doesn't announce new versions.
- Wine, DXVK and vkd3d-proton are bumped by checking by hand; today they are at the latest (Wine 11.21, DXVK 3.1.1, vkd3d-proton 3.1).
- There are no per-game fixes (variables, overrides, redistributables) outside the catalog, and no installation of Windows dependencies (vcredist, .NET, fonts).
- macOS is signed ad hoc, with no Developer ID or notarization.

## Scope

Ten improvements, independent except where noted. Each one is its own PR (or under 400 lines per PR, see `tasks.md`).

| ID | Improvement | Platform |
|---|---|---|
| M1 | Binary portability guard (ISA level) | Linux |
| M2 | `SHA256SUMS` and provenance attestations on every release | Both |
| M3 | Smoke test of each package on a clean system | Both |
| M4 | Chained release after `tag-version` | Linux (macOS optional) |
| M5 | Automatic version check for Wine, DXVK, vkd3d-proton | Linux |
| M6 | Per-game fixes database | Both |
| M7 | Windows dependencies with winetricks | Both |
| M8 | New version notice in the app, and later updating | Both |
| M9 | `PKGBUILD` for the AUR | Linux (Arch) |
| M10 | Developer ID and notarization | macOS |

Out: Flatpak, more stores (Heroic: Epic, GOG, Amazon), a manager for several Wine versions per bottle, a DMG with a background, and everything related to anti-cheat (the project rules forbid it).

## GitHub Free limits

The account is GitHub Free and the repository is private. According to GitHub's documentation (*GitHub Actions billing*):

- **Included compute:** 12 USD a month. A 2-core Linux runner costs 0.006 USD/min (about 2,000 min); a macOS one, 0.062 USD/min (about 190 min). With no payment method on file, workflows are blocked once it runs out.
- **Artifacts:** 500 MB, shared with GitHub Packages. A Linux release passes them between jobs: `.tar.gz` (247 MB) and AppImage (220 MB), plus the `.deb`, and 167 MB for the Arch package. That is more than the quota.

Rules for every new or changed workflow:

1. Whatever can be is **optional and off by default**, with a boolean `workflow_dispatch` input (like `build_engine` in `release-macos`).
2. **macOS only by hand**: it costs ten times more than Linux. Nothing chains it to another workflow.
3. Artifacts have `retention-days: 1`.
4. PR tests cancel the previous run on the same branch (`concurrency`) and have a short `timeout-minutes`.
5. Undecided idea (M11): upload the packages as assets of a draft release from `build`, instead of passing them between jobs as artifacts. As far as I understand, release assets don't count toward Actions storage.

## Requirements (EARS)

| ID | Requirement |
|---|---|
| X1 | When `package_linux.sh` builds the `bodega` executable, it shall reject it with a clear error if `readelf -n` declares `x86-64-v3` or `x86-64-v4` as the needed ISA. |
| X2 | When a release is published, it shall upload `SHA256SUMS-linux` or `SHA256SUMS-macos` with the sha256 of each file, and a provenance attestation (`actions/attest`) per file, if the repository allows it. |
| X3 | When requested (`smoke` in `release-linux`; on macOS, an equivalent input), before publishing, the workflow shall install the `.deb` on Ubuntu 24.04 and the `.pkg.tar.zst` on `archlinux`, unpack the AppImage, and on each one run `bodega backend list` (CLI, headless). If it fails, nothing is published. It is off by default. |
| X4 | When `tag-version` creates a tag, it shall start `release-linux` with that tag through `workflow_dispatch`. The macOS release stays manual while it depends on `engine-*` and `hostlibs-*` tags. |
| X5 | Every week, a workflow shall compare `packaging/linux/assets.json` with the latest stable releases and open a PR with the new version and its sha256, or an issue if it can't compute it. It shall never pin a pre-release. |
| X6 | When a Steam game is opened, the engine shall apply the steps of the fix in `packages/engine/lib/fixes_data.dart` (variables, registry values and `dlloverride`) marked for that machine, without overriding what the user set in the bottle, the program or the launch. |
| X7 | The engine shall install Windows dependencies (`vcredist`, `dotnet`, fonts) in a bottle with `winetricks`, only with verbs from an allowlist, in a headless Wine process. |
| X8 | The app shall check the GitHub releases once per session, and if there is a higher version it shall show a notice with the link to the release. It shall never install without the user asking. |
| X9 | The AUR `PKGBUILD` shall download the release's `.tar.gz` and verify its sha256. |
| X10 | The macOS DMG shall be signed with a Developer ID and notarized, if there is an Apple Developer account. If not, the ad hoc signature and the instructions in `README.txt` remain. |

## Decisions to make

1. **Order.** Proposal: M1, M2, M3 (release safety) → M4 → M6 → M7 → M8 → the rest. It clashes with the previous list (UI on Linux, milestone 3 of the interface, ntsync): we need to decide whether it goes before or after.
2. **M4 and macOS.** `release-macos` needs the `engine-*` and `hostlibs-*` tags, which are created by hand in other workflows. Do we leave it manual or automate it with a pinned tag?
3. **M10.** It requires an Apple Developer account (paid). [INFERENCE] Getting one may not be possible. Without it, M10 is dropped and M8 on macOS only shows the notice.
4. **M6, where the fixes come from.** Resolved: the game recipes from `highball-db` (CC0), imported with `tool/import_fixes.py` and marked `mac`. Linux gets no steps until there are fixes tested on Linux; `umu-database` is GPL-3.0 and is not copied. Nothing is copied from CrossOver.
5. **M7.** Is winetricks included in the package, or is the user asked to install it? Including it adds a dependency (LGPL, already listed in `wine/NOTICE.md` for macOS) and downloads from Microsoft's servers.

## Acceptance criteria

- Each improvement comes with its test (see `design.md`) and, if it touches workflows, it is tested with a real tag or in a fork before the PR is considered good.
- `tool/version.sh check` passes; each PR bumps the version according to `AGENTS.md`.
- Process changes (M4) update `AGENTS.md`, because today it says "run them by hand".
