# Proposal · mach9-runtime

Input: the judge's synthesis of three candidate designs (minimal, robust, user-facing) and the engine, app, Mach9 and rules maps of 2026-11-19. The user asked to fix Bodega based on Mach9, which runs games well: Windows games on Apple silicon shall run natively instead of under Rosetta, and everything that works today shall keep working. The decisions below are the synthesis's D1–D31; four of them wait for the user (§Open questions).

## Why
- Bodega runs every bottle on one x86_64 Wine under Rosetta 2 (`packages/engine/lib/engine.dart:158-172`, the `runtimes/current` link). Measured on MW3 (32-bit D3D9, Plutonium): under that engine the game's main and render threads saturate a CPU core (frames of 40+ ms, GPU idle); under Mach9 the same game with heavier settings uses 2.5–6x less CPU and the GPU does the work.
- Mach9 (github.com/athei/mach9, Zlib) is a relocatable, signed and notarized arm64 Wine 11.21 made to be embedded in launchers: FEX runs x86 and x64 code (x64 as ARM64EC), D3D9 runs on mtld3d (Metal), D3D10/11 on DXMT, D3D12 on vkd3d-proton, D3D8 and DirectDraw on wined3d, and the backend is chosen per process through `WINE_COMPATDB`.
- arm64 and x86_64 prefixes are not compatible, so Mach9 can only be a second runtime, chosen per bottle, beside Bodega's own.

## What
**In**
- A second runtime kind, `mach9`, installed from the pinned Mach9.dmg v0.4.0, a picked `.dmg` or `.app`, or the `/Applications/Mach9.app` already on the Mac when it is exactly the pinned version; copied unmodified with `ditto --noqtn` into `runtimes/mach9-<version>/engine` behind a `runtimes/mach9` link; never bundled in Bodega.app.
- A runtime per bottle, fixed at creation (`"runtime":"mach9"` in `settings.json`), with the prefix's `kernel32.dll` PE machine having the last word, so Wine of the wrong architecture never touches a prefix.
- Wine Mono 11.3.0 x86, pinned with Mach9, installed into each Mach9 prefix as the last step of creation; a missing Mono is shown, with a button and a CLI verb, and never installed silently during a launch.
- Graphics names for Mach9 bottles: auto, wine, dxmt and mtld3d, written as `WINE_COMPATDB` rules by a canonical Dart writer; the bottle, exception, launch option and HUD behave as today.
- A Mach9 environment: Mach9.app's own variables plus Bodega's hermetic basics, with no Rosetta, MoltenVK, D3DMetal, overlay or `WINEDLLOVERRIDES` knobs.
- CLI: `runtime list|install`, `create --runtime`, `mono install`, `rules`, `backend list --runtime`, `catalog install --runtime`.
- App: a "Native engine (Mach9)" card on Backends, an Engine choice in the new bottle dialog (Native by default once installed), an Engine fact and a Mono warning in the bottle column, AVX and DLSS hidden for Mach9 bottles, new errors, hints and steps in English and Spanish.
- The missing spec of the uncommitted dxvk9 backend (D3D9 through DXVK with DXMT behind it, probe mode `9`, `BackendRole.dx9to11`) is folded in (MG12).

