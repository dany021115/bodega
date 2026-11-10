# Screens

Each bloc is tested with `bloc_test` and fake repositories (`mocktail`). You accept the visual side (U).

## First launch

### P1 · Rosetta and runtime
`/setup`: if Rosetta is missing, it shows the command to install it and a button to check again. If the runtime is missing, it lets you choose with `file_selector` the engine and library tarballs, which must have their `.sha256` next to them, and installs them with a loading indicator. An error is shown as is and allows a retry.

**Scenarios (test `SetupBloc`):** no Rosetta; no runtime; successful install; engine error.

## Catalog

### P2 · List and search
`/catalog`: a search box, and cards with icon, title and status in Spanish (`Probado` ("Tested"), `Reportado` ("Reported"), `Sin probar` ("Untested"), `Bloqueado` ("Blocked"), and `Inestable` ("Unstable") if it has `flaky`). No stars. A "Agregar otra aplicación" ("Add another application") link. An application that is already installed says so.

**Scenarios (test `CatalogBloc`):** loads the 7; filters case-insensitively; marks the installed ones.

### P3 · Detail page
`/catalog/:id`: status and its note, backend and sync, notes, known issues and provenance. A button depending on the case:
- `Instalar` ("Install");
- `Abrir` ("Open"), if it is installed;
- disabled, with its reason, if it is blocked;
- `Instalar <backend>` ("Install <backend>"), which leads to Backends, if the backend is missing.

### P4 · Install with progress
A global `InstallBloc`: one install at a time, which carries on even if you switch screens. States: downloading (percentage and a cancel button), installing (current step, from `onStep`), finished (notes and an Open button) and failed (message, log path and a Delete bottle button).

- The download is done with `dio`, to `downloads/<id>-setup.exe.part`, and resumes with `Range`.
- Cancel deletes the `.part` and leaves no bottle.
- Without `sha256`, it shows the notice that HTTPS and the domain are being trusted.

**Scenarios (test `InstallBloc`):** progress; cancel; network error with no bottle; installer error with log; a second install rejected while one is running.

### P5 · Anti-cheat warning
In the catalog, searching for a game looks it up in the `db/anticheat.json` list from `highball-db` at `f0bf6a2`, with `retrofit`, cached in `cache/anticheat.json`. It shows the game, its anti-cheat and its verdict. It makes clear that not being listed guarantees nothing, and that `warning` ("Puede fallar", "May fail") can mean the game does not start: POLYGON is listed that way, and on a Mac it does not get past Easy Anti-Cheat.

**Scenarios (test `AntiCheatRepository`):** downloads and saves; with no network it uses the cache; with no network and no cache it gives `NetworkError`, and the catalog keeps working.

## Library

### P6 · List
`/library`: cards from `installedApps` with an icon, or an initial if it is a custom application, title and status (`Abierta` ("Open") or `Cerrada` ("Closed")). Empty: it invites you to go to the Catalog.

**Scenario (test `LibraryBloc`):** list and empty state.

### P7 · Open and stop
A global `LibraryBloc`. `Abrir` calls `openApp` and `Parar` ("Stop") calls `stopBottle`, with a confirmation, because it closes whatever is open. An application is open as long as `waitBottle` has not finished, even if the first process has already exited. When the app starts, the state is rebuilt: `waitBottle` returns in under 1 s if there is no server.

**Scenarios (test `LibraryBloc`):** opening makes it open; it stays open even if the first process exits; it becomes closed when `waitBottle` ends; state rebuilt at startup.

### P8 · Warnings while it is open
Every 5 s, while it is open, it checks `antiCheatHints` with `since` equal to the opening time, and once on close it checks `hintsIn` on the log. Each warning comes out once, as a toast, and stays visible on the card.

**Scenario (test `LibraryBloc`):** a warning is emitted only once.

### P9 · Add another application
Dialog: choose the `.exe`, the title (by default, the file name), a new bottle (the default) or an existing one with no application, and the "Es un instalador" ("It's an installer") checkbox.
- **Unchecked:** `addApp` with that path.
- **Checked:** runs it in the bottle, waits for it to finish, and asks you to choose the installed executable, with `file_selector` opened in `drive_c`.

The path is validated with `winPathProblem` before anything is created.

**Scenarios (test `AddAppBloc`):** standalone program; installer; invalid path with no bottle created.

## Bottles

### P10 · List
`/bottles`: `listBottles` with name, application and status (`Lista` ("Ready"), `Incompleta` ("Incomplete") or `Abierta`). An incomplete one can be deleted.

### P11 · Detail
`/bottles/:name`: a backend selector (`auto` and the installed ones) and an msync selector, with a warning that changing msync closes the bottle; per-program exceptions, which can be removed; `Ejecutar un programa` ("Run a program"); a list of logs and their content, with the last 2,000 lines; `Borrar` ("Delete"), with a confirmation that names the bottle.

**Scenarios (test `BottleDetailBloc`):** load; change backend and msync; deleting goes back to the list; engine error.

## Backends

### P12 · List and install
`/backends`: the 4, with their status. `dxmt` and `dxvk` are installed with `dio`, with progress and a check of the pinned SHA. Also `Elegir archivo…` ("Choose file…"), to use a local tarball.

### P13 · D3DMetal
Instructions on the screen:
1. Get it from Apple (link to developer.apple.com) or use a copy of your own that you already have.
2. Choose the folder that contains `wine/` and `external/`, or `lib/`.
3. Press `Comprobar` ("Check").

It says that its use is governed by Apple's license, that the CrossOver copy is not accepted, and that it has only been tested with the Whisky and Sikarugir copies.

### P14 · Check
`Comprobar` needs a bottle and runs `backendTest`, which **closes whatever is open in it**: it warns about that first. It shows `OK` or `Falla` ("Fail") per case, with its log.

**Scenarios (test `BackendsBloc`):** progress; wrong SHA; import with an error; check results.
