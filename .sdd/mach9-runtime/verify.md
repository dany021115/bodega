# Verify · mach9-runtime

Run on 2026-11-19, on this Mac (macOS 27.2.1, arm64), headless only. `bodega` is `fvm dart compile exe bin/bodega.dart` of the tree under test. Experiments used temporary homes (`BODEGA_HOME=<scratchpad>/v/home1`, `home2`, `home3`); the user's real home was touched only by V4's read-only checks and one probe run.

## V1 · Join

Both streams are in one tree.

| Where | Command | Result |
|---|---|---|
| engine | `fvm dart format --output=none --set-exit-if-changed lib test bin` | 36 files, 0 changed |
| engine | `fvm dart analyze` | No issues found |
| engine | `fvm dart test` | 373 passed, 4 skipped (3 old + opt-in `BODEGA_TEST_MACH9`) |
| app | `fvm dart run build_runner build --delete-conflicting-outputs` | OK, 0 outputs to write |
| app | `fvm flutter gen-l10n` | OK, nothing untranslated |
| app | `fvm flutter analyze` | No issues found |
| app | `fvm flutter test` | 878 passed |
| app | `tool/check_layers.sh` | Layers OK |

## V2 · Real install (MR2–MR7, MC1, MC2)

Sources: the pinned DMG and MSI, downloaded again in E0 because the scratchpad copies named in tasks.md were gone.

```
shasum -a 256 Mach9.dmg wine-mono-11.3.0-x86.msi
3b5dd83ee7b08d55e6c4a84dabb32db994dc6a5bfb2a1500fb50d0b45436e6d9  Mach9.dmg
df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3  wine-mono-11.3.0-x86.msi
```

**From the DMG** (home1), 4.9 s:

```
$ bodega runtime install mach9 .../Mach9.dmg --mono .../wine-mono-11.3.0-x86.msi
Opening the dmg
Checking Mach9's signature
Copying Mach9
Checking the copy
Switching to the new version
.../home1/runtimes/mach9-0.4.0
$ bodega runtime list
bodega: not installed
mach9: installed 0.4.0 (mach9-0.4.0)
runtime.json: {"kind":"mach9","version":"0.4.0","source":"dmg","checked":true}
runtimes/: mach9 -> mach9-0.4.0, mach9-0.4.0/
hdiutil info: no Mach9 volume left mounted
```

**From `/Applications/Mach9.app`** (home2), 1.1 s:

```
Checking Mach9's signature
Copying Mach9
Checking the copy
Switching to the new version
runtime.json: {"kind":"mach9","version":"0.4.0","source":"app","checked":true}
mach9-0.4.0/: engine  runtime.json  wine-mono-11.3.0-x86.msi
engine/bin/wine -> ../lib/wine/aarch64-unix/wine.app/Contents/MacOS/wine   (still a symlink)
engine/bin/wine --version: wine-11.21-54-g501796b0ed
```

A second install of the same version gives `already installed: .../mach9-0.4.0 ...`, exit 1 (MR7).

**MR2:** `MacPlatform().mach9Block` is `null` on this Mac.

**MR6, the copied `wine.app`** (both homes):

```
$ codesign --verify --strict --verbose=2 .../engine/lib/wine/aarch64-unix/wine.app
...: valid on disk
...: satisfies its Designated Requirement
TeamIdentifier=WLKUUJD25W
```

**MR5, a tampered copy:** `ditto /Applications/Mach9.app` to the scratchpad. Untouched, `MacPlatform().signingTeam(copy, deep: true)` gives `WLKUUJD25W`. After one byte at offset 2000 of `Contents/Resources/wine/lib/wine/aarch64-windows/d3d9.dll` was changed (outside `wine.app`):

```
signingTeam(copy, deep: true) -> THROWS RuntimeNotTrusted: ... is not signed by the developer of Mach9, so Bodega will not use it: ...: a sealed resource is missing or invalid
$ bodega runtime install mach9 <tampered copy> --mono ...   (home3)
Checking Mach9's signature
bodega: ... is not signed by the developer of Mach9 ... a sealed resource is missing or invalid
exit 1; home3/runtimes/ empty (no .tmp-*, no link)
```

