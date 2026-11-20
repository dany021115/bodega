# Design · runtimes-and-performance

## 1. Files and layers

**Engine**
- `packages/engine/lib/dependencies.dart`: the table's new shape (§2), the eight rows (§3), the installs (§4), the status (§5) and the proposals (§6).
- `failures.dart`: `InstallTimedOut`.
- `backends.dart`: `BottleSettings.dxvkAsync`.
- `platform_mac.dart`: DXVK's variables (§7).
- `bin/bodega.dart`: `all`.

**App**
- `domain/`: `Arch.all` and `DependencyStatus`.
- `data/`: the list of downloads.
- `app/`: the section's list, the status line, "Details" and the switch.

Only `data/` imports the engine, as before. `fixes_data.dart` and `tool/import_fixes.py` do not change.

## 2. The table's new shape

```dart
typedef Download = ({String url, String sha256, int bytes, String file});

enum DependencyKind { run, cab, copy }

typedef DependencyFile = ({
  DependencyKind kind,
  List<Download> downloads, // in the order they are used
  List<String> args,        // run: each download's silent arguments
  List<String> cabs,        // cab: inner cabinets to open, patterns; empty = the files are in the outer one
  List<String> take,        // cab: files to copy out, patterns
  String into,              // cab: the folder under drive_c they go to
  List<String> register,    // cab: DLLs regsvr32 registers afterwards
  String marker,
  List<String> wineManifests,
  int minutes,              // the time limit for the whole install
});

typedef Dependency = ({
  String id,
  String name,
  List<String> imports,      // lowercase DLL names; one `*` allowed
  List<String> dlls,         // set to native,builtin after a good install
  String? windows,
  Map<String, DependencyFile> files, // 'x86' and 'x64', or 'all'
});
```

**Architectures**
- `dependencyArches` becomes a row's `files.keys`.
- `all` is one install for the whole bottle. Bodega's prefixes hold both `system32` and `syswow64`, and .NET's, PhysX's and the fonts' installers fill both.

**Visual C++ rows**
- The six Visual C++ rows move into the new shape unchanged: kind `run`, one download, `minutes: 10`.

**Downloads**
- A download's `file` is its name in `downloads/`.
- The Visual C++ ones keep `<id>-<arch>.exe`.
- The DirectX file is `directx-jun2010.exe`, shared by four rows, so it is downloaded once.

**API**
- `dependencyDownload(home, id, arch)` returns the list of `(url, sha256, bytes, path)`.
- `installDependency(..., {List<String>? files})` takes the files the app downloaded or the user picked, in the same order.

## 3. The eight rows

Facts are read from winetricks `20260125` (LGPL-2.1-or-later), by verb name, and no code is copied. Each pin is taken in T2 from a real download. Sizes marked `~` and the markers marked *(T-n)* are found by a real install in that task.

