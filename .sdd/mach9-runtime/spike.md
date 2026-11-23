# Spike · mach9-runtime (E0)

Run on 2026-11-19 on this Mac (Apple M6, macOS 27.2.1, arm64), headless, in a scratch folder only (no Bodega home touched). Runtime: `ditto --noqtn /Applications/Mach9.app/Contents/Resources/wine <scratch>/rt/engine` (Mach9 v0.4.0). Environment of every run: `env -i` with HOME, USER, LOGNAME, TMPDIR, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, WINEPREFIX, `WINEMSYNC=1`, `WINEDEBUG=fixme-all,-dbghelp_msc,-dbghelp_dwarf,-dbghelp_pdb,-dbghelp_macho` and the `WINE_COMPATDB` named per case (design §4.3's Mach9 column). Probes: `probe-32.exe` and `probe-64.exe` decoded from `packages/engine/lib/probe_data.dart`. Evidence in `spike-files/`.

| # | Question | Result | Verdict |
|---|---|---|---|
| S1 | `exe=*;dll_overrides=winemenubuilder.exe=` honoured, no winemenubuilder during wineboot | wineboot exit 0; the compatdb log shows `dll_overrides = … ; winemenubuilder.exe= (WINE_COMPATDB line 1)` for all 17 processes of wineboot; 0 `warning:` lines; `pgrep -fl winemenubuilder` sampled every 0.1 s through wineboot found nothing, and no `compatdb: winemenubuilder.exe` block appears | Pass: D20 as designed, **no** `WINEDLLOVERRIDES` fallback |
| S2 | `exe=*;dxgi=wined3d;d3d9=wined3d` + `exe=probe-32.exe;d3d9=mtld3d` | probe-32 mode 9 exit 0, `adapter9: Apple M6 driver=mtld3d`; compatdb: `dxgi = wined3d … WINE_COMPATDB line 1`, `d3d9 = mtld3d … WINE_COMPATDB line 2` | Pass: a program line beats `exe=*` (D17) |
| S3 | `exe=*;metal_hud=true` | `metal_hud = true, WINE_COMPATDB line 1`, and compatdb sets `MTL_HUD_ENABLED=1`, `MTL_HUD_ALIGNMENT`, `MTL_HUD_ELEMENTS` in the process's env | Pass (the HUD's look inside a game stays a USER check, V6) |
| S4 | Wine Mono | `wine msiexec /i wine-mono-11.3.0-x86.msi /qn` exit **0**; `drive_c/windows/mono/mono-2.0` present; 14.6 s including `wineserver -w` (first run in the prefix). One harmless `err:msi` line: `createlinks-x86_64.dll (193)` | Pass; 0 is in `_installerOk` |
| S5 | Probe modes under auto, mtld3d, dxmt, wine | see the table below: 19 of 20 pass; `wine` 64-bit mode 12 exits 2 (`d3d12 load FAIL`), as design §4.1 predicts (wine misfits DX12) | Pass; design §4.1's probe cases confirmed |
| S6 | wineboot time; `codesign --deep` on the mounted DMG | wineboot + `wineserver -w` of a fresh prefix: **17.5 s** (cold, after the copy). DMG attach 2.8 s; `codesign --verify --deep --strict <mnt>/Mach9.app` **1.1 s**, exit 0, `Identifier=app.mach9`, `TeamIdentifier=WLKUUJD25W`, version 0.4.0; detach clean. On `/Applications/Mach9.app` 0.3 s. `ditto --noqtn` of the tree: 0.2 s (APFS clone) | Pass: far under 30 s, so `--deep` **always** runs (no hash shortcut) |
| S7 | Both registry values with `reg add` | both exit 0; `user.reg` holds `[Software\\Wine\\WineDbg] "ShowCrashDialog"=dword:00000000` and `[Software\\Wine\\X11 Driver] "EmulateModeset"="Y"` | Pass |
| S8 | `VKD3D_SHADER_CACHE_PATH`; `bytes`, `diskBytes` | vkd3d-proton (`lib/wine/dxgi/dxmt/{aarch64,i386}-windows/d3d12core.dll`) holds `VKD3D_SHADER_CACHE_PATH` and "Remapping VKD3D_SHADER_CACHE to: %s". The probe's D3D12 case (exit 0, fence completed) builds no pipeline, so no cache file was written with or without the variable, neither in the cache folder nor beside the exe. Sizes: DMG 200,499,232 bytes, sha256 `3b5dd83e…e6d9` (matches the pin); MSI 83,348,992 bytes, sha256 `df2dfc16…18d3` (matches); `engine/` 977,580,032 bytes on disk (`du -sk` 954,668 KB; apparent 954,126 KB) | Partial: the variable is read by Mach9's vkd3d-proton; that it is *used* needs a real D3D12 game (V6). `diskBytes` set to 1,061,000,000 (engine + MSI) |

## S5 matrix (exit codes; compatdb's source of the field)
| name | 32/9 | 64/9 | 32/11 | 64/11 | 64/12 | fields reported |
|---|---|---|---|---|---|---|
| auto (no fields) | 0 | 0 | 0 | 0 | 0 | dxgi dxmt, d3d9 mtld3d, both `built-in` |
| mtld3d (`d3d9=mtld3d`) | 0 | 0 | 0 | 0 | 0 | d3d9 `WINE_COMPATDB line 1`; dxgi `built-in` |
| dxmt (`dxgi=dxmt`) | 0 | 0 | 0 | 0 | 0 | dxgi `WINE_COMPATDB line 1`; d3d9 `built-in` |
| wine (`dxgi=wined3d;d3d9=wined3d`) | 0 | 0 | 0 | 0 | **2** | both `WINE_COMPATDB line 1`; D3D9 adapter shows as wined3d's default `NVIDIA GeForce GTX 470` |

No `warning:` line in any run. Each run 0.3–4.5 s.

## Other findings
- D2 confirmed: a fresh Mach9 prefix has `system32/kernel32.dll` machine **0xAA64** and `syswow64/kernel32.dll` 0x14C.
- compatdb's built-in rule for every process already sets `dll_overrides=mshtml=` (Gecko off) and the d3dx9/d3dx10/d3dx11/d3dcompiler `n,b` list; Bodega's lines add to it.
- Mach9.app's launcher defaults `WINEDEBUG` to `fixme-all,-dbghelp_msc,-dbghelp_dwarf,-dbghelp_pdb,-dbghelp_macho` (as design §4.3) and strips `WINE_COMPATDB_FILE`, `WINE_PROF_SERVICE`, `WINE_LARGE_ADDRESS_AWARE` (strings of `Contents/MacOS/gamelauncher`).
- The pinned DMG downloads at a stable size; `/Applications/Mach9.app` and the DMG's app are both Developer ID `WLKUUJD25W`.

## Real check (V3)
- `bodega create --runtime mach9 m9t` from the installed runtime took 20.6 s in all: wineboot about 12.5 s, the two `reg add` under 1 s, Mono about 7 s (faster than S4's 14.6 s). Details in `verify.md`.
- Mono's msiexec logs `failed to load dll ... createlinks-x86_64.dll (193)` on the aarch64 prefix and still exits 0 with `mono-2.0` in place.
