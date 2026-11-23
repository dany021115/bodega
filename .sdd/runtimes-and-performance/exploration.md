# Exploration · Runtimes and performance (issue #15)

## Problem

Issue #15 asks for a Dependencies panel per bottle that installs the Windows runtimes most games need, and for performance options that are measured to work, on macOS and on Linux. The `dependencies` change (`.sdd/dependencies/`, not yet archived) delivered the panel and Microsoft's Visual C++ 2005–2022. This change covers the rest of #15:

- **The runtimes still missing:**
  - .NET Framework 4.8;
  - the DirectX 9–11 extras (`d3dx9`, `d3dx10`, `d3dx11_43`, `d3dcompiler_47`);
  - XACT (32- and 64-bit);
  - PhysX;
  - the core fonts.
- **The panel details the issue describes:** one line per item on what needs it, an "Unknown" status and when it was last checked, and a details view with the log when an install fails.
- **The performance options,** each with a test or a measurement, and none that does nothing.
- **Linux:** the same panel there, checked on a real Linux host.

## What exists today

### The engine

**Runtimes (`packages/engine/lib/dependencies.dart`)**
- `Dependency` and `DependencyFile`, `:5` and `:28`, describe one installer per architecture: URL, SHA-256, size, file name, silent arguments, a marker, and Wine's own manifests to move aside.
- `dependencies`, `:45`, holds the six Visual C++ rows.
- `dependencyInstalled`, `:260`, counts an item as installed only when Microsoft's file is in the prefix (`_markerFiles` `:300`, `_isMicrosofts` `:333`). Detection is a few file reads per item, so it runs on every load and needs no cache.
- `installDependency`, `:700`:
  - downloads or takes the file, checks its SHA-256 and runs it headless with a time limit;
  - sets `native,builtin` for the item's DLLs;
  - checks the marker, waits for the bottle to be idle, and logs to the bottle.
- `appNeeds`, `:604`, maps a program's imports (`scanProgram`, `:359`) to runtimes: "recommended" when a fix names one or when Wine lacks the DLL, "optional" otherwise.

**Performance settings (per bottle)**
- `BottleSettings`, `backends.dart:405-440`, holds `sync`, `avx` (on by default), `dlss`, `gpu`, `gamemode` and `highRes`.
- **macOS, `platform_mac.dart`:**
  - `baseEnv` sets `WINEMSYNC=1` and `ROSETTA_ADVERTISE_AVX=1` (`:88-89`); `avx: false` removes it (`engine.dart:324`);
  - the sync modes are `msync` and `none`, where `none` sets `WINEMSYNC=0` (`:144-153`);
  - for DXVK, `backendEnv` sets only the DLL path and the overrides (`:176-179`), and no DXVK option.
- **Linux, `platform_linux.dart`:**
  - GameMode wraps a launch in `gamemoderun` when it is on the `PATH` (`:169`, `:275-276`);
  - the HUD uses MangoHud when it is installed, otherwise `DXVK_HUD` (`:198-220`);
  - the only sync mode is `none` (`:170`): the bundled Wine has no esync or fsync variable (`:174`).

### The app

- `DependenciesSection` (`apps/bodega/lib/app/presentation/bottles/widgets/dependencies_section.dart`) lists what the bottle's programs need, installs one item at a time with progress, and shows a failure with `CopyDetailsButton` and "Choose the installer file…" (`:160-198`).
- The bottle's logs already open in `showLogDialog` (`log_dialog.dart:10`), which `bottle_column.dart:573-578` uses. A failed install can open its own log the same way.
- The settings toggles (AVX, msync, GameMode, HUD) live in `bottle_column.dart`'s Settings section (`:374`) and in `run_options_dialog.dart`.

## Measurements

All of these ran headless on this Mac (M2 Pro, macOS 27.0.1), with Bodega's runtime `engine-wine-11.0`, in a scratch bottle that was then deleted.

**Settings that already exist**

