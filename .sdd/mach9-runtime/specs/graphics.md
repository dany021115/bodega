# Spec · Graphics, rules and environment

Requirements MG1..MG13: graphics names per runtime kind, how a launch's choice becomes `WINE_COMPATDB` rules, the Mach9 environment, the HUD, DLL overrides, probes, log lines and hints, fixes, and the uncommitted dxvk9 backend (`design.md` §4, §5). Terms as in `runtimes.md` and `bottles.md`. Golden strings are design §4.2's examples.

## MG1 · Names per kind
`backendNamesFor(bodega)` shall be today's `backendNames`; `backendNamesFor(mach9)` `['wine','dxmt','mtld3d']`. Each mach9 name sets only the DirectX family it names, `wine` both (design §4.1). dxvk, dxvk9 and d3dmetal are not offered on Mach9, and mtld3d is not offered on bodega.
- **Given** each kind, **then** `backendNamesFor` gives that list. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`.

## MG2 · Installed, fits and catalog mapping per kind
`listBackends(home, runtime: mach9)` shall give `wine` true when `lib/wine/dxgi/wined3d` and `lib/wine/d3d9/wined3d` exist under `runtimes/mach9/engine`, `dxmt` when `lib/wine/dxgi/dxmt` does, `mtld3d` when `lib/wine/d3d9/mtld3d` does, all false without the runtime; without `runtime` it is today's map. `backendFitsFor(mach9, b, exe)` is false only for `wine` with a DX12 exe. `mapBackendFor(mach9, name)` gives wine → wine and everything else → auto; for bodega it is `hostPlatform.mapBackend`.
- **Given** the fake Mach9 runtime, **then** `{wine: true, dxmt: true, mtld3d: true}`; without it, all false. (test)
- **Given** `listBackends(home)` with no argument, **then** `backends_test` 580-590's exact map still passes. (test)
- **Check:** `fvm dart test test/runtimes_test.dart test/backends_test.dart`.

## MG3 · Choices checked against the bottle's kind
`setBackend`, `resolveBackend` and `backendTest` shall throw `BackendNotForRuntime(backend, kind)` for a known name of the other kind, and `BadChoice` listing the bottle's kind's names for an unknown one. Reading settings accepts names of either kind. `resolveBackend` keeps its order (launch option, the launched program's exception, the bottle, auto) and gives one effective name and origin; on Mach9 auto does not scan the exe.
- **Given** a Mach9 bottle, **when** dxvk, dxvk9 or d3dmetal is set or asked for, **then** `BackendNotForRuntime`; **given** a bodega bottle and mtld3d, **then** the same. (test)
- **Given** a Mach9 bottle and `foo`, **then** `BadChoice` whose choices are `[wine, dxmt, mtld3d]`. (test)
- **Given** a Mach9 bottle whose settings hold `dxvk` (edited by hand), **then** `bottleSettings` reads it and a launch throws `BackendNotForRuntime`. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MG4 · The canonical rule writer
The writer shall join fields with `;` and lines with `\n`, with nothing after the last line; order fields exe, dxgi, d3d9, metal_hud, dll_overrides; and write `%` as `%25`, `;` as `%3B` and bytes 0x00–0x1F and 0x7F as uppercase `%XX` in every value, exe keys and override elements included, leaving everything else as is.
- **Given** an exe key `a;b%c.exe` and a tab in an override, **then** `exe=a%3Bb%25c.exe` and `%09`. (test)
- **Given** any value, **then** it does not end with `\n`. (test)
- **Check:** `fvm dart test test/compatdb_test.dart`.

## MG5 · Lines for one launch
`compatdbRules(home, name, program, {backend, hud})` shall return design §4.2's value for a Mach9 bottle and null for a bodega one, and `_launchIn` shall send the same value as `WINE_COMPATDB`: the `exe=*` line always; the launched program's line when the choice came from a launch option or its exception; one line per other program with an exception (unless a launch option was given) or a saved HUD; then the user's own `WINE_COMPATDB`.
- **Given** each of design §4.2's six cases, **then** the exact golden string. (test)
- **Given** the combinations of bottle, exception, option, `--backend auto` and HUD, **then** the golden strings of `compatdb_test`. (test)
- **Given** this Mac, **when** `bodega rules m9t iw5mp.exe` runs, **then** it prints the value. (headless V3)
- **Check:** `fvm dart test test/compatdb_test.dart`.

## MG6 · The Mach9 environment
`wineEnv` of a Mach9 prefix and `_launchIn` in a Mach9 bottle shall build design §4.3's Mach9 column: hermetic basics, `WINEPREFIX`, `USER`, `WINEMSYNC`, `WINEDEBUG` (Mach9's default unless `BODEGA_WINEDEBUG`), `WINE_COMPATDB` (`exe=*;dll_overrides=winemenubuilder.exe=` in `wineEnv`, MG5's value in launches), `VKD3D_SHADER_CACHE_PATH=<bottle>/cache/vkd3d` (folder created at launch, before the user's variables), then fix, bottle, program, sync, GPU and launch variables. Never `WINEDLLOVERRIDES` (unless the user's variables set it), `ROSETTA_*`, `MVK_*`, `DOTNET_*`, `CX_*`, `WINEDLLPATH_PREPEND`, `DXVK_*`, `DXMT_*`, `D3DM_*`, `MTL_HUD_*`, nor any inherited `WINE_COMPATDB*`, `WINE_LARGE_ADDRESS_AWARE`, `WINE_PROF_SERVICE`, `DYLD_*`, `VK_*`, `GST_*`. Rosetta bottles keep today's environment exactly.
- **Given** a parent with `WINE_COMPATDB`, `WINE_COMPATDB_FILE`, `WINEDLLOVERRIDES`, `WINE_PROF_SERVICE`, `WINE_LARGE_ADDRESS_AWARE` and `DYLD_INSERT_LIBRARIES`, **then** the Mach9 `wineEnv` map is exact and holds none of them. (test)
- **Given** a launch with `dlss: true`, `hud: true`, `avx: false`, **then** the fake wine's `last-env` holds the exact `WINE_COMPATDB`, `VKD3D_SHADER_CACHE_PATH`, `WINEMSYNC`, Mach9's `WINEDEBUG`, and none of the forbidden keys. (test)
- **Given** `engine_test` 94-129, **then** the Rosetta `wineEnv` is unchanged. (test)
- **Check:** `fvm dart test test/mach9_test.dart test/engine_test.dart`.

## MG7 · The HUD
In a Mach9 bottle the HUD (asked for this launch, or saved for the launched program) shall be `metal_hud=true` on `exe=*`; another program's saved HUD is `metal_hud=true` on its own line.
- **Given** `hud: true`, **then** the `exe=*` line holds `metal_hud=true` and the environment holds no `MTL_HUD_ENABLED`. (test)
- **Given** MW3 through Plutonium with the HUD on, **then** the HUD shows inside iw5mp.exe. (USER V6)
- **Check:** `fvm dart test test/compatdb_test.dart`.

## MG8 · DLL overrides as rules
On Mach9, DLL overrides shall be `dll_overrides=` fields on `exe=*`: `winemenubuilder.exe=` always, then each non-empty element of each fix's dlloverride split on `;`, then the probe's `winedbg.exe=`. If spike S1 shows the first entry is not honoured, `WINEDLLOVERRIDES=winemenubuilder.exe=d` is set for that entry only, and this spec records it.
- **Given** a fix with dlloverride `gameoverlayrenderer64,gameoverlayrenderer=d`, **then** design §4.2's Steam golden string. (test)
- **Given** a real `exe=*;dll_overrides=winemenubuilder.exe=`, **then** the compatdb log shows it with no `warning:` and no winemenubuilder process runs during wineboot. (headless E0 S1)
- **Check:** `fvm dart test test/compatdb_test.dart`; `spike.md` S1.

## MG9 · The user's own rules
A `WINE_COMPATDB` in the bottle, program or launch variables shall be appended after Bodega's lines, separated by `\n`, and left out of the log's `# rules` line. No `WINE_COMPATDB_FILE` is set in v1.
- **Given** a bottle variable `WINE_COMPATDB=exe=a.exe;d3d9=wined3d`, **then** the value ends with `\nexe=a.exe;d3d9=wined3d`. (test)
- **Check:** `fvm dart test test/compatdb_test.dart`.

