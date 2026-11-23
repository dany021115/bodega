# Spec · Engine and CLI

Requirements RE1..RE10 cover the engine's side of `design.md` §2–§8, as amended by §12 (S1–S4 in `tasks.md`, approved on 2026-11-18).

**Where things run**
- `engine/` is `packages/engine/`.
- The test home, the bottle `b`, the fake Wine and the fake installer are those of `.sdd/dependencies/specs/engine.md`.
- **The fake cabinet** is a few bytes standing for the self-extracting wrapper, then `MSCF\0\0\0\0`, then a tar archive. The fake Wine's `extrac32` drops the eight header bytes and untars what remains into `/l`'s folder. The engine never reads a cabinet itself, so this tests what the engine does: the cut, the commands, the picking, the copy, the clean-up. The real `extrac32` is RC1's job.

## RE1 · The table's new shape
`Dependency`, `DependencyFile` and `Download` shall have `design.md` §2's shape, and the six Visual C++ rows shall keep their values, moved into it. `dependencyArches` becomes a row's `files.keys`.
- **Given** `dependencies`, **then**:
  - the test reads the fourteen ids in §3's order (the six Visual C++ ones first);
  - every row's `files` keys are either `{x86, x64}` or `{all}`;
  - every Visual C++ file is kind `run` with one download, whose `file` is `<id>-<arch>.exe`;
  - `vcrun2008` x86 is still `(…/5D8C65CB-…/vcredist_x86.exe, 8742bcbf…d92, 4483040, [/q])`.
- **Check:** `dart test test/dependencies_test.dart`.

## RE2 · The eight rows
The eight rows shall hold `design.md` §3's files, kinds, `cabs`, `take`, `into`, `register`, `dlls`, markers, imports and time limits. The comment shall name where the pins come from (winetricks `20260125`, by verb; Microsoft's re-signed DirectX file).

**Hosts**
- Every URL's host is one of:
  - `download.microsoft.com`;
  - `download.visualstudio.microsoft.com`;
  - `us.download.nvidia.com`;
  - `raw.githubusercontent.com`, with a 40-character commit in the path.
- `raw.githubusercontent.com` is used only by `d3dcompiler_47` and `corefonts`.

**Shared file**
- The four DirectX rows share one download, `directx-jun2010.exe`, with the same pin.

**Network test**
- **Given** `BODEGA_NETWORK_TESTS=1`, **then**:
  - every distinct download (the twelve Visual C++ ones and the new ones) arrives with its pinned size and SHA-256;
  - without the variable, the test is skipped.

- **Check:** `dart test test/dependencies_test.dart`. Once, `BODEGA_NETWORK_TESTS=1 dart test test/dependencies_test.dart -n "server"`, with the output pasted in `verify.md`.

## RE3 · Status with "unknown"
`dependencyStatus` shall return `true`, `false` or `null`, as `design.md` §5 says.
- **Given** the bottle, **then**:
  - with Microsoft-like `d3dx9_43.dll` in `syswow64`, `d3dx9 x86` is `true` and `x64` is `false`;
  - with `windows/Fonts/arial.ttf` a regular file, `corefonts all` is `true`; with it a link to a real file, it is `false`.
- **Given** `windows/syswow64` unreadable (mode `000`), **then** `d3dx9 x86` is `null`, and `deps list` prints `unknown` for it.
- **Check:** `dart test test/dependencies_test.dart`.

## RE4 · Proposals
`appNeeds` shall match import patterns, read "not in Wine" from the runtime, and propose `all` rows with arch `all`.
- **Given** a PE32 fixture importing `d3dx9_43.dll` and `PhysXLoader.dll`, and a runtime holding `lib/wine/i386-windows/d3dx9_43.dll` and no PhysX loader, **then**:
  - `d3dx9 x86` is optional (`imported`, `dll: d3dx9_43.dll`);
  - `physx all` is recommended (`notInWine`).
