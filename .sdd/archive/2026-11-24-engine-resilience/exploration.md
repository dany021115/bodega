# Exploration · engine-resilience

Date: 2026-11-24. Base: `feat/fex-options` (cut from `origin/main` after v1.7.0), with fex-options, the Visual C++ fix and the per-line progress bar uncommitted in the worktree `../pr22`.

`ENG/` is `packages/engine/` and `APP/` is `apps/bodega/`.

## Problem

On 2026-11-23 and 2026-11-24 the user ran games on both engines. Seven things made Bodega look unreliable. None of them depends on a particular game:

1. A pad worked on the Native engine only after two values were set by hand.
2. A Wine process left over from a bottle that no longer exists held the pad, and no other bottle got its buttons.
3. A game that starts a second copy of itself and exits shows as closed while it runs.
4. A game that hangs on the Native engine stays frozen with no word from Bodega.
5. Running a game on the Rosetta engine took a new bottle, adding the exe and choosing D3DMetal, all by hand.
6. The user believes the Rosetta engine runs on the CPU only.
7. On a Rosetta bottle, "fullscreen" covered a quarter of the screen.

## 1 · Gamepads on the Native engine

### Evidence (2026-11-23, the Games bottle on Mach9 0.4.0)

- **Inverted controls:** Mach9's Wine 11.21 took the raw IOHID device, and the controls came out inverted. With `DisableHidraw=1` under `HKLM\System\CurrentControlSet\Services\winebus`, it takes the SDL device instead (`WINEBUS\VID_045E&PID_02FD\c8:3f:…`).
- **No input at all:** Mach9's SDL is sdl2-compat over SDL3: `engine/lib/external/libSDL2-2.0.0.dylib` and `libSDL3.dylib`. In `winedevice.exe`, a process with no window, it delivers nothing unless `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`. Measured in a temporary Mach9 prefix: 8 events without the variable, 451 axis and 25 button events with it.
- **Today's setup:** both values are on the Games bottle by hand, the variable in its `settings.json` `env`. With them, the pad works.

### Code

- **`ENG/lib/engine.dart:941-944`:** `_prepareBottle` returns at once for a Mach9 bottle ("a Mach9 bottle gets none", MB4). So no Mach9 bottle gets any gamepad setup.
- **`ENG/lib/platform_mac.dart:410-451`:** `_ensureGamepads`, for Rosetta only.
  - Version 1 is raw IOHID (`Enable SDL=0`, `DisableInput=1`); version 2 is SDL (`Enable SDL=1`, `DisableInput=0`), chosen when `hasSdl` (`ENG/lib/engine.dart:771-773`) finds Bodega's SDL2 in `current`.
  - It is saved as `gamepads` in `settings.json` (`ENG/lib/backends.dart:445, 585, 664`).
- **`ENG/lib/engine.dart:74-101`:** `wineEnv`, the environment of every process the engine starts, with its Mach9 branch.
  - `winedevice.exe` inherits the environment of the session's first process, so a variable has to be there, not only on a game's launch.
- **`ENG/lib/mach9.dart:555`:** `moveToNative` carries the old bottle's settings over, `gamepads: 2` included, which says nothing about Mach9's SDL3.

## 2 · Orphan Wine processes

### Evidence (2026-11-24)

- A `winedevice.exe` (pid 26464) had been running for 4 days and 23 hours.
- It held `/private/tmp/.wine-501/server-100000d-4ecc432` and the old Games prefix's `drive_c/windows`, with `IOHIDLib` and Bodega's `libSDL2-2.0.0.dylib` loaded. That was the Games bottle when it was a Rosetta bottle, on 2026-11-19; the move of 2026-11-23 replaced it.
- No wineserver served it any more.
- While it lived, the new Rosetta bottle Fifa22 saw the pad (`Enum\HID\VID_045E&PID_02FD&XI_00…`) but no button reached the game. SDL's hidapi opens a pad exclusively on macOS.
- Once the user ended it, the pad worked.
- An agent was not allowed to end it: the classifier blocked the `kill`.