| Option | Measurement | Result |
|---|---|---|
| AVX (`ROSETTA_ADVERTISE_AVX=1`) | A small x86_64 program reads CPUID under Rosetta, with the variable and without it | Without it: AVX, AVX2, FMA, F16C, BMI2 and OSXSAVE are all 0. With it: all 1. `sysctl machdep.cpu.features` does not change, so the check has to run CPUID. |
| AVX inside Wine | `wine cmd /c echo %ROSETTA_ADVERTISE_AVX%` | Prints `1`: the variable reaches Windows programs and the processes they start. |
| msync | `wine cmd /c exit` with `WINEMSYNC=1`, then with `WINEMSYNC=0`, stopping the server between runs | `msync: up and running.` shows once with 1 and never with 0. |

**Proposed options**

| Option | Measurement | Result |
|---|---|---|
| App Nap | `strings winemac.so` | It holds `beginActivityWithOptions:reason:` and `Running Windows program`: Wine already holds an activity in its own processes. An activity in Bodega's process would not reach the game's process. |
| DXVK on the Mac | `strings d3d11.dll` of `backends/dxvk` | It reads `DXVK_ASYNC`, `DXVK_STATE_CACHE` and `DXVK_STATE_CACHE_PATH` (`dxvk.enableAsync`, `dxvk.enableStateCache`): it is an async build. |
| DXVK on Linux (3.1.1) | DXVK's own source at `v3.1.1` | `src/dxvk/dxvk_state_cache.cpp` returns 404 and its README does not name `DXVK_STATE_CACHE`. Upstream DXVK never read `DXVK_ASYNC`. |

**The new runtimes**

| Check | Result |
|---|---|
| Wine's own cab tool | `wine extrac32 /y /e /l C:\cabtest <cab>` extracts a real cabinet headless, with the same files and sizes that `cabextract -l` lists. It does not open the self-extracting `.exe` around it; cutting the file from its `MSCF` header first works. Wine's `cabinet.dll` reads MSZIP, LZX and Quantum, so neither the Mac nor Linux needs `cabextract`. |

## Where the new runtimes come from

Read from winetricks `20260125` (LGPL-2.1-or-later), whose script was downloaded only to read its recipes. Each URL answered `200` on 2026-11-16.

| Item | winetricks does | File, source and size |
|---|---|---|
| `d3dx9`, `d3dx10`, `d3dx11_43` | Extracts the `*d3dx9*x86*` cabs (and `x64` ones) from the DirectX redistributable, copies `d3dx9_*.dll` to `syswow64` and `system32`, and sets `native` | `directx_Jun2010_redist.exe`. winetricks pins a third-party mirror (100,271,992 bytes, SHA-256 `8746ee1a…`). **Microsoft's own URL** (`download.microsoft.com/download/8/4/A/84A35BF1-…/directx_Jun2010_redist.exe`) serves a different file: 100,275,120 bytes, re-signed, so it needs its own pin. This is the stale-checksum case the issue warns about. |
| `xact`, `xact_x64` | Extracts the `*_xact_*`, `*_x3daudio_*` and `*_xaudio_*` cabs from the same redistributable; copies `xactengine*`, `xaudio*`, `x3daudio*` and `xapofx*`; sets `native,builtin`; runs `regsvr32` on `xactengine*.dll` and `xaudio2_0`…`xaudio2_7` | The same file |
| `d3dcompiler_47` | Copies the DLL and sets `native` | Mozilla's `fxc2` repository on GitHub (`d3dcompiler_47.dll`, 4,346,120 bytes, plus `d3dcompiler_47_32.dll`). **Not Microsoft's server**; Microsoft ships the DLL only inside the Windows SDK. |
| `dotnet48` | Removes Wine Mono, installs `dotnet40` first, sets `win7`, runs the installer `/q /norestart` with `fusion=b`, then sets `mscoree=native` | `ndp48-x86-x64-allos-enu.exe`, Microsoft (`download.visualstudio.microsoft.com`), 72,721,568 bytes, SHA-256 `95889d6d…fd53`. `dotNetFx40_Full_x86_x64.exe`, Microsoft, 50,449,456 bytes, SHA-256 `65e06425…659f`. |
| `physx` | Runs the installer `/s`. It is marked broken on Wine 9.5–9.10 (bug 56606); Bodega's Wine is 11.0. | `PhysX_9.23.1019_SystemSoftware.exe`, NVIDIA's own server, 29,417,888 bytes, SHA-256 `9b42b84e…208c` |
| `corefonts` | Ten font packages (Andale, Arial, Comic Sans, Courier, Georgia, Impact, Times, Trebuchet, Verdana, Webdings): extracts the `.TTF` files to `windows/Fonts` and registers each one | Microsoft's original `arial32.exe` and the others, about 5 MB in all, from the `pushcx/corefonts` GitHub repository. **Not Microsoft's server**: Microsoft stopped hosting them in 2002. The Arial SHA-256 matched winetricks' pin. |