**Out (later, D31)**
- The copy-to-native flow for existing bottles, the library tip, the catalog's engine choice and a Check button on the engine card (M3); setup without Rosetta (M4).
- `WINE_COMPATDB_FILE`, `steam:<appid>` rules, `runtime use|remove` and keeping two Mach9 versions, 0xAA64 in `exeGraphics`, DLSS on Mach9, launching through LaunchServices for Game Mode.
- dxvk, dxvk9 and d3dmetal in Mach9 bottles (x86_64 overlays that Mach9's ntdll ignores); any change to Mach9's tree; Gecko.

## Decisions
| # | Question | Decision | Reason |
|---|---|---|---|
| D1 | Where is the runtime chosen? | Per bottle, fixed at creation. `settings.json` gets `"runtime":"mach9"`, written only for Mach9 bottles and before wineboot; a missing key means `bodega`. | arm64 and x86_64 prefixes are incompatible. Old files stay byte for byte the same: no migration, a minor bump. |
| D2 | Settings and prefix disagree? | The prefix wins: the PE machine of `drive_c/windows/system32/kernel32.dll` decides (0xAA64 mach9; 0x8664 or 0x14C bodega); unreadable, the settings decide. | Wrong-architecture Wine never touches a prefix, even if settings.json is lost, edited or erased by a downgrade. The test wineboot writes only `syswow64/kernel32.dll`, so existing tests stay on bodega. |
| D3 | How many runtimes? | One per kind. `runtimes/current` stays the x86 one and Mach9 code never writes it; `runtimes/mach9` links to `mach9-<version>`. Bottles store the kind, not a version. | Mach9 updates a prefix by itself (`wine.inf` mtime against `.update-timestamp`). |
| D4 | Sources | The pinned DMG v0.4.0 (sha256 `3b5dd83e…e6d9`), a picked `.dmg`, or a `Mach9.app`; never the release tarball. With no source, the Mach9.app in `/Applications` or `~/Applications` when it is exactly the pinned version, else the DMG download. | The app tree is the runtime-only build that ran MW3, Developer ID signed throughout; the tarball is the 1.1 GB full bundle with ad hoc signed libraries. Copying from the app is an APFS clone (~0.2 s). |
| D5 | What is checked? | Before copying: bundle id `app.mach9`; version ≥ 0.4.0 (else `RuntimeTooOld`); `LSMinimumSystemVersion` ≤ host; `codesign --verify --deep --strict` on the whole Mach9.app and TeamIdentifier `WLKUUJD25W` (else `RuntimeNotTrusted`). After: required files; `bin/wine` still a symlink; `codesign --verify --strict` on `wine.app`, `bin/wineserver`, `aarch64-unix/{ntdll.so,compatdb.so}`; a `.app` source's version unchanged; `bin/wine --version` starts with `wine-`. | The deep seal catches any changed byte (verified); `wine.app` alone does not. Bodega only verifies, never signs. |
| D6 | How is it copied? | `ditto --noqtn <app>/Contents/Resources/wine runtimes/.tmp-mach9-<v>/engine`, then a rename. Never codesign, xattr, edit or move inside `engine/`; never modify the source or remove its quarantine. | ditto keeps the 15 symlinks and the dates, clones on APFS and leaves no quarantine on Bodega's copy. |
| D7 | Other versions | Newer accepted, marked "not checked"; older than 0.4.0 refused. | Mach9 releases about weekly; older compatdb drops lines without `name=`. |
| D8 | Updates | The same install; `BottleOpen` if a Mach9 bottle runs (checked before copying and before switching); atomic link switch; older `mach9-*` deleted. No rollback verbs in v1. | 932 MB per version; the pin moves with Bodega releases. |
| D9 | Bundling | Never inside Bodega.app; `tool/package_macos.sh` skips `mach9` and `mach9-*`. | `package_macos.sh:155` runs `codesign --force --deep`, which strips wine.app's entitlements; 932 MB; redistribution duties. |
| D10 | Availability | `HostPlatform.mach9Block`: on the Mac, `sysctl -n hw.optional.arm64` = 1 and `sw_vers -productVersion` ≥ 26.4, computed once; Linux `notThisHost`. The app reads it through `listRuntimes`; `HostCapabilities` does not change; the Rosetta check stays. | Mach9's loader refuses macOS < 26.4. Keeping `HostCapabilities` keeps the app's test compiling and the streams independent. |
| D11 | Mono pin | Wine Mono 11.3.0 x86 MSI pinned in the same release record (sha256 `df2dfc16…18d3`, as Mach9's appwiz.cpl), downloaded first and kept at `runtimes/mach9-<v>/wine-mono-11.3.0-x86.msi`. | Creation needs no network; an offline Mac fails early; the Mach9 tree stays unmodified. |
| D12 | Mono install | `msiexec /i <msi> /qn` into every Mach9 prefix, exit codes `_installerOk` {0,102,194,105}, last step of creation (the app creates with `mono:false`, sets Windows and graphics, then calls `installMono`). A missing Mono shows a warning with "Install Wine Mono", `bodega mono install` and the `monoMissing` hint; never silently in a launch. | .NET launchers (Plutonium) exit without Mono; a Mono failure must not leave graphics or Windows unset; a launch must not hide a minute-long step. |
| D13 | Registry | At creation: `HKCU\Software\Wine\WineDbg ShowCrashDialog` REG_DWORD 0 and `HKCU\Software\Wine\X11 Driver EmulateModeset` REG_SZ Y; no WineBus values. | Fullscreen mode changes stay virtual, no crash dialogs; Mach9 ships SDL2 in `lib/external`. |
| D14 | Environment | Mach9.app's plus Bodega's hermetic basics (design §4.3); `WINEDEBUG` defaults to Mach9's value; `VKD3D_SHADER_CACHE_PATH=<bottle>/cache/vkd3d`. | The rest are Rosetta, overlay, MoltenVK or D3DMetal knobs Mach9 ignores or retires; without the cache path vkd3d-proton writes into the game's folder. |
| D15 | Names | auto, wine, dxmt, mtld3d; each sets only the family it names; `wine` sets both. | No choice downgrades the other family; only `wine` with DX12 is a misfit. |
| D16 | Resolution | As today: launch option, the launched program's exception, the bottle, auto (`resolveBackend`), one effective name per launch. On Mach9, auto sends no backend fields and the exe is not scanned. | The `# backend <name> (<origin>)` log line stays true; Mach9's built-ins and per-game rules apply under auto. |
| D17 | Scope of a choice | On `exe=*` (the whole process tree); from a launch option or the program's exception also on `exe=<launched exe key>`. A bottle choice never overrides Mach9's built-in rules for one program. | Steam games launch as steam.exe; launchers start games as children; an explicit choice beats a built-in rule deterministically. |
| D18 | Other programs | Saved exceptions of other programs (only without a launch option) and their HUD become their own `exe=<key>` lines. | An exception follows its program into a launcher (iw5mp.exe started by plutonium.exe). |
| D19 | HUD | `metal_hud=true` on `exe=*`. | Reaches the same processes as `MTL_HUD_ENABLED` today, with the key compatdb asks for. |
| D20 | DLL overrides | `dll_overrides=` fields on `exe=*`: always `winemenubuilder.exe=`, then each element of a fix's dlloverride, then the probe's `winedbg.exe=`. No `WINEDLLOVERRIDES`. If spike S1 fails, keep `WINEDLLOVERRIDES=winemenubuilder.exe=d` for that entry only. | compatdb retires `WINEDLLOVERRIDES` for launchers and replaces its entries for the modules it overrides. |
| D21 | Transport | `WINE_COMPATDB` only, rebuilt per launch; no `WINE_COMPATDB_FILE` in v1. A user's own `WINE_COMPATDB` (bottle, program or launch variables) is appended after Bodega's lines. | A file rule beats a variable rule of the same kind, which would break per-launch options. |
| D22 | Writer | Canonical Dart writer: LF between lines, none after the last; fields exe, dxgi, d3d9, metal_hud, dll_overrides; `%`, `;` and control characters as uppercase `%XX`. Golden tests, the `rulesIgnored` hint and a headless check. | compatdb says to write rules only through its Rust code, which Dart cannot call. |
| D23 | Fixes | Apply in Mach9 bottles as now: variables, registry values, DLL overrides as rules. | VKD3D_* and registry fixes apply to Mach9's Wine and vkd3d-proton; ROSETTA_* and D3DM_* do nothing there. |
| D24 | Stale names | Reading settings accepts names of either kind; `setBackend`, `resolveBackend` and `backendTest` raise `BackendNotForRuntime`; an unknown name gives `BadChoice` listing that kind's names. | An actionable message instead of a bottle whose settings cannot be read. |
| D25 | Catalog | `installEntry(runtime)` (default bodega) for new bottles, the existing bottle's kind otherwise; `mapBackendFor(mach9)`: wine → wine, else auto; auto stored as no exception; installers run with auto on Mach9. New catalog bottles stay on Rosetta until M3. | Storing `'auto'` would make `resolveBackend` throw `BackendNotInstalled('auto')`; the recipes were checked on x86. |
| D26 | Default engine | In the app, new bottles default to Native when Mach9 is installed and not blocked, else Rosetta with no Engine control. The CLI's `create` stays on bodega unless `--runtime mach9`. | The user's goal is native games; installing Mach9 is the opt-in. Scripts and the smoke test do not change. **Waits for the user (Q1).** |
| D27 | Words | "Native engine (Mach9)" and "Rosetta engine"; "Graphics for the Rosetta engine" above the existing cards; the engine card lives on Backends, never in Setup, never a `BackendInfo`/`BackendCard`; AVX and DLSS hidden in Mach9 bottles; an Engine fact in the bottle column. | Users know "Rosetta"; Mach9 is credited; games show as "Mach9" in the Dock. |
| D28 | Probe | `bodega backend test` works in Mach9 bottles (FEX runs the x86/x64 probes). The app's Check stays for Rosetta backends and lists only Rosetta bottles; a Check on the engine card comes in M3. | A headless proof of D3D9, 11 and 12 now. |
| D29 | Logs | `# runtime <id>`; `# backend <name> (<origin>)` (`auto (auto)` on Mach9); a new last header line `# rules a \| b` with Bodega's lines only. New LogHints `monoMissing`, `rulesIgnored` (marker `warning: WINE_COMPATDB line`), `loaderNotSigned`. | `backendOf` reads the first 4 header lines; logging only Bodega's lines keeps R12 (no user environment in the header). |
| D30 | Version and IDs | 1.7.0+15, one minor bump that also covers dxvk9. Prefixes MR, MB, MG, MC, MA, MD (unused). dxvk9's spec folded in. | Only additions; no data format breaks. |
| D31 | Later | See Out. | Keeps v1 shippable and the two streams independent. |

## Milestones
| | Content | Done when |
|---|---|---|
| M0 | This spec (J0) and the engine spike (E0, `spike.md`) | S1–S8 recorded; D20's fallback decided |
| M1 | Engine stream E1–E8 and app stream A0–A6, in parallel; A6 after E1 | each stream's checks pass with existing tests unedited |
| M2 | Join and verification V1–V6 | full engine and app checks, the headless real check, docs, the bump to 1.7.0+15, and `verify.md` with the USER checks |
| M3 (later) | Copy to native, library tip, catalog engine choice, engine-card Check | — |
| M4 (later) | Setup without Rosetta | — |

## Impact
- Engine: new parts `runtimes.dart` and `mach9.dart` (`engine.dart:14-24`); changes in `engine.dart`, `backends.dart`, `catalog.dart`, `fixes.dart`, `apps.dart`, `failures.dart`, `english.dart`, `platform*.dart`, `bin/bodega.dart`; new tests `runtimes_test.dart`, `compatdb_test.dart`, `mach9_test.dart`; `test/_mac.dart` gains seam parameters; `tool/package_macos.sh` skips Mach9.
- App: domain entities, `AppError` cases, repositories, three blocs, the engine card, the new bottle dialog, the bottle column, run options, ARB keys in both languages.
- Data root: `runtimes/mach9`, `runtimes/mach9-<v>/`, `bottles/<b>/cache/vkd3d/`; nothing changes for existing bottles.
- Docs: `README.md`, `.claude/CLAUDE.md`, `AGENTS.md`, `.claude/rules/architecture.md`, `wine/NOTICE.md`.
- Users: on Apple silicon with macOS 26.4+, a Native engine to install from Backends; existing Rosetta bottles unchanged.

## Risks
| Risk | Mitigation |
|---|---|
| Game Mode may not turn on: Bodega starts Wine as a child, Mach9.app is started by LaunchServices | USER check (V6); LaunchServices launch later |
| Games show as "Mach9" in the Dock | A note on the engine card |
| Rules written by hand drift from compatdb's format | Golden tests, the `rulesIgnored` hint, the headless check at every pin bump |
| Weekly Mach9 releases outpace the pin | One pin per Bodega release; newer imports accepted as "not checked"; the Mono hash cross-checked against appwiz.cpl |
| A downgrade to Bodega 1.6 runs x86 wineboot on an arm64 prefix | Documented; 1.7 follows the prefix (MB2) |
| Disk: 932 MB, plus a 283 MB DMG download | Free when cloned from the app; the DMG is deleted after install |
| Rosetta still required by setup and the CLI | M4 |
| mtld3d writes `mtld3d-logs/` beside the game's exe | Same as Mach9.app |
| Shared GStreamer registry with Mach9.app; Gecko off everywhere | Documented |

## Version
1.7.0+15 through `tool/version.sh bump minor`, covering dxvk9 and Mach9 (D30). The change only adds; a settings.json without `runtime` is written back byte for byte.

## Open questions
1. Confirm D26: new bottles default to Native once it is installed.
2. dxvk9: give it a pin, or document it as placed by hand (MG12 is written for "placed by hand" until the user decides)?
3. Commit `.fvmrc`?
4. M3 in this release or the next?

## Specs
- `specs/runtimes.md` (MR1..MR13): runtime kinds, availability, the Mach9 and Mono pins, install, trust checks, layout, updates, packaging guard, the shared engine contract.
- `specs/bottles.md` (MB1..MB10): the stored and effective runtime, every bottle operation on its own runtime, creation, registry, Wine Mono, the catalog.
- `specs/graphics.md` (MG1..MG13): names per kind, resolution, the `WINE_COMPATDB` writer and lines, the Mach9 environment, HUD, DLL overrides, probes, logs and hints, fixes, dxvk9.
- `specs/cli.md` (MC1..MC8): the new and changed verbs.
- `specs/app.md` (MA1..MA11): domain, errors, repositories, blocs, screens, text, tests.
- `specs/docs.md` (MD1..MD8): amended archived requirements, docs, rules, notice, version, real checks, delivery.