**MR3, the Mono hash in `appwiz.cpl`:** `strings lib/wine/aarch64-windows/appwiz.cpl` and `lib/wine/i386-windows/appwiz.cpl` each hold `df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3` once, next to `11.3.0`.

## V3 · Real bottle and probes (MB5–MB7, MG5, MG8, MG10, MC3, MC5)

In home2 (runtime from the app):

```
$ /usr/bin/time -p bodega create --runtime mach9 m9t
Creating the Windows folder
Installing Wine Mono
real 20.56
```

Logs: wineboot 20:02:09 → reg 20:02:22 (about 12.5 s of wineboot), both `reg add` under a second, Mono 20:02:23 → end (about 7 s). Every exit file is `0`.

- `settings.json`: `{"runtime":"mach9","backend":"auto","sync":"msync","programs":{}}`.
- `prefix/drive_c/windows/system32/kernel32.dll` machine `0xAA64` (MB2).
- **MB7:** `prefix/drive_c/windows/mono/mono-2.0` exists (Mono 225 MB). The Mono log has one `err:msi:... failed to load dll L"C:\\windows\\mono\\mono-2.0\\support\\createlinks-x86_64.dll" (193)`. That is Mono's optional x86_64 link helper on an aarch64 prefix; msiexec still exits 0.
- **MB6:** `prefix/user.reg` holds:

  ```
  [Software\\Wine\\WineDbg] ...
  "ShowCrashDialog"=dword:00000000
  [Software\\Wine\\X11 Driver] ...
  "EmulateModeset"="Y"
  ```

- Internal runs carry `# rules exe=*;dxgi=wined3d;d3d9=wined3d;dll_overrides=winemenubuilder.exe= | exe=reg.exe;dxgi=wined3d;d3d9=wined3d` (the same with `msiexec.exe`), and compatdb reports `reg.exe`/`msiexec.exe` values from `WINE_COMPATDB line 2`.

**MG5 / MC5, `bodega rules`:**

```
$ bodega rules m9t iw5mp.exe
exe=*;dll_overrides=winemenubuilder.exe=
$ bodega rules m9t --backend mtld3d --hud iw5mp.exe
exe=*;d3d9=mtld3d;metal_hud=true;dll_overrides=winemenubuilder.exe=
exe=iw5mp.exe;d3d9=mtld3d
$ bodega backend list --runtime mach9
wine: installed
dxmt: installed
mtld3d: installed
```

**MG10 / MG8, probes:**

```
$ bodega backend test m9t mtld3d     (2.5 s)
OK   D3D9 32 bits
OK   D3D9 64 bits
$ bodega backend test m9t dxmt       (7.2 s)
OK   D3D11 32 bits
OK   D3D11 64 bits
OK   D3D12 64 bits
$ bodega backend test m9t wine       (5.8 s)
OK   D3D9 32 bits
OK   D3D9 64 bits
OK   D3D11 64 bits
```

compatdb lines of each probe log (paths trimmed):

| case | `# rules` | probe's field | dll_overrides |
|---|---|---|---|
| mtld3d 32/9 (i386), 64/9 (x86_64 arm64ec) | `exe=*;d3d9=mtld3d;dll_overrides=winemenubuilder.exe=;dll_overrides=winedbg.exe= \| exe=probe-NN.exe;d3d9=mtld3d` | `d3d9 = mtld3d, WINE_COMPATDB line 2` | `winemenubuilder.exe= (WINE_COMPATDB line 1); winedbg.exe= (WINE_COMPATDB line 1)` |
| dxmt 32/11, 64/11, 64/12 | `exe=*;dxgi=dxmt;... \| exe=probe-NN.exe;dxgi=dxmt` | `dxgi = dxmt, WINE_COMPATDB line 2` | same |
| wine 32/9, 64/9, 64/11 | `exe=*;dxgi=wined3d;d3d9=wined3d;... \| exe=probe-NN.exe;dxgi=wined3d;d3d9=wined3d` | `dxgi`, `d3d9 = wined3d, WINE_COMPATDB line 2` | same |