| Id | Files | Kind and steps | `dlls` (native,builtin) | Marker | Imports |
|---|---|---|---|---|---|
| `dotnet48` | `all`: Microsoft's `ndp48-x86-x64-allos-enu.exe`, 72,721,568 B, `95889d6d…fd53`; `dotNetFx40_Full_x86_x64.exe`, 50,449,456 B, `65e06425…659f`, first, only if T7 shows 4.8 needs it | `run`, `/q /norestart`, 30 min | `mscoree` | Microsoft's `clr.dll` in `windows/Microsoft.NET/Framework/v4.0.30319/` plus a file only 4.8 brings *(T7)* | `mscoree.dll` |
| `d3dx9` | x86, x64: Microsoft's `directx_Jun2010_redist.exe`, 100,275,120 B | `cab`, `cabs: *d3dx9*x86*` (or `x64`), `take: d3dx9_*.dll`, into `syswow64` (x86) or `system32` (x64), 10 min | `d3dx9_24`…`d3dx9_43` | `d3dx9_43.dll` there | `d3dx9_*.dll` |
| `d3dx10` | the same file | the same with `d3dx10` | `d3dx10_33`…`d3dx10_43` | `d3dx10_43.dll` | `d3dx10_*.dll` |
| `d3dx11_43` | the same file | the same with `d3dx11_43` | `d3dx11_43` | `d3dx11_43.dll` | `d3dx11_43.dll` |
| `xact` | the same file | `cab`, `cabs: *_xact_*, *_x3daudio_*, *_xaudio_*` for the arch, `take: xactengine*.dll, xaudio*.dll, x3daudio*.dll, xapofx*.dll`, `register: xactengine*.dll, xaudio2_0…xaudio2_7.dll` | the same four patterns, by name | `xactengine3_7.dll` | `x3daudio1_*.dll`, `xapofx1_*.dll` |
| `d3dcompiler_47` | x86: `d3dcompiler_47_32.dll`, x64: `d3dcompiler_47.dll` (`mozilla/fxc2`, ~4.3 MB each) | `copy` to the marker | `d3dcompiler_47` | `d3dcompiler_47.dll` in `syswow64` or `system32` | `d3dcompiler_47.dll` |
| `physx` | `all`: NVIDIA's `PhysX_9.23.1019_SystemSoftware.exe`, 29,417,888 B, `9b42b84e…208c` | `run`, `/s`, 10 min | none | NVIDIA's `PhysXLoader.dll` *(T8)* | `physxloader.dll` |
| `corefonts` | `all`: Microsoft's eleven packages (`andale32.exe`, `arial32.exe`, `arialb32.exe`, `comic32.exe`, `courie32.exe`, `georgi32.exe`, `impact32.exe`, `times32.exe`, `trebuc32.exe`, `verdan32.exe`, `webdin32.exe`) from `pushcx/corefonts`, about 5 MB | `cab`, `cabs: []`, `take: *.ttf`, into `windows/Fonts`, 10 min | none | `windows/Fonts/arial.ttf` | none |

**DLL names and markers**
- `dlls` with a range stand for each name in it, written out in the table's code.
- XACT's `dlls` are the DLLs `take` copied, by name.

**The URLs**
- Microsoft's: `download.microsoft.com` and `download.visualstudio.microsoft.com`.
- NVIDIA's: `us.download.nvidia.com`.
- The two GitHub copies: `raw.githubusercontent.com`, at a commit, not a branch, so the pin can't move.

**Where the pins come from**
- The comment above the table names the sources.
- For DirectX it adds that Microsoft's file is a re-signed one, unlike winetricks' mirror.

## 4. Installing, by kind

These are the steps of `installDependency` that are new or that change. Steps 1–2 (bad choice, bottle open) and the Wine-manifest steps stay as they are.

1. **The files.**
   - Each one is `files[i]` when given, or else `_download` into `downloads/<file>`, which reuses a file there that matches.
   - Each must match its pin, or `ChecksumMismatch`.
