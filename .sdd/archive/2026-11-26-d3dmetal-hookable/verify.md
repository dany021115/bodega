# Verify · d3dmetal-hookable

> **Renumbered on 2026-11-26:** this change's patch is `wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch`, because PR #28 took 0029 (`0029-ntdll-ntlockfile-io-status-block.patch`). The documents below were written before that and call it 0029.

Date: 2026-11-26.
- Branch `feat/d3dmetal-hookable`, cut from `origin/main` b56463d (v1.9.0), uncommitted.
- Version 1.10.0+18.

## Requirements

| Requirement | Verdict | Evidence |
|---|---|---|
| HW1 · thunks rewritten after load | Met on a locally built loader | **Headless run** (tasks.md, "T8 on that loader"): the CrossOver 26.3 tree with the 28 patches, built locally with clang and lld (same 1463 exports, same ordinals, 516 of 516 syscall ids as the shipped `ntdll.dll`). Right after load: "thunks in dxgi.dll: 0", "thunks in d3d12.dll: 0", and Present at `dxgi.dll+0x1007080` starts `48 b8`. **The user's own FIFA 23** (2026-11-26 08:20:17, the mod's log): "Original bytes for DirectX12 - Present: 48 B8 7E D7 B8 12 02 00 00 00 FF E0 90 90". `ResizeBuffers` and `ResizeBuffers1` are the same. |
| HW1 · Present still works | Met | **PolyHook 2** b0aac63 on that loader: 3 of 3 S_OK, the detour ran 3 times. **MinHook:** the same. |
| HW1 · nothing without the variable | Met | **With the bottle env `BODEGA_HOOKABLE_THUNKS=''`:** 1024 thunks left in each DLL, and PolyHook faults at `0x39200000003C25FF`, as before the patch. |
| HW2 · byte rules | Met | **`run_rewrite_test.sh`, run on the block cut from the patch file:** 12 cases, 0 failed, under ASan and UBSan. During apply, 20 mutants of the function were all caught. |
| HW2 · "not listed", "not writable or not executable" | Met, indirectly | **"Not listed"** is the empty-list run above: no DLL changed. **"Not writable or not executable"** follows from the headers: `dxgi.dll`'s `.data` is RW and only its thunk pages are RX, so the 16 MB of untouched data are never read. No test plants a thunk in an unlisted module. |
| HW3 · traceable | Met | **`WINEDEBUG=trace+module`** logs `L"dxgi.dll": 1024 thunks made hookable`, `L"d3d12.dll": 1024 …` and `L"d3d12core.dll": 0 …`. **`+module` alone** aborts this engine at start (`debugstr buffer overflow`, exit 134), and does so with the shipped `ntdll.dll` too, so it is not this patch. The spec says so. |
| HE1 · D3DMetal launches ask for it | Met | `options_test` "HE1 only D3DMetal launches ask for them": the d3dmetal list, none on dxmt, dxvk, dxvk9, wine or Mach9. `backends_test` checks the exact d3dmetal map. |
| HE2 · not for anti-cheat games | Met | `fixes_test` "HE2 no hookable thunks for a game with anti-cheat": a control without anti-cheat; EAC with the bottle env asking for it; and the configuration turned off. A mutation without `antiCheat` fails the last case. |
| HE3 · a program turns it off | Met | `options_test` "HE3 a program turns them off with an empty value"; in the loader, see the empty-list run. |
| HC1 · automated | Met | Output below. |
| HC2 · real, headless | Met on the local build; open for the CI build | All of HW1 to HW3 above. The engine that `release-macos` `build_engine` builds with mingw gcc has not been run. The same checks, and a `wineboot` boot check, are due on it before the user installs 1.10.0. |
| HC3 · the user | Met | FIFA 23 (bottle `Fifa22`, D3DMetal), opened directly: the game no longer crashes. On 2026-11-26 08:09 the mod logged "Creating Present Detour", then "Waiting for main menu...", with no crash report. The user: the keyboard works. |
| T10 · Metal 4 off means off | Met | **`options_test` "ER8 …":** off gives `D3DM_MTL4=0`, on gives `1`, wine gives none. **On the user's screen:** the HUD read "D3D12 (Metal 4)" with the switch off before the change, and "D3D12" with `D3DM_MTL4=0`. |

## Output (2026-11-26)

```
$ patch -p1 < wine/patches/0*.patch   (clean clone of ~/Downloads/sources/wine, CrossOver 26.3)
applied 28 of 28

$ clang -target x86_64-windows -fsyntax-only <Wine's PE ntdll flags> -Wall -Wextra -Wshadow -Wsign-compare -Wdeclaration-after-statement dlls/ntdll/loader.c
before (series without 0029): exit 0 warnings 17 errors 0
after  (series with 0029):    exit 0 warnings 17 errors 0
diagnostics only in the patched loader.c: 0

$ bash .sdd/d3dmetal-hookable/spike-files/run_rewrite_test.sh
12 cases, 0 failed
$ dart analyze
No issues found!
$ dart test
01:16 +521 ~5: All tests passed!
$ dart test test/options_test.dart test/fixes_test.dart test/backends_test.dart --name 'HE1|HE2|HE3|ER8|backendEnv'
+1: test/options_test.dart: ER8 metal4: D3DM_MTL4 only where D3DMetal draws
+2: test/fixes_test.dart: launching a Steam game HE2 no hookable thunks for a game with anti-cheat
+3: test/options_test.dart: D3DMetal thunks that hooks can copy (wine/patches/0029) HE1 only D3DMetal launches ask for them
+4: test/options_test.dart: D3DMetal thunks that hooks can copy (wine/patches/0029) HE3 a program turns them off with an empty value
+5: All tests passed!
$ flutter analyze
No issues found! (ran in 1.5s)
$ flutter test
00:32 +1030: All tests passed!
$ tool/check_layers.sh
Layers OK
$ tool/version.sh check
OK: version 1.10.0 (tag v1.9.0).

user runtime ntdll.dll has 0029: True | size 942080
shipped copy kept: 1153388 bytes   (runtimes/engine-wine-11.0-20261030T202616Z-primer-build/ntdll.dll.shipped)
```

## Known

- **The headless runs were not repeated today.** They are recorded in tasks.md, with the outputs of 2026-11-26. A reboot then cleared the scratch folder that held their builds: zig, PolyHook 2, the Wine build tree and the temporary home. Repeating them means about 80 MB of downloads again; the CI engine's check (HC2) repeats them anyway.
- **The mod does not always create its detours.** In some sessions it stops after reading the addresses (08:19, 08:24), and the game goes on. In others it creates them (08:09), and with 0029 there is no crash. That stop is the mod's.
- **Until 1.10.0 ships, the user's Rosetta runtime runs a test loader.** It is the `ntdll.dll` built locally with clang. The CI one is built with mingw gcc. The shipped loader is kept next to it.
- **The bottle `Fifa22` has Retina off and Metal 4 off.** These are the user's choices for speed, and FIFA 22 is in the same bottle. FIFA 23 also has its program env `D3DM_MTL4=0` and its own `fifasetup.ini` settings.
- **On "Run .exe" and launchers:** "Run .exe" and games started by an already-running launcher are outside HE2, as the docs say.