`grep -c 'warning:'` is 0 in every log of the bottle (wineboot, reg, Mono and the 8 probes).

Then `bodega stop m9t` (exit 0) and `removeBottle(home2, 'm9t')` through the engine (the CLI has no `remove` verb, as before this change): `bottles/` is empty.

## V4 · Nothing broken (MR7, MB2, MD1)

The user's real home, `~/Library/Application Support/Bodega`, one bottle `Games`:

| Check | Before | After |
|---|---|---|
| `readlink runtimes/current` | `engine-wine-11.0-20261030T202616Z-primer-build` | same |
| `ls runtimes` | `current`, `engine-wine-…` | same (no `mach9*`) |
| `shasum bottles/Games/settings.json` | `4ad2a1e54267c3f90d6b0383b74a608c0fe5b14d` | same |

- `Games`' `system32/kernel32.dll` machine is `0x8664`, so it stays bodega (MB2). `bodega runtime list` prints `bodega: installed (engine-wine-11.0-20261030T202616Z-primer-build)` and `mach9: not installed`.
- `bodega backend test Games dxmt` (4.1 s):

  ```
  OK   D3D11 64 bits
  OK   D3D11 32 bits
  ```

  Its log starts `# runtime engine-wine-11.0-…`, `# backend dxmt (option)`, and has no `# rules` line (the Rosetta path is unchanged).
- MD1: the archived spec files were not edited.

## R1 · Review fixes (2026-11-19)

- Engine: `fvm dart analyze` no issues; `fvm dart test` 379 passed, 4 skipped; `BODEGA_TEST_MACH9=/Applications/Mach9.app fvm dart test test/mach9_test.dart -N "real Mach9.app"` passed.
- App: build_runner, gen-l10n, `fvm flutter analyze` no issues, `tool/check_layers.sh` "Layers OK"; `fvm flutter test` all pass except `switch_repository_test` "a game runs until Stop…", which fails in this agent sandbox with `PathAccessException … Applications/Ryujinx.app/Contents/MacOS/code (Operation not permitted)` (macOS refuses writes inside a fake `.app` here; no switch code changed).
- `ditto --noqtn /Applications/Mach9.app` 0.27 s; `codesign --verify --deep --strict` on the copy 0.33 s, rc 0; one byte appended to the copy's `aarch64-windows/d3d9.dll` → "a sealed resource is missing or invalid", rc 1.
- Temporary `BODEGA_HOME`, compiled CLI: install from `/Applications/Mach9.app` (steps: copying, signature, checking, switching; 2.1 s); again → "already installed"; link removed by hand plus a `.tmp-mach9-0.4.0` left → `runtime list` "mach9: not installed"; install from `Mach9.dmg` → succeeds, `runtimes/` holds `.mach9.lock`, `mach9`, `mach9-0.4.0`, no mount left; copied `wine.app` passes `codesign --verify --strict`; `wine --version` → `wine-11.21-54-g501796b0ed`.
- Lock: a Python `fcntl.lockf` held on `runtimes/.mach9.lock` for 6 s made an install wait (elapsed 6 s, rc 0); two CLI installs started together → one rc 0, the other "already installed".

## V5 · Docs, version and final checks (2026-11-19)

