# Spec: launch, environment and logs

### R12 · Hermetic environment
Every process the engine launches (`/bin/sh`, `wine` and `wineserver`) gets `includeParentEnvironment: false` and exactly the map that `wineEnv(prefix, parent)` builds:
- From the parent, and only if they exist: `HOME`, `USER`, `LOGNAME`, `TMPDIR` and `__CF_USER_TEXT_ENCODING`.
- Fixed values:
  - `PATH=/usr/bin:/bin:/usr/sbin:/sbin`
  - `WINEPREFIX=<root>/bottles/<b>/prefix`, always absolute
  - `WINEMSYNC=1`
  - `WINEDLLOVERRIDES=winemenubuilder.exe=d`
  - `ROSETTA_ADVERTISE_AVX=1`
  - `DOTNET_EnableWriteXorExecute=0`
  - `MVK_CONFIG_LOG_LEVEL=2`
- `WINEDEBUG`: the parent's `BODEGA_WINEDEBUG` value or, if it does not exist, `fixme-all`.

No other variable gets in: no `LANG` or `LC_*`, and no `WINEARCH`, `WINEDLLPATH*`, `WINELOADER`, `WINESERVER`, `DYLD_*`, `CX_*` or `BODEGA_*`.

Scenarios:
- **Given** a parent with `WINEARCH=win32`, `DYLD_LIBRARY_PATH`, `WINEDLLPATH`, `CX_ROOT`, `LANG`, `WINEDEBUG=+all`, `PATH=/opt/homebrew/bin`, `HOME` and `USER`, **then** the map has exactly the keys above and `WINEDEBUG=fixme-all`.
- **Given** also `BODEGA_WINEDEBUG=+loaddll`, **then** `WINEDEBUG=+loaddll`.
- **Given** `bodega run t cmd /c set` with the real runtime, **then** the log contains no `DYLD_`, `WINEARCH`, `CX_` or `LANG=`.

**Check:** test `wineEnv is hermetic`; T16.

### R13 · Program and working directory
- If `<program>` contains `/`, it is a Unix path: it is resolved with `resolveSymbolicLinksSync()` (it has to exist), it has to pass `winPathProblem` and it is handed to Wine as an absolute path. The cwd is its folder.
- If it starts with `C:\` (or `c:\`), it is passed as is and the cwd is its translated folder: `prefix/drive_c/<rest with \ → />` without the file name, if it exists; if not, `prefix/drive_c`. This is the usual case for a game that an installer put in `C:\Program Files\…`, and Highball also uses the exe's folder (`HBK/WineRunner.swift#L436-L441`).
- Any other name (`notepad`, `cmd`, `cscript`) is passed as is and the cwd is `prefix/drive_c`.
- The CLI's cwd is never inherited (design §4).

Scenarios:
- **Given** that `prefix/drive_c/Juegos` exists, **when** `runInBottle(…, r'C:\Juegos\Mi Juego.exe')` runs, **then** the log header says `# cwd <prefix>/drive_c/Juegos`.
- **Given** `notepad`, **then** the header says `# cwd <prefix>/drive_c`.
- **Given** a nonexistent `/path/to/Juego.exe`, **then** it gives an error before launching anything.

**Check:** test `fake runtime cycle`; U3 (`drive_c`); U5 (a Unix path with a space and an accented letter).

### R14 · Detached launch and exit code
- `run` launches `/bin/sh -c S bodega <log> <rt>/engine/bin/wine <program> [args…]` with `ProcessStartMode.detached` (design §2).
- The script `S` appends `# exit=N` to the log and writes `N` to `<log without .log>.exit` atomically.
- `bodega run` prints `log: <path>`, polls the `.exit` every 250 ms and exits with `N`.
- Ctrl-C or closing the Terminal only makes the CLI stop waiting: the program keeps running.

Scenarios:
- **Given** a fake program that exits with 7 and leaves a grandchild process with the log open for 5 s, **then** `exitOf(log)` returns 7 in under 2 s (pitfall 1).
- **Given** `bodega run t cmd /c exit 7` with the real runtime, **then** `echo $?` prints 7.
- **Given** an open game, **when** the Terminal is closed, **then** the game keeps running.

**Check:** test `fake runtime cycle`; T15; U6.

### R15 · One log per run
- **Path:** `bottles/<b>/logs/<UTC>-<label>.log`, with the time in ISO-8601 with microseconds and `:` replaced with `-`.
- **Creation:** with `createSync(exclusive: true)`.
- **Label:** `wineboot` in `create`. In `run`, the program's base name (whatever comes after the last `/` or `\`), without `.exe`, with everything that is not `[A-Za-z0-9._-]` replaced with `_`, and at most 40 characters.
- **Header** (written by Dart): `# runtime <id>`, `# cwd <dir>` and `# argv <…>`. It never includes the environment.
- **Footer** (written by the script): `# exit=N`.
- **Size:** no limit and no rotation (ponytail).
- Checks require the log to **contain** `# exit=N`, not to end with that line (design §3).

Scenario:
- **Given** `C:\Juegos\Mi Juego.exe`, **then** the log's name ends in `-Mi_Juego.log`.

**Check:** test `fake runtime cycle`; U3.

### R16 · Hints
When `create` (even if it fails) and `run` finish, the CLI scans the log and prints `pista: …` ("hint: …") to stderr for each marker it finds. The exit code does not change.

Markers, only those that can occur with this design:
- `cannot find the FreeType`
- `ailed to load libgnutls`
- `version mismatch`
- `wine: failed to open`

There are no msync or Rosetta markers: `WINEMSYNC=1` is constant (design §4) and R3 checks Rosetta before every verb.

Scenarios:
- **Given** a log with each marker, **then** the hint for each one appears.
- **Given** a clean log, **then** none appears.

**Check:** test `hints`; T15, where the `real runtime` group requires the FreeType and GnuTLS hints without hostlibs.
