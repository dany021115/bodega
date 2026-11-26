# Exploration · d3dmetal-hookable

Date: 2026-11-25.
- Branch `feat/d3dmetal-hookable`, cut from `origin/main` b56463d (v1.9.0).
- `.sdd/` is written in English, as the project's `CLAUDE.md` asks; this overrides the skill's Spanish default.

## Problem

Under D3DMetal on the Rosetta engine, a program that inline-hooks DXGI or Direct3D 12 methods can crash the game. Examples:
- overlays;
- mods that draw their own window over the game;
- FPS counters.

**Seen with FIFA 23 Live Editor v23.1.3.3** (2026-11-25, M2 Pro, Bodega 1.9.0 Rosetta engine, D3DMetal backend, bottle `Fifa22`). The mod uses PolyHook to detour `IDXGISwapChain::Present`, `ResizeBuffers`, `ResizeBuffers1` and `ID3D12CommandQueue::ExecuteCommandLists`:
- **Every time it creates the detours, the game jumps to `0x3825FF` and dies.** This is a DEP fault. The game's own crash reports `CrashReport_25112026175840365.json`, `…182906199.json`, `…190240409.json`, `…190346346.json` and `…190439…` all show `Rip = 0x3825FF`.
- **When the mod stalls before creating the first detour, the game survives** but loses the keyboard. Seen at 17:59; the mod's log stops after "ExecuteCommandLists Addr". That the stall and the lost keyboard are linked is likely, not proven.
- **The same mod hooks fine on Mach9.** There, D3D12 is vkd3d-proton, whose methods start like ordinary code. Its log (19:59:40) shows all four "Creating … Detour" lines, then "Waiting for main menu…", with no crash.

## Root cause (measured)

D3DMetal's DXGI and D3D12 methods are **thunks** that jump to the native Mach-O code. Each one starts with:

```
66 90                 nop
ff 25 00 00 00 00     jmp qword ptr [rip]   ; reads the 8 bytes right after it
<8-byte absolute address>
```

The mod's hook dump in the Bodega run log (`bottles/Fifa22/logs/2026-11-25T23-28-34.671567Z-FIFA23.log`) shows how PolyHook relocates that prologue into its trampoline:

```
Trampoline:
fb35f930 [2]: 66 90                 nop
fb35f932 [6]: ff 25 06 00 00 00     jmp qword ptr [rip + 6] -> 200000003825ff
Trampoline Jmp Tbl:
fb35f93e [6]: ff 25 38 00 00 00     jmp [fb35f97c] -> 212cd777e
```

- **The relocated `jmp [rip+6]` reads the bytes of PolyHook's own jump-table instruction** (`ff 25 38 00 …`) as its destination. The low bytes of that bogus destination are `0x3825FF`: the crash address.
- **The real destination `0x212cd777e` sits correctly in the jump table**, but nothing jumps through it.
- This is a relocation bug in that hooking library, set off by the `jmp [rip+0]` shape. Windows' own DLLs start their methods with ordinary instructions. Whether the mod's hooks work there was not seen: on the Windows PC (18:45–18:49) the game crashed elsewhere before the mod reached its DirectX hooks.

## Spike (2026-11-25, `spike-files/thunks.c`)

**Setup:** a 64-bit test program, built with zig the way `packages/engine/tool/build_probe.sh` builds the probe. It ran headless in a temporary Rosetta bottle (`hookspike`, since deleted) with `--backend d3dmetal`; its 64×64 window was never shown. At each step it counted the thunks in each loaded module's image:

| Step | dxgi.dll | d3d12.dll | d3d12core.dll |
|---|---|---|---|
| after `LoadLibrary` | 1024 | 1024 | 0 |
| after `CreateDXGIFactory2` | 1024 | 1024 | 0 |
| after `D3D12CreateDevice` | 1024 | 1024 | 0 |
| after `CreateCommandQueue` | 1024 | 1024 | 0 |
| after `CreateSwapChainForHwnd` | 1024 | 1024 | 0 |

**What it showed:**
- **All thunks exist as soon as the DLL is loaded,** and no step adds more. A rewrite done once, right after load, covers every later object.
- **The files on disk hold none of them.** `backends/d3dmetal/wine/x86_64-windows/*.dll` contain no `66 90 ff 25` sequence. The thunks live in each DLL's `.data`, which is zeros on disk; in `dxgi.dll` that section is 0x1009018 bytes. D3DMetal writes them while loading.
- **The layout matches the game's.** `Present` is `dxgi.dll+0x1007080`, `ResizeBuffers` is `dxgi.dll+0x10070d0` and `ExecuteCommandLists` is `d3d12.dll+0x8b90`: the same offsets as in the FIFA 23 hook dump. The thunks sit 16 bytes apart.
- **The pages are `PAGE_EXECUTE_READ` (0x20)**; `VirtualProtect` to RWX succeeds.
- **The rewrite works.** `Present`'s thunk was rewritten to `48 B8 <abs64> FF E0 90 90 90 90` (`mov rax, imm64; jmp rax`), and three `Present(0, 0)` calls returned `S_OK`. A relocating hooker copies `mov rax, imm64` as it is, since it has no RIP-relative operand, so its trampoline stays correct.
- **RAX is free to clobber** at a Windows x64 function's entry: it is volatile and carries no argument.
- **Rosetta handles the code change.** It invalidates the translation of a written code page, which is the same mechanism every hook already relies on.