- **Given** a PE32+ fixture importing `mscoree.dll`, which the runtime has, **then** `dotnet48 all` is optional.
- **Given** the `dependencies` change's MFC fixture, **then** its result is unchanged.
- **Check:** `dart test test/dependencies_test.dart`.

## RE5 · Install `run` with several files and a time limit
`installDependency` shall take `files` in download order, check each against its pin, run each with `args`, and throw `InstallTimedOut(id, arch, log)` past the row's `minutes`, after stopping the bottle.
- **Given** a two-download `run` row in `dependencyTable` (a test row), **then** the fake Wine records both runs in order.
- **Given** a run that never exits and a test row with a one-second limit, **then** `InstallTimedOut` is thrown, and the bottle is stopped.
- **Given** a second file that does not match its pin, **then** `ChecksumMismatch` is thrown, and nothing runs.
- **Check:** `dart test test/dependencies_test.dart test/english_test.dart` (the new failure's English).

## RE6 · Install `cab`
A `cab` row shall do the following:
- cut each download at its first `MSCF\0\0\0\0`;
- extract it, and its matching inner cabinets, under `windows/temp/bodega-<id>`;
- copy the files that match `take` into `into`;
- run `regsvr32 /s` on the files that match `register`, with the arch's own `regsvr32`;
- delete its temporary folder whatever happens.
- **Given** the fake cabinet holding `inner_x86.cab` (with `d3dx9_43.dll`) and `inner_x64.cab`, and a test row for x86, **then** only the x86 DLL lands in `syswow64`, and `windows/temp/bodega-<id>` is gone.
- **Given** a test row with `register`, **then** the fake Wine records `syswow64\regsvr32.exe /s <dll>` for x86.
- **Given** a download with no `MSCF` header, **then** `DependencyNotInstalled` is thrown, and the temporary folder is gone.
- **Check:** `dart test test/dependencies_test.dart`.

## RE7 · Install `copy`
A `copy` row shall write its download at its marker through a temporary file renamed over it, and set its overrides.
- **Given** `d3dcompiler_47` x64 with a Microsoft-like test file, **then**:
  - `system32/d3dcompiler_47.dll` holds its bytes;
  - `user.reg` holds `"d3dcompiler_47"="native,builtin"`;
  - the status is `true`.
- **Check:** `dart test test/dependencies_test.dart`.

## RE8 · DXVK on the Mac
`BottleSettings` shall gain `dxvkAsync` (default `false`, saved only when `true`). On the Mac, a launch whose backend resolves to `dxvk` shall add `DXVK_STATE_CACHE_PATH` (the bottle's `dxvk-cache`, created, as a `Z:` path), and `DXVK_ASYNC=1` when `dxvkAsync` is on. Linux adds neither.
- **Given** a Mac launch with `dxvk`, **then**:
  - with `dxvkAsync` on, the env holds both variables;
  - with it off, it holds only the path;
  - with `wine` as the backend, it holds neither.
- **Given** a Linux launch with `dxvk` and `dxvkAsync` on, **then** it holds neither.
- **Given** the settings JSON without `dxvkAsync`, **then** it reads `false`, and writing defaults leaves the key out.
- **Check:** `dart test test/engine_test.dart` (or the platform tests where AVX's cases are).

## RE9 · AVX and msync stay tested
- **Given** a Mac launch, **then**:
  - with `avx` on, the env holds `ROSETTA_ADVERTISE_AVX=1`, and with it off, it doesn't;
  - with sync `msync`, it holds `WINEMSYNC=1`, and with `none`, `WINEMSYNC=0`.
- Existing tests count, if they already check this.
- **Check:** `dart test`. The exploration's measurements are cited in `verify.md`.

## RE10 · CLI
`deps list` shall print the fourteen rows with `installed`, `unknown` or their size. `deps install` shall take `all` and several files.
- **Given** `deps install b corefonts all`, **then** the usage accepts it. **Given** `deps install b d3dx9 all`, **then** it is `BadChoice` (exit 2, as today's bad choices).
- **Check:** `dart test test/dependencies_test.dart`; `dart compile exe bin/bodega.dart -o ../../build/bodega` builds.
