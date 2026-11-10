# Design: graphics-backends

Only what is not obvious.

## 1. One layer per backend, resolved per process

`_start` takes an extra map that is added to `wineEnv`. No DLLs are copied into the prefix: switching backends means changing a variable (patch `0003`, `BE/patches/0003-ntdll-winedllpath-prepend.patch`). It has the same effect as CrossOver's closed `cxcompatdb.so`, with an open piece.

`CX_ACTIVE_GRAPHICS_BACKEND` has to be set by hand: in CrossOver that closed module sets it, and the LGPL tree reads it in `CX/dlls/win32u/d3dkmt.c:719-724`.

## 2. D3DMetal: a single binary and no `DYLD_*`

`d3d11.so`, `d3d12.so`, `dxgi.so` and the rest are **symbolic links** to `../../external/libd3dshared.dylib`. They have `LC_RPATH @loader_path` and load `@rpath/D3DMetal.framework/D3DMetal`. Since dyld resolves the link, `@loader_path` is `external/`, where the framework is, and all the modules are the same image.

If they are copied as separate files, dyld loads different images and the process jumps to an invalid address when it creates the device (`spike.md`, Correction). That is why `import` always recreates the links, even if the source has lost them, and rejects a `.so` that is not the same size as the library.

No `DYLD_*` is needed, so it does not clash with SIP, which strips it when `/bin/sh` starts (`_launch`, `P/lib/engine.dart`).

## 3. Why the probe is needed

A badly made copy of D3DMetal loads, answers `dxgi` and only crashes when it creates the device: it happened to this change's own test, which blamed the Whisky copy for no reason. Without `backend test`, that would look like a game bug.

The probe is embedded in base64 because `dart compile exe` does not carry files along, and the future app should not depend on a repo path either. It is a 60–70 KB PE compiled with `zig cc`.

- `tool/build_probe.sh` regenerates `lib/probe_data.dart`.
- `zig` is installed in a temporary venv and does not go into the repo.
- It is the only generated file.

## 4. Auto searches for text, not imports

An import parser does not see DLLs loaded with `LoadLibrary`, and many game engines load them that way. Searching the binary for the name is shorter and gets more cases right, at the cost of false positives: an exe that mentions `d3d12.dll` without using it will go through D3DMetal. If it guesses wrong, the manual setting fixes it, and that is why S6 shows what was chosen and why.

## 5. Switching backends in a bottle that is in use

The bottle's services keep the environment of the first process (pitfall 4 of the prototype), but the layer is resolved in each new process, and the server shuts down 3 s after the last client (`CX/server/main.c:48`).

// ponytail: a switch made while another game is open in the same bottle is not detected. The log says which backend each one used. A warning will be added if this causes real problems.

## 6. The license is shown, not decided

`import` prints the notice (B2) and asks nothing: that conversation belongs to the interface. Rejecting `CrossOver.app` is a guardrail against an easy mistake, not a security measure: it resolves links, but a manual copy of the files gets around it.