## MG10 · Probes in Mach9 bottles
`backendTest` in a Mach9 bottle shall run design §4.1's probe cases per name (mtld3d: 32/64 mode 9; dxmt: 32/64 mode 11 and 64 mode 12; wine: 32/64 mode 9 and 64 mode 11), with the probe's `winedbg.exe=` as a rule instead of `WINEDLLOVERRIDES`; the Rosetta path is unchanged.
- **Given** a Mach9 bottle and `dxmt`, **then** three cases and MG5's D3D12 golden string. (test)
- **Given** this Mac, **when** `bodega backend test m9t mtld3d`, `dxmt` and `wine` run, **then** each passes and each log's `compatdb:` lines show the values coming from `WINE_COMPATDB line N`, with no `warning:` line. (headless V3)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MG11 · Log header and hints
A Mach9 launch log shall keep `# runtime <id>` and `# backend <name> (<origin>)` (`auto (auto)` under auto) in the first four lines (`backendOf`), and end its header with `# rules <lines 1–3 joined by " | ">`. New LogHints: `monoMissing` (marker `Wine Mono is not installed`), `rulesIgnored` (`warning: WINE_COMPATDB line`), `loaderNotSigned` (`the loader must run from the signed wine.app`), with design §5's English.
- **Given** a Mach9 launch under auto, **then** line 2 is `# backend auto (auto)` and the last header line starts with `# rules `. (test)
- **Given** a log holding each marker, **then** `hintsIn` gives that hint; the 8 markers are unique. (test, `english_test`)
- **Check:** `fvm dart test test/mach9_test.dart test/english_test.dart`.

