# Design · mach9-runtime

Only what is not obvious. Decisions are `proposal.md`'s D1–D31. Paths: `ENG` is `packages/engine/`, `APP` is `apps/bodega/`; other paths start at the repo root. Line numbers are today's, with the uncommitted dxvk9 work in the tree.

## 1. Two runtime kinds, one per bottle
- `RuntimeKind {bodega, mach9}`. `runtimes/current` stays Bodega's x86_64 runtime, written only by `installRuntime` and the bundle registration (`ENG/lib/platform_linux.dart:392-395`). `runtimes/mach9` is a new link, written only by `installMach9`.
- A bottle stores its kind in `settings.json` (`"runtime":"mach9"`, only for Mach9 bottles); a missing key means `bodega` (D1). The **effective** kind comes from the prefix (D2): the PE machine of `drive_c/windows/system32/kernel32.dll` (0xAA64 → mach9; 0x8664 or 0x14C → bodega), falling back to the stored value when the file is missing, short or unreadable. `_peMachine` is factored out of `_peBits` (`ENG/lib/backends.dart:815-832`).
- Every call that used `currentRuntime(home)` for a bottle resolves `runtimeDir(home, bottleRuntime(home, name))` instead: `engine.dart:179, 246, 336, 344, 640-643, 655-667`, `platform_mac.dart:363`, `fixes.dart:136`, `catalog.dart:124`. Stop and wait on a Mach9 bottle whose runtime is missing return 0; remove deletes the bottle without `wineserver -k` then.
- `hostPlatform.prepareBottle` (`engine.dart:200, 217, 659`, `apps.dart:385`) becomes a private `_prepareBottle` by kind: the host's for bodega, nothing for mach9. `_syncSdl` (`platform_mac.dart:58-75`) and `installSdl` do nothing when `current` has no `x86_64-unix`.

### 1.1 On disk
```
runtimes/current -> engine-wine-11.0-…                 unchanged
runtimes/mach9   -> mach9-0.4.0                         new; written only by installMach9
runtimes/mach9-0.4.0/engine/                            ditto --noqtn copy of Mach9.app/Contents/Resources/wine, never modified
runtimes/mach9-0.4.0/wine-mono-11.3.0-x86.msi           pinned, hash checked
runtimes/mach9-0.4.0/runtime.json                       {"kind":"mach9","version":"0.4.0","source":"app|dmg|download","checked":true}
bottles/<b>/settings.json                               + "runtime":"mach9" (Mach9 bottles only, written before wineboot)
bottles/<b>/cache/vkd3d/                                Mach9 bottles; created at launch
downloads/Mach9-0.4.0.dmg                               versioned name; deleted after a successful install
```
Invariants: **I1** a settings.json without `runtime` is written back byte for byte; **I2** `current` never moves because of Mach9; **I3** nothing is written under a Mach9 `engine/`; **I4** a prefix is never run by Wine of the other architecture; **I5** creation and launches use no network (except re-downloading the MSI as a fallback); **I6** a failed install leaves no `.tmp-*`, no link change and no mounted volume.

