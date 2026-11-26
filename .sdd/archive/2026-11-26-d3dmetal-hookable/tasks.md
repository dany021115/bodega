# Tasks · d3dmetal-hookable

> **Renumbered on 2026-11-26:** this change's patch is `wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch`, because PR #28 took 0029 (`0029-ntdll-ntlockfile-io-status-block.patch`). The documents below were written before that and call it 0029.

## Wine

- [x] **T1 (HW1–HW3, D1–D3):** `wine/patches/0029-ntdll-hookable-d3dmetal-thunks.patch`.
  - Header: what it fixes, how it was verified, upstream status.
  - The rewrite in `process_attach`, with its `+module` trace.
  - Its row and paragraph in `wine/patches/README.md`.
- [x] **T2 (HW2):** the rewrite function built standalone with zig against a synthetic image, with its cases (`spike-files/rewrite_test.c`). It must be byte-for-byte the code in the patch.
- [x] **T3:** the series applies to the pinned CrossOver 26.3 source (`git apply --check`, in order), or this is left to the engine build when the source is not at hand.

## Engine

- [x] **T4 (HE1, HE2, HE3, D4):**
  - `platform_mac.dart` `backendEnv` sets the list for `d3dmetal`;
  - `_launchIn` drops it for an anti-cheat game;
  - tests in `packages/engine/test/`.
- [x] **T5 (HC1):** `dart analyze && dart test`; `flutter analyze && flutter test && tool/check_layers.sh`.

## Rules and delivery

- [x] **T6:** `CLAUDE.md`, "Lines not to cross", D3DMetal line: Bodega may rewrite D3DMetal's thunks in memory, never its files.
- [x] **T7:** `bump-version` (minor, 1.10.0); the PR and the release with `build_engine` are the user's decision.

## Real checks

- [ ] **T8 (HC2):** on the engine that release builds, in a temporary bottle, headless:
  - the zig test program, with and without the variable;
  - the PolyHook 2 harness, with and without the variable.
  - Output goes in this file.
- [ ] **T9 (HC3):** the user's FIFA 23 run, noted here.

## Notes from apply (2026-11-25)

- **Load order (spike-files/order.c), headless, D3DMetal 4.0b3.** Each DLL holds its thunks as soon as its own load returns:
  - `dxgi.dll` alone: 1024;
  - `d3d12.dll` alone: 1024 (it pulls `dxgi.dll` in, 1024);
  - `d3d11.dll` alone: 1024;
  - `d3d12core.dll` and `nvapi64.dll`: 0.
  So rewriting each DLL right after its own `DLL_PROCESS_ATTACH` is enough.
- **T1:**
  - `wine/patches/0029-ntdll-hookable-d3dmetal-thunks.patch` sits in `process_attach`, right after a successful `DLL_PROCESS_ATTACH`. The pure function is between the BEGIN/END markers; `make_thunks_hookable` walks the writable sections one memory region at a time.
  - After review: the list buffer keeps its last WCHAR at 0, because Wine copies a value that fills the buffer exactly without a terminator (`dlls/ntdll/env.c:208-213`). The thread-safety wording is narrowed to Windows threads.
  - README row and paragraph: kind `workaround (opt-in: BODEGA_HOOKABLE_THUNKS)`, from `Bodega`.
- **T2:** `spike-files/run_rewrite_test.sh` cuts the block from the patch file and runs `rewrite_test.c`.
  - Toolchain: `xcrun clang -std=c99 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=all`, at -O0 and -O2, arm64 and x86_64. This is clang, not zig: the deviation from HW2's wording is noted for the spec.
  - Result: 12 cases, 0 failed. 20 mutants of the function, each with one deliberate bug, are all caught.
- **T3:**
  - On a clean clone of `~/Downloads/sources/wine` (CrossOver 26.3 tree; Wine 11.0), `patch -p1` applies all 28 files in order (0001–0029, no 0004), and the resulting `loader.c` equals the edited one. The tarball's SHA-256 could not be checked: the tarball is not on this Mac.
  - Compile check: zig's clang, `x86_64-windows-gnu`, Wine's PE ntdll flags (`spike-files` of the review: `scratchpad/rwtest/scripts/check.sh`) with `-Wall -Wextra -Wdeclaration-after-statement -Wunused -Wsign-compare -Wshadow`. Exit 0, and 0 diagnostics new against the loader without 0029 (17 old ones in both).
  - mingw-w64 gcc is not on this Mac; CI's `build_engine` run is the gcc check.
