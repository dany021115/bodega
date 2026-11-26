# Spec · the Wine patch

## HW1 · Thunks rewritten after load

After a module's `DLL_PROCESS_ATTACH` has returned TRUE, the loader acts only if:
- `BODEGA_HOOKABLE_THUNKS` lists the module's base name (comma-separated, any case);
- the module's image is 64-bit.

It then walks the module's sections that have `IMAGE_SCN_MEM_WRITE`, one memory region at a time, and only the regions that are committed and executable (changed in apply: D3DMetal makes its thunk pages executable, so the rest of `dxgi.dll`'s 16 MB `.data` is never read), at 16-byte steps. A 16-byte slot is a thunk when:
- it starts `66 90 FF 25 00 00 00 00`;
- the next 8 bytes, the target, are not zero;
- the target lies outside the module's image.

Each thunk becomes `48 B8 <target> FF E0 90 90 90 90`. The loader:
- makes the pages writable for the rewrite;
- puts their protection back;
- flushes the instruction cache.

Scenarios:
- **Given** D3DMetal's `dxgi.dll` and `d3d12.dll` listed, **then** after `LoadLibrary` neither image holds a `66 90 FF 25 00000000` slot, and `IDXGISwapChain::Present` and `ID3D12CommandQueue::ExecuteCommandLists` start with `48 B8`. (zig test program, headless)
- **Given** the same, **then** `Present(0, 0)` on a hidden window's swap chain returns `S_OK`, three times. (same program)
- **Given** the variable unset or empty, **then** the slots stay as D3DMetal wrote them: 1024 in each. (same program)

## HW2 · Nothing else touched

- **Given** a module whose name is not listed, **then** none of its bytes change.
- **Given** a slot whose target lies inside the module's image, **then** it stays.
- **Given** read-only or non-writable sections, **then** they are not walked.

The byte rules are tested by building the rewrite function standalone against synthetic buffers: thunks inside and outside the image, misaligned copies, near misses. The build uses the Mac's clang with AddressSanitizer and UndefinedBehaviorSanitizer, not zig (changed in apply). The two rules that live in the loader around it, "not listed" and "not writable or not executable", are checked on a built loader (HC2).

## HW3 · Traceable

With `WINEDEBUG=trace+module`, each listed module logs one line naming the module and the number of thunks. `+module` alone aborts this engine at start, with or without the patch (measured 2026-11-26). This is how the checks and a user's log show that it ran.
