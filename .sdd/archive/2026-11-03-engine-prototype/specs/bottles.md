# Spec: bottles

### R8 · Name and layout
- The bottle's name is the name of its folder and matches `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`.
- Layout:
  - `bottles/<b>/prefix`: it is the `WINEPREFIX` and Wine creates it.
  - `bottles/<b>/logs/`.
- There is no UUID and no `bottle.json`.
- `run`, `wait` and `stop` on a bottle that does not exist fail with `no existe la botella <b>` ("bottle <b> does not exist").

Scenarios:
- **Given** `prueba` or `cave-story_2`, **then** they are accepted.
- **Given** `''`, `.x`, `-x`, `a.`, `a b`, `a/b`, `a:b` or a 65-character name, **then** a `FormatException` is thrown.

**Check:** test `names and windows paths`.

### R9 · Create
`create <b>`:
1. Requires a current runtime and that `bottles/<b>` does not exist. APFS is case-insensitive, so `Prueba` clashes with `prueba`.
2. Creates `logs/`.
3. Launches `<rt>/engine/bin/wine wineboot` in attached mode, with no flags, with the script from design §2, the cwd in `bottles/<b>` and the log `<UTC>-wineboot.log`.
4. If wineboot exits with a code other than 0: runs `wineserver -k` and reports an error.
5. If it exits with 0: runs `wineserver -w` with a 10 min limit. If that runs out, runs `-k` and reports an error.

Scenarios:
- **Given** the fake runtime, **when** `createBottle('t')` runs, **then** it returns the log's path, and the log contains `# exit=0`.
- **Given** that `bottles/t` already exists, **then** it gives the error `ya existe` ("already exists") and suggests `rm -rf <path>`.

**Check:** test `fake runtime cycle`; T15; U2 (time).

### R10 · Bottle ready
- A bottle is ready if, after `-w`, `prefix/drive_c/windows/syswow64/kernel32.dll` and `prefix/system.reg` exist. wineboot can return 0 even when syswow64 is missing (pitfall 7), and the registry only reaches the disk when the server saves it.
- If the bottle does not end up ready, `create` fails. It neither repairs nor deletes it: the folder and the log stay for diagnosis.
- `run` requires the bottle to be ready.

Scenario:
- **Given** the fake bottle `broken`, whose wineboot returns 0 without creating syswow64, **then** it gives an error with the log's path, and the folder and the log are still there.

**Check:** test `fake runtime cycle`; T15.

### R11 · Wait and stop
- `wait <b>` runs `<rt>/engine/bin/wineserver -w` and returns its code. If there is no server, it returns at once.
- `stop <b>` runs `wineserver -k`. Codes 0 and 1 (1 = there was no server) are returned as 0; any other code is passed through.
- Both use the bottle's environment, that is, the same `WINEPREFIX` (pitfall 5).
- There is no reaper.

Scenarios:
- **Given** the fake runtime, where `-k` exits with 1, **then** `stopBottle` returns 0 and so does `waitBottle`.
- **Given** notepad open, **when** `bodega stop prueba` runs, **then** notepad closes within about 11 s at most and the `run` that launched it ends.

**Check:** test `fake runtime cycle`; T15; U6 and U7.
