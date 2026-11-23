# Design · dependencies

Paths: `engine/` is `packages/engine/`, `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`; other paths start at the repo root. Line numbers are those of `feat/switch-keys-firmware` at 40faa18 (`1.7.0+15`).

## 1. Files and layers
- `engine/lib/dependencies.dart`, a new `part of 'engine.dart'` (one more `part` line, `engine.dart:14-24`): the runtime table (§2), reading a program (§3), proposals (§4), install and status (§5).
- `engine/lib/bodega_fixes_data.dart`, a new library imported by `engine.dart` as `fixes_data.dart` is: Bodega's own per-game entries, hand-written, as one JSON text (`dart compile exe` carries no assets, `fixes_data.dart:2-3`) (§6).
- `engine/lib/fixes.dart`: the `ini` step, `exes`, `requires`, a nullable `steam`, matching by exe name, and applying settings (§6).
- `engine/lib/failures.dart`: `DependencyNotInstalled` and `UnexpectedLink`, and `ChoiceKind.dependency`.
- `engine/bin/bodega.dart`: `deps list|check|install` and `fix apply` (§7).
- App (§8): `domain/entities/dependency.dart`, `domain/repository/dependency_repository.dart`, `data/repository/dependency_repository_impl.dart`, `app/bloc/dependencies/`, `app/presentation/bottles/widgets/dependencies_section.dart`, `app/shared/widgets/needs_dialog.dart`, `app/shared/text/dependency_text.dart`, and hooks in the add-app and install flows.
- `fixes_data.dart` and `tool/import_fixes.py` stay as they are.

## 2. The runtime table
```dart
/// A Windows runtime that Bodega installs from its vendor's own installer.
typedef Dependency = ({
  String id,            // 'vcrun2008', winetricks' name for the same thing
  String name,          // 'Visual C++ 2008': a product name, shown as is
  List<String> imports, // lowercase DLL names that point to it (§4)
  List<String> dlls,    // set to native,builtin for the whole bottle (§5)
  String? windows,      // the Windows version its installer must see, or null
  DependencyFile x86,
  DependencyFile x64,
});

typedef DependencyFile = ({
  String url,           // HTTPS, the vendor's own server
  String sha256,
  int bytes,            // shown before anything downloads
  String file,          // its name in $BODEGA_HOME/downloads: '<id>-<arch>.exe'
  List<String> args,    // silent install
  String marker,        // under drive_c; one '*' allowed in one folder name (§5)
  List<String> wineManifests, // Wine's own manifests in winsxs/manifests that would stop the install (§5)
});

const dependencies = <Dependency>[ /* the six rows below */ ];
```

| id | name | args | x86 bytes | x64 bytes | dlls | marker x86 / x64 |
|---|---|---|---|---|---|---|
| vcrun2005 | Visual C++ 2005 | `/q` | 2,710,520 | 3,179,000 | atl80 msvcm80 msvcp80 msvcr80 vcomp | `windows/winsxs/x86_microsoft.vc80.crt_1fc8b3b9a1e18e3b_8.0.50727.6195_*/msvcr80.dll` / `amd64_…` |
| vcrun2008 | Visual C++ 2008 | `/q` | 4,483,040 | 5,211,080 | atl90 msvcm90 msvcp90 msvcr90 vcomp90 | `windows/winsxs/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*/msvcr90.dll` / `amd64_…` |
| vcrun2010 | Visual C++ 2010 | `/q` | 5,076,456 | 5,677,032 | atl100 msvcp100 msvcr100 vcomp100 | `windows/syswow64/msvcr100.dll` / `windows/system32/msvcr100.dll` |
| vcrun2012 | Visual C++ 2012 | `/q` | 6,554,576 | 7,186,992 | atl110 msvcp110 msvcr110 vcomp110 | `…/msvcr110.dll` likewise |
| vcrun2013 | Visual C++ 2013 | `/q` | 6,510,544 | 7,201,032 | atl120 msvcp120 msvcr120 vcomp120 | `…/msvcr120.dll` likewise |
| vcrun2022 | Visual C++ 2015–2026 | `/install /quiet /norestart` | 6,941,536 | 18,731,856 | concrt140 msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait msvcp140_codecvt_ids vcamp140 vccorlib140 vcomp140 vcruntime140 vcruntime140_1 | `…/vcruntime140.dll` likewise |

