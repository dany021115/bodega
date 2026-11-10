# Installing and checking backends

Root: `$HOME_B/backends/<nombre>/wine/{x86_64-windows,i386-windows,x86_64-unix}`, where `HOME_B` is `bodegaHome`. `wine` takes no folder.

## B1 · Install `dxmt` and `dxvk`
- `bodega backend install <dxmt|dxvk> [tarball]`.
- Without `tarball`, it downloads with `/usr/bin/curl -fL -C - --retry 5` to `$HOME_B/downloads/`, from the pinned URL.
- URL and SHA-256 are pinned in the code. The SHA-256 is always checked, also with a local tarball.
- Extracts into `backends/.tmp-<nombre>`, normalizes to `wine/` and renames. If it fails, no `.tmp-*` and no partial install is left behind.
- If it is already installed, error `ya instalado` ("already installed") with the command to remove it.

**Scenarios**
- **Given** the correct tarball, **when** `dxmt` is installed, **then** `wine/x86_64-windows/d3d11.dll` and `wine/x86_64-unix/winemetal.so` exist. (test)
- **Given** a tampered tarball, **when** it is installed, **then** it gives a checksum error and does not create `backends/dxmt`. (test)
- **Given** `dxvk`, **then** `wine/x86_64-windows/d3d11.dll` and `wine/i386-windows/d3d11.dll` exist. (test)

## B2 · Import `d3dmetal`
- `bodega backend import d3dmetal <carpeta>`.
- Accepts `wine/x86_64-{unix,windows}` + `external/`, or `lib/wine/x86_64-{unix,windows}` + `lib/external/`.
- Requires `x86_64-windows/{d3d11,d3d12,dxgi}.dll`, `x86_64-unix/{d3d11,d3d12,dxgi}.so`, `external/libd3dshared.dylib` and `external/D3DMetal.framework`.
- Copies only those modules, plus `atidxx64`, `nvapi64`, `nvngx` and `d3d12core.dll` if they exist, and keeps the `wine/` + `external/` layout.
- Each `.so` ends up as a symbolic link to `../../external/libd3dshared.dylib`, even if the source has lost the links. If a `.so` is not the same size as that library, it gives an error and creates nothing.
- Rejects any path that, once resolved, contains `/CrossOver.app/`.
- Bodega never downloads D3DMetal.
- When it finishes, it prints that it has to be checked with `bodega backend test` and that its use is governed by Apple's license.

**Scenarios**
- **Given** a fake `wine/+external/` layout with regular files, **when** it is imported, **then** `libd3dshared.dylib` and the framework end up in `external/`, and each `.so` is a link to that library. (test)
- **Given** a `.so` of a different size, **when** it is imported, **then** it gives an error and creates nothing. (test)
- **Given** the `lib/…` layout, **when** it is imported, **then** the result is the same. (test)
- **Given** a path under `CrossOver.app`, or a link to it, **then** an error and nothing created. (test)
- **Given** that `d3d12.dll` is missing, **then** an error that names it and nothing created. (test)

## B3 · List
`bodega backend list` prints one line per backend, `nombre: instalado|no instalado` ("name: installed|not installed"), always with `wine` installed. (test)

## B4 · Check
- `bodega backend test <botella> <backend>` runs the probe, headless, with that backend and one log per run.
- Cases: `wine` → 11 and 12 in 64-bit. `dxmt` → 11 in 64 and 32. `dxvk` → 11 in 64 and 32. `d3dmetal` → 11 and 12 in 64; and, if `dxmt` is installed, 11 in 32.
- The probe (`tool/probe.c`) is written to `backends/probe/` from `lib/probe_data.dart` and only creates devices.
- Prints `OK` or `FALLA` ("FAIL") per case, with the log path. The exit code is 0 only if all of them pass.

**Scenarios**
- **Given** each installed backend, **when** it is checked, **then** every case gives `OK`. (headless T9, T10)
- **Given** D3DMetal imported from Whisky, **when** it is checked, **then** every case gives `OK`. (headless T11)
- **Given** a program that exits with an error, **when** it is checked, **then** it gives `FALLA` and an exit code other than 0. (test with a fake Wine)