2. **`windows`**, as today, for each `run` file.
3. **By kind.** Each step runs headless with `_launchIn` and checks its exit code, as today's run does. The whole install has the row's `minutes`; past it, `stopBottle` and `InstallTimedOut(id, arch, log)`.
   - **`run`:** each download in order, with `args`. A code outside `_installerOk` throws `WineToolFailed(installer)`.
   - **`cab`:** for each download:
     1. Copy it from its first `MSCF\0\0\0\0` header to `drive_c/windows/temp/bodega-<id>/outer.cab`.
     2. `extrac32 /y /e /l C:\windows\temp\bodega-<id>\outer C:\windows\temp\bodega-<id>\outer.cab`.
     3. When `cabs` is not empty, each extracted cabinet whose name matches is extracted again into `inner\`.
     4. The files that match `take` (found without case, among real files, following no link) are copied to `into`, overwriting.
     5. The `bodega-<id>` folder is deleted at the end, also after a failure.
     6. `register` runs `regsvr32 /s` for each matching DLL: `syswow64\regsvr32.exe` for x86 and `system32\regsvr32.exe` for x64.
   - **`copy`:** the download is written to the marker's path, overwriting, through a temporary file renamed over it.
4. **Overrides.** The `native,builtin` overrides of `dlls`, as today.
5. **Check.** The marker must now count (§5), or `DependencyNotInstalled`.
6. **Wait.** `waitBottle`, as today.

**Fonts**
- T9 checks whether Wine lists the copied fonts without registry entries: after the copy, a Windows program asks GDI for "Arial" and gets `arial.ttf`.
- If it does not, `corefonts` gets a `fonts` list of `(file, face)` pairs, which `reg add HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts` writes. If it does, nothing more is written.

## 5. Status

`dependencyStatus(home, bottle, id, arch)` returns `bool?`:
- `true` when the marker counts;
- `false` when it doesn't;
- `null` when reading the bottle throws a `FileSystemException` (the "Unknown" status).

`dependencyInstalled` stays, meaning `== true`.

A marker counts when:
- it resolves as today (the `*` folder matched without case, no link followed) to a regular file;
- a `.dll` or `.exe` marker also passes today's PE test (`MZ`, and no Wine mark in the first 128 bytes);
- any other marker (`.ttf`) only has to be a regular file. Wine keeps its own fonts outside the prefix, so a `.ttf` in `windows/Fonts` is never Wine's.

## 6. Proposals

`appNeeds` keeps its rules, with two changes:
- **Patterns.** An `imports` entry may hold one `*`, matched as markers are (`_nameMatches`). The need's `dll` is the name the program imports.
- **"Not in Wine".** It is read from the runtime: the imported DLL is in neither of the Bodega runtime's `lib/wine/i386-windows/` and `lib/wine/x86_64-windows/`. This replaces today's `startsWith('mfc')`, and the MFC cases still pass, since Wine ships no MFC 8–14.

**Architecture**
- Rows with `all` are proposed with arch `all` whatever the program's bits.
- `corefonts` has no imports, so it is offered only from the list or by a fix's `requires`.

## 7. Performance

| Option | Host | What it does | Measurement |
|---|---|---|---|
| AVX (exists) | Mac | `ROSETTA_ADVERTISE_AVX=1` | exploration: CPUID's AVX, AVX2, FMA, F16C, BMI2 and OSXSAVE go from 0 to 1; the variable reaches Windows programs. A test checks the variable in the launch env, on and off. |
| msync (exists) | Mac | `WINEMSYNC=1`, and `0` for "none" | exploration: `msync: up and running.` with 1 only. The same kind of test. |
| Async shader compilation (new) | Mac, DXVK | `BottleSettings.dxvkAsync`, off by default; when on and the backend resolves to `dxvk`, `DXVK_ASYNC=1` | **USER, RC4:** a DXVK game with `DXVK_LOG_LEVEL=info` in the bottle's env. The log holds `async compiler threads` with the option on and not with it off. |
| Shader cache folder (new) | Mac, DXVK | always, with `dxvk`: `DXVK_STATE_CACHE_PATH` set to the bottle's `dxvk-cache` folder as a `Z:` path, created before the launch | **USER, RC4:** after a session, `<exe>.dxvk-cache` is in `bottles/<b>/dxvk-cache/`. On the second run the log shows `valid state cache entries`. |
| App Nap | Mac | not added | exploration: `winemac.so` holds `beginActivityWithOptions:reason:` and `Running Windows program` |
| GameMode (exists) | Linux | `gamemoderun` when installed | **RC3:** `gamemoded -s` says `gamemode is active` while a program runs with it on, and `inactive` with it off |
| MangoHud (exists) | Linux | `MANGOHUD=1` when installed | **RC3:** the overlay shows (a person sees it) |
| Sync | Linux | `none`: nothing is set | **RC3:** with Wine running, `ls -l /proc/<wineserver>/fd` shows whether `/dev/ntsync` is open, on a kernel that has it. Written in `verify.md`. The setting is unchanged unless the result contradicts what Bodega shows. |

**Where the switch shows**
- The switch appears where AVX does: the bottle's Settings and the run options.
- A `HostCapabilities` flag shows it on the Mac only, the way AVX's flag does.
- Its line says it compiles shaders in the background, and that some objects may show a moment late.

**Settings**
- `dxvkAsync` is saved only when it is true, as `avx` is saved only when false.

## 8. CLI

```
bodega deps list <bottle>                                   adds the new rows; `unknown` for null
bodega deps install <bottle> <id> <x86|x64|all> [file...]   files in the row's download order
```

## 9. App

**Domain**
- `Arch { x86, x64, all }`.
- `DependencyStatus { installed, notInstalled, unknown }` replaces `Dependency.installed`.
- `BottleDependencies` gains `checkedAt`.
- The repository's `download` returns a list of paths, and `install` takes one.

**Repository**
- It downloads each missing file of the list with `Downloader`, one after another.
- Progress is the sum of received bytes over the sum of the sizes.
- A file already in `downloads/` with the right SHA-256 counts as received.

**Bloc**
- `load` sets `checkedAt` to the time it read the bottle.
- A new event, `refresh`, reads it again.
- The failed item keeps the log path that `WineToolFailed`, `DependencyNotInstalled` and `InstallTimedOut` carry, so the section can show it. `AppError` gains `installTimedOut(id, arch)`.

**Section**
- It keeps "For your programs" (today's list by app).
- It adds "All runtimes": one row per table row with:
  - its name;
  - its one line, from the ARB, by id, with a default;
  - its status per architecture ("32-bit: Installed · 64-bit: Not installed", or one status for `all`);
  - an Install button for what is not installed.
- At the top: "Checked at 15:04" and "Check again".
- A failure shows "Details", which opens the log with `showLogDialog` (`log_dialog.dart:10`).
- "Choose the installer file…" shows only for items with one download.

**Dialog**
- `NeedsDialog` loses its hand-picked mode and "Install a runtime…". The list does that job.

**Text**
- One line per id, the three statuses, "Checked at {time}", "Check again", "Details", "One for both" for `all`, the switch and its line, and the time-limit error.
- All in both ARBs, worded in `dependency_text.dart` and `error_text.dart`, with exhaustive switches over the enums.

## 10. Defaults for exploration's open questions

1. **.NET.**
   - T7 installs 4.8 alone first, in a fresh scratch bottle that still has Wine Mono.
   - If that fails, it adds winetricks' steps one at a time, in this order: Windows 7 for the installer (`windows: 'win7'`), Wine Mono out (the bottle's `uninstaller --remove` with Wine Mono's product code), then 4.0 first.
   - Each step stays only if it was needed.
   - The marker gets a file that 4.8 has and 4.7.2 doesn't, found by comparing the folder before and after the install.
2. **PhysX's marker.** Whatever T8's real install leaves that an installed PhysX always has: NVIDIA's `PhysXLoader.dll`, wherever the installer puts it.
3. **Who checks Linux.** The collaborator, on the Linux machine where Linux support was checked (`.sdd/linux-support/tasks.md:5`). That machine is real hardware, with GameMode, MangoHud and a kernel that may have NTSync, and nothing large downloads over this link. `specs/checks.md` RC2 and RC3 list the commands, and the user passes on the output. If the user prefers, an x86_64 Ubuntu 24.04 container here can do RC2 (the installs) but not RC3.
4. **Download sizes for the checks.** About 260 MB once, into `$BODEGA_HOME/downloads/`, kept for the app's own installs afterwards.

## 11. Delivery, branch and version

**Branch**
- T1 needs `feat/dependencies` committed (`../dependencies-commit.sh`, run by the user) and a clean working tree.
- Then `git switch -c feat/runtimes-and-performance` from it, no upstream.
- It moves onto `main` after `feat/dependencies` does.

**Version**
- The same minor bump that `feat/dependencies` takes (1.8.0), if both reach `main` before the next tag. Otherwise one more minor.
- `tool/version.sh check` runs before each commit.

**Commits**
- `../runtimes-commit.sh` commits M1, M2 and M3's docs and pushes nothing.
- Messages are in English, with no AI attribution.

**Issue #15**
- It closes only after `verify.md` shows every requirement met, Linux included, as the user asked.

## 12. Changes approved in apply (2026-11-18)

`tasks.md` holds four measured changes, "Spec changes found in apply", S1–S4. The user approved them on 2026-11-18, and where they differ they replace this design:
- **S1:** a `.ttf` marker also counts through Wine's `External Fonts` (§5). The fonts are registered with one `regedit /S` (§4).
- **S2:** each `cab` step runs `extrac32` and `regsvr32` from one batch file, with one Wine start (§4).
- **S3:** `.NET 4.8` is Wine Mono out, Wine's `mscoree.dll` out, Windows 7 for the run, then 4.0 and 4.8, with a 120-minute limit. Its marker is Microsoft's `clr.dll` plus `Release` ≥ 528040 (§3, §5, §10.1).
- **S4:** PhysX's marker is `Program Files (x86)/NVIDIA Corporation/PhysX/Common/PhysXLoader.dll` (§3, §10.2).
