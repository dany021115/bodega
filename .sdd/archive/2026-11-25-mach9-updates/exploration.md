# Exploration · mach9-updates

Date: 2026-11-24. Base: `origin/main` (fb39407, v1.8.0), in the worktree `../pr22`, on the branch `feat/rosetta-game-mode`, whose Game Mode work is still uncommitted.

`ENG/` is `packages/engine/` and `APP/` is `apps/bodega/`.

## Problem

Today Bodega takes one Mach9 release, fixed in the code: v0.4.0, with its URL, size and SHA-256, plus the Wine Mono that release asks for.

- **A new Mach9 means a new Bodega:** someone edits `mach9.dart`, tests it, and Bodega ships again.
- **What the user asked for (2026-11-24):** no versions in the code; when Mach9 ships a new version, the app says so and updates it, with no change to the code and no new Bodega release.

## What is fixed today

### The record (`ENG/lib/mach9.dart:1-42`)

`Mach9Release mach9Release` holds:
- `version` 0.4.0, `url`, `sha256`, `bytes` and `file`;
- `diskBytes` (1.06 GB);
- `bundleId` `app.mach9` and `team` `WLKUUJD25W`;
- `minimumVersion` 0.4.0 (older ones drop rules without `name=`) and `minimumMacos` 26.4;
- `mono`: 11.3.0, its WineHQ URL, SHA-256, bytes and file.

Tests replace the record; the app only reads it.

### Who reads it

- **`installMach9` (`ENG/lib/mach9.dart:80-145`):**
  - Wine Mono is downloaded first and checked against `mono.sha256`;
  - the source is, in this order, the given `.dmg` or `.app`, the user's `Mach9.app` when its version equals the pin (`:123-126`), or else the pinned download;
  - with `pinned`, the dmg's hash must equal `sha256` (`:139`).
- **The checks (`ENG/lib/mach9.dart:303-330`):** the bundle id must be `app.mach9` (`:303`), the version at least `minimumVersion` (`:307`), and the team `WLKUUJD25W` (`:327`). `findMach9App` (`:414`, `:445`) applies the same.
- **`runtime.json` (`ENG/lib/mach9.dart:210`):** it writes `checked: version == mach9Release.version`. `runtimeInfo` gives the same to the UI (`ENG/lib/runtimes.dart:88`).
- **`installMono` (`ENG/lib/mach9.dart:489-495`):** the copy in the runtime, or a download checked against the pin.
- **`mach9Block` (`ENG/lib/platform_mac.dart:501`):** reads `minimumMacos`.
- **App: `BackendRepositoryImpl.install` (`APP/lib/data/repository/backend_repository_impl.dart:60-80`):** downloads with progress from the record.
- **App: `_runtimeInfo` (`:270-290`):** gives the engine card `pinnedVersion`.

### What `installMach9` does with the dmg

Its steps, `Mach9Step` (`ENG/lib/mach9.dart:44-56`):
1. download Wine Mono;
2. download Mach9;
3. mount the dmg read-only;
4. check the signature (`app.mach9`, team `WLKUUJD25W`);
5. copy `Contents/Resources/wine` to `runtimes/.tmp-*/engine`, untouched (`:195-200`);
6. check the copy again;
7. switch `runtimes/mach9` to `mach9-<version>`.

A failure or a cancel leaves no `.tmp-*`, no changed link and no mounted volume (I6). Installs are serialized by `runtimes/.mach9.lock`.

## What the world gives without a pin (measured 2026-11-24)

### GitHub, `athei/mach9`

`GET api.github.com/repos/athei/mach9/releases/latest` gives:
- **`tag_name`:** `v0.4.0`, `published_at` 2026-11-17;
- **assets, each with `size` and `digest` (`sha256:…`):**
  - `Mach9.dmg`: 200499232 bytes, digest `3b5dd83e…e6d9`, equal to the pin;
  - `appcast.xml`, the deltas and `wine-v0.4.0-macos-arm64.tar.xz`.

### Mach9's own update feed, `appcast.xml` (Sparkle)