## 2. Installing Mach9
1. Host gate: `hostPlatform.mach9Block` non-null → `RuntimeUnavailable`.
2. Mono first: the MSI given by `mono:` or downloaded with `_download` (`backends.dart:330-367`), its sha256 checked against `mach9Release.mono.sha256` (`ChecksumMismatch` before any copy).
3. Source: `source` (a `.dmg` or `.app`); else `findMach9App()` when its version equals the pin; else the pinned DMG downloaded to `downloads/Mach9-0.4.0.dmg`. `pinned: true` means the caller downloaded the pinned DMG, so its sha256 must match.
4. DMG: `attach` and `detach` are factored out of `installD3DMetalDmg` (`backends.dart:139-163, 223-233`) and reused; the app is `<mnt>/Mach9.app` (else `IncompleteArchive`); detach in `finally`.
5. Pre-copy checks (D5), from the plist: `Info.plist` bundle id `app.mach9`, `CFBundleShortVersionString` ≥ `minimumVersion` (`RuntimeTooOld`), `LSMinimumSystemVersion` ≤ host. The signature is checked on the copy (step 7): a source `.app` can change between a check of it and the copy. From step 5 to the end, the install holds `runtimes/.mach9.lock` (an exclusive `fcntl` lock, also queued in-process), so two installs (app and CLI) never share `.tmp-mach9-<v>`; under it, any `.tmp-mach9-*` left by a killed install is removed first.
6. `BottleOpen` if any Mach9 bottle's wineserver runs.
7. `copyTree(<app>, runtimes/.tmp-mach9-<v>/Mach9.app)` (Mac: `/usr/bin/ditto --noqtn`, an APFS clone; Linux and TestMac: `cp -a`), never a Dart file-by-file copy (it follows links). Then `signingTeam(copy, deep: true)` = `WLKUUJD25W` (`RuntimeNotTrusted`) and the copy's version equal to step 5's: the app's seal covers every file of the copy, PE DLLs and dylibs included. Then `Contents/Resources/wine` is renamed to `.tmp-mach9-<v>/engine` (a rename, nothing inside changes) and the rest of the copy deleted. Measured: ditto 0.3 s, `codesign --verify --deep --strict` 0.3 s on the copy; one byte appended to `aarch64-windows/d3d9.dll` fails it ("a sealed resource is missing or invalid").
8. Post-copy checks: required files (§2.1), `bin/wine` a symlink, `signingTeam` (verify only, not deep) on `wine.app`, `bin/wineserver`, `aarch64-unix/ntdll.so` and `compatdb.so`; `bin/wine --version` starts with `wine-`.
9. Copy the MSI in, write `runtime.json`, check `BottleOpen` again, rename `.tmp-mach9-<v>` to `mach9-<v>`, switch `runtimes/mach9` atomically (a temporary link renamed over) before the DMG is detached, then delete the `mach9-*` folders the link does not name, except one an open Mach9 bottle still runs on (its `wineserver -w`), which the next install removes. `AlreadyInstalled` only if the link names `mach9-<v>`: a `mach9-<v>` the link does not name is not installed (a killed install left it) and is replaced, or `BottleOpen` if a bottle runs on it. `cancelled()` is polled between steps → `Cancelled`. Any failure removes `.tmp-*` (I6).

### 2.1 Required files (mach9)
`engine/bin/wine` (symlink), `engine/bin/wineserver`, `engine/lib/wine/aarch64-unix/{ntdll.so,compatdb.so,wine.app}`, `engine/lib/wine/aarch64-windows/kernel32.dll`, `engine/lib/wine/i386-windows/kernel32.dll`, `engine/lib/wine/dxgi/{dxmt,wined3d}`, `engine/lib/wine/d3d9/{mtld3d,wined3d}`, `engine/lib/external/libfreetype.6.dylib`, `engine/lib/external/libgnutls.30.dylib`.

## 3. Shared contract (gate between the streams)
Only `data/` in the app imports the engine. Task E1 lands all of this at once, exported by `package:engine/engine.dart`; read-only functions really implemented, `installMach9`, `installMono`, `compatdbRules` and the Mach9 path of `createBottle` stubbed with `UnimplementedError` until E5, E6 and E3.

