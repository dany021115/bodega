# Linux package: third-party files

`assets.json` pins the versions, URLs and sha256 of what the Linux package brings in from outside: Wine, DXVK, vkd3d-proton and appimagetool. `fetch_assets.sh` downloads them to `cache/<name>/` and verifies each one. `cache/` is in `.gitignore`.

```
cd packaging/linux && ./fetch_assets.sh
```

Requires `curl`, `sha256sum` and `python3`.

## Binary portability (CPU)

`tool/check_isa.sh` uses `readelf -n` to check the `bodega` executable, the CLI and the bundle's `.so` files, and fails if any of them declares `x86-64-v3` or `x86-64-v4` as its required ISA. That marker is set by the libraries of a distro tuned for new CPUs (CachyOS): even if you compile with `-march=x86-64`, linking inherits the marker from the system's objects. The result is a `bodega` that dies on an older machine with `CPU ISA level is lower than required` (it happened on Manjaro).

- Releases are built on `ubuntu-24.04`, which does not set it. From there they go to the other distros.
- A package that will only run on the machine that built it: `BODEGA_ALLOW_NATIVE=1 tool/package_linux.sh`.

## Versions

| name | version | file | bytes (download) | sha256 |
|---|---|---|---|---|
| wine | 11.21 | `wine-11.21-staging-amd64-wow64.tar.xz` (Kron4ek) | 99958200 | `a70a9691...fa503ab` |
| dxvk | 3.1.1 | `dxvk-3.1.1.tar.gz` | 18041512 | `40565b4a...f54e608` |
| vkd3d-proton | 3.1 | `vkd3d-proton-3.1.tar.zst` | 5665978 | `b85ea821...f02120b` |
| appimagetool | 1.9.1 | `appimagetool-x86_64.AppImage` | 15092216 | `ed4ce84f...6eb0` |

Origin and checks:

- All four are published releases with a stable tag (not pre-releases).
- The digest GitHub publishes for DXVK, vkd3d-proton and appimagetool matches the sha256 computed locally.
- Wine's sha256 matches the SHA256 table in the body of Kron4ek's 11.21 release (GitHub does not publish it as the asset's digest).
- appimagetool: GitHub marks the `continuous` tag, a moving build with no version, as "latest". The release tagged `1.9.1` (2025-11-18) is pinned instead.

## Layout of the tarballs (inspected, not run)

Extracted in the scratchpad, never in the repo.

**Wine** (`wine-11.21-staging-amd64-wow64/`, the tar's single root):

- `bin/wine`, `bin/wineserver`: present.
- `lib/wine/x86_64-unix/ntdll.so`: present.
- `lib/wine/x86_64-windows/kernel32.dll` and `ntdll.dll`: present.
- `lib/wine/i386-windows/kernel32.dll` and `ntdll.dll`: present.
- There is no `lib/wine/i386-unix/`. The 32-bit WoW64 part runs on `x86_64-unix`.
- Others: `bin/` with winecfg, regedit, msiexec, wineboot and the rest; `share/wine/wine.inf`, `share/applications/wine.desktop`, `share/man/`.
- There are no `.dylib` files and no links to follow.

**DXVK** (`dxvk-3.1.1/`): `x64/` and `x32/`. Each one has `d3d8.dll`, `d3d9.dll`, `d3d10core.dll`, `d3d11.dll`, `dxgi.dll`. It has no `d3d12`.

**vkd3d-proton** (`vkd3d-proton-3.1/`): `x64/` and `x86/` (not `x32/`). Each one has `d3d12.dll` and `d3d12core.dll`. It also has `setup_vkd3d_proton.sh`, which is not run.

## Wine sync (strings)

Search for `sync`, `ntsync`, `ESYNC`, `FSYNC`, `WINE_*` in the binaries:

- `lib/wine/x86_64-unix/ntdll.so`: does not contain `WINEESYNC`, `WINEFSYNC`, `WINE_NTSYNC` or `ntsync`. The `fsync` and `msync` matches are glibc symbols (`fsync@@GLIBC_2.2.5`, `msync@@GLIBC_2.2.5`), not Wine variables.
- `bin/wineserver`: contains `/dev/ntsync`. That is where the ntsync support is; no environment variable name shows up.
- `bin/wine`: only `WINEDLLPATH`.

Conclusion: the strings do not show which environment variable turns on esync, fsync or ntsync in this build. It has to be tested on a real machine (without running Wine from the agent). Until then, `syncModes` in the code can only count on `none` as safe. The `esync`, `fsync` and `ntsync` modes wait for that test.

## Licenses

- Wine: the tar has no license file and no NOTICE. The LGPL text and the reference to the source code have to be added from the package (R16), not from the tar.
- DXVK: the tar has no license.
- vkd3d-proton: the tar has no license.
- appimagetool: not packaged; it is only used to build the AppImage.

## Uncompressed sizes (`du -sb`)

- Wine: 853115842 bytes (~814 MiB)
- DXVK: 45666444 bytes (~44 MiB)
- vkd3d-proton: 14222247 bytes (~14 MiB)

## Contradictions with design.md and tasks.md

1. Name of the Wine asset: tasks.md says `wine-staging-<ver>-amd64-wow64.tar.xz`, but the real name is `wine-<ver>-staging-amd64-wow64.tar.xz`. The real one is used.
2. vkd3d folders: design.md and `_ensureLayers` assume `x64/` and `x32/`. vkd3d-proton has `x86/`, not `x32/`. Copying to `syswow64` has to map `x86/` for vkd3d.
3. D3D12 comes from vkd3d-proton, not from DXVK. The package's `dxvk` layer must copy the DLLs of both (`d3d12.dll` and `d3d12core.dll` included). design.md implies it when it asks for overrides for `d3d12,d3d12core`, but does not say so when it describes `backends/dxvk/`.
4. No licenses in the tarballs: design.md asks for `LICENSES/`, and that content has to be written from the official sources, not from these files.
5. `syncModes` (design.md: `none`, `esync`, `fsync`, `ntsync`): cannot be verified through the strings (see above).
