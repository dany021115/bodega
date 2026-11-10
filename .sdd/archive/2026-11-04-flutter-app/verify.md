# Verification: flutter-app

2026-11-04, M2 Pro, macOS 27.0.1. Base `628be6b`, the T17 commit, plus this phase's changes in `.sdd/`. No code changes in `verify`.

## Engine

| Requirement | Status | Evidence |
|---|---|---|
| E1 Workspace | met | `dart test` and `dart compile exe` in output 2 |
| E2 `listBottles` | met | Test `listBottles`: ready with an application, ready without one, and incomplete. Real data in output 6 |
| E3 `bottleSettings` | met | Test `settings`; real in output 6 |
| E4 `removeBottle` | met | Test `removeBottle`: the outside link survives and a bottle that does not exist gives an error. Real: `DELETED true`, output 6 |
| E5 Rosetta and runtime | met | Test `hasRuntime`; output 4 shows that the app passes the check |
| E6 Downloaded installer | met, with a limit | Test `installEntry with a downloaded setup`. Only with a fake Wine: see U3 |
| E7 `bottleLogs` | met | Test `bottleLogs`; real in output 6 |
| E8 `addApp` | met | Test `addApp`, inside and outside `drive_c`; your real Blur in U5 |
| E9 `pinnedBackend` | met | `backends_test.dart:96-98`; real DXVK download with that SHA, output 6 |

## Foundation

| Requirement | Status | Evidence |
|---|---|---|
| B1 Project | met | Output 3. Opened with `open`, the app launches the engine with its environment: output 4. Real Wine from the app: the U1 logs, with `flutter run` |
| B2 Layers | met | `check_layers.sh` passes, and fails with each broken rule (output 5). No relative imports and no file in `widgets/` with two widgets (output 3) |
| B3 Theme | met | Test `ThemeBloc`; output 3 |
| B4 Router | met | Test `router`; output 3 |
| B5 Breakpoints | met | Test `MainShell` at 1000 and 600 px; same values as TeeShot (output 3); 36 screen tests with no overflows |
| B6 Errors | met | Repository test; real engine messages in output 6 |
| B7 Injection and generated code | met | build_runner and `flutter analyze` clean; output 3 |
| B8 Assets | met, with a deviation | 7 SVGs with `spider`. Deviation 3 |
| B9 Rules | met | `.claude/CLAUDE.md` and its 3 rules; they name the versions and the layers (output 3) |

## Screens

| Requirement | Status | Evidence |
|---|---|---|
| P1 Rosetta and runtime | met, with a limit | Test `SetupBloc`, the 4 cases. Nobody has gone through this screen with real files: your runtime was already installed |
| P2 List and search | met | Tests `CatalogBloc` and `the 7 of the catalog`; your real search in U2 |
| P3 Detail page | met | Test `the detail offers each case`, the 4 buttons |
| P4 Install | met, with a limit | Tests `InstallBloc`, the 5 cases, and `Downloader`, with real HTTPS in output 7. Real install of a launcher: see U3 |
| P5 Anti-cheat | met, with a correction | Tests `AntiCheatRepository`, the 3 cases; 1,166 real games (output 7). Deviations 2 and 4 |
| P6 List | met | Test `LibraryBloc`, list and empty |
| P7 Open and stop | met | Tests `LibraryBloc`, the 4 cases; real U1 logs |
| P8 Warnings | met, with a limit | Test `a hint comes out once`; the 5 s timer, with a fake clock, in output 8; 3.8 ms per read in output 9. No real game: see U8 |
| P9 Another application | met, with a limit | Tests `AddAppBloc`, including the 3 cases; your Blur in U5. Installer with the real bottle, but using the probe: output 6 |
| P10 Bottle list | met | Test `a bottle says what it is` |
| P11 Detail | met | Tests `BottleDetailBloc`, the 4 cases, and the repository with 2,000 lines; real in output 6 |
| P12 Backends | met | Tests `BackendsBloc`; real download, wrong SHA and no leftovers: output 6 |
| P13 D3DMetal | met | Test `D3DMetal is imported, never downloaded`; real import and CrossOver rejection: output 6 |
| P14 Check | met | Test `BackendsBloc`; real DXMT (output 6) and your real D3DMetal (U7) |

## User acceptance

You said everything went well. This is what those tests left on disk, because for the rest I only have your word.