### 3.1 New engine API
```dart
// ENG/lib/runtimes.dart (new part)
enum RuntimeKind { bodega("Bodega's Wine (x86_64)"), mach9('Mach9'); const RuntimeKind(this.english); final String english; }
enum RuntimeBlock {
  notThisHost('Mach9 runs only on a Mac'),
  appleSiliconOnly('Mach9 needs a Mac with Apple silicon'),
  macosTooOld('Mach9 needs macOS 26.4 or later');
  const RuntimeBlock(this.english); final String english;
}
typedef RuntimeInfo = ({RuntimeKind kind, bool installed, String? id, String? version, bool checked,
    RuntimeBlock? blocked, ({String path, String version})? app});
List<RuntimeInfo> listRuntimes(String home);          // Linux: [bodega]; Mac: [bodega, mach9]
String runtimeDir(String home, RuntimeKind kind);     // NoRuntime (bodega) or RuntimeNotInstalled (mach9)
RuntimeKind bottleRuntime(String home, String name);  // D2; files only, safe inside Isolate.run
List<String> backendNamesFor(RuntimeKind kind);       // mach9: const ['wine','dxmt','mtld3d']
Map<String, bool> listBackends(String home, {RuntimeKind runtime = RuntimeKind.bodega});
bool backendFitsFor(RuntimeKind kind, String backend, ExeGraphics exe);
String mapBackendFor(RuntimeKind kind, String name);

// ENG/lib/mach9.dart (new part)
typedef Mach9Release = ({String version, String url, String sha256, int bytes, String file, int diskBytes,
  String bundleId, String team, String minimumVersion, String minimumMacos,
  ({String version, String url, String sha256, int bytes, String file}) mono});
Mach9Release mach9Release = (
  version: '0.4.0',
  url: 'https://github.com/athei/mach9/releases/download/v0.4.0/Mach9.dmg',
  sha256: '3b5dd83ee7b08d55e6c4a84dabb32db994dc6a5bfb2a1500fb50d0b45436e6d9',
  bytes: 200499232, file: 'Mach9-0.4.0.dmg', diskBytes: 1015000000,
  bundleId: 'app.mach9', team: 'WLKUUJD25W', minimumVersion: '0.4.0', minimumMacos: '26.4',
  mono: (version: '11.3.0',
    url: 'https://dl.winehq.org/wine/wine-mono/11.3.0/wine-mono-11.3.0-x86.msi',
    sha256: 'df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3',
    bytes: 83348992, file: 'wine-mono-11.3.0-x86.msi'),
);
enum Mach9Step { downloadingMono, downloading, mounting, checkingSignature, copying, checking, switching } // + english
Future<String> installMach9(String home, {String? source, bool pinned = false, String? mono,
    void Function(Mach9Step step)? onStep, bool Function()? cancelled});
({String path, String version})? findMach9App();
enum BottleStep { prefix, mono }                                   // + english
Future<String?> installMono(String home, String name);            // log; null for bodega or Mono present
bool monoMissing(String home, String name);                       // mach9 without drive_c/windows/mono/mono-2.0
String? compatdbRules(String home, String name, String program, {String? backend, bool hud = false});
```
The pinned numbers (`bytes`, `diskBytes`) are measured again when the pin is set (E0).

