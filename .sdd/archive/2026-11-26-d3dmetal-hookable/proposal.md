# Proposal · d3dmetal-hookable

> **Renumbered on 2026-11-26:** this change's patch is `wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch`, because PR #28 took 0029 (`0029-ntdll-ntlockfile-io-status-block.patch`). The documents below were written before that and call it 0029.

## Why

Under D3DMetal, a mod or overlay that inline-hooks DXGI or Direct3D 12 can crash the game the moment it hooks.
- D3DMetal's methods start with `nop; jmp [rip]` thunks, and a relocating hooker can turn them into a jump to junk.
- Seen with PolyHook (FIFA 23 Live Editor): every crash was at `0x3825FF`.
- The same mod hooks fine on Mach9, whose Direct3D 12 starts with ordinary code.
- For the user this looks like "Bodega crashes the game". See `exploration.md`.

## What

1. **A patch to Bodega's Wine (`wine/patches/0029`).**
   - Right after a listed DLL has run its `DLL_PROCESS_ATTACH`, `ntdll` rewrites each D3DMetal thunk in it to an equivalent with no RIP-relative operand: `mov rax, <target>; jmp rax`.
   - The list comes from the environment variable `BODEGA_HOOKABLE_THUNKS`.
   - The target and the behaviour are the same; only the first instruction changes, so any hooker copies it correctly.
   - Only memory changes, never D3DMetal's files.
2. **The engine sets the list for D3DMetal launches.**
   - The list is D3DMetal's DLLs, set for launches on the D3DMetal backend.
   - It is left out when the game's configuration names an anti-cheat.
   - A program's own environment can turn it off with an empty value.
3. **Checks.**
   - A small Windows test program (zig, like the probe) shows that no thunk is left and that `Present` still works.
   - A PolyHook 2 detour on D3DMetal's `Present` crashes without the patch and works with it. PolyHook 2 is MIT, open source, built only for the test.

**Decided at the approval of `exploration.md`** (2026-11-25). These are the defaults; change them at this gate if they are not what you want:
- **License (Q1):** a rewrite in memory of D3DMetal's thunks, never of its files, is acceptable to the user.
- **Default (Q2):**
  - on for every D3DMetal launch;
  - off for games whose configuration names an anti-cheat;
  - off for a program whose environment sets `BODEGA_HOOKABLE_THUNKS` to empty.
  - No new switch in the app for now.
- **Delivery (Q3):** an engine patch, shipped by `release-macos` with `build_engine`, which builds Wine from the release tag.
- **Legitimate test (Q4):** the PolyHook 2 harness and the zig test program; FIFA 23 is only the user's own check.

## Impact

- **Rosetta engine with the D3DMetal backend only.** Mach9 and the other backends are untouched.
- **Inert until the new engine ships.** On today's engine the variable does nothing.
- **Cost:**
  - one engine build (hours of macOS runner time), started by `release-macos` with `build_engine`;
  - Bodega 1.10.0.
- **Risk:**
  - **Wrong code rewritten:** a thunk-shaped sequence that is not a thunk. Guarded by 16-byte alignment, writable sections only, and a target outside the image.
  - **Thunks written after `DLL_PROCESS_ATTACH`:** they would be missed. The spike shows none; the test program checks it.
- **Rules:**
  - `CLAUDE.md`'s D3DMetal line gains that Bodega may rewrite D3DMetal's thunks in memory, never its files.
  - `wine/patches/README.md` gains the patch's row.