`vcrun2008` lists in `wineManifests` Wine's own manifests of the same assemblies and version, `x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest` and `x86_microsoft.vc90.atl_…` (`amd64_…` for x64); every other file lists none. Wine's prefix registers its own VC90 CRT and ATL at the very version Microsoft's installer brings, and Wine's side-by-side installer skips an assembly whose manifest exists (`dlls/sxs/cache.c`, `install_assembly`: "manifest exists, skipping install"). Found on 2026-11-16 in a scratch bottle: the installer exited 0 and left Wine's `msvcr90.dll`; with those two manifests moved aside, it put Microsoft's `msvcr90.dll`, `msvcp90.dll`, `msvcm90.dll` and `atl90.dll` in place. Wine's VC80 assemblies are other versions (8.0.50727.9672 and .4053) than Microsoft's 2005 package (.6195), so vcrun2005 needs none.

`vcrun2022` has `windows: 'win10'`: its installers exit 1 when they see Windows 7 (highball-db's `vcrun2022` recipe, verified 2026-11-02). The others have `windows: null`.

URLs and SHA-256, the pins the code holds:

| id, arch | URL | SHA-256 |
|---|---|---|
| vcrun2005 x86 | `https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE` | `8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd` |
| vcrun2005 x64 | `https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE` | `4487570bd86e2e1aac29db2a1d0a91eb63361fcaac570808eb327cd4e0e2240d` |
| vcrun2008 x86 | `https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe` | `8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92` |
| vcrun2008 x64 | `https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe` | `c5e273a4a16ab4d5471e91c7477719a2f45ddadb76c7f98a38fa5074a6838654` |
| vcrun2010 x86 | `https://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe` | `31d32fa39d52cac9a765a43660431f7a127eee784b54b2f5e2af3e2b763a1af8` |
| vcrun2010 x64 | `https://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe` | `2fddbc3aaaab784c16bc673c3bae5f80929d5b372810dbc28649283566d33255` |
| vcrun2012 x86 | `https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe` | `b924ad8062eaf4e70437c8be50fa612162795ff0839479546ce907ffa8d6e386` |
| vcrun2012 x64 | `https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe` | `681be3e5ba9fd3da02c09d7e565adfa078640ed66a0d58583efad2c1e3cc4064` |
| vcrun2013 x86 | `https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe` | `89f4e593ea5541d1c53f983923124f9fd061a1c0c967339109e375c661573c17` |
| vcrun2013 x64 | `https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe` | `20e2645b7cd5873b1fa3462b99a665ac8d6e14aae83ded9d875fea35ffdd7d7e` |
| vcrun2022 x86 | `https://download.visualstudio.microsoft.com/download/pr/6ad63323-a427-4c58-8464-9f1f19f62359/F0BAB33A302B3CDB2E11113760D016F54FD3D2632C65BA7834FAC4F0ABD7F1A3/VC_redist.x86.exe` | `f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3` |
| vcrun2022 x64 | `https://download.visualstudio.microsoft.com/download/pr/ebdab8e5-1d7b-4d9f-a11b-cbb1720c3b12/843068991DAAA1F73AD9F6239BCE4D0F6A07A51F18C37EA2A867E9BECA71295C/VC_redist.x64.exe` | `843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c` |

Where they come from, in the table's comment, by name and never as code copied: the 2005–2013 pins are the ones winetricks (LGPL-2.1-or-later) lists in `load_vcrun2005` to `load_vcrun2013` at version `20260125-next`, and the 2015–2026 pins and the `win10` need are highball-db's `recipes/tweaks/vcrun2022.json` at `7a008d5` (CC0). On 2026-11-16 all twelve URLs answered 200 with these sizes, and vcrun2008 x86 was downloaded and matched its SHA-256; T2 checks the other eleven the same way.

The `imports` of each row: vcrun2005 `msvcr80 msvcp80 mfc80 mfc80u`; vcrun2008 `msvcr90 msvcp90 mfc90 mfc90u`; vcrun2010 `msvcr100 msvcp100 mfc100 mfc100u`; vcrun2012 `msvcr110 msvcp110 mfc110 mfc110u`; vcrun2013 `msvcr120 msvcp120 mfc120 mfc120u`; vcrun2022 `vcruntime140 vcruntime140_1 msvcp140 msvcp140_1 msvcp140_2 concrt140 mfc140 mfc140u`. Each with `.dll`.

## 3. Reading a program
```dart
/// What an exe shows of its needs (D4).
typedef ProgramScan = ({
  int bits,
  Set<String> imports,      // lowercase DLL names, imported or delay-loaded
  Set<String> assemblies,   // 'microsoft.vc90.crt' and the like, from the manifest
  Set<String> besideIt,     // lowercase names of the DLLs in the exe's folder
});

Future<ProgramScan?> scanProgram(String path);  // Isolate.run, like exeGraphics
```
- Null when `path` is not a PE for x86 or x86-64 (`_peBits`, `backends.dart:815-832`).
- The import directory (data directory 1, 20-byte entries) and the delay-import directory (data directory 13, 32-byte entries), each name read through the section table. A table that points outside the file, or runs past it, ends the reading there: what was read stands, nothing throws.
- Reads the headers and those tables only, with `RandomAccessFile` and positions, never the whole file: game executables reach hundreds of MB.
- `assemblies`: every `name="Microsoft.VC80.CRT"`, `VC80.MFC`, `VC90.CRT` or `VC90.MFC` in the file's bytes (the manifest is a resource in plain text), lowercased.
- `besideIt`: one `listSync(followLinks: false)` of the exe's folder, regular files ending in `.dll`. Nothing below it (ponytail: the DLLs beside an exe import runtimes too; scanning them is the upgrade path).

## 4. Proposals
For one program of a bottle, worked out each time from the bottle and the program, never stored:

| Source | Becomes | Reason |
|---|---|---|
| a fix that matches the program (§6) and names the runtime in `requires` | recommended | `knownFix`, with the fix's id |
| an import of `mfc*` (Wine has no MFC 8.0 to 14.0) or an assembly `*.mfc` | recommended | `notInWine`, with the DLL |
| an import of any other DLL in a row's `imports`, or an assembly `*.crt` | optional | `imported`, with the DLL |
| a fix's `ini` steps that apply on this host | a setting, recommended | `knownFix` |

- The arch is the program's: 32 → `x86`, 64 → `x64`. A fix's `requires` takes the arch of the program it matched.
- An import whose DLL is in `besideIt` proposes nothing: the game brings its own copy. A fix's `requires` is proposed anyway.
- One runtime is proposed once per program, at its strongest level: recommended wins over optional.
- An installed runtime stays in the list with `installed: true`, so the panel can show it as done; the dialog leaves it out.
- Steam games (`steam:<appid>` keys) open through `steam.exe`, so their proposals come from fixes only, with the bits of `steam.exe`; nothing is read from `steam.exe` for them.

```dart
enum Need { recommended, optional }
enum NeedReason { knownFix, notInWine, imported }
typedef DependencyNeed = ({String id, String arch, Need need, NeedReason reason, String? dll, String? fix, bool installed});
enum SettingState { applied, notApplied, noFile }
typedef SettingNeed = ({String fix, String section, String name, String value, SettingState state});
typedef AppNeeds = ({String key, List<DependencyNeed> dependencies, List<SettingNeed> settings});

Future<AppNeeds> appNeeds(String home, String bottle, String key);
List<({String id, String arch, bool installed})> bottleDependencies(String home, String bottle);
```

## 5. Install and status
`dependencyInstalled(home, bottle, id, arch)` reads the row's marker under `drive_c`: the folder with `*` is matched among the real folders of its parent, case-insensitively and following no link; the file must be a regular file that starts with `MZ`, and its first 128 bytes must contain neither `Wine builtin DLL` nor `Wine placeholder DLL`, the marks Wine writes in its own DLLs (checked on 2026-11-16: Wine's `msvcr90.dll` and `msvcr100.dll` in the user's prefix carry the first; Microsoft's `msvcr90.dll` carries neither).