### Code

- **`ENG/lib/engine.dart:559-568`:** `stopBottle` is `wineserver -k`, and its own comment says "no reaper; whatever survives -k (trap 6) stays".
- **`ENG/lib/engine.dart:902-910`:** `removeBottle` runs `-k` and `-w`, then deletes. A process with no server is not reached.
- **`ENG/lib/mach9.dart:596, 632, 637`:** `moveToNative` stops and removes through those two.

### How to find a bottle's processes

- **The server folder:** every Wine process of a prefix holds files in `/private/tmp/.wine-<uid>/server-<dev>-<inode>/`, where dev and inode are the prefix folder's, in hex.
  - Checked: the Games prefix is `100000d-5238dd4`, the dir of the msync service `wine-100000d-5238dd4-msync`.
- **Listing them:** `lsof -t +d <that folder>` lists the bottle's wineserver and its Windows processes. On Fifa22's `52a1511` it gave the wineserver, `services.exe`, `winedevice.exe`, `plugplay.exe` and `svchost.exe`.
- **An orphan:** a process holding such a folder while no `wineserver` holds it.
- **Caution:** Whisky, CrossOver and Mach9.app also use `/tmp/.wine-<uid>`. An orphan is Bodega's only if it maps files under `BODEGA_HOME`, as 26464 mapped `…/Bodega/runtimes/…/libSDL2-2.0.0.dylib`.

## 3 · A game that relaunches itself

### Evidence (2026-11-24, the Fifa22 bottle, Rosetta)

- The `FIFA22.exe` Bodega started wrote `# exit=255` at 14:14:25.
- A second `FIFA22.exe` (pid 4361, parent 1) ran on at 200% CPU. Bodega showed the game as closed.
- Steam does the same when it updates (exit 42), and so do launchers whose first exe starts the real one.

### Code

- **`APP/lib/app/bloc/library/library_bloc.dart:232-250`:**
  - `_follow` keeps the bottle "open" until it is idle (`firstExit`, then `waitBottle`);
  - `_followApp` marks the app closed at its first process's exit.
- **`ENG/lib/apps.dart:422-470`:** `_runPid` and `runningApps` read the run's `.pid` and `.exit`.
- **`ENG/lib/engine.dart:469-473`:** the `.pid` file holds the launch shell's pid and the app key.
- **`ENG/lib/fixes.dart:469`:** `_steamRunning` asks `tasklist` inside the bottle. It starts a Wine process each time.

### Options

- **(a) Keep it "open" until the bottle is idle.** Simple. Wrong when another program keeps the bottle alive, such as Steam.
- **(b) Look at the bottle's processes.** List them from the server folder (section 2) and keep the app "open" while one of them runs its exe's file name.
  - `ps -o command=` shows the Windows name: `FIFA22.exe` on Rosetta, `Z:\Volumes\…\FIFA22.exe` on Mach9.
  - It is cheap: one `lsof` and one `ps`, with no Wine process.

## 4 · A game hung on the Native engine

### Evidence (2026-11-24)

- On Mach9, in Bodega and in Mach9.app alike, a game stopped at 0% CPU. Its log repeated `00f4:err:sync:RtlpWaitForCriticalSection section 0000000148525EA0 "?" wait timed out in thread 00f4, blocked by 0000, retrying (60 sec)`.
- Bodega said nothing.
- The same game started on the Rosetta engine.

### Code

- **`ENG/lib/engine.dart` `enum LogHint`:** markers in a log, worded by the app. `hintsIn` is at `:662`.
- **`APP/lib/app/bloc/library/library_bloc.dart`:**
  - hints are read when the bottle closes (`:186-191`);
  - a 5-second timer (`:205-209`, `:226-229`) checks only anti-cheat during a run.
