# Tasks: catalog

**Conventions.** `P` = `bodega/packages/engine`; `T` = `Bodega/runtimes/terceros`. **(USER)**: you do it. The agent does not commit or push, and does not run downloaded installers. Tests without Wine: `cd P && dart test -N '<nombre>'`.

## Engine
- [x] **T1** `lib/backends.dart`: pin of the DXMT fork, `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN` (A3) and the `d3d9.dll` rule in `auto` (A4), with tests `backendEnv` and `resolve`.
  **Check:** `dart test -N backendEnv` and `dart test -N resolve`.
- [x] **T2** Settings: `_settings` with `sync` and per-program `env`; `setBackend` keeps them; `setSync` (A1, A2), with test `settings`.
  **Check:** `dart test -N settings`.
- [x] **T3** `_launchIn` applies the A2 order and `WINEMSYNC`, with a check in `fake runtime cycle` (the fake Wine saves its environment).
  **Check:** `dart test -N 'fake runtime'`.
- [x] **T4** `lib/catalog_data.dart`: the 7 entries, read from `HBDB/recipes/launchers/*.json` at `f0bf6a2`, with notes in Spanish and `source` (C1, C2). `lib/catalog.dart`: types, `catalogEntries` (C3). Tests `catalog data` and `catalogEntries`.
  **Check:** `dart test -N catalog`.
- [x] **T5** `_download` with HTTPS, `.part` and no `sha256` (I3; `design.md` §5), preserving `installBackend`.
  **Check:** `dart test -N installBackend`.
- [x] **T6** `installEntry` (I1, I2, I4–I8, I10) and test `installEntry` with a fake Wine: blocked, missing backend, existing bottle, `http://`, wrong SHA, MSI, exit 194, exit 5, no exe, registry, a server that does not exit and a server that exits.
  **Check:** `dart test -N installEntry`.
- [x] **T7** `installedApps` and `openApp` (I8, I9), with test `installedApps`.
  **Check:** `dart test -N installedApps`.
- [x] **T8** CLI: `catalog list|show|install`, `apps`, `open`, `sync`, and updated usage. Wrong usage gives 64.
  **Check:** `dart analyze`; `dart test`; `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`; `build/bodega catalog list` shows all 7 with their status; `catalog list STEAM` gives one; `catalog show steam`; `catalog show nope; echo $?` gives 1; `catalog install epic-games; echo $?` gives 1 with its reason; `catalog; echo $?` gives 64.

## Windowless check with the real runtime
With a temporary `BODEGA_HOME`: first `stop`, then `rm -rf`.

- [x] **T9** Runtime, `create t`, `backend install dxmt T/dxmt-highball-20261017T231707Z-331c552.tar.gz` and `backend test t dxmt`. `sync t none`; `run --backend dxmt t cmd /c set`: the log has `WINEMSYNC=0` and `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`. `sync t msync`: another `run` works. A test in the `real runtime` group calls `installEntry` with the probe as the "installer" (`file://`), a registry value and `exe` `windows/system32/notepad.exe`: `app.json` is written, `reg query` shows the value in the registry, and no processes are left.
  **Check:** output pasted in `verify`. The probe exits immediately, so it does not exercise a real installer; that is U3.
- [x] **T10 (USER)** Commit in `bodega`. The agent leaves `~/Documents/GitHub/Bodega/catalogo-commit.sh`, with no AI attribution and no push.
  **Check:** `git -C bodega log --oneline -1`.

## User acceptance
With windows, on your Mac. I will give you the commands ready to copy.

- [x] **U1** Switch DXMT in your real folder: `rm -rf ".../Bodega/backends/dxmt"`, `backend install dxmt T/dxmt-highball-…tar.gz` and `backend test prueba dxmt`. **Expected:** `OK` in 64 and 32 bits.
- [~] **U2 (right backend and exit 0; you still need to confirm it plays the same)** Blur without options: `run prueba ".../Blur.exe"`. **Expected:** it prints `backend wine (auto)` and runs as before.
- [x] **U3** **The deciding test:** `catalog install steam` and `open steam`. The first launch can take 15–25 min and look frozen. **Expected:** it installs, and the Steam window opens without staying black; you can log in. If you can, install a small free game and open it.
- [ ] **U4 (optional, not done)** Optional: `catalog install rockstar` or `ea-app`, and `open`. **Expected:** a visible login window.
- [ ] **U5** `catalog list`, `catalog show steam` and `apps`. **Expected:** the information is clear and `apps` lists what is installed.

## Added after U3
- [x] **T12** Easy Anti-Cheat notice (I11): `antiCheatHints`, the check in `run` and `open`, and test `antiCheatHints`.
  **Check:** `dart test -N antiCheatHints`; with a temporary `BODEGA_HOME`, a log written during a `run` prints `pista:` ("hint:") before the run finishes.

## After the tests
- [x] **T11** With the result of U3 and U4, update `status` and `statusNote` in `lib/catalog_data.dart` (`tested` with a date, or the cause if it failed), and leave the commit script.
  **Check:** `dart test -N 'catalog data'`.