`installDependency(home, bottle, id, arch, {String? file})`, in order:
1. `BadChoice(ChoiceKind.dependency, '<id> <arch>')` for an id not in the table or an arch other than `x86` or `x64`; `BottleNotFound`, `BottleNotReady` as `_launchIn` gives them.
2. `BottleOpen(bottle)` when the bottle's wineserver runs (`_serverRunning`, `engine.dart:664`): an installer replaces DLLs that a running game may hold, and overrides reach only processes that start afterwards.
3. The installer: `file` when given (`MissingFile` if it is not there), else `_download(home, url, sha256, name: <id>-<arch>.exe)` (`backends.dart:330-367`), which reuses a matching file in `downloads/`. Either way, `sha256Of` must equal the pin, or `ChecksumMismatch(file)`.
4. When the row has `windows`, `reg add HKCU\Software\Wine\AppDefaults\<the installer's file name>` `/v Version /d <windows>`.
5. The file's `wineManifests` that match in `drive_c/windows/winsxs/manifests/` (real files, no link followed) move to `bottles/<bottle>/wine-manifests/`, outside the prefix, so that Wine's side-by-side installer writes Microsoft's assembly over Wine's (§2).
6. `_launchIn(home, bottle, <installer>, args, backend: 'wine', label: '<id>-<arch>')`, then `exitOf` with a 10-minute limit, after which `stopBottle` and the code `-1`; then `waitBottle`. A code outside `_installerOk` (`catalog.dart:66-67`: 0, and 3010, 1641 and 1638 as 8 bits) throws `WineToolFailed(WineTool.installer, code, log)`.
7. `reg add HKCU\Software\Wine\DllOverrides /v <dll> /t REG_SZ /d native,builtin /f` for each of the row's `dlls`, as `_applyFixRegistry` runs `reg` (`fixes.dart:166-182`); a failure throws `WineToolFailed(WineTool.reg, code, log)`.
8. `dependencyInstalled` must now be true, or `DependencyNotInstalled(id, arch, log)`.
9. `waitBottle` again: Wine's server outlives the last `reg` by a few seconds, and the next item of a queue would find the bottle open (found on 2026-11-16: a second install right after the first failed with `BottleOpen`).
10. Returns the installer's log.

