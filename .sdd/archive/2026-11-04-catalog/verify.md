# Verification: catalog

2026-11-04, M2 Pro, macOS 27.0.1. Base `83934de` plus T11 and T12, uncommitted. `H` is a temporary `BODEGA_HOME`, since deleted.

| Requirement | Status | Evidence |
|---|---|---|
| C1 Data | met | Test `catalog data`; 7 entries in order |
| C2 Statuses | met | `catalog list`; Steam becomes `tested` after U3 |
| C3 List and search | met | Outputs below; test `catalogEntries` |
| C4 Detail | met | `show steam`; `show nope` exits with 1 |
| I1 Checks | met | Blocked entries and a missing backend exit with 1 without creating a bottle; test `installEntry` |
| I2 Order | met | Real Steam install; test `installEntry` |
| I3 Download | met, with a limit | Real HTTPS download of Steam with its warning; `http://` and wrong SHA in a test. `--proto-redir` was not exercised with a real redirect |
| I4 Installer | met, with a limit | Real Steam; 194 and 5 in a test. **MSI only with the fake Wine:** Epic, the only MSI, is blocked |
| I5 Registry | met | `reg query` with the real Wine in `real runtime` |
| I6 Wait and stop | met | Test `waits for the server`; the real Steam install finished and the first launch was a cold start |
| I7 Check | met | Test `missing exe` |
| I8 Library | met | `bodega apps` in your real folder lists `steam` |
| I9 Open | met | Real `open steam`: `backend dxmt (exe)` |
| I10 Progress and notes | met | Output of your `catalog install steam` |
| I11 EAC notice | met, with a limit | Test with lines from the real log, and a live test with the CLI. The real log no longer exists. It does not warn if `open` has already returned |
| A1 Per-bottle msync | met | `WINEMSYNC=0` and `=1` read inside Wine; repeating stops nothing; `foo` rejected |
| A2 Per-program variables | met | Tests `settings` and `installedApps` |
| A3 Patched DXMT | met | Installed with its SHA; `OK` in 64 and 32 bits; variable present; Muck ran with it |
| A4 Auto and D3D9 | met | Test `resolve`; your Blur printed `backend wine (auto)` |

## User acceptance

| Test | Result | Evidence |
|---|---|---|
| U1 DXMT in your folder | OK | `OK` in 64 and 32 bits |
| U2 Blur | Partial | `backend wine (auto)` and exit 0; your confirmation that it plays the same is still missing |
| U3 Steam | **OK** | Installs, opens, logs in, downloads and launches games |
| U3 Muck (AppID 1625450) | **OK, according to the user** | 09:44:15 to 09:47:50 through Steam. `Player.log`: `Direct3D 11.0 [level 11.1]`, `Renderer: Apple M2 Pro`; backend `dxmt` |
| U3 POLYGON (AppID 1241100) | **Fails** | EAC: `Failed to map the anti-cheat module`, error 206, after requesting the `linux64` module. The user confirms it also fails in CrossOver |
| U4 Another launcher | Not done | Optional |
| U5 List and detail | Checked by the agent | `catalog list`, `show steam` and `apps`; your opinion on whether it is clear is still missing |

## Observations

- **Only Steam is tested.** Rockstar, EA, Ubisoft and Battle.net remain `reported` or `untested`.
- **No FPS:** Muck "went fine" according to the user, with no measurements or comparison with CrossOver. The cost of running without msync in that bottle has not been measured.
- **`open` returns early if the launcher relaunches itself:** during the Steam update it exited with `exit=42` while Steam kept running. The Flutter app must track the bottle, not that process.
- **No H.264:** `GStreamer doesn't support H.264 decoding` in the Steam log. Some videos may not play.
- **Other errors in the Steam log with no visible effect:** `Steam Client Service` does not start and `gldriverquery.exe` cannot find `SDL2.dll`.
- **DXMT fork:** a third-party binary, pinned by SHA-256, not built by us.

## Outputs

```
$ dart analyze
No issues found!
$ dart format (check)
Formatted 7 files (0 changed) in 0.04 seconds.
$ dart test
00:14 +24 ~2: All tests passed!
backendEnv      +1: All tests passed!
resolve         +1: All tests passed!
settings        +1: All tests passed!
installBackend  +1: All tests passed!
catalog data    +1: All tests passed!
catalogEntries  +1: All tests passed!
installEntry    +8 ~1: All tests passed!
installedApps   +1: All tests passed!
antiCheatHints  +1: All tests passed!
fake runtime    +1: All tests passed!
$ compile
Generated: build/bodega
$ bodega catalog list
steam             Steam                     tested
rockstar          Rockstar Games Launcher   reported
ea-app            EA app                    reported
ubisoft-connect   Ubisoft Connect           reported
battle-net        Battle.net                untested
epic-games        Epic Games Launcher       blocked
gog-galaxy        GOG Galaxy                blocked
-> 0
$ catalog list STEAM / zzz
steam             Steam                     tested
-> 0
$ catalog show steam
Steam (steam)
estado: tested: Probado en Bodega el 2026-11-04 (M2 Pro, macOS 27.0.1): instala, abre, inicia sesión, descarga
backend: dxmt, sync: none
fuente: gauthierpiarrette/highball-db f0bf6a2, recipes/launchers/steam.json (CC0-1.0); verificado: 2026-08-24,
$ catalog show nope
bodega: no está en el catálogo: nope (bodega catalog list)
-> 1
$ catalog install epic-games / gog-galaxy (blocked)
bodega: Epic Games Launcher está bloqueada: Comprueba permisos de Windows que Wine no guar
-> 1
bodega: GOG Galaxy está bloqueada: Se instala, pero en Wine 11 muestra el inicio de sesión
-> 1
       0
$ wrong usage
catalog -> 64
open -> 64
sync x -> 64
install a b c -> 64
$ install + create + sync
H/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
create -> 0
H/backends/dxmt
OK    D3D11 64 bits  
OK    D3D11 32 bits  
-> 0
$ catalog install rockstar with dxvk missing
bodega: dxvk no está instalado: bodega backend install dxvk
-> 1
       0
botella detenida
sync none -> 0
repeated -> 0
bodega: sync desconocido: foo (msync, none)
run -> 0
backend dxmt (opcion)
DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1 WINEMSYNC=0 
botella detenida
run -> 0
WINEMSYNC=1
DXMT_ALLOW in wine: 0
stop -> 0
$ real runtime
create: 0:00:11.909168
install: 0:00:20.573848
00:41 +2: All tests passed!
$ your real folder
steam  Steam  Program Files (x86)/Steam/steam.exe
apps -> 0
wine: instalado;dxmt: instalado;dxvk: instalado;d3dmetal: instalado;
steam             Steam                     tested
```
