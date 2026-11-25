# Proposal · mach9-updates

## Why

Mach9 0.4.0 and the Wine Mono it asks for, 11.3.0, are fixed in `mach9.dart`, so each Mach9 release needs a Bodega release. The user wants Bodega to find a new Mach9, say so, and update it, with no version in the code (exploration).

## What

1. **No fixed versions.** `mach9Release` keeps only what identifies the author and what Bodega's rules need:
   - the bundle id `app.mach9` and the team `WLKUUJD25W`;
   - `minimumVersion` 0.4.0 and the `minimumMacos` floor 26.4;
   - the disk estimate.

   Version, URL, size, SHA-256 and the whole `mono` record leave the code.
2. **The latest release, from GitHub.** `mach9Latest()` reads `releases/latest` of `athei/mach9`:
   - the tag;
   - `Mach9.dmg` with its `size`, `digest` and URL;
   - `minimumSystemVersion` from its `appcast.xml`.
3. **Wine Mono from the Mach9 being installed.** The version comes from its `appwiz.cpl` (`wine-mono-<v>-x86.msi`). The MSI comes from the GitHub release `wine-mono-<v>`, checked against that asset's `digest`.
4. **Install and update.** `installMach9` with no file installs the latest:
   - it checks the dmg against GitHub's `digest` and `size`, then Apple's signature with the team as today;
   - it copies the new version beside the old one;
   - it switches, then makes a temporary bottle and runs the probe.
   - If the probe fails, it switches back, deletes the new copy and says so.
   - On success it marks the version checked and keeps only it and the previous one.
5. **The app tells the user.** At start, and every 24 h while it runs, Bodega looks for the latest release. When it is newer than the one installed:
   - the engine card says "Mach9 0.5.0 is out" with "Update";
   - the app shows one notice.

   The update runs with progress and its result. A Mach9 bottle that is open blocks the switch, as today (MR8).
6. **The user's own `Mach9.app`:** when it is the latest version or newer, the install takes it from there, with no download.
7. **The CLI:** `bodega runtime check mach9` prints installed and latest; `bodega runtime install mach9`, with no file, installs the latest.
8. **The rule in `CLAUDE.md`:** "from its pinned GitHub release" becomes "from its latest GitHub release, checked against GitHub's digest and Apple's signature with Mach9's team".

## Decisions taken by default

The user approved without choosing; each can change at this gate.

- **A notice with a button, never a silent update:** an update switches every Mach9 bottle's Wine.
- **The look-up:** at start and every 24 h.
- **Automatic rollback when the probe fails.**
- **What stays on disk:** the current version and the previous one; older ones go.
- **Sparkle's `edSignature`:** not checked. Apple's signature with the team already proves the author, and Ed25519 in Dart would be a new dependency.

## Impact

- **Engine:** `mach9.dart` (record, install, Mono, latest, cleanup), `runtimes.dart` (`checked`, `latest`), `platform_mac.dart` (`minimumMacos` from what is installed or the floor), the CLI, and many of `mach9_test`'s install tests, which replace the record today.
- **App:** the engine card, the update notice and its timer, and the install flow's new steps (Wine Mono after the copy, the probe).
- **Compatibility:** runtimes installed by 1.8 have `runtime.json` with `checked` against 0.4.0; they read as checked.
- **Network:** one API call a day, plus `appcast.xml`. Offline nothing changes and nothing breaks.
- **Not in it:** updating Bodega's own Rosetta engine, which ships with the app.