### 3.2 Changed engine API
```dart
typedef BottleSettings = (/* existing */, RuntimeKind runtime);              // stored value
typedef BottleInfo = ({String name, bool ready, List<InstalledApp> apps, RuntimeKind runtime}); // effective (D2)
Future<String> createBottle(String home, String name,
    {RuntimeKind runtime = RuntimeKind.bodega, bool mono = true, void Function(BottleStep step)? onStep});
Future<String> installEntry(String home, CatalogEntry entry, {/* existing */ RuntimeKind runtime = RuntimeKind.bodega});
enum InstallStepKind { unpinnedDownload, downloading, syncMismatch, creatingBottle, installingMono, registry, runningInstaller, waiting }
enum WineTool { wineboot, reg, installer, winecfg, mono }
enum LogHint { freeType, gnuTls, otherServer, cannotOpen, fixNotApplied, monoMissing, rulesIgnored, loaderNotSigned }
enum ChoiceKind { /* existing */, runtime }
BadChoice(ChoiceKind kind, String value, [List<String>? choices]);
final class RuntimeNotInstalled extends EngineFailure { const RuntimeNotInstalled(this.runtime); final RuntimeKind runtime; }
final class RuntimeUnavailable extends EngineFailure { const RuntimeUnavailable(this.runtime, this.reason); final RuntimeKind runtime; final RuntimeBlock reason; }
final class RuntimeNotTrusted extends EngineFailure { const RuntimeNotTrusted(this.source, this.reason); final String source, reason; }
final class RuntimeTooOld extends EngineFailure { const RuntimeTooOld(this.version, this.minimum); final String version, minimum; }
final class BackendNotForRuntime extends EngineFailure { const BackendNotForRuntime(this.backend, this.runtime); final String backend; final RuntimeKind runtime; }

// HostPlatform seams (NoHost uses noSuchMethod and app test hosts extend MacPlatform, so neither breaks)
RuntimeBlock? get mach9Block;                                  // Mac: sysctl + sw_vers, cached; Linux: notThisHost
Future<String> signingTeam(String path, {bool deep = false});  // Mac: codesign --verify --strict [--deep] then -dv; Linux: NotAvailable
Future<void> copyTree(String from, String to);                 // Mac: ditto --noqtn; Linux: cp -a
List<String> get applicationDirs;                              // Mac: /Applications, $HOME/Applications; Linux: []
```
- Unchanged signatures that now follow the bottle's kind: `wineEnv`, `runInBottle`, `openApp`, `setBackend`, `resolveBackend`, `backendTest`, `waitBottle`, `stopBottle`, `removeBottle`, `renameBottle`, `setSync`, `setHighRes`, `setBottleUser`, `setWindowsVersion`, `bottleSettings`, `listBottles`.
- Unchanged and Rosetta-only: `installRuntime`, `currentRuntime`, `hasRuntime`, `hasSdl`, `installSdl`, `HostCapabilities`, `BackendRole`.
- `ENG/test/_mac.dart`: `const TestMac({RuntimeBlock? mach9Block, String? team = 'WLKUUJD25W', String? applications})`; copies with `cp -a`; `signingTeam` returns `team` or throws `RuntimeNotTrusted` when null. `const TestMac()` still compiles everywhere.

### 3.3 App side
- New domain enums `RuntimeKind`, `RuntimeBlock`, `Mach9Step`, `BottleStep`; Freezed `RuntimeInfo({required kind, required installed, String? version, @Default(true) checked, RuntimeBlock? blocked, String? appPath, String? appVersion})`.
- `Bottle` and `BottleDetail` get `@Default(RuntimeKind.bodega) runtime`; `BottleDetail` also `@Default(false) monoMissing`.
- `AppError`: `runtimeNotInstalled(runtime)`, `runtimeUnavailable(runtime, reason)`, `runtimeNotTrusted(source)`, `runtimeTooOld(version, minimum)`, `backendNotForRuntime(backend, runtime)`, each with `{String? detail}`. `WineTool.mono`; `LogHint` +3; `InstallStep.installingMono()`.
- `BackendRepository`: `runtimes()`; `installRuntime(RuntimeKind kind, {String? file, required onProgress, required onStep})` → false when cancelled (reuses `cancelDownload()`); `readyBottles()` returns only ready bodega bottles.
- `BottleRepository.create(name, {windows, backend, RuntimeKind runtime = RuntimeKind.bodega, onStep})` in the order `createBottle(mono:false)` → `setWindowsVersion` → `setBackend` → `installMono` (Mach9); new `installMono(name)`.
- `installRuntime(mach9)` in data: Downloader fetches the MSI (unless a matching file is there); the source is `file`, else `appPath` when `appVersion == mach9Release.version`, else the Downloader fetches the DMG; then `engine.installMach9(source:, pinned:, mono:)`; it deletes only files it downloaded, after success and after an engine failure about a file (`ChecksumMismatch`, `RuntimeNotTrusted`, `IncompleteArchive`); after any other failure (`BottleOpen`, `AlreadyInstalled`, `MountFailed`, `RuntimeUnavailable`, …) it keeps them for the next attempt.