It holds:
- `sparkle:version` and `shortVersionString`, 0.4.0;
- `sparkle:minimumSystemVersion`, 26.4, the same value as `minimumMacos`;
- the dmg's URL and `length`;
- a `sparkle:edSignature` per item.

### Wine Mono

- **What Mach9 asks for:** its `appwiz.cpl` names it, in UTF-16, as `wine-mono-11.3.0-x86.msi` and `wine-mono-11.3.0-arm64.msi`, and in ASCII as `11.3.0` (`lib/wine/aarch64-windows/appwiz.cpl` of Mach9 0.4.0). So the version follows from the installed Mach9.
- **GitHub:** the release `wine-mono-11.3.0` (the API redirects `madewokherd/wine-mono` to its current repo) has `wine-mono-11.3.0-x86.msi`, 83348992 bytes, with digest `df2dfc16…18d3`, equal to the pin.
- **WineHQ:** `dl.winehq.org/wine/wine-mono/11.3.0/` lists only the two MSIs, with no checksum file.

### What already does this in Bodega

`UpdateRepositoryImpl` (`APP/lib/data/repository/update_repository_impl.dart:19, 64-80`) reads Bodega's own `releases/latest` from the GitHub API: `tag_name`, then the assets by name.

## Where the trust comes from

| Check | Today | Without a pin |
|---|---|---|
| The download is the file meant | the fixed SHA-256 | GitHub's `digest` over HTTPS, plus `size` |
| The app is Mach9's author's | Apple signature, team `WLKUUJD25W`, bundle `app.mach9` | the same: the anchor that stays fixed |
| Bodega understands this Mach9 | the version equals the pin (`checked`) | the probe (`backend test`) on the new version, before switching |
| Wine Mono | the fixed SHA-256 | the version from `appwiz.cpl`, and the `digest` of its GitHub release |

- **Someone who swaps the dmg on GitHub** cannot make it signed by team `WLKUUJD25W`, so Apple's signature still rejects it.
- **`minimumVersion` (0.4.0)** stays as a floor, because it is about what Bodega's rules need.

## Constraints

- **`CLAUDE.md`, "Lines not to cross":** it says "Mach9 is downloaded from its pinned GitHub release or copied from the user's `Mach9.app`". The rule changes with this; the user owns it.
- **Mach9's tree:** never touched. Quarantine leaves only Bodega's own copy (`ditto --noqtn`). Wine Mono goes only into prefixes.
- **Running Wine:** agents run Wine headless, and only wineboot, `msiexec /qn` and the probe in Mach9 bottles.
- **Network:** the user is on Starlink from Cuba. GitHub's API answers; its unauthenticated limit is 60 calls an hour per address, so one check a day is far below it. Offline, nothing changes.
- **Disk:** one Mach9 takes about 1.06 GB. A rollback needs the previous one.
- **A switch while a Mach9 bottle runs is refused (MR8).**
- **The archived sdd `mach9-runtime` specified the pin (MR3).** This change supersedes that part.
- **Tests:** they replace `mach9Release` today, and the downloads in tests use `file://` URLs (`dependencies_test`). A latest-release lookup needs the same: a URL a test can point at a local file.

## Open questions

1. **Automatic or with a button?** The user asked that "the app tell you and update it". By default, a notice with "Update", or update by itself at start?
2. **When to look:** at the app's start and then every 24 h? And a CLI `bodega runtime check mach9` (and `install` with no file taking the latest)?
3. **Sparkle's `edSignature`:** checking it needs Mach9's public key (`SUPublicEDKey`, in its `Info.plist`) and Ed25519 in Dart, a new dependency. Is Apple's signature with the team enough, the lazy and sufficient option?
4. **The probe as the gate:** install the new version beside the old one, switch, make a temporary bottle, run the probe; if it fails, switch back and say so. Or switch without a probe and only mark it unchecked?
5. **Old versions:** keep only the previous one for a rollback and delete the rest?
6. **The user's own `Mach9.app`:** if it is newer than Bodega's, offer to take it from there, which needs no download?
7. **The engine card:** "Checked with 0.4.0" (`pinnedVersion`) becomes "checked by the probe on <date>".