## Project constraints that apply

- Microsoft's installers are downloaded from Microsoft at the user's request, checked against their pinned SHA-256, and never stored in the repo or the packages (`.claude/CLAUDE.md`). The issue extends this to each vendor's own server.
- Agents run Wine only headless, and the user does anything with a window. A real install of each new item can run headless, as the Visual C++ ones did. Playing a game to check an option is the user's job.
- Check against the real thing: every pin needs a real download, and every runtime a real install in a scratch bottle.
- Linux was developed and checked on a Linux machine by a collaborator (`.sdd/linux-support/tasks.md:5`). Docker is installed here, but its daemon is off.
- `winetricks` is LGPL-2.1-or-later: reading its recipes as facts (URLs, files, overrides) is fine, while copying its code into Bodega is a licensing decision.
- Text goes into both ARB files; errors are codes; the engine's English detail is never rendered (`CopyDetailsButton`). A log already has its own dialog.

## Open questions for `propose`

1. **How to install:**
   - **Bodega's own recipes (recommended).** They extend `dependencies.dart` with three kinds of step: run an installer, extract from cabinets with Wine's `extrac32`, and copy one file. They use Microsoft's own URLs with Bodega's own pins, show Bodega's progress, and report a checksum mismatch clearly. They need no host tool.
   - **winetricks.** It needs `bash` and `cabextract` on every Mac and Linux host, and brings its mirrors and pins (the DirectX one no longer matches Microsoft's file).
2. **The two items that no vendor serves:** the core fonts (the `pushcx/corefonts` GitHub copy of Microsoft's files) and `d3dcompiler_47` (Mozilla's copy). Take them from those copies, pinned by SHA-256 as winetricks does, or leave them out? Wine has its own `d3dcompiler_47`.
3. **.NET 4.8:**
   - whether .NET 4.0 has to go first, as in winetricks, or 4.8 installs alone on Wine 11. This is tested in `apply`, headless; an install takes several minutes under Rosetta;
   - how to tell it is installed: Microsoft's `clr.dll` in `Microsoft.NET/Framework/v4.0.30319`, plus the `Release` value in the registry or the DLL's version.
4. **Performance options,** from the measurements:
   - **Keep:** AVX and msync on the Mac (measured), and GameMode and MangoHud on Linux (need a Linux measurement).
   - **Don't add App Nap:** Wine already does it.
   - **Add on the Mac only:** DXVK async and a state-cache folder per bottle, because Linux's DXVK reads neither.
5. **Status:**
   - "Unknown" when a bottle's files can't be read;
   - "checked at <time>" with a "Check again" button, since a check is a few file reads and needs no cache;
   - "Details" opens the install's log in the existing log dialog.
6. **Linux check:** on the collaborator's Linux machine, or in an x86_64 Linux container here (the user would start Docker Desktop, and it means large downloads over this link)?
7. **Download sizes for the real checks:** about 260 MB (the DirectX redistributable 100 MB, .NET 4.8 73 MB, .NET 4.0 50 MB, PhysX 29 MB, fonts and `d3dcompiler_47` 13 MB), once, into `$BODEGA_HOME/downloads/`.