| Engine | App |
|---|---|
| `RuntimeKind`, `RuntimeBlock`, `Mach9Step`, `BottleStep` | same-named domain enums, exhaustive switches in `data/service/code_mapper.dart` |
| `RuntimeInfo.app` | `appPath`, `appVersion` |
| `BottleInfo.runtime` | `Bottle.runtime` |
| `bottleRuntime`, `monoMissing`, `listBackends(runtime:)` | `BottleDetail.runtime`, `.monoMissing`, `.installedBackends` (in `_detail`, inside `Isolate.run`, so no `listRuntimes`) |
| `backendFitsFor` over `listBackends(runtime:)` | `ExeGraphics.misfits` (`backend_repository_impl.dart:124-152`) |
| the 5 failures | the 5 `AppError` cases (`repository_call.dart`, exhaustive) |
| `WineTool.mono`, `LogHint` +3, `InstallStepKind.installingMono` | `code_mapper.dart`, `logHintOf` (`library_repository_impl.dart:144`), `installStepOf` |
| `mach9Release` | the Downloader's URLs and names; the card's size line |

## 4. WINE_COMPATDB
### 4.1 Names in a Mach9 bottle
| Name | Fields | Result | Misfit |
|---|---|---|---|
| auto | none | Mach9's built-ins: D3D9 mtld3d, D3D10/11 DXMT, D3D12 vkd3d-proton, D3D8/DirectDraw wined3d, OpenGL EGL; Mach9's per-game rules | none |
| mtld3d | `d3d9=mtld3d` | D3D9 on mtld3d; DXGI family untouched | none |
| dxmt | `dxgi=dxmt` | D3D10/11 on DXMT, D3D12 on vkd3d-proton; D3D9 untouched | none |
| wine | `dxgi=wined3d;d3d9=wined3d` | wined3d for D3D9–11; no D3D12 | DX12 |

dxvk, dxvk9 and d3dmetal → `BackendNotForRuntime`. Probe cases: mtld3d `[(32,'9'),(64,'9')]`; dxmt `[(32,'11'),(64,'11'),(64,'12')]`; wine `[(32,'9'),(64,'9'),(64,'11')]`. `listBackends(runtime: mach9)`: wine = `lib/wine/dxgi/wined3d` and `lib/wine/d3d9/wined3d` exist; dxmt = `lib/wine/dxgi/dxmt`; mtld3d = `lib/wine/d3d9/mtld3d`; all false without the runtime. `backendFitsFor(mach9, b, exe)` = `exe.directx.isEmpty || !(b == 'wine' && exe.directx == 'DX12')`.

### 4.2 The value for one launch
Inputs: settings `s`; `key = _exeKey(program)`; `choice` from `resolveBackend` (name and origin option|exe|bottle|auto; on Mach9 auto has no fields); `optionGiven` (also `--backend auto`); `hudOn` (this launch or saved for `key`); `overrides` (fix dlloverride values, plus `winedbg.exe=` for the probe). `F(name)` is §4.1's fields.
1. `exe=*` with `F(choice.name)`; `metal_hud=true` if `hudOn`; `dll_overrides=winemenubuilder.exe=`; one `dll_overrides=<element>` per non-empty element of each override split on `;`. Always sent.
2. `exe=<key>` with `F(choice.name)`, only when the origin is option or exe and the fields are not empty.
3. For each `k` in `sorted(s.programs.keys)` other than `key`: `exe=<k>`, `F(p.backend)` unless `optionGiven`, `metal_hud=true` if `p.hud`; sent only with fields.
4. If the bottle, program or launch variables hold `WINE_COMPATDB`, `"\n" + thatValue` is appended.