Whatever fails after step 5 puts each moved manifest back, unless the installer wrote one of that name; after a good install the moved ones are deleted. Overrides are written after a good run only, so a failed install changes nothing but the files the installer itself wrote. Both arches share the DLL names, so installing one arch sets them for both; `native,builtin` falls back to Wine's copy where Microsoft's is absent.

## 6. Bodega's fixes and the `ini` step
`bodega_fixes_data.dart` holds `const bodegaFixesJson`, in `fixes_data.dart`'s shape with three changes: `steam` may be null, `exes` lists lowercase exe file names, and `requires` lists runtime ids. Its header says it is hand-written, how each entry was verified, and that nothing in it comes from CrossOver's data. `gameFixes()` reads `fixesJson`, then `bodegaFixesJson` (`fixes.dart:83-91`); a Bodega id that repeats a generated one is `CorruptData`.

```json
[
 {"id": "blur", "title": "Blur", "steam": null, "exes": ["blur.exe"], "optIn": false,
  "requires": ["vcrun2008"], "steps": [],
  "notes": ["Blur crashes now and then in Wine's msvcr90.dll: sin and cos get a huge argument while Direct3D 9 holds the x87 unit at single precision. Microsoft's Visual C++ 2008 runtime does not crash there. Verified on 2026-11-12, Apple Silicon, macOS 27: a 73-minute session with no crash."],
  "knownIssues": [], "verified": {"date": "2026-11-12", "result": "73 minutes without a crash"}, "source": "bodega"},
 {"id": "need-for-speed-most-wanted-2012", "title": "Need for Speed: Most Wanted (2012)", "steam": null, "exes": ["nfs13.exe"], "optIn": false,
  "requires": [],
  "steps": [{"type": "ini", "file": "%USERPROFILE%\\Documents\\Criterion Games\\Need For Speed(TM) Most Wanted\\config.NFS13Save", "section": "Sound", "name": "Reverb", "data": "0", "platforms": ["mac"]}],
  "notes": ["The game's audio engine is x87 code, which Rosetta runs slowly: with reverb on, its sound thread keeps a core busy and the sound stutters. Verified on 2026-11-16, Apple Silicon, macOS 27: 95 late writes in 71 s with reverb, 6 in 190 s without it."],
  "knownIssues": [], "verified": {"date": "2026-11-16", "result": "the stutter is gone"}, "source": "bodega"}
]
```

