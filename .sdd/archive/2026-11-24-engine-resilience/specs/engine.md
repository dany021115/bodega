# Spec · engine

## Part A

### ER1 · Pads on the Native engine (D7)

- Before a Mach9 session starts, and only when none runs, the bottle's `winebus` key holds `DisableHidraw=1`, `Enable SDL=1` and `DisableInput=0`, and `settings.json` has `gamepads: 3`. A running session is left alone.
- Every environment `wineEnv` builds for a Mach9 prefix has `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`. A Rosetta prefix's has none.
- `moveToNative` leaves no `gamepads` in the new bottle's settings.

Scenarios:
- **Given** a Mach9 bottle whose `system.reg` lacks `DisableHidraw`, **then** a launch runs `reg add … DisableHidraw … 1` before the program. (test with the fake Wine)
- **Given** the values already there, **then** no `reg` runs. (test)
- **Given** `wineEnv` for a Mach9 prefix and for a Rosetta prefix, **then** only the first has the variable. (test)

### ER2 · A bottle's processes (D1)

- `bottleProcesses(home, bottle)` gives each process of the bottle with its pid, CPU and program name, and `[]` when none runs.

Scenarios:
- **Given** a fake `lsof` and `ps` output for the bottle's server folder, **then** the list holds the parsed pids, CPU values and names, `fifa22.exe` from both `FIFA22.exe` and `Z:\Volumes\X\FIFA22.exe`. (test)
- **Given** the real Games prefix, **then** its server folder is `server-100000d-5238dd4`. (real, FC2)

### ER3 · The reaper (D2)

- `stopBottle` and `removeBottle` end with no process of the bottle listed by ER2.
- `reapOrphans(home)` ends each process that:
  - holds a `/tmp/.wine-<uid>/server-*` folder no wineserver holds;
  - maps a file under `home`.

  It never ends one that maps nothing under `home`.

Scenarios:
- **Given** a fake listing where a bottle's process survives `-k`, **then** `stopBottle` sends it TERM, and KILL if it stays. (test)
- **Given** two orphans, one mapping `home/runtimes/…` and one mapping `/Applications/Whisky.app/…`, **then** only the first is ended. (test)
- **Given** a folder with its wineserver, **then** nothing in it is ended. (test)

### ER4 · Staying open after a relaunch (D3)

- A launch's `.pid` file has three lines: pid, app key, program file name lower-cased.
- `appStillRunning(home, bottle, log)` is true while the bottle runs a process of that name. With a two-line file it is false.

Scenarios:
- **Given** a run whose first process exited, and the bottle running `fifa22.exe`, **then** it is true; once that process is gone, false. (test with fake listings)

### ER7 · Retina for both runtimes (D6)

- `setRetina(home, bottle, mode)` takes `auto`, `on` and `off` for both runtimes. Before a Rosetta session, as before a Mach9 one, the prefix gets `RetinaMode` and `LogPixels` for `mode`, with `auto` read from the main display (PE3, PE4).
- A bottle with `highRes` and no `retina` reads as `auto` when true and `off` when false.
- `bodega option <b> retina auto` works on a Rosetta bottle.

Scenarios:
- **Given** a Rosetta bottle with `highRes: true` and a display that isn't HiDPI, **then** its next launch writes `RetinaMode` `n` and `LogPixels` 96, and the header reads `# retina off (auto)`. (test)
- **Given** `highRes: false`, **then** it reads `off`. (test)

## Part B

### ER5 · The hang (D4)

- `LogHint.stuckLock` has the marker `wait timed out in thread`.
- `runHung(home, bottle, log, samples)` is true when the log holds it and the app's processes averaged under 2% CPU over `samples`, which hold at least 60 s.

Scenarios:
- **Given** the marker and samples at 0.1%, **then** true; at 40%, false; without the marker, false. (test)

### ER6 · Open with the Rosetta engine (D5)

- `openWithRosetta(home, bottle, key)` for a Mach9 app whose program is a host path gives the target `(bottle, key)`:
  - reusing a Rosetta bottle with that path, or making one named after the title;
  - adding the app;
  - giving it `d3dmetal` for DX11 and DX12 when it is installed;
  - hiding the source entry.
- For an app inside a `drive_c` it throws `BadChoice`.

Scenarios:
- **Given** no Rosetta bottle with the exe, **then** a bottle named after the title is made, holds the app with `d3dmetal`, and the source key is in its bottle's `hidden`. (test with the fake Wine)
- **Given** a Rosetta bottle that has it, **then** no bottle is made. (test)

### ER8 · Measuring and Metal 4 (D8)

- `bodega measure <bottle> [seconds]` prints one line per second: time, CPU, the busiest process, and the GPU on the Mac. Then it prints the averages.
- `metal4` in `settings.json`, false by default. A Rosetta `d3dmetal` launch with it gets `D3DM_MTL4=1`; no other launch does.

Scenarios:
- **Given** a fake listing and fake `ioreg` output, **then** the lines and averages are right. (test)
- **Given** `metal4` on a Rosetta bottle, **then** a `d3dmetal` launch has `D3DM_MTL4=1`, and a `dxmt` or Mach9 launch has none. (test)