- **T4:**
  - `platform_mac.dart`: the `d3dmetal` case sets the list (HE1).
  - `engine.dart` `_launchIn`: `remove: {…, if (fix?.antiCheat != null) 'BODEGA_HOOKABLE_THUNKS'}`, which drops it whatever the bottle, program or fix env says (HE2).
  - HE3 needs no code.
  - Tests: `options_test.dart` HE1 and HE3; `fixes_test.dart` HE2, with a control and the bottle env case; `backends_test.dart` gets the exact d3dmetal map. A mutation (the HE2 line disabled) fails HE2.
- **T5:**
  - engine: `dart analyze` no issues; `dart test` +521 ~5, twice;
  - app: `flutter analyze` no issues; `flutter test` +1030; `tool/check_layers.sh` "Layers OK".
- **T6:** done (`CLAUDE.md`, D3DMetal line).
- **HC2 in the process, before the engine is built** (`spike-files/hook_harness.cpp`, `build_hook_harness.sh`). Bottle `hookspike2`, current engine, headless; logs `bottles/hookspike2/logs/2026-11-26T01-5*-hook_harness.log`.
  - PolyHook 2 at b0aac63 (2023-07-19), no rewrite: `exception 0xc0000005 at 39200000003C25FF (not in any module), execute`, exit 3. The relocated `ff 25 06 00 00 00` reads its jump table's own bytes.
  - PolyHook 2 at b0aac63, with the in-process rewrite: 1024 thunks rewritten in `dxgi.dll` and 1024 in `d3d12.dll`; Present starts `48 b8`; 3 of 3 S_OK; detour calls 3.
  - PolyHook 2 at 0d4d90e (2023-07-13), no rewrite: refuses to hook ("Function too small to hook safely!"). With the rewrite: 3 of 3 S_OK.
  - MinHook 0f25a24, with and without the rewrite: 3 of 3 S_OK, detour calls 3.
- **Review (4 lenses, 34 agents) found three things that need a spec decision.**
  - FIFA 23 is in `fixes_data.dart:282` with `antiCheat {EA anticheat, blocked}`, so HE2 leaves it out whenever Bodega recognises it, by its Steam id or its title.
  - HE2 does not hold:
    - when the game's configuration is switched off;
    - for "Run .exe" (`runInBottle` looks up no GameFix);
    - for a game started by a launcher that is already running.
  - Reading every writable region makes `dxgi.dll`'s untouched 16 MB `.data` resident in every process that loads it.
  - These go to the user before any code changes.

## Decisions of 2026-11-26 and the rest of apply

**The user's decisions:**
- **1a:** HE2 stays as it is, FIFA 23 included.
- **2:** HE2 holds with the game's configuration turned off. `openApp` now passes `antiCheat`, and `fixes_test` HE2 has that case; a mutation without it fails.
- **3:** only executable regions are scanned. `dxgi.dll`'s `.data` is RW in its header, and only the thunk pages become RX.
- **4:** PolyHook 2 pinned at b0aac63; checks in a temporary `BODEGA_HOME`; a boot check for the new engine.

The specs, the design and the patch header follow these decisions.

**Local build of the patched loader** (instead of waiting for CI):
- **Source:** a clean clone of the CrossOver 26.3 tree with the 28 patches applied in order.
- **Configure:** like `build.yml`, with `--enable-archs=i386,x86_64`.
- **Compilers:**
  - host tools: `/usr/bin/clang -arch x86_64` under `arch -x86_64` (the explicit `-arch` is needed: CrossOver's configure adds `-D__x86_64__`, and xcrun's clang ran arm64);
  - PE side: Homebrew clang 21, which Wine drives as `-target x86_64-windows -fuse-ld=lld`;
  - linker: zig's `lld-link` (LLD 22) through a wrapper.
  - Homebrew's own `lld` was not used: it pulls LLVM 23 (457 MB), and that install was cancelled.