- **`APP/lib/domain/entities/run_hint.dart`:** `RunHint.log(LogHint)` and `RunHint.antiCheat`.
- **CPU:** section 2's process list gives each process's CPU through `ps -o %cpu`.

## 5 · "Open with the Rosetta engine" and the engine that works

### Evidence (2026-11-24)

By hand, the user:
1. made a Rosetta bottle, Fifa22;
2. added `/Volumes/SSD Daniel/FIFA 22/FIFA22.exe`;
3. chose D3DMetal.

The game started.

### Code

- **`ENG/lib/engine.dart:208`:** `createBottle(home, name, runtime:)`.
- **`ENG/lib/apps.dart:139`:** `addApp`. An exe outside `drive_c` works: its key is the host path, such as `/volumes/ssd daniel/fifa 22/fifa22.exe`.
- **`ENG/lib/apps.dart:44-76`:** each bottle's `hidden` list, which the library's "hide" already uses.
- **D3DMetal:** imported once per Mac (`backend list`: `d3dmetal: installed`), and chosen per bottle or per program.

## 6 · Rosetta engine performance

### Facts

- **The GPU is used:** the Fifa22 run's header is `# backend d3dmetal (bottle)`. D3DMetal turns DirectX 12 into Metal, which draws on the GPU.
- **Where the CPU goes:** under Rosetta, Wine itself and the game are both translated, while Native runs Wine natively and translates only the game. The 200% CPU seen 52 s after start also includes loading and shader compiling.
- **Bodega's Rosetta environment:** `WINEMSYNC=1`, `ROSETTA_ADVERTISE_AVX=1`, `DOTNET_EnableWriteXorExecute=0` and `MVK_CONFIG_LOG_LEVEL=2` (`ENG/lib/platform_mac.dart:88-91`).
  - AVX leaves when the bottle's `avx` is off (`ENG/lib/engine.dart:467`).
  - D3DMetal gets `D3DM_ENABLE_METALFX` only for DLSS (`ENG/lib/backends.dart:492`).
- **What the imported D3DMetal 4.0b3 reads:** among its variables, `D3DM_MTL4`, `D3DM_ENABLE_METALFX`, `D3DM_MAX_FPS`, `D3DM_SUPPORT_DXR` and `D3DM_SHOW_HUD_STATS`. Taken with `strings`.
- **Whisky (`com.franke.Whisky` 3.7.0):**
  - its app sets `D3DM_MTL4`, `D3DM_ENABLE_METALFX`, `D3DM_FEATURE_LEVEL_*`, `D3DM_SHADER_MODEL`, `ROSETTA_ADVERTISE_AVX` and several `WINE_*`;
  - the user's Whisky bottle of that game has `metal4Enabled: true`, `metalFX: true`, `avxEnabled: false` and msync.
- **Whisky's `WINE_*` do nothing here:** `WINE_CPU_TOPOLOGY`, `WINE_THREAD_PRIORITY_PRESERVE`, `WINE_MACH_PORT_*` and `WINE_DISABLE_FAST_PATH` appear nowhere in Bodega's Rosetta Wine. They belong to Whisky's own Wine.

### Measuring without sudo

- **GPU:** `ioreg -r -d 1 -w 0 -c IOAccelerator` gives `"Device Utilization %"`. It read 68 with no game running, so a baseline is needed.
- **CPU:** `ps -o %cpu` of the bottle's processes (section 2).

## 7 · Fullscreen and Retina on Rosetta bottles

### Evidence (2026-11-24)

- **The display:** the main display is the built-in Retina panel, but its current mode is 2048×1330 points at 2048×1330 pixels, which is not HiDPI. Read with CoreGraphics.
- **The bottle:** Fifa22 has `highRes: true` and `"RetinaMode"="y"` in `user.reg`.
- **The symptom:** the game's first window covered about half the width and half the height of the screen. With `FULLSCREEN = 1` at 2048×1330 in `~/Documents/FIFA 22/fifasetup.ini`, it "starts going fullscreen and does not".

