# Design · d3dmetal-hookable

## D1 · Where: `ntdll`'s loader, after `DLL_PROCESS_ATTACH`

The rewrite runs in `dlls/ntdll/loader.c` `process_attach()`, once `MODULE_InitDLL(…, DLL_PROCESS_ATTACH, …)` has succeeded.
- **The thunks exist by then.** The spike counted 1024 in each DLL right after `LoadLibrary`, and none were added later.
- **No Windows thread can be inside a thunk yet.** The loader lock is held, and nobody has the DLL's methods before `LoadLibrary` returns. A thread the DLL starts waits for the loader lock before its own code runs, and D3DMetal's native threads run native code, not the thunks. So the 16-byte write cannot race an executing thread.
- **Every process gets it,** with no injection: a game that relaunches itself, and children of launchers.

Not chosen:
- **AppInit DLLs:** they don't load in this Wine (measured).
- **A launcher that injects:** it misses relaunches.
- **A proxy `dxgi.dll`:** it would have to forward every export and COM object.

## D2 · The rewrite

`66 90 FF 25 00000000 <t>` (`nop; jmp [rip]; .quad t`) becomes `48 B8 <t> FF E0 90 90 90 90` (`mov rax, t; jmp rax`, padded to 16 bytes).
- **Same destination and same stack.** RAX is volatile at a Windows x64 function's entry and carries no argument.
- **Hookers copy it correctly.** The first instruction (10 bytes) has no RIP-relative operand, so any relocating hooker copies it as it is, whether it overwrites 5, 6, 12 or 14 bytes.
- **Rosetta handles the change.** It retranslates a written code page, as it does for any hook.

## D3 · Match rules

A slot is rewritten only if all of these hold:
- it is 16-byte aligned (D3DMetal's thunks are);
- it is inside a section with `IMAGE_SCN_MEM_WRITE` (D3DMetal keeps them in `.data`), in a committed region that is executable (D3DMetal makes its thunk pages executable; the rest of `dxgi.dll`'s 16 MB `.data` stays read-write and is never read, so it never becomes resident);
- it starts with the exact 8 bytes;
- its target is not zero and lies outside the module's image.

Together these keep ordinary code and data out.

## D4 · Asking for it

`BODEGA_HOOKABLE_THUNKS` holds the DLL base names, the way `WINEDLLPATH_PREPEND` (patch 0003) is a Bodega-set loader variable.
- **The engine sets it** for the `d3dmetal` backend (HE1).
- **It is removed** when the recognised game names an anti-cheat (HE2), even with its configuration turned off: `openApp` passes `antiCheat` to `_launchIn`, whose `remove` set takes the variable out whatever the bottle or program says.
- **Limits, written in the docs:**
  - "Run .exe" has no game to look up;
  - a game started by a launcher that is already running inherits the launcher's environment.
- **A program's environment can set it empty** (HE3); the patch reads empty as off.
- **No switch in the app.** Add one if a game needs it often.

## D5 · Delivery

- **Inert until shipped.** The variable is harmless on an engine without the patch, so the engine change and the Dart change can merge together.
- **How it ships:** the release workflow `release-macos`, run with `build_engine` on the release tag, builds Wine with the series and packages it. That takes hours of macOS runner time.
- **Real checks** (HC2) run against that engine tarball before the user installs the release.

## D6 · Tests that are not product code

The zig test program and the PolyHook 2 harness live in `.sdd/d3dmetal-hookable/spike-files/`, with the commands to build them.
- They are not shipped.
- PolyHook 2 is fetched at a pinned commit only into a scratch folder, never into the repo.