## AppInit_DLLs (measured, `spike-files/appinit.c`)

**Test:** a DLL that writes to stderr in `DLL_PROCESS_ATTACH`, registered with `AppInit_DLLs = C:\appinit.dll`, `LoadAppInit_DLLs = 1` and `RequireSignedAppInit_DLLs = 0` (`reg import`, headless, same temporary bottle).

**Result:** a later run, which loads user32 and creates a window, never printed it. Bodega's Wine (CrossOver 26.3 tree) does not load AppInit DLLs. So a DLL cannot be slipped into every process that way.

## Code this touches

- **`packages/engine/lib/platform_mac.dart:218`, `backendEnv`.** The `'d3dmetal'` case is at `:248`. It sets `WINEDLLPATH_PREPEND` to D3DMetal's layer, so its `dxgi`, `d3d11`, `d3d12`, `d3d12core` and `nvapi64` load as builtins. A switch for the rewrite would go here, as an environment variable for D3DMetal launches only.
- **`packages/engine/lib/backends.dart:199`.** D3DMetal is imported into `backends/d3dmetal`, with the PE side in `wine/x86_64-windows` and the native side in `external/`. Bodega never edits those files, and the rewrite would not either.
- **`wine/patches/`.** These are the 27 patches (0001–0028; there is no 0004) applied in lexical order to the pinned CrossOver 26.3 source by `.github/workflows/build.yml`, which builds the engine tarballs that `release-macos` packages.
  - Precedent: `0003-ntdll-winedllpath-prepend.patch` already teaches `ntdll`'s loader a Bodega-set environment variable.
  - The README's table asks each patch for its header (what it fixes, how it was verified, upstream status) and a row in the table.
- **`packages/engine/tool/build_probe.sh` and `tool/probe.c`.** Bodega's existing way to build a small Windows test program with zig and ship it as base64 (`lib/probe_data.dart`). A hook test could follow it.
- **`packages/engine/lib/engine.dart:438–481`, the launch environment.** The program, bottle and fix environments are merged here, so a per-program opt-out would fit in the same place.

## Where the rewrite can live

1. **A patch to Bodega's Wine (`ntdll` loader).** After a module's `DLL_PROCESS_ATTACH`, if the launch asked for it (an environment variable set by `backendEnv` for D3DMetal), scan that module's writable sections for 16-byte-aligned `66 90 ff 25 00000000 <abs64>` whose target lies outside the image, and rewrite each one.
   - **For:** it covers every process, including a game that relaunches itself (FIFA 23 does, with `-url http://127.0.0.1:1338/`) and children of launchers, and needs no injection.
   - **Against:** it needs a new engine build (`build.yml`, hours of macOS runner time) and a release that ships it.
2. **A Windows DLL that Bodega loads into games.** No way to load it into every process was found: AppInit is out (measured), and a launcher that injects into the process it starts misses relaunches and children. A proxy `dxgi.dll` in front of D3DMetal's would have to forward every export and COM object.
3. **Nothing in Bodega; document the limit.** Mods and overlays that inline-hook DX12 keep crashing on D3DMetal.

## Constraints from the project

- **D3DMetal:** "never bundled or downloaded by Bodega … the user imports their own copy, and its license is their decision". The rewrite changes only D3DMetal's code in memory, never its files. Whether that sits within the license the user accepted is the user's decision (open question 1).
- **Anti-cheat:** "Don't help bypass anti-cheat". The rewrite hides nothing and swaps no module, but it does change D3D code in memory, which anti-cheat may notice. It must stay out of the way of anti-cheat games (open question 2).
- **Agents and Wine:** "Agents run Wine only headless". The spike did; any test in apply must too.
- **Language:** English in git; Spanish only in `app_es.arb`.
- **Verification:** "Check against the real thing". The acceptance test cannot be a pirated game. A legitimate case is needed (open question 4).

## Open questions

1. **D3DMetal's license.** Is a rewrite of D3DMetal's thunks in memory (never its files) acceptable to you, as the user who accepted Apple's license?
2. **On by default or opt-in?**
   - On by default for D3DMetal launches, with a per-program off switch and always off for titles on the anti-cheat list?
   - Or an opt-in per program ("Compatibility with mods and overlays")?
3. **An engine patch, with a new engine release** (option 1), as the delivery?
4. **The legitimate test.**
   - A small test program with PolyHook 2 (MIT, open source) that detours D3DMetal's `Present`. It should crash at a junk address without the rewrite and work with it.
   - Is there also a legitimate mod or overlay you use on D3DMetal (for example on Cyberpunk 2077) to check by hand?
5. **Not in scope:**
   - the slowness of FIFA 23 on Mach9 (shader compilation through vkd3d → MoltenVK);
   - the Live Editor overlay's red-only colours there.