- `FixStep` admits `ini` (`fixes.dart:21`) with `file`, `section`, `name` and `data`. `GameFix.active` leaves `ini` steps out, as it does for opt-in fixes: they are never applied at launch, so `openApp` (`apps.dart:390-395`) and `_launchIn` (`engine.dart:290-312`) do not change.
- `fixForApp(key)`: a `steam:` key as today; any other key by its last path segment, lowercase, among a fix's `exes`.
- `fixSettingState(home, bottle, fix)` and `applyFixSettings(home, bottle, fixId)`, for the `ini` steps that apply on this host:
  - `%USERPROFILE%` is `drive_c/users/<user>`, the bottle's Windows user or the host's (`backends.dart:650`); the rest of `file` follows with `\` as `/`. It is the only variable read.
  - The path is opened as it is: the profile's `Documents` is a link to the host's own folder (`apps.dart:255-256`), which the game itself writes through. Before reading or writing, its real path must start with the bottle's prefix or with `HOME` from the host's env, or `UnexpectedLink(path)`; no folder is listed.
  - No file: state `noFile`, and `applyFixSettings` throws `MissingFile(path)`: the game makes it on its first run.
  - `applyFixSettings` throws `BottleOpen` while the bottle runs: the game writes its file again when it exits.
  - The edit, `setIniValue(text, section, name, value)`, a pure function on the file's bytes read as Latin-1: the section header matches without case, the key matches without case before its `=`, the value is replaced and nothing else changes, the line ends included. A key missing from its section is added after the section's last line; a missing section is added at the end, with the file's own line end. The new text goes to a temporary file in the same folder, renamed over the old one.
  - State: `applied` when the key already holds the value, `notApplied` otherwise.

## 7. CLI
The verbs are `depsVerb(args, out)` in the engine, which returns the work or null for a bad usage and writes to `out`, as `switchVerb` does (`switch.dart:942`), so their parsing and their lines are tested without a process; `fix apply` is one more case in `bin/bodega.dart`.

```
bodega deps list <bottle>                               every runtime and arch: installed, or its size
bodega deps check <bottle> <key>                        what Bodega proposes for an app (bodega apps lists the keys)
bodega deps install <bottle> <id> <x86|x64> [installer.exe]
bodega fix apply <bottle> <id>                          a fix's settings steps
```
English output, one line per item, as `fix list` prints (`bin/bodega.dart`). They need the runtime and the host, like `open`.

## 8. App
- **Domain** (`domain/entities/dependency.dart`, Freezed): `Dependency(id, name, arch, bytes, installed)`, `DependencyNeed`, `SettingNeed`, `AppNeeds` and the enums `Arch`, `Need`, `NeedReason`, `SettingState`, mirroring §4.
- **Repository** `DependencyRepository`: `bottle(name)` (every runtime and arch with its status, and the needs of each app of the bottle), `needs(bottle, key)`, `install(bottle, id, arch, {file, cancel, onProgress})`, `applySettings(bottle, fixId)`. The implementation downloads with `Downloader` into `$BODEGA_HOME/downloads/<id>-<arch>.exe` (skipped when a file there already matches) and hands the file to `engine.installDependency(..., file:)`, as `BackendRepositoryImpl` does with backends (`data/repository/backend_repository_impl.dart:51-86`).
- **Bloc** `DependenciesBloc`, `@lazySingleton` and provided in `main.dart`, because an install outlives the page (`.claude/rules/architecture.md`, BLoCs). One job at a time: a queue of items for one bottle; the state holds each bottle's data, the job (bottle, item, phase `downloading|installing|applying`, received, total), the last error and the item it failed on.
- **The dialog** `NeedsDialog` (`app/shared/widgets/needs_dialog.dart`), in two modes:
  - *for an app*: its title, then its proposals not yet installed or applied, recommended ones checked, optional ones not, each with its name, arch, size and reason, and the line "Installs for every program in this bottle";
  - *by hand*: every runtime and arch not installed, none checked.
  "Install" queues the checked items; "Not now" closes it. Settings items say what changes (`[Sound] Reverb = 0`) and in which game.
- **When the dialog opens by itself**: after "Add program" registers an app (`AddAppStep.done`, with the new key in the state), and after a catalog install reaches `InstallPhase.done` (the entry's key, `engine.appKey(entry.exe)`), when that app has at least one recommended item not done. Never for detected apps: they have no moment.
- **The section** `DependenciesSection`, a `CollapsibleSection` in `BottleColumn` after Settings (`bottle_column.dart:373`): the apps with needs, each with its items and their state (installed, not installed with size, applied, not applied, open the game once first), an "Install" or "Apply" per item, the job's progress as a live region, and "Install a runtime…" for the dialog by hand. While the bottle is open (`LibraryBloc.state.open`), the buttons are off and a line says to stop the bottle first.
- **A failed download** shows the error and "Choose the installer file…", which opens a file picker for `.exe` and installs from that file, checked against the same SHA-256.
- **Text**: names are product names; arches, needs, reasons, states, buttons and the two fixes' reasons come from the ARBs, in `dependency_text.dart`, in exhaustive switches; a fix's reason is a table keyed by fix id with a default.

## 9. Defaults for exploration's open questions
1. Installers only (Q1). 2. The dialog after "Add program" and a catalog install; the section for everything else; nothing stored about dismissals (Q2). 3. Recommended from fixes and missing MFC; optional from other CRT imports; `d3dx9`, XInput, `d3dcompiler` and .NET are not proposed (Q3). 4. Bottle-wide overrides (Q4). 5. `bodega_fixes_data.dart` (Q5). 6. Settings applied once, by the user (Q6). 7. Exe file name (Q7). 8. Installed read from the prefix (Q8). 9. Uninstall, #15's performance options and the Wine patch are out (Q9). 10. The branch starts from `main` once pull request #20 is merged; if it is not merged when apply starts, from `feat/switch-keys-firmware`, and moves onto `main` before its own pull request (Q10).

highball-db's `requires`: at `7a008d5`, nine game recipes require something besides Steam: `dotnet48`, `physx`, `corefonts`, `fakejapanese` (winetricks), `concrt140-native` and `flight-controls-raw-hid` (overrides and registry), and the launchers `rockstar` and `ea-app`. None is a runtime of §2, so importing them now gives no proposal (ponytail: import `requires` and the tweaks with the winetricks change).

## 10. Tests
- Engine, under a temporary home with the fake Wine of `engine_test.dart`, whose script writes a native-looking DLL at the marker for an installer named in the test and exits with the code the test sets; installers are local files, so no test downloads anything.
- PE fixtures: a small writer in the tests that builds a PE32 or PE32+ with chosen imports, delay imports and manifest text, and broken ones (a table past the end, a section that points nowhere).
- `setIniValue` as a table of cases: LF and CRLF, case, a missing key, a missing section, bytes above 127 kept as they were.
- A network test, skipped unless `BODEGA_NETWORK_TESTS=1`, that downloads the twelve installers and checks each SHA-256 and size.
- App: repository tests against a temporary home; bloc tests with mocktail; widget tests of the section and the dialog through `wrapApp`; `pages_test.dart` with the section open and the dialog, in `en` and `es`; text and parity cases.

## 11. Delivery and version
- A feature: one minor bump above what `main` holds when the branch starts (1.8.0 if pull request #20 has brought 1.7.0). `tool/version.sh check` before each commit.
- Built in the working tree, uncommitted; `../dependencies-commit.sh` commits the bump, M1, M2 and M3's docs in four commits, pushes nothing, with English messages and no AI attribution.
