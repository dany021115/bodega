# Install and open

## I1 · Pre-checks
`bodega catalog install <id> [botella]`; without `botella` (the bottle name), the bottle is named after the `id`. Before downloading or creating anything, it fails if:
- the entry is `blocked`, with its `statusNote`;
- its backend is not installed, with the command to install it;
- the bottle already exists;
- there is no runtime;
- the URL does not start with `https://` (or `file://`, for tests only).

**Scenario (test `installEntry`):** each case gives its error and does not create the bottle folder.

## I2 · Order
1. Checks (I1).
2. Download (I3).
3. `createBottle`.
4. `settings.json` with `sync`, and the program with `backend` and `env`.
5. Registry (I5).
6. Installer (I4).
7. Wait and stop (I6).
8. Check the executable (I7).
9. `app.json` (I8).

A network failure leaves no bottle. A failure from step 3 on leaves the bottle with its logs and says how to delete it (`bodega stop` and `rm -rf`). Without `app.json`, it does not count as installed.

**Scenario (test `installEntry`):** a failing installer leaves the bottle and its log, without `app.json`.

## I3 · Download
- To `downloads/<id>-setup.exe`, or `.msi` if `installer.msi`; the name does not come from the URL, because some URLs have no extension.
- `curl -fLsS --proto =https,file --proto-redir =https -C - --retry 5` into a `.part` file, which is renamed when it finishes.
- With `sha256`: it is checked, and if it does not match, an error and the file is deleted. An already downloaded file that matches is not downloaded again.
- Without `sha256`: it prints `sin checksum fijo: se confía en HTTPS y en <dominio>` ("no pinned checksum: trusting HTTPS and <domain>"), and downloads again unless there is a `.part` to resume.
- After a successful install, an installer without `sha256` is deleted.

**Scenarios (test `installEntry`):**
- **Given** a `sha256` that does not match, **then** an error, with no bottle and no file.
- **Given** `http://…`, **then** the error `no es https` ("not https").

## I4 · Installer
- It runs with the `wine` backend, the entry's `sync` and a `<id>-setup` log, waiting for it to exit.
- MSI: `msiexec /i <archivo> /qn` + `args`. Otherwise: `<archivo>` + `args`.
- Valid codes: 0, 102, 194 and 105 (1638, 3010 and 1641 truncated). Any other: an error with the code and the log.
- No time limit while the installer process is still alive, because it may be a window waiting for the user.

**Scenarios (test `installEntry`):** MSI with `msiexec /i … /qn`; exit 194 accepted; exit 5 gives an error with the log path.

## I5 · Registry
Each `registry` item is applied with `wine reg add <key> /v <name> /t <type> /d <data> /f`, before the installer. An exit code other than 0 gives an error.

**Scenario (test `installEntry`):** the fake Wine receives those arguments; (T9) the value ends up in the registry with the real Wine.

## I6 · Wait and stop
After the installer exits, it waits until the first of these happens:
- the wineserver exits;
- the executable exists and 60 s pass;
- 30 min pass.

Then it runs `wineserver -k`, so that the first launch is a cold start, with the final settings.

**Scenarios (test `installEntry`, with short timings passed as parameters):**
- **Given** a server that does not exit and the executable already created, **then** it stops after the grace period.
- **Given** a server that exits, **then** it moves on without waiting.

## I7 · Check
`prefix/drive_c/<exe>` must exist; if not, the error `el instalador terminó pero no está <exe>` ("the installer finished but <exe> is not there"), with the log.

## I8 · Library
`bottles/<b>/app.json` is written atomically, only at the end: `{id, title, exe, args, installedAt}`.

`bodega apps` prints `botella  título  exe` (bottle, title, exe); with no applications it prints nothing and exits with 0. A bottle without `app.json`, such as `prueba`, does not appear.

**Scenario (test `installedApps`):** it lists the installed one and ignores the others, and a broken `app.json` is named in an error.

## I9 · Open
`bodega open [--backend <b>] [--hud] <botella>` launches `C:\<exe con \>` (the `exe` with backslashes) with its `args`, just like `run`: same settings, log, `# backend` and exit code. Without `app.json`, an error that suggests `bodega run`.

**Scenario (test `installedApps`):** with the fake Wine, it receives the `C:\…` path and the `args`, with the program's cwd.

## I10 · Progress and notes
`installEntry` takes `onStep(String)`, which the app will use to show progress, and which the CLI prints. When it finishes, the CLI prints the entry's `notes`, because they warn about things like the 15–25 min of Steam's first launch.

## I11 · Easy Anti-Cheat notice
Added after U3: POLYGON does not start, neither here nor in CrossOver. The failure only shows up in `AppData/Roaming/EasyAntiCheat/**/anticheatlauncher.log`, inside the bottle.

- `antiCheatHints(home, botella, since:)` returns one notice per game if the last `Launcher finished with:` line in that log is 206. It gives the game's title (`ProcessTitle`) and says that it is not an installation failure.
- `run` and `open` check it every 5 s while they wait, and when they finish, because it is the launcher that opens the game. Each notice appears once, as `pista:` ("hint:"), and only for logs written after the launch.
- It does not follow links inside the bottle.

**Scenarios (test `antiCheatHints`):**
- **Given** a log with 206, **then** one notice with the title.
- **Given** a log that ends with another code, or without that line, **then** none.
- **Given** a `since` later than the log, **then** none.
- **Given** a bottle without that folder, **then** none.

**Real check (T12):** with the CLI, a log written during a `run` gets its notice printed before the run finishes, and an older log does not. The real POLYGON log no longer exists, because Steam deleted EAC when the game was uninstalled: the test uses its lines, copied from the 2026-11-03 output.

**Limit:** if `open` has already returned, as on Steam's first launch, where Steam relaunches itself, the CLI does not warn. The app can call `antiCheatHints` whenever it wants.