Format: fields joined by `;`, lines by `\n`, nothing after the last; field order exe, dxgi, d3d9, metal_hud, dll_overrides; in values (exe keys and override elements too) `%` → `%25`, `;` → `%3B`, bytes 0x00–0x1F and 0x7F → uppercase `%XX`; everything else as is. The log's `# rules` line is lines 1–3 joined by `" | "`.

```
# bottle wine
exe=*;dxgi=wined3d;d3d9=wined3d;dll_overrides=winemenubuilder.exe=

# bottle auto, exception iw5mp.exe=wine, plutonium.exe launched with the HUD
exe=*;metal_hud=true;dll_overrides=winemenubuilder.exe=
exe=iw5mp.exe;dxgi=wined3d;d3d9=wined3d

# same bottle: run --backend mtld3d iw5mp.exe
exe=*;d3d9=mtld3d;dll_overrides=winemenubuilder.exe=
exe=iw5mp.exe;d3d9=mtld3d

# Steam game (program steam.exe, exception dxmt), with the fix's override
exe=*;dxgi=dxmt;dll_overrides=winemenubuilder.exe=;dll_overrides=gameoverlayrenderer64,gameoverlayrenderer=d
exe=steam.exe;dxgi=dxmt

# backend test <b> dxmt, D3D12 case
exe=*;dxgi=dxmt;dll_overrides=winemenubuilder.exe=;dll_overrides=winedbg.exe=
exe=probe-64.exe;dxgi=dxmt

# --backend auto on any bottle
exe=*;dll_overrides=winemenubuilder.exe=
```
Bodega's internal runs (reg, winecfg, msiexec, tasklist) keep `backend: 'wine'` (harmless rules: nothing draws). Catalog installers on Mach9 run with `backend: 'auto'` (`catalog.dart:203`).