- Docs: `README.md`, `.claude/CLAUDE.md`, `AGENTS.md`, `.claude/rules/architecture.md`, `wine/NOTICE.md`. `grep -n Mach9 README.md` hits lines 6, 16, 18, 42, 69, 72, 73, 74, 82, 139, 149; `awk 'FNR == 3' .claude/CLAUDE.md AGENTS.md | grep -c Mach9` prints 2; `grep -n Mach9 wine/NOTICE.md` hits lines 17 and 18.
- Version: `tool/version.sh bump minor` → `Version: 1.6.0+14 -> 1.7.0+15`; `tool/version.sh check` → `OK: version 1.7.0 (tag v1.6.0).`
- Engine: `fvm dart format --output=none --set-exit-if-changed lib test bin` 36 files, 0 changed; `fvm dart analyze` no issues; `fvm dart test` 379 passed, 4 skipped.
- App: build_runner OK; gen-l10n OK; `fvm flutter analyze` no issues; `tool/check_layers.sh` "Layers OK"; `fvm flutter test` 878 passed, 1 failed in the agent sandbox (`switch_repository_test` "a game runs until Stop…", the `PathAccessException` of R1); the same file run outside the sandbox: 18 passed, all tests passed.
- Delivery (V7): `/Users/arian/Documents/GitHub/Arian/bodega-commit-mach9.sh`, beside the repo, not run. It starts from `main`, runs `git switch --no-track -c feat/mach9-runtime`, runs `tool/version.sh check` before each of five commits (version, engine, app, docs, `.sdd`), adds no attribution, and leaves `.fvmrc` out (Q3).

## Requirements

Status as of V5 (2026-11-19). "Pass" means the task's checks passed: the unit and widget tests named in the spec, plus the headless sections above where a V task is named.