## MG12 · dxvk9 (folded in)
The Mac backend `dxvk9` shall run D3D9 through DXVK's d3d9 with DXMT behind it for D3D10/11 (`BackendRole.dx9to11`, "DirectX 9 with DXVK, and 10 and 11 with DXMT"), on the Rosetta engine only; its environment is `backends_test` 63-125's dxvk9 rows (with and without dxmt installed); its probe uses mode `9` of `tool/probe.c` (`lib/probe_data.dart` regenerated). Until the user decides (proposal Q2), dxvk9 has no pin: it is placed by hand in `backends/dxvk9`, `pinnedBackend('dxvk9')` is null and `installBackend('dxvk9')` throws `NotDownloadable`. If the user gives a pin, B1's rules apply (URL, sha256, `_pinned`).
- **Given** the uncommitted tests in `backends_test.dart`, **then** they pass. (test)
- **Given** a Mach9 bottle, **then** dxvk9 gives `BackendNotForRuntime`. (test)
- **Given** `text_test`'s role map, **then** it holds `dx9to11`. (test, A0)
- **Check:** `fvm dart test test/backends_test.dart`; `fvm flutter test test/app/text_test.dart` in `APP`.

## MG13 · Fixes in Mach9 bottles
Fixes shall apply in Mach9 bottles as in Rosetta ones: their variables are set (ROSETTA_* and D3DM_* simply do nothing), their registry steps run, and their dlloverride steps become MG8's rules. Per-game data still comes only from highball-db.
- **Given** a fix with a variable and a dlloverride, **when** its program launches in a Mach9 bottle, **then** the variable is in `last-env` and the override is in the rules, not in `WINEDLLOVERRIDES`. (test)
- **Check:** `fvm dart test test/mach9_test.dart test/fixes_test.dart`.
