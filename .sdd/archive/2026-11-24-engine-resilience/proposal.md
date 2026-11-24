# Proposal · engine-resilience

## Why

On 2026-11-23 and 2026-11-24 seven things made Bodega look unreliable with games it can run (exploration):

- a pad needed hand-set values on the Native engine;
- a leftover process of a deleted bottle took the pad from every other bottle;
- a game that relaunches itself showed as closed;
- a hang on the Native engine went unannounced;
- moving a game to the Rosetta engine took four manual steps;
- nobody could tell how the Rosetta engine uses the CPU and the GPU;
- Rosetta's high resolution broke fullscreen on a display mode that isn't HiDPI.

None depends on one game.

## What

Two parts, applied and checked in this order. Part A fixes what has evidence; part B adds behavior.

### Part A

1. **Pads on the Native engine (ER1).** Every Mach9 bottle gets the winebus values Mach9's SDL3 needs (`DisableHidraw=1`, `Enable SDL=1`, `DisableInput=0`), written before a session as retina is (PE4).
   - Every Mach9 process gets `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`.
   - A bottle already moved, such as Games, gets them at its next session.
2. **A bottle's processes, and orphans (ER2, ER3).**
   - Bodega lists a bottle's processes from its wineserver folder.
   - Stopping, removing and moving a bottle end whatever survives `wineserver -k`.
   - When the app starts, it ends Wine processes left by Bodega's bottles that no longer have a wineserver.
   - It never touches a process that maps nothing under Bodega's home: Whisky's, CrossOver's and Mach9.app's are safe.
3. **A game that relaunches itself stays open (ER4).** After its first process exits, an app stays open while a process of its bottle runs its exe's file name.
4. **Retina on Rosetta bottles as on Native (ER7).**
   - Rosetta bottles take `auto`, `on` and `off`, written before each session; `auto` follows the main display's mode.
   - New bottles of both engines start on `auto`.
   - An old `highRes: true` becomes `auto` and `false` becomes `off`.

### Part B

5. **A hang on the Native engine is announced (ER5).** The log's `wait timed out in thread` line, plus a minute with the app's processes at about 0% CPU, gives a hint with two actions: "Close" and "Open with the Rosetta engine".
6. **"Open with the Rosetta engine" (ER6).** For an app whose exe lives outside any bottle, one click:
   - uses a Rosetta bottle that already has that exe, or makes one named after the game;
   - adds the exe, with D3DMetal for DirectX 11 and 12 when it is installed;
   - hides the Native entry, with the library's existing hide, so the library shows the one that works.
7. **Rosetta performance, measured (ER8).**
   - `bodega measure <bottle> [seconds]` prints, each second, the bottle's CPU and, on the Mac, the GPU's utilization.
   - A Rosetta bottle may turn on D3DMetal's Metal 4 (`D3DM_MTL4=1`), off by default.
   - Defaults change only after the user's measured runs.

## Decisions taken on the open questions

These are defaults that the user can change at this gate.

1. **Pads (Q1):** existing Mach9 bottles included.
2. **Orphans (Q2):**
   - Reaped on stop, remove and move, and once when the app starts. Not before every launch, which would cost time.
   - A process is Bodega's only when it maps a file under `BODEGA_HOME`.
3. **Relaunch (Q3):** option (b), the process list, which ER2 and ER5 share.
4. **Hang (Q4):** the log line plus 60 s at under 2% CPU on average.
   - The hint shows on both engines.
   - "Open with the Rosetta engine" shows only on Native.
5. **The engine that works (Q5):**
   - Hide the Native entry; the user can show it again.
   - Reuse a Rosetta bottle that already has the exe.
6. **Performance (Q6):** part B, with the measurement before any default changes.
7. **Retina (Q7):**
   - `auto` is the default;
   - `highRes: true` becomes `auto`, because on a HiDPI mode `auto` is on, and on any other mode on is wrong (exploration §7);
   - `on` stays on, as on Native, with no warning.
8. **Size (Q8):** one change in two parts. Part A is applied, checked and tried by the user before part B starts.

## Impact

- **Engine:** gamepads and the launch environment for Mach9; a process list per bottle (macOS with `lsof`, Linux with `/proc`); the reaper; the relaunch rule; retina for both runtimes and its migration; a log hint; "open with Rosetta"; `bodega measure`; one D3DMetal option.
- **App:** the retina dropdown for Rosetta bottles; apps that stay open; the hang hint with its actions; a menu item; a Metal 4 switch; a toast when orphans were ended; texts in English and Spanish.
- **Compatibility:**
  - `settings.json` keeps `highRes` readable and writes `retina`;
  - a `gamepads` value of 3 is new, and an older Bodega reads it as unknown and sets its own again.
- **Not in it:**
  - anything specific to one game or to how a copy was obtained;
  - Whisky's `WINE_*` variables, which Bodega's Wine does not read.