| Requirement | Status | Evidence |
|---|---|---|
| MR1 Two runtime kinds | Pass | E1 tests; V1 and R1 full checks |
| MR2 Where Mach9 can run | Pass | E1, V2; outputs in V2 above |
| MR3 The release pin | Pass | E1, V2; outputs in V2 above |
| MR4 Sources | Pass | E5, V2; outputs in V2 above |
| MR5 Trust of what was copied | Pass | E0, E5, V2, R1; outputs in V2 above |
| MR6 Copied unmodified, then checked | Pass | E5, V2, R1; outputs in V2 above |
| MR7 Layout and links | Pass | E5, V2, V4, R1; outputs in V2, V4 above |
| MR8 Updating | Pass | E5, R1 tests; V1 and R1 full checks |
| MR9 Failure and cancel leave nothing | Pass | E5, R1 tests; V1 and R1 full checks |
| MR10 Resolving a kind's folder | Pass | E1 tests; V1 and R1 full checks |
| MR11 HostPlatform seams | Pass | E1 tests; V1 and R1 full checks |
| MR12 Never bundled | Pass | E2, E8 tests; V1 and R1 full checks |
| MR13 The shared contract | Pass | E1 tests; V1 and R1 full checks |
| MB1 The runtime in settings.json | Pass | E1, R1 tests; V1 and R1 full checks |
| MB2 The prefix has the last word | Pass | E1, E4, V4; outputs in V4 above |
| MB3 Every operation on the bottle's runtime | Pass | E2, R1 tests; V1 and R1 full checks |
| MB4 Host preparation by kind | Pass | E2 tests; V1 and R1 full checks |
| MB5 Creating a Mach9 bottle | Pass | E0, E6, V3; outputs in V3 above |
| MB6 Registry values of a Mach9 prefix | Pass | E0, E6, V3; outputs in V3 above |
| MB7 Wine Mono in each Mach9 prefix | Pass | E0, E6, V3; outputs in V3 above |
| MB8 A missing Mono is shown, never fixed silently | Pass | E1, E6 tests; V1 and R1 full checks |
| MB9 The catalog | Pass | E6 tests; V1 and R1 full checks |
| MB10 No network after install | Pass | E6 tests; V1 and R1 full checks |
| MG1 Names per kind | Pass | E1 tests; V1 and R1 full checks |
| MG2 Installed, fits and catalog mapping per kind | Pass | E1 tests; V1 and R1 full checks |
| MG3 Choices checked against the bottle's kind | Pass | E4 tests; V1 and R1 full checks |
| MG4 The canonical rule writer | Pass | E3 tests; V1 and R1 full checks |
| MG5 Lines for one launch | Pass | E3, V3; outputs in V3 above |
| MG6 The Mach9 environment | Pass | E3 tests; V1 and R1 full checks |
| MG7 The HUD | Pass (tests); USER | E3 tests; the HUD inside iw5mp.exe is V6 |
| MG8 DLL overrides as rules | Pass | E0, E3, V3; outputs in V3 above |
| MG9 The user's own rules | Pass | E3 tests; V1 and R1 full checks |
| MG10 Probes in Mach9 bottles | Pass | E0, E4, V3; outputs in V3 above |
| MG11 Log header and hints | Pass | E3 tests; V1 and R1 full checks |
| MG12 dxvk9 (folded in) | Pass | A0 tests; V1 and R1 full checks |
| MG13 Fixes in Mach9 bottles | Pass | E3 tests; V1 and R1 full checks |
| MC1 runtime list | Pass | E7, V2; outputs in V2 above |
| MC2 runtime install mach9 | Pass | E7, V2; outputs in V2 above |
| MC3 create --runtime | Pass | E7, V3; outputs in V3 above |
| MC4 mono install | Pass | E7 tests; V1 and R1 full checks |
| MC5 rules | Pass | E7, V3; outputs in V3 above |
| MC6 backend list --runtime | Pass | E7 tests; V1 and R1 full checks |
| MC7 catalog install --runtime | Pass | E7 tests; V1 and R1 full checks |
| MC8 Existing verbs follow the bottle | Pass | E7 tests; V1 and R1 full checks |
| MA1 The role map test starts green | Pass | A0 tests; V1 and R1 full checks |
| MA2 Domain | Pass | A1 tests; V1 and R1 full checks |
| MA3 Errors | Pass | A1, A2, A6 tests; V1 and R1 full checks |
| MA4 Repositories | Pass | A6 tests; V1 and R1 full checks |
| MA5 BackendsBloc and the engine card | Pass | A3, A4, A5 tests; V1 and R1 full checks |
| MA6 New bottle dialog | Pass | A3, A4, A5 tests; V1 and R1 full checks |
| MA7 Bottle column | Pass | A3, A4, A5 tests; V1 and R1 full checks |
| MA8 Run with options | Pass | A4, A5 tests; V1 and R1 full checks |
| MA9 Text | Pass | A2 tests; V1 and R1 full checks |
| MA10 Mappers | Pass | A6 tests; V1 and R1 full checks |
| MA11 End to end on a fake runtime (optional) | Pass | A7 tests; V1 and R1 full checks |
| MD1 Amended archived requirements | Pass | J0, V4: archived specs not edited; the amendments are named in specs/docs.md |
| MD2 README | Pass | V5: `grep -n Mach9 README.md` shows the intro, What it does, Requirements, Install (Native engine), D3DMetal, License and Credits |
| MD3 Agent rules | Pass | V5: `awk 'FNR == 3' .claude/CLAUDE.md AGENTS.md \| grep -c Mach9` prints 2; CLAUDE.md Commands and Lines not to cross, architecture.md Host platform |
| MD4 Notice | Pass | V5: `grep -n Mach9 wine/NOTICE.md` shows the Mach9 row and the Wine Mono pin row |
| MD5 Version | Pass | V5: `tool/version.sh bump minor` 1.6.0+14 -> 1.7.0+15; `tool/version.sh check` OK |
| MD6 Headless real check (agent) | Pass | V2, V3, V4, R1 above |
| MD7 USER checks | USER | V6, not run yet |
| MD8 Delivery | Prepared | V7: `../bodega-commit-mach9.sh` written, not run; the user runs it |

## V6 · USER checks (to fill in)

Commit tested: · Date: · macOS:

- MW3 through Plutonium in a Mach9 bottle, the game added by its Unix path on "/Volumes/Satechi HD": 
- CPU and GPU use, Bodega Mach9 bottle / Mach9.app / Rosetta bottle: 
- HUD on, shown inside iw5mp.exe: 
- Game Mode turns on: · the Dock shows "Mach9": 
- Existing Rosetta bottles still open and play: 