| Test | Result | Evidence on disk |
|---|---|---|
| T17 Commit | done | `628be6b`, with your identity and no AI attribution. The only `claude` in the message is the `.claude` folder |
| U1 Library | accepted | Steam logs at 15:53, 15:59 and 16:01 UTC, with `backend dxmt (exe)`. The last one exits with 1, as expected when it is stopped |
| U2 Catalog | accepted | `cache/anticheat.json` created at 10:58: there was a real search |
| **U3 Install** | **unconfirmed** | **No bottle from another launcher.** Steam is from November 3, through the CLI. `downloads/` changed at 11:00, so something was downloaded, and it may have been deleted afterwards |
| U4 Cancel | accepted | `downloads/` empty, with no `.part` and no extra bottle. This is consistent with it, but does not prove it |
| U5 Another application | accepted | Bottle `games`: `custom`, `Blur.exe`, `exit=0`, `backend wine (auto)`. **Its title is `Games`, not `Blur`** |
| **U6 Bottles** | **unconfirmed** | **Neither `prueba` nor `games` has a `settings.json`, and the one in `steam` is from November 3.** Changing the backend always writes it, so the change was not made in these three. No bottle has been deleted since 12:12 either |
| U7 Backends | accepted | D3DMetal in `games`: `probe-64`, `probe-64` and `probe-32`, all with `exit=0` and `backend d3dmetal (opcion)` |
| **U8 Anti-cheat** | **not run** | No bottle has an `EasyAntiCheat` folder: there is no game to test it with. Reading the log was tested with the CLI in `catalog`; its wiring into the app only with mocks |
| U9 Reopen | accepted | It leaves no trace: only your word. The mechanism is in the test `rebuilds what is running` |

## On archiving

Archived with your approval and with this still open:

- **U3, U6 and U8:** unconfirmed, and left unchecked in `tasks.md`.
- **The `Games` title of your Blur:** it is not known whether you typed it. The default title comes from the file name and no code path gives `Games`, but a bug has not been ruled out.

## Deviations

1. **Download:** `Downloader` reads the stream by hand instead of using `dio.download`, and asks for `identity`. `design.md` §4 already says so. Its tests are in `test/data/downloader_test.dart`, not in a repository test, because two repositories use it.
2. **Anti-cheat:** the cache is read before the network, because the list is pinned to a commit and does not change. The 3 scenarios of P5 are met.
3. **Colors:** in the dark theme, brand colors are lightened by 25%, and Epic's `313131` counts as black. Otherwise they would barely be visible.
4. **POLYGON:** the spec said it was not on the list, and it is. P5 is already corrected.
5. **`Incompleta`** ("Incomplete"): it only means an unfinished prefix, as E2 says. `design.md` §6 said something else and is already corrected.
6. **EAC reads:** they are not limited to when the log changes. Measured: there is no need (output 9).
7. **Additions that were not in the spec:** `Parar` ("Stop") in the bottle detail, `El instalador ya terminó` ("The installer has finished"), the theme button and the initial 1100×720 window.
8. **Dependencies removed:** `package_info_plus` and `cupertino_icons`, unused.

## Not checked

- Installing a real launcher from the app (U3), and a real installer with a window through `Es un instalador` ("It's an installer").
- `Comprobar` ("Check") with `wine` and `dxvk` from the app; they were tested with the CLI in `graphics-backends`.
- The pickers `Elegir archivo…` ("Choose file…"), `Elegir carpeta…` ("Choose folder…") and the ones in `/setup`, with real files.
- Apple's current D3DMetal image; only the Whisky and Sikarugir copies, which is why the screen warns about it.
- How it looks. The agent does not judge that.

## Outputs

### 1. App
```
$ flutter analyze
No issues found! (ran in 2.1s)
$ flutter test
00:03 +112: All tests passed!
per-test results (--reporter json): {'success': 112}; 36 screen tests at 720, 801, 1100 and 1921 px, all correct
$ tool/check_layers.sh
Capas correctas
exit=0
$ flutter build macos
✓ Built build/macos/Build/Products/Release/Bodega.app (48.9MB)
```

### 2. Engine
```
$ dart analyze
No issues found!
$ dart test
00:18 +30 ~2: All tests passed!
$ dart compile exe bin/bodega.dart -o ../../build/bodega
Generated: /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
$ build/bodega catalog list
steam             Steam                     tested
rockstar          Rockstar Games Launcher   reported
ea-app            EA app                    reported
ubisoft-connect   Ubisoft Connect           reported
battle-net        Battle.net                untested
epic-games        Epic Games Launcher       blocked
gog-galaxy        GOG Galaxy                blocked
```

### 3. Cross-check against the code
```
B1  10: self.minSize = NSSize(width: 720, height: 480)
    Release.entitlements:0  DebugProfile.entitlements:0   (app-sandbox)
    <window title="Bodega"   PRODUCT_NAME = Bodega   PRODUCT_BUNDLE_IDENTIFIER = com.dany021115.bodega
B2  files in widgets/ with more than one widget: none.  relative imports: 0
B3  color.dart radius.dart spacing.dart theme.dart typography.dart
    static String? get fontFamily => null;
    super(ThemeState(isDark: preferences.getDarkTheme() ?? true))
B4  27: enum AppRoute   40: setupRedirect   54: StackObserver   55: refreshListenable   72: ShellRoute
    manager.dart observer.dart transitions.dart
B5  Bodega and TeeShot: 0-450 MOBILE, 451-800 TABLET, 801-1920 DESKTOP, 1921+ 4K
B6  AppError.engine = EngineError, .network = NetworkError, .unknown = UnknownError
B7  build.yaml: explicit_to_json, include_if_null   .gitignore: *.g.dart *.freezed.dart *.config.dart
    @preResolve   @InjectableInit(initializerName: 'init', asExtension: true)
B8  7 SVG   lib/resources/assets_catalog_icons.dart
B9  .claude: CLAUDE.md rules/{architecture,code-style,widget-standards}.md
```

