# Proposal · runtimes-and-performance

Input: `exploration.md` and its recommendations. The user approved them, and they are the decisions here:

1. **Bodega's own recipes.**
   - Bodega installs the new runtimes the way it installs Visual C++: no winetricks and no `cabextract`.
   - Wine's own `extrac32` opens the cabinets.
2. **Pinned downloads.**
   - Every file comes from its vendor's own server, pinned by size and SHA-256.
   - No vendor serves the core fonts or `d3dcompiler_47` any more. They come from the copies winetricks itself uses (the `pushcx/corefonts` and `mozilla/fxc2` repositories on GitHub), pinned the same way.
3. **Performance.**
   - AVX and msync stay; exploration measured both.
   - App Nap is not added: Wine already holds the activity.
   - On the Mac only, DXVK gets its async option and a shader cache folder per bottle. Linux's DXVK reads neither.
   - GameMode, MangoHud and the sync setting are measured on a real Linux host.
4. **Status.**
   - It is read from the bottle each time.
   - "Unknown" means the bottle's files can't be read.
   - The panel shows the time of the last check and a "Check again" button.
   - A failed install's "Details" opens its log.

Exploration's other questions get the defaults in `design.md` §10: .NET's steps, the markers of .NET and PhysX, and who checks Linux.

## Why

Issue #15 asks for a Dependencies panel that installs the runtimes most games need, on macOS and Linux, and for performance options that are measured to change something.

The `dependencies` change (`.sdd/dependencies/`) delivered the panel and Visual C++ 2005–2022. Three things are still missing:
- most of the issue's items;
- the panel details the issue describes;
- the performance part.

The issue can't be closed until all of it is done and checked, Linux included.

## What

**In**

**1. Eight new runtimes**

Each one follows the existing rules: downloaded only when the user asks, checked against its pin, never stored in the repo or the packages, and counted as installed only after the bottle is read.

| Id | Shown as | Arch | From | How |
|---|---|---|---|---|
| `dotnet48` | .NET Framework 4.8 | one for both | Microsoft | runs Microsoft's installer silently |
| `d3dx9` | D3DX9 | 32 and 64 | Microsoft's `directx_Jun2010_redist.exe` | takes the DLLs out of its cabinets |
| `d3dx10` | D3DX10 | 32 and 64 | the same file | the same |
| `d3dx11_43` | D3DX11 | 32 and 64 | the same file | the same |
| `xact` | XACT | 32 and 64 | the same file | the same, then registers the XACT and XAudio DLLs |
| `d3dcompiler_47` | D3DCompiler 47 | 32 and 64 | `mozilla/fxc2` | copies the DLL |
| `physx` | PhysX | one for both | NVIDIA | runs NVIDIA's installer silently |
| `corefonts` | Core fonts for the Web | one for both | `pushcx/corefonts` | takes the `.ttf` files out of Microsoft's eleven font packages |

**2. Proposals**

These follow the rule the `dependencies` change set:
- A program that imports one of these runtimes' DLLs gets it as *optional*, since Wine has its own copy.
- It gets it as *recommended* when Wine has no copy, as with PhysX's loader.
- "Wine has no copy" is now read from the runtime Bodega ships, no longer from a fixed list.

**3. The panel**

- An "All runtimes" list: one row per item, with its name and one line on what needs it.
- Each row shows its status (Installed, Not installed or Unknown) per architecture, and an Install button.
- The panel shows when it was last checked, with a "Check again" button.
- A failed install has a "Details" button that shows the install's log.
- The list replaces the hand-picked mode of the dialog ("Install a runtime…").

**4. Performance on the Mac**

- An "Async shader compilation" switch per bottle (`DXVK_ASYNC=1`) for DXVK, off by default.
- A shader cache folder per bottle (`DXVK_STATE_CACHE_PATH`).
- Each one is measured from DXVK's own log.

**5. Linux**

- The same panel and recipes, checked on a real Linux host.
- GameMode, MangoHud and Wine's use of NTSync are measured there and written down.

**6. Rules**

