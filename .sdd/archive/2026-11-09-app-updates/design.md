# Design · app-updates

## 1. No GitHub Pages, no Sparkle
The app asks the public repo's releases API. Sparkle needs an appcast and an EdDSA signature, and
with the ad hoc signature its identity check between versions can fail; besides, our own
modal is needed on Linux anyway. A single path for both platforms.

## 2. Layers
- `domain/`: `AppUpdate` (version, current, notes, page, and whether it can be installed) and
  `UpdateRepository` (`check`, `download`, `install`, `skip`).
- `data/`: `UpdateRepositoryImpl` with `dio` (API), `Downloader` (download), `Preferences`
  (last check and skipped version), `engine.sha256Of` and `Process` (`hdiutil`,
  `ditto`, swap script). Only `data/` touches processes and the network.
- `app/`: `UpdateBloc` (singleton) and `UpdateDialog`, listened to in `ShellBody`.

## 3. Replacing the running app (macOS)
`Bodega.app` cannot be replaced safely while it runs. The app leaves
`.Bodega-update.app` next to the installed one and launches, detached from itself
(`ProcessStartMode.detached`), an `sh` that waits for Bodega's PID to end, deletes the
old app, renames the new one and runs `open`. Then the app quits. A `.dmg` downloaded by the app
carries no quarantine flag (the app is not sandboxed and does not set it), so Gatekeeper does not step in.

## 4. AppImage
On Linux you can rename over an executable that is in use: `rename` the new one over
`$APPIMAGE`, and launch it detached before quitting.

## 5. Release builds only
`kReleaseMode`: a development build lives in `build/` and would replace itself.

## 6. Publishing with a separate token
`github.token` only works for the repo where the workflow runs. The public repo needs a
*fine-grained* token with "Contents: write" only on `bodega-releases`, stored as
`RELEASES_TOKEN`. The notes are copied from the private release (`gh release view --json body`).