### 4.3 Environment
| Variable | Rosetta bottle (unchanged) | Mach9 bottle |
|---|---|---|
| HOME, USER, LOGNAME, TMPDIR, `__CF_USER_TEXT_ENCODING` | from the parent | same |
| PATH | `/usr/bin:/bin:/usr/sbin:/sbin` | same |
| WINEPREFIX; USER from settings | yes | same |
| WINEMSYNC | 1, or 0 for sync `none` | same |
| WINEDEBUG | `BODEGA_WINEDEBUG`, else `fixme-all` | `BODEGA_WINEDEBUG`, else `fixme-all,-dbghelp_msc,-dbghelp_dwarf,-dbghelp_pdb,-dbghelp_macho` |
| WINEDLLOVERRIDES | `winemenubuilder.exe=d` + backend's + fixes' | not set (only by the user's own variables) |
| WINE_COMPATDB | never | `wineEnv`: `exe=*;dll_overrides=winemenubuilder.exe=`; launches: §4.2 |
| VKD3D_SHADER_CACHE_PATH | none | `<bottle>/cache/vkd3d`, set before the user's variables |
| ROSETTA_ADVERTISE_AVX, DOTNET_EnableWriteXorExecute, MVK_CONFIG_LOG_LEVEL | yes | never |
| CX_*, WINEDLLPATH_PREPEND, DXVK_*, DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN, D3DM_*, DXMT_ENABLE_NVEXT, MTL_HUD_ENABLED | per backend, DLSS, HUD | never; the HUD goes through `metal_hud` |
| Fix, bottle, program, launch variables, syncEnv, gpuEnv | yes | yes |
| WINE_COMPATDB_FILE, WINE_LARGE_ADDRESS_AWARE, WINE_PROF_SERVICE, DYLD_*, VK_*, GST_* | never inherited | same |

## 5. Failures, hints, steps
| Failure | When | AppError | Key and English |
|---|---|---|---|
| `RuntimeNotInstalled(runtime)` | Mach9 bottle, create or catalog install while `runtimes/mach9` is missing or dangling | `runtimeNotInstalled` | `errRuntimeNotInstalled`: "This bottle uses the native engine, which isn't installed. Install it in {backends}." |
| `RuntimeUnavailable(runtime, reason)` | install, create or launch on Linux, Intel, macOS < 26.4 | `runtimeUnavailable` | `errRuntimeUnavailable`: select on reason ("The native engine needs macOS {version} or later." / "…needs a Mac with Apple silicon.") |
| `RuntimeNotTrusted(source, reason)` | bad seal, wrong team or bundle id, source changed during the copy | `runtimeNotTrusted` | `errRuntimeNotTrusted`: "That copy of Mach9 isn't signed by its developer, so Bodega won't use it." |
| `RuntimeTooOld(version, minimum)` | Mach9 < 0.4.0 | `runtimeTooOld` | `errRuntimeTooOld`: "Mach9 {version} is older than {minimum}, the first version Bodega works with." |
| `BackendNotForRuntime(backend, runtime)` | dxvk/dxvk9/d3dmetal in Mach9; mtld3d in Rosetta | `backendNotForRuntime` | `errBackendNotForRuntime`: select on engine ("{backend} doesn't work with the native engine. Choose another option in Graphics.") |
| `WineToolFailed(WineTool.mono, code, log)` | msiexec exits outside {0,102,194,105} or hits 10 min (code -1) | `wineToolFailed(mono)` | wine-tool word "Wine Mono's installer" |

Reused: `ChecksumMismatch` (DMG or MSI), `MountFailed`, `IncompleteArchive` (missing file or link, no Mach9.app in the DMG), `AlreadyInstalled`, `ProcessFailed` (ditto, hdiutil, `--version`), `BottleOpen`, `Cancelled`, `InstallerNoExe` (Mono exited well but no `mono-2.0`), `CorruptData` wrapping `BadChoice(ChoiceKind.runtime, …)`, `BadChoice` with the kind's list, and the app's `downloadCut` and `network`.

| LogHint | Marker | English |
|---|---|---|
| `monoMissing` | `Wine Mono is not installed` | "the program needs Wine Mono: bodega mono install <bottle>" |
| `rulesIgnored` | `warning: WINE_COMPATDB line` | "Mach9 ignored a rule Bodega sent: report it with this log" |
| `loaderNotSigned` | `the loader must run from the signed wine.app` | "Mach9's copy is damaged or this macOS cannot run it: bodega runtime install mach9" |

Steps: `Mach9Step` (7), `BottleStep` (`prefix`, `mono`), `InstallStepKind.installingMono`; one text key per meaning.

## 6. CLI
```
bodega runtime list
bodega runtime install mach9 [Mach9.dmg|Mach9.app] [--mono wine-mono-11.3.0-x86.msi]
bodega create [--runtime bodega|mach9] <bottle>
bodega mono install <bottle>
bodega rules <bottle> [--backend <b>] [--hud] <program>
bodega backend list [--runtime mach9]
bodega catalog install <id> [bottle] [--runtime mach9]
```
`runtime list` prints `bodega: installed (<id>)` and, on the Mac, one of `mach9: installed 0.4.0 (mach9-0.4.0)`, `mach9: installed 0.5.0 (not checked with this Bodega)`, `mach9: not installed`, `mach9: not available (needs macOS 26.4 or later)`. `run`, `open`, `backend set|test`, `sync`, `stop`, `wait`, `rename` and `hud` keep their syntax and follow the bottle's kind. `needsHost` (the Rosetta check) is unchanged.

## 7. The app
- Backends page: `presentation/backends/widgets/engine_card.dart` before the backend loop (`backends_page.dart:51-55`), and the heading "Graphics for the Rosetta engine" above the cards, both only when a mach9 entry exists that is not blocked as `appleSiliconOnly` or `notThisHost` (so a too-old macOS shows the card with its reason). States: not installed (size line `engineSizeDownload {download} {disk}`), app found at the pinned version (`engineUseApp`, `engineSizeFromApp`), app found newer (`engineUntested`), downloading, a step, installed, installed not checked, update available, macOS too old. Picker: `XTypeGroup(extensions: ['dmg'], uniformTypeIdentifiers: [appBundleType])`, `initialDirectory: '/Applications'`. Dock note `engineNativeDock`.
- New bottle dialog (`new_bottle_dialog.dart:148-201`): Engine first of three `Expanded` dropdowns, shown only when Mach9 is usable, Native preselected; Graphics keyed `ValueKey('graphics ${state.runtime}')` with the chosen runtime's names; the info box follows the engine; the form scrolls if three dropdowns do not fit at 720×480. "Automatic" stays the only Automatic.
- Bottle column: Engine fact (`engineNativeChip` / `engineRosettaChip`); AVX and DLSS hidden for Mach9; Mono warning with "Install Wine Mono". Run with options (`run_options_dialog.dart:195-203`): AVX hidden for Mach9.
- Blocs: `BackendsBloc` gains `runtimes`, `installRuntime` events (file, app, download), `busy: 'mach9'`, the step, cancel through `cancelDownload`; `NewBottleBloc` gains `@Default(RuntimeKind.bodega) runtime`, `runtimeChanged` (resets graphics to auto), the step and the "made but Mono failed" outcome; `BottleDetailBloc` gains `installMono`.

## 8. Tests
- Engine (`cd ENG && fvm dart analyze && fvm dart test`): new `runtimes_test.dart` (MR, MB), `compatdb_test.dart` (MG golden strings), `mach9_test.dart` (environment, launches, choices, creation, Mono, install from a fake Mach9.app on Linux CI, a real DMG on macOS skipped elsewhere with "needs hdiutil", and an opt-in real import with `BODEGA_TEST_MACH9=/Applications/Mach9.app`); additions to `bundle_test` and `english_test` (41 failures, 8 unique LogHint markers, the new enums' English). Must stay green unedited: `engine_test` 94-129, 175-239, 241-343; `backends_test` 63-125, 127-261, 464-478, 510-578, 580-590; `options_test`, `apps_test`, `catalog_test`, `fixes_test`, `linux_test`, `switch_test`.
- App (`cd APP && fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter gen-l10n && fvm flutter analyze && fvm flutter test && tool/check_layers.sh`): `text_test` (dx9to11 first, then runtime words, errors, hints, steps, wine tool), `repository_call_test`, `step_mapper_test`, `host_codes_test`, data tests on `TestHome`, bloc tests, `pages_test` engine-card states at 720/801/1150/1921 in en and es, `new_bottle_dialog_test`, `l10n_parity_test` allowlist (Mach9, mtld3d, DXMT, vkd3d-proton, wined3d, Wine Mono, .NET). `setup_page_test` unchanged.
- Real checks: headless agent run (`specs/docs.md` MD6) and the USER checks (MD7).

## 9. Rules and docs
- Lines not to cross (new in `.claude/CLAUDE.md`): never re-sign, edit or move Mach9's tree; strip quarantine only from Bodega's own copy, never from the source; Mono goes only into prefixes; agents may run wineboot, `msiexec /qn` and the probe in Mach9 bottles, nothing else.
- Per-game data still comes only from highball-db; no CrossOver data and no anti-cheat hiding in rules.
- Docs: `README.md`, `.claude/CLAUDE.md:3`, `AGENTS.md:3`, `.claude/rules/architecture.md` (Host platform, 57-64), `wine/NOTICE.md` (`specs/docs.md`).

## 10. Delivery
Prologue J0 (this folder), then two streams that never edit the same file (engine owns `ENG/**`, `tool/package_macos.sh` and `spike.md`; app owns `APP/**`), joined by the verification stream (`tasks.md`). The bump to 1.7.0+15 happens once, in the join. Agents never commit or push; the user commits from a script beside the repo on `feat/mach9-runtime`, made with `git switch --no-track -c`, with no AI attribution (repo rule).
