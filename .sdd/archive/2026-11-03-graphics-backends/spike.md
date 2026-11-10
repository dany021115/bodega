# Short test (spike): backends on our runtime

2026-11-03, M2 Pro, macOS 27.0.1. Runtime `engine-wine-11.0-20261030T202616Z-primer-build` + hostlibs, in a temporary bottle, since deleted. Our own probe, headless: it creates `dxgi` and a real device. In D3D11 it creates a texture, clears it and flushes; in D3D12 it creates a queue and a fence and waits for the signal.

**Limit:** it does not present any frame on screen. It proves that the backend starts, not that a game looks right.

| Backend | Layer | D3D | Bits | Result |
|---|---|---|---|---|
| Wine | none | 11 | 64 | OK, level 10_1 (`level=a100`), adapter "NVIDIA GeForce 8800 GTX"; one `GL_INVALID_FRAMEBUFFER_OPERATION` in the log |
| Wine (vkd3d) | none | 12 | 64 | OK, fence completed |
| DXMT v0.80 | `dxmt-v0.80-builtin` | 11 | 64 | OK, level 11_0, adapter "Apple M2 Pro" |
| DXMT v0.80 | same | 11 | 32 | OK, level 11_0 |
| DXVK 1.10.3 | `dxvk-macOS…repack-builtin` + `d3d10core,d3d11=n,b` | 11 | 64 | OK, level 11_0 |
| **D3DMetal 3.0 from Sikarugir** | `Template-1.0.11` → `renderer/d3dmetal` | 11 and 12 | 64 | **OK**, adapter "AMD Compatibility Mode" |
| D3DMetal 3.0 from Sikarugir, without `DYLD_*` | `external/*` next to the `.so` files | 12 | 64 | **OK** |
| D3DMetal 3.0 from Whisky | `WH/Wine/lib` | 11 and 12 | 64 | **Crashes:** `Unhandled page fault on execute access to 0020019008070C10` when creating the device, with and without `DYLD_*`, msync or esync |

**Not tested:**
- D3DMetal with `CX_APPLEGPTK_LIBD3DSHARED_PATH` using the Sikarugir copy.
- The `d3dmetal:dxmt` chain for 32-bit: the attempt exited with `rc=53` because of a bug in the script itself.
- D3DMetal from Apple or from Gcenx.
- Real games and FPS with any of the new backends.

**Findings:**
- In D3DMetal, `d3d11.so`, `d3d12.so`, `dxgi.so`, `nvapi64.so`, `atidxx64.so`, `nvngx.so` and `libd3dshared.dylib` are **the same file** (same SHA-1 `6c7da2a222…`, id `@rpath/libd3dshared.dylib`).
- `D3DMetal.framework` also loads through `@rpath`: it is enough to put it next to the `.so` files.
- The Whisky copy is not stock: `WH/pre-gptk-backup` (October 30) shows that it was installed by hand on top of Whisky's Wine. It does not work with Whisky's own Wine either: `unimplemented function ntdll.dll.__wine_unix_call`.

**Tarballs saved in `Bodega/runtimes/terceros/`:**

| File | SHA-256 |
|---|---|
| `dxmt-v0.80-builtin.tar.gz` | `8f260e36b5739e68f3bad613381441385c4dc7b85b78ba8de653d5a6a264529d` |
| `dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz` | `810b1e5caf8ce975b784fae866a130ad23fa0ea233b0e5609cbc4a45f3ef6f00` |
| `Template-1.0.11.tar.xz` (Sikarugir; matches the SHA that Highball pins) | `9fa15479e7ff6abd99c1d07be285fb95f41fc6991586502427152b1f7d6ccb8a` |

## Correction (during apply, T10)

**The conclusion about Whisky was wrong: that copy works.** The crash in the table did not come from the copy, but from the way it was copied for the test.

- In both copies, `d3d11.so`, `d3d12.so`, `dxgi.so` and the rest are **symbolic links** to `../../external/libd3dshared.dylib`.
- Copying them without preserving the links creates separate files. dyld loads them as different images and the process jumps to `0x20019008070C10` when it creates the device. Exactly the same happens with the Sikarugir template.

Results with the links preserved and the `wine/` + `external/` layout, without `DYLD_*`:

| Copy | Case | Result |
|---|---|---|
| Sikarugir | D3D12 and D3D11, 64-bit | OK |
| Sikarugir | D3D12 with `CX_APPLEGPTK_LIBD3DSHARED_PATH` | OK |
| Sikarugir | D3D12 with that variable and the `d3dmetal:dxmt` chain | OK |
| Sikarugir | 32-bit D3D11 through the chain | OK |
| Whisky | D3D12 and D3D11, 64-bit, with that variable | OK |

`pre-gptk-backup` and the failure of Whisky's own Wine (`__wine_unix_call`) are still true, but they say nothing about this copy.
