# Engine additions

All in `packages/engine/lib`, with tests that do not need Wine. The CLI does not change its behavior.

## E1 · Workspace
A root with a workspace `pubspec.yaml`; the engine with `resolution: workspace`; its `pubspec.lock` moves to the root.

**Scenario:** `dart test` in `packages/engine` passes and `dart compile exe bin/bodega.dart` builds the program.

## E2 · `listBottles(home)`
Returns `{name, ready, app}` by name, with `app` null if there is no `app.json`. `ready` is the same check that `runInBottle` uses. A broken `app.json` gives the same error as in `installedApps`.

**Scenario (test `listBottles`):** a ready bottle with an application, another one without it and an incomplete one come out with those values.

## E3 · `bottleSettings(home, botella)`
Public version of `_settings`: `backend`, `sync` and `programs`.

**Scenario (test `settings`):** returns what was saved with `setBackend` and `setSync`, and the default values if there is no file.

## E4 · `removeBottle(home, botella)`
Stops the bottle if there is a runtime and deletes its folder without following links (`dosdevices/z:` points to `/`).

**Scenarios (test `removeBottle`):**
- **Given** a bottle with a link to an outside folder, **then** the bottle is deleted and the outside folder is still there.
- **Given** one that does not exist, **then** error `no existe la botella` ("the bottle does not exist").

## E5 · `rosettaInstalled()` and `hasRuntime(home)`
`rosettaInstalled` moves out of the CLI, which now uses it. `hasRuntime` does not throw.

**Scenario (test `hasRuntime`):** `false` with no runtime or with a broken `current`; `true` with a runtime.

## E6 · Installer already downloaded
`installEntry(…, setup: <ruta>)` skips the download and uses that file. If the entry pins `sha256`, it still checks it. The rest of the flow does not change, and after a successful install it deletes the file if the entry has no `sha256`.

**Scenarios (test `installEntry`):** with `setup`, `curl` is not called, since the invalid URL does no harm; with a `sha256` that does not match, an error and no bottle.

## E7 · `bottleLogs(home, botella)`
Logs from newest to oldest: `{path, name, modified, exitCode}`. `exitCode` comes from the `.exit` file, and is null if that does not exist yet.

**Scenario (test `bottleLogs`):** correct order, and `exitCode` null or with its value.

## E8 · `addApp(home, botella, title, exe)`
Registers a custom application in `app.json`, with `id` equal to `custom`. `exe` is relative to `drive_c` or an absolute Unix path, and `openApp` accepts both. An error if the file does not exist or the bottle already has an application.

**Scenarios (test `addApp`):** paths inside and outside `drive_c` open with their program; no file, an error; a second application, an error.

## E9 · `pinnedBackend(nombre)`
Returns the `url` and `sha256` of `dxmt` and `dxvk`, and null for the others, so that the app can download with `dio`.

**Scenario (test `backendEnv`):** `dxmt` gives the fork's URL and SHA, and `d3dmetal` gives null.