- The CLI takes `all` as an architecture.
- The rules in `.claude/` name the two non-vendor sources.
- English and Spanish texts.

**Out**

- **winetricks and `cabextract`.** Not needed: Wine's `extrac32` does the job, and Bodega's own pins replace winetricks' stale DirectX one.
- **Uninstalling a runtime.**
- **App Nap.** Wine's `winemac` already calls `beginActivityWithOptions:reason:` in each Windows program's own process.
- **DXVK options on Linux.** DXVK 3.1.1 reads neither `DXVK_ASYNC` nor a state cache.
- **A new sync mode on Linux.** The measurement is written down, and the setting changes only if it shows that Bodega's Wine ignores what Bodega sets.
- **Importing highball-db's `requires` and every per-game configuration.** They belong to #16.
- **Caching the status.** Reading a bottle is a few file reads (exploration, "What exists today"), so there is no cache to go stale.

## Milestones

One branch, `feat/runtimes-and-performance`, starts from `feat/dependencies` once the user has committed that branch (design §11). The work stays in the working tree, and the user commits it with a script.

| | Content | Done when |
|---|---|---|
| M1 | **Engine and CLI.** The table's new shape, the eight rows, the three kinds of install, the status with "unknown", "not in Wine" read from the runtime, the time limit as its own failure, and DXVK's two variables on the Mac | `dart analyze && dart test` pass. Each new item installs headless into a scratch bottle on this Mac, and its marker is the vendor's file. Every pin matches a real download. |
| M2 | **App.** The list, the status per architecture, "checked at" and "Check again", "Details", the one line per item, the async switch, texts | `flutter analyze`, `flutter test` and `tool/check_layers.sh` pass. `pages_test.dart` renders the section in `en` and `es`. |
| M3 | **Checks, rules and delivery** | The Linux checks and the USER checks of `specs/checks.md` are written in `verify.md`. `tool/version.sh check` passes. |

## Impact

**Engine**
- `dependencies.dart`: the table changes shape, gains eight rows and the cab and copy installs.
- `failures.dart`: one more failure, for the time limit.
- `platform_mac.dart`: DXVK's two variables.
- `backends.dart`: `BottleSettings.dxvkAsync`.
- `bin/bodega.dart`: the `all` architecture.

**App**
- Entities: a `DependencyStatus`, and `Arch` gains `all`.
- The repository downloads a list of files.
- The bloc gains `checkedAt`.
- The section gains a list; the dialog loses its hand-picked mode.
- The switch goes in Settings and in the run options.
- About 25 keys per ARB.

**Users**
- Downloads only when asked:
  - the DirectX file, 100 MB, once for four items;
  - .NET, 73 MB (123 MB if .NET 4.0 has to go first);
  - PhysX, 29 MB;
  - the fonts, about 5 MB;
  - `d3dcompiler_47`, about 8 MB.
- `downloads/` keeps them, as it keeps the Visual C++ installers.

## Risks

| Risk | Mitigation |
|---|---|
| Microsoft's DirectX file differs from winetricks' pin, so its SHA-256 may change again | Bodega pins Microsoft's own file from a real download. A mismatch fails with its own message, and the network test checks every pin. |
| .NET 4.8 under Rosetta is slow, or needs winetricks' extra steps (.NET 4.0 first, Wine Mono out, Windows 7) | A 30-minute limit for it. Apply tries the bare install first and adds each extra step only when a real install shows it is needed, writing down why. |
| Native D3DX or XAudio replaces Wine's own copy in a bottle where Wine's worked | They are *optional*, never checked by default. The dialog says the change is for the whole bottle, and `native,builtin` falls back to Wine's copy. |
| The two non-vendor copies change or disappear | They are pinned by SHA-256. A mismatch or a 404 fails clearly, and "Choose the installer file…" still works for them. |
| Linux can't be checked from this Mac | Design §10: the collaborator's Linux machine, or an x86_64 container here if the user prefers. Issue #15 stays open until it is done. |
| The async option shows missing geometry for a moment while shaders compile | It is off by default, and its line says what it does. |
