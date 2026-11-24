# Design · engine-resilience

## D1 · A bottle's processes

- **The server folder:** a Wine process of the prefix `P` holds files in `/tmp/.wine-<uid>/server-<dev>-<ino>/`, where `<dev>` and `<ino>` are `P`'s `st_dev` and `st_ino` in lower-case hex without padding. On macOS `/tmp` is `/private/tmp`.
  - Checked: Games → `server-100000d-5238dd4`; Fifa22 → `server-100000d-52a1511`.
- **Listing, behind `HostPlatform.wineProcesses(prefix)` and `orphanWineProcesses(home)`, each process with `pid`, `cpu` and `command`:**
  - **macOS:** one `ps -axo pid=,%cpu=,command=` picks the Wine processes, those running an `.exe` and the wineservers. Then one `lsof -p <them> -Fn` gives each its files, and the first under `/private/tmp/.wine-<uid>/server-*` is its server folder.
    - Changed in apply, 2026-11-24: Mach9's processes only map their `tmpmap-*` file, which `lsof +d` does not list. On a real Mach9 session it showed only the wineserver, while `lsof -p` shows all six.
  - **Linux:** each `/proc/<pid>/environ` of this user whose `WINEPREFIX` is `P`. `lsof` may be missing there.
- **The program's name:** the last part of `command` after `\` or `/`, lower-cased. Wine shows `FIFA22.exe` on Rosetta and `Z:\Volumes\…\FIFA22.exe` on Mach9; both give `fifa22.exe`.
- **The wineserver:** a process whose command ends in `/wineserver`.

## D2 · The reaper

- **After `stopBottle` and `removeBottle`:**
  - their `-k` and `-w` stay;
  - then any process D1 still lists for the bottle gets SIGTERM, up to 3 s, then SIGKILL;
  - `moveToNative` goes through them.
- **Orphans: `reapOrphans(home)`.** D1's listing grouped by server folder:
  - skip a group with a wineserver;
  - otherwise end each member with a file under `home` in the same `lsof` output (`lsofNamesUnder`);
  - it returns what it ended (pid and name).
  - On Linux the rule is a prefix under `home` with no wineserver among its processes.
- **Safe by construction:**
  - a Whisky, CrossOver or Mach9.app process maps their own Wine, not Bodega's;
  - a live bottle has its wineserver, so its processes are never orphans.

## D3 · Staying open after a relaunch

- **The `.pid` file:** gains a third line, the program's file name lower-cased. An old two-line file means the old rule, closed at the first exit.
- **`appStillRunning(home, bottle, log)`:** true while D1 lists, in the bottle, a process whose name is that file name.
- **In the app:** `_followApp` waits for the first exit, then asks every 5 s until false, then marks the app closed. The bottle's own "open" is unchanged.

## D4 · The hang

- **`LogHint.stuckLock`:** its marker is `wait timed out in thread`, Wine's `RtlpWaitForCriticalSection` error, which comes only after 60 s of waiting.
- **`runHung(home, bottle, log)`:** true when:
  - the log holds the marker;
  - the app's processes (D3's name) average under 2% CPU over the last 60 s.
  - `ps`'s `%cpu` is a decaying average. Bodega keeps the last 12 samples of the 5-second timer and averages them.
- **In the app:** the hint is `RunHint.hung(bottle, key, native)`. Its actions are "Close", which is `stopApp`, and "Open with the Rosetta engine" when `native`.

## D5 · Open with the Rosetta engine

**`openWithRosetta(home, bottle, key)`** for an app of a Mach9 bottle whose program is a host path, not inside any bottle's `drive_c`.

1. **The target bottle:** a Rosetta bottle with an app of the same host path (compared as `addApp` keys it); otherwise a new Rosetta bottle named after the app's title, made unique with ` 2`, ` 3` and so on.
2. **The app:** `addApp` with the same title and path, when the target lacks it.
3. **The backend:** the program's DirectX from the PE scan the library already shows (`DX11` or `DX12`). With D3DMetal installed it becomes the program's backend there; otherwise the bottle's `auto`.
4. **The source entry:** its key goes into the source bottle's `hidden`.
5. **The result:** `(bottle, key)` of the target, which the app opens.

An app inside a bottle's `drive_c` does not offer it: its installation lives in that prefix.

## D6 · Retina for both runtimes

- **One setting:** `retina` (`auto`, `on`, `off`) for both runtimes.
  - `_syncRetina` runs before a Rosetta session as before a Mach9 one.
  - `highRes` is read only to migrate: a bottle with `highRes` and no `retina` gets `auto` for true and `off` for false, saved at the next write.
- **The API:** `setHighRes` stays as `setRetina(on|off)`; `setRetina` takes `auto` for Rosetta.
- **The app:** the dropdown of PA1 for both engines on the Mac, where the new capability `retina` is true.
  - Linux, where high resolution is only `LogPixels` and `auto` would always be off, keeps the switch. It no longer asks to close the bottle, since the next session takes the value.
  - `highRes: true` reads `on` there.
- **Older readers:** a Rosetta bottle with retina not `off` keeps writing `"highRes": true`, and `retina` only when it differs from what that implies. So an older Bodega, and MB1's byte-for-byte legacy file, keep working.
- **`setHighRes(true)` on Rosetta:** it means what `highRes` reads back as (`auto` on the Mac), and does nothing when it already is.
- **The default:** `auto`, already the default of `retina` (`backends.dart:511`).

## D7 · Pads on Mach9

- **The registry:** `_syncGamepads`, beside `_syncRetina`, runs before a Mach9 session that is not running. When `system.reg` lacks any of `"DisableHidraw"=dword:00000001`, `"Enable SDL"=dword:00000001` and `"DisableInput"=dword:00000000` under `winebus`, `reg add` writes them and `gamepads` becomes 3.
- **The environment:** `wineEnv`'s Mach9 branch adds `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`.
- **`moveToNative`:** drops `gamepads`.

## D8 · Measuring

- **`bodega measure <bottle> [seconds=60]`:** each second it prints `t`, the bottle's CPU (the sum of D1's `%cpu`), its busiest process, and on the Mac the GPU's `Device Utilization %` from `ioreg -r -d 1 -w 0 -c IOAccelerator`.
  - On Linux there is no GPU column.
  - It ends with the averages.
- **`metal4`:** a bottle setting, false by default. A Rosetta launch whose backend is `d3dmetal` gets `D3DM_MTL4=1` when it is true.