### Wine 11.0's Mac driver (`dlls/winemac.drv`, tag `wine-11.0`)

- **`macdrv_main.c:377-380`:** `RetinaMode` sets `retina_enabled`, and `retina_on` starts equal to it.
- **`display.c:419`:** with `retina_enabled`, the original display mode is reported at twice its size, whether or not it is HiDPI.
- **`display.c:664-678`:** `check_retina_status` keeps `retina_on` while the mode is the original one.

So on a non-HiDPI mode, `RetinaMode=y` makes Windows see a 4096×2660 screen drawn at half size. A game's 2048×1330 fullscreen then fills a quarter of the real screen.

### Code

- **`ENG/lib/backends.dart:832`:** `setHighRes`, Rosetta's on or off.
- **`ENG/lib/backends.dart:857`:** `setRetina`. For a Rosetta bottle "auto is not offered".
- **`ENG/lib/engine.dart:489-530`:** PE4. A Mach9 bottle's `auto` follows `mainDisplayHiDpi()` and is written before each session.
- **`ENG/lib/platform_mac.dart:297`:** `highResRegistry`.
- **`APP/lib/app/presentation/bottles/widgets/bottle_column.dart:576-608`:** a Rosetta bottle shows a switch, a Native one shows the dropdown.

### Pending

- The user's run with FIFA's own borderless mode (`fifasetup.ini` now has `FULLSCREEN = 0`, `WINDOWED_BORDERLESS = 1`; the old file is kept as `.before-borderless`).
- A run with the bottle's high resolution off.

## Constraints

- **Running Wine:** agents run Wine headless, and only wineboot, `msiexec /qn` and the probe in Mach9 bottles. Games are the user's to run; measurements are taken while the user plays.
- **Mach9's tree is never touched.** The pad values go into the prefix and the launch environment.
- **Links:** never follow links inside a bottle, and stop a bottle before deleting it. A reaper kills only what maps files under `BODEGA_HOME`.
- **Copies:** D3DMetal is the user's import. No CrossOver data or code; Whisky's facts are variable names of Apple's D3DMetal, read from its binary.
- **Text:** everything in git is in English. User text goes in both ARBs and is worded only in `app/`.
- **Versioning:** `bump-version` before a commit.
- **Scope:** nothing here is specific to any game or to how a copy was obtained. The examples come from the user's runs.

## Open questions

1. **Pads on Native:** a `gamepads` value of its own for Mach9 (`DisableHidraw=1`, `Enable SDL=1`), written before a session as PE4 writes retina, plus `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1` in `wineEnv` for every Mach9 process. Should this also reach bottles already moved, such as Games?
2. **Orphans:**
   - When does Bodega reap? On stop, remove and move, and also when it starts, or before each launch?
   - Is the "maps files under `BODEGA_HOME`" rule enough to never touch Whisky's, CrossOver's or Mach9.app's processes?
3. **Relaunch:** option (b), the process list? It also serves sections 2 and 4.
4. **Hang:**
   - The thresholds: the `RtlpWaitForCriticalSection … wait timed out` line plus a minute at about 0% CPU?
   - Only on Native, or also on Rosetta, where it would suggest Native?
5. **The engine that works:**
   - After "Open with the Rosetta engine" works, should the Native entry hide itself (the existing `hidden`) or carry a mark?
   - Reuse a Rosetta bottle or always make one for the game?
6. **Performance:** the variables to try come from the measurement, `D3DM_MTL4` and AVX off first. Should section 6 be its own step after the others, since it needs the user's runs?
7. **Retina:** Rosetta bottles get `auto`, `on` and `off` like Native.
   - Does `auto` become the default?
   - What does `highRes: true` become: `on`, or `auto`?
   - Should `on` be refused, or warned about, on a display mode that isn't HiDPI, where Wine's doubling is always wrong?
8. **Size:** seven items is a large change. Split it into two: first 1, 2, 7 and 3 (bugs with evidence), then 4, 5 and 6 (new behavior and measurement)?