### 4. Release build opened with `open`
Empty folder:
```
dart_ran=yes after=2s dirs=bottles runtimes
new_pid=30030 alive=yes rss_mb=120
log: Using the Impeller rendering backend (MetalSDF).
stopped=yes others_kept=[25779 ] now=[25779 ]
new_crash_reports=0
```
Temporary folder with a fake `wineserver` that records how it is called:
```
engine_called=yes after=1s
args: -w
HOME=~
LOGNAME=quasar
PATH=/usr/bin:/bin:/usr/sbin:/sbin
TMPDIR=(present)
USER=quasar
WINEMSYNC=1
WINEPREFIX=<home>/bottles/una/prefix
env_vars=16
```
An earlier attempt with your real data, looking for `wineserver` every 0.1 s, saw 0 processes. It proves nothing: with no server it lasts about 0.03 s. That is why the fake `wineserver` test was done.

### 5. Layer check with each rule broken
In temporary copies. The last line is an allowed import, as a control:
```
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (dart:io)
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (flutter)
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (data/)
exit=1 NO: solo data/ importa package:engine   (app/)
exit=1 NO: solo data/ importa package:engine   (device/)
exit=1 NO: device/ no importa data/ ni domain/
exit=1 NO: solo data/ importa package:engine   (main.dart)
exit=1 NO: imports absolutos: package:bodega/...
exit=0 Capas correctas
```

### 6. Real repositories, milestone 3
With a temporary test, since deleted. The bottle was created and deleted in your real folder; the downloads and imports went to a temporary folder:
```
BOTTLE prueba ready=true app=null
BOTTLE steam ready=true app=Steam
DETAIL backend=auto sync=none exceptions=[ProgramBackend(exe: steam.exe, backend: dxmt)] logs=8 installed=[wine, dxmt, dxvk, d3dmetal]
LOG 2026-11-04T16-01-38.949831Z-steam.log exit=1 lines=99 size=6335 ms=7
DOWNLOAD true last=(2785833, 2785833) d3d11=true
AGAIN ya instalado: …/backends/dxvk. Para cambiarlo: rm -rf "…/backends/dxvk"
BADFILE AppError.engine(message: checksum incorrecto en …/dxmt-falso.tar.gz: e1c1b2e9…, se esperaba 89e731b8…)
DXMT_INSTALLED false TMP false
IMPORT true null ms=75 link=../../external/libd3dshared.dylib
CROSSOVER no se importa desde CrossOver.app: usa tu propia copia de D3DMetal
CREATED zz-prueba-app ms=13364
FREE [prueba, zz-prueba-app]
SET true true
EXC true
DETAIL dxmt none [ProgramBackend(exe: probe-64.exe, backend: dxvk)]
RESET auto msync []
INSTALLER true ms=7513 drive=true
ADDAPP true null
LIBRARY [steam:steam:Steam, zz-prueba-app:custom:Zz Prueba: App!]
CHECK ms=2791 [64/D3D11=true, 32/D3D11=true]
LOGS [2026:0, 2026:0, 2026:0, 2026:0]
DELETED true exists=false rootOk=true
```

### 7. Real repositories, milestone 2
```
LIB [LibraryApp(bottle: steam, id: steam, title: Steam)]
WAIT steam 752 ms
FIRST_EXIT 2271 ms exit=3
EMPTY 5339 ms
ANTICHEAT 1166 … blocked=31 polygon=1
CACHE 251114 bytes
CANCEL returned=null part=false
RESUME first=(101378, 251114) last=(251114, 251114) same=true
REDIRECT size=251114
HTTP refused
```

### 8. P8 timer
With a fake clock and a temporary test, since deleted. It checks at 5 and 10 s, always with the same opening time, once more on close, and never in the following 30 s:
```
P8 checks=3 atClose=3 hintsIn=1
00:00 +1: All tests passed!
```

### 9. Reading the EAC log
20 reads of a synthetic log:
```
size=614525 hints=1 median=3.815 ms max=12.523 ms
```

### 10. Traces in your real folder
```
games | 2026-11-04T17-17-33.872514Z-probe-32.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-17-28.556041Z-probe-64.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-16-55.986537Z-probe-64.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-12-58.592738Z-Blur.log | exit=0 | # backend wine (auto)
games | 2026-11-04T17-12-39.049315Z-wineboot.log | exit=0 |
steam | 2026-11-04T16-01-38.949831Z-steam.log | exit=1 | # backend dxmt (exe)
steam | 2026-11-04T15-59-58.610277Z-steam.log | exit=0 | # backend dxmt (exe)
steam | 2026-11-04T15-53-14.001090Z-steam.log | exit=0 | # backend dxmt (exe)
games app.json: {'id': 'custom', 'title': 'Games', 'exe': '/Users/quasar/Documents/Games/Blur/Blur.exe', …}
settings.json: games no, prueba no, steam 14:29 on November 3
folders (local time): bottles 12:12, bottles/games 12:12, downloads 11:00, cache 10:58
EasyAntiCheat folders across all bottles: 0
```
