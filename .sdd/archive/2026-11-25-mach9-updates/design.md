# Design · mach9-updates

## D1 · What stays in the code

```dart
typedef Mach9Identity = ({
  String bundleId,      // app.mach9
  String team,          // WLKUUJD25W
  String minimumVersion, // 0.4.0: older ones drop rules without name=
  String minimumMacos,  // 26.4, a floor; a release may ask for more
  int diskBytes,        // what a copy takes, for the card
});
```

`mach9Identity` replaces `mach9Release`. Tests may still replace it.

## D2 · The latest release

```dart
typedef Mach9Latest = ({
  String version, String url, int bytes, String sha256, String minimumMacos,
});
Future<Mach9Latest> mach9Latest();
```

1. **The release:** `GET <api>/repos/athei/mach9/releases/latest`.
   - `<api>` is `https://api.github.com`, or `BODEGA_GITHUB_API` (a `file://` folder in tests, where the path ends in `.json`).
   - `version` is `tag_name` without its `v`.
   - The asset `Mach9.dmg` gives `browser_download_url`, `size`, and `digest`, which must be `sha256:` followed by 64 hex digits.
2. **The macOS it needs:** the asset `appcast.xml`, read for the `sparkle:minimumSystemVersion` of the item whose `sparkle:version` is `version`. It is the larger of that and the floor; without the item, the floor.
3. **Failures:** a missing asset, a malformed digest or a version under `minimumVersion` throw `NoMach9Release`, a new failure that the app words. Network errors stay as they are.
4. **The cache:** each answer is saved in `runtimes/.mach9-latest.json`, with `checkedAt`, for the card and the 24 h timer.

## D3 · Wine Mono from what is installed

- **`monoVersionOf(engine)`:** reads `lib/wine/aarch64-windows/appwiz.cpl` as UTF-16LE and takes the first `wine-mono-(\d+\.\d+\.\d+)-x86\.msi`; null when there is none.
- **`monoRelease(version)`:** `GET <api>/repos/madewokherd/wine-mono/releases/tags/wine-mono-<v>`, following the redirect, then the asset `wine-mono-<v>-x86.msi` with its `browser_download_url`, `size` and `digest`.
- **The install's order changes:** Wine Mono comes after the copy, whose `appwiz.cpl` names it, and before the switch. A bad MSI still leaves nothing switched.
- **A given `--mono <msi>`:** its file name must be the one `appwiz.cpl` names, and its hash is checked against the release's digest when one is reachable. Offline it is taken as it is, as the user's own file.

## D4 · Install, probe, rollback

`installMach9(home, {source, latest, mono, onStep, cancelled})`:

1. **The source:**
   - a given `.dmg` or `.app`;
   - else the user's `Mach9.app`, when its version is `latest.version` or newer;
   - else the download of `latest.url`, checked against `latest.bytes` and `latest.sha256`.
   - A given `.dmg` is checked against `latest.sha256` when its version is `latest.version`. A dmg of another version is checked only by Apple's signature.
2. **Mount, signature, copy:** as today.
3. **Wine Mono:** D3, then into the copy as today.
4. **`runtime.json`:** `{kind, version, source, checked: false}`.
5. **The switch:** as today (MR8).
6. **The probe:** a temporary bottle `.mach9-check` is made with the new runtime (wineboot), and `backendTest` runs its mtld3d cases.
   - If they pass, `checked: true` and `checkedAt` go into `runtime.json`.
   - If they fail, `runtimes/mach9` goes back to the previous version, the new copy is deleted, and `Mach9CheckFailed(version, log)` is thrown.
   - With no previous version, the new one stays, unchecked, and the failure is still thrown.

   The temporary bottle is stopped and removed either way.
7. **Cleanup:** after the probe, `mach9-*` folders other than the current one are deleted, never while a Mach9 bottle runs. The previous version is kept only until the probe has passed: that is when a rollback needs it.
   - Changed in apply: the proposal kept two versions. The existing cleanup already deletes the old ones after a good install, so the rollback needs no second gigabyte.

The new steps in `Mach9Step` are `downloadingMono`, now after `copying`, and `probing`.

## D5 · Runtime info

- `RuntimeInfo.checked` reads `runtime.json`'s `checked`. An older file without `checkedAt` but with `checked: true` stays checked.
- `RuntimeInfo.latest` is the cached version from D2, or null.
- `RuntimeInfo.updateAvailable` is `latest` newer than `version`.

## D6 · The app

- **Looking:** `BackendsBloc`, or the bloc behind the engine card, asks `checkMach9()` at start when the cache is older than 24 h or missing, then hourly while the app runs, but asks the network only past 24 h.
- **The notice:** a newer release makes one notice per version ("Mach9 0.5.0 is out: update it in Engines"), and the card shows "Update to 0.5.0".
- **The update:** the card's install flow, with the steps and the probe. A failed probe shows its text and the log.
- **The card:** "Checked by Bodega" or "Not checked", instead of "Checked with 0.4.0".

## D7 · The CLI

- `bodega runtime check mach9` prints `installed <v|none>`, `latest <v>` and `update available` when it is.
- `bodega runtime install mach9 [file]` installs the latest when no file is given. `--mono` is as today.