- **Output:** `make dlls/ntdll/x86_64-windows/ntdll.dll`, in 9 s, then `llvm-strip --strip-debug` (942,080 bytes).
- **Against the shipped `ntdll.dll`:**
  - the same 1463 exports with the same ordinals;
  - 516 of 516 Nt/Zw syscall ids identical;
  - "Wine builtin DLL" signature;
  - the new strings present.

**T8 on that loader, before CI:** a temporary `BODEGA_HOME` (`scratchpad/home0029`) with an APFS clone of the Rosetta runtime, the new `ntdll.dll` and a symlink to the user's D3DMetal 4.0b3. The CLI was built from this branch.
- `bodega create hk`: `wineboot` exit 0.
- `hook_harness.exe polyhook` (PolyHook 2 b0aac63), with no in-process rewrite:
  - "thunks in dxgi.dll: 0", "thunks in d3d12.dll: 0";
  - Present at `dxgi.dll+0x1007080` starts `48 b8`;
  - 3 of 3 S_OK, detour ran 3 times, exit 0.
- `hook_harness.exe minhook`: 3 of 3 S_OK, exit 0.
- Bottle env `BODEGA_HOOKABLE_THUNKS=''`:
  - 1024 thunks left in each;
  - PolyHook faults at `0x39200000003C25FF` (not in any module), exit 3.
- `WINEDEBUG=trace+module` logs:
  - `L"dxgi.dll": 1024 thunks made hookable`;
  - `L"d3d12.dll": 1024 thunks made hookable`;
  - `L"d3d12core.dll": 0 thunks made hookable`.
- `WINEDEBUG=+module` aborts the process at start (`debugstr buffer overflow` in `start_main_thread`, exit 134), and does so with the shipped `ntdll.dll` too, so it is not this patch.
- What is still open: the same checks on the engine that CI's `build_engine` builds with mingw gcc.

**T9 (the user, 2026-11-26).** The user's real Rosetta runtime got the local `ntdll.dll`; the shipped one is kept as `runtimes/<engine>/ntdll.dll.shipped`. The debug app was built from this branch.
- FIFA 23 (bottle `Fifa22`, D3DMetal), opened directly: the mod hooks and the game no longer crashes.
- The keyboard was not reported.
- **Speed, measured with `bodega measure Fifa22 30`:** GPU 99 % over 26 samples; CPU about 430 %, no thread above about 47 %.
  - The Metal HUD showed 4096x2660: the game's 2048x1330 doubled by Retina "on" in that bottle. FPS was 32, GPU time 30.3 ms.
  - With the bottle's Retina off, the user reports 90 fps.
  - That change belongs to the bottle, not to this change.

**T7:** `tool/version.sh bump minor` gave 1.9.0+17 -> 1.10.0+18.

**Checks after these changes:**
- `run_rewrite_test.sh`: 12 cases, 0 failed.
- Engine: `dart analyze` no issues; `dart test` +521 ~5.
- App: `flutter analyze` no issues; `flutter test` +1030; `tool/check_layers.sh` "Layers OK".

## Added in apply (the user's go-ahead of 2026-11-26): the Metal 4 switch

- [x] **T10:** a Rosetta bottle's Metal 4 switch, when off, now sends `D3DM_MTL4=0` on `d3dmetal` launches, instead of nothing.
  - **Why:** D3DMetal 4.0b3 reads `D3DM_MTL4` (it is among its strings) and takes Metal 4 when the variable is unset. So "off" left Metal 4 on: FIFA 23's Metal HUD read "D3D12 (Metal 4)" with the switch off, and "D3D12" only with `D3DM_MTL4=0` (2026-11-26).
  - **Measured on FIFA 23,** all graphics at their highest, 2048x1330, Retina off, dynamic resolution on (the scenes differed, so this is indicative):
    - Metal 4: 55.5 fps, GPU 17.9 ms;
    - Metal 4 near the box: 51.4 fps, GPU 19.4 ms;
    - without: 58.0 fps.
  - **The code change:**
    - `engine.dart` `_launchIn` now sends `'D3DM_MTL4': settings.metal4 ? '1' : '0'` where D3DMetal draws;
    - the doc in `backends.dart` follows.
  - **Test:** `options_test.dart` ER8 now also checks the `0`.
  - **Effect:** bottles that never turned the switch on now really run without Metal 4, which is what the switch and its note always said.
  - **Checks:** engine `dart analyze` no issues; `dart test` +521 ~5.
