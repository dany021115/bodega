# Spec · App updates

## P1 · Publish
- `release-macos` and `release-linux`, after uploading to the private release, create (if missing) the
  `vX.Y.Z` release in `dany021115/bodega-releases` with the private release's title and notes,
  and upload its files (`--clobber`) and `wine-src.tar.gz`.
- Without the `RELEASES_TOKEN` secret: a warning (`::warning::`), and the step does not fail.

## A1 · Check
- When the release app starts, it requests (every start since 1.7.0, issue #19; until then,
  only if 24 h had passed since the last check)
  `https://api.github.com/repos/dany021115/bodega-releases/releases/latest`.
- It compares `tag_name` (`vX.Y.Z`) with the installed version (SemVer, number by number).
- There is a notice if it is greater. "Ahora no" ("Not now") closes it for that session only
  and saves nothing, so the next start shows it again (since 1.7.0, issue #19; until then, it hid
  that version for good).
- Network error, odd response or a non-SemVer tag: no notice, no error on screen.
- Development builds check nothing.

## A2 · What can be done
- **macOS** → `Bodega-X.Y.Z-macos-arm64.dmg`. **AppImage** (`APPIMAGE` variable) →
  `Bodega-X.Y.Z-linux-x86_64.AppImage`. It is installed from the app.
- **Linux without AppImage** → notice only: the package manager command and the link.
- If the release lacks this platform's file or its `SHA256SUMS-*`: link only.

## A3 · Modal
- Title "Hay una versión nueva" ("A new version is available"), "Bodega X.Y.Z (tienes A.B.C)" ("Bodega X.Y.Z (you have A.B.C)"), the notes with scrolling.
- Buttons: **Actualizar** ("Update") (or **Ver la versión** ("See the version") if it is only a notice) and **Ahora no**.
- While downloading: a progress bar with MB and **Cancelar** ("Cancel"). Cancelling leaves everything as it was.
- If something fails: the reason in the modal, and the app stays as it was.

## A4 · Install
- Downloads to a temporary folder of the app, resuming a `.part` if there is one.
- Checks the SHA256 against that file's line in `SHA256SUMS-macos`/`-linux`. If it does not
  match: deletes the download and does not install.
- **macOS:** mounts the dmg without showing it, copies `Bodega.app` next to the installed one and unmounts.
  A separate script waits for Bodega to quit, swaps the old app for the new one and opens it.
  If the install location is not writable: it says so and touches nothing.
- **AppImage:** writes the new one next to the old one, makes it executable, moves it into
  place and opens it.
- Then the app quits.

## A5 · Everything is kept
- Updating only changes the program: `Bodega.app` (macOS) or the AppImage. It never touches the
  data folder (`~/Library/Application Support/Bodega` on macOS: bottles with their games
  and settings, backends with D3DMetal, installed engines, icons, logs) or the preferences.
- The download goes to a temporary folder, outside the data folder.
- On startup, the new version registers the engine and backends it ships only if they do not
  exist (`_register` does not overwrite) and does not change the engine in use (`runtimes/current`).

## Scenarios
- **Given** a data folder with a bottle, `backends/d3dmetal` and `runtimes/current`,
  **when** a version that ships another engine and other backends starts, **then** the
  bottle, D3DMetal and `current` stay the same and the new engine is installed alongside.
  (engine test)
- **Given** a prepared install (test dmg), **then** the data folder has not
  changed. (test)
- **Given** the `v1.4.0` release and the `1.3.0` app, **when** it starts, **then** the
  modal shows `1.4.0`. With `v1.3.0` or `v1.2.9`: nothing. (bloc + data with a fake server)
- **Given** "Ahora no" on `1.4.0`, **then** the next start shows `1.4.0` again (since 1.7.0,
  issue #19). (test)
- **Given** a check that ends before the shell shows, as on the setup page, **then** the modal
  opens once the shell does (since 1.7.0, issue #19). (test)
- **Given** less than 24 h since the last check, **then** it requests nothing. (test)
- **Given** no network or a 404, **then** nothing on screen. (test)
- **Given** a SHA256 that does not match, **then** it does not install and says so. (test)
- **Given** a `.dmg` made with `hdiutil create` that contains a `Bodega.app`, **when** the
  install is prepared, **then** the new `Bodega.app` is ready next to the installed one, along with
  the swap script, and nothing is left mounted. (test, Mac)
- **Given** Linux without `APPIMAGE`, **then** the modal gives the command and the link. (test)
- **Given** the first public release and an older installed app, **when** it opens,
  **then** it updates and opens the new one. (U, the user)
