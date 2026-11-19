# Spec · Bottles

Requirements MB1..MB10: the stored and effective runtime of a bottle, every bottle operation on its own runtime, Mach9 bottle creation, its registry values, Wine Mono and the catalog (`design.md` §1, §3, §5). Terms as in `runtimes.md`. **A fake Mach9 runtime** is `runtimes/mach9-0.4.0/engine` with `bin/wine` and `bin/wineserver` scripts that log their calls to `$WINEPREFIX/../mach9-calls`, and `runtimes/mach9` pointing at it.

## MB1 · The runtime in settings.json
`BottleSettings` shall gain `runtime`. `_settings` reads a missing key as bodega and an unknown value as `CorruptData` wrapping `BadChoice(ChoiceKind.runtime, …)`; `_saveSettings` writes `"runtime":"mach9"` only for Mach9 bottles, so a file without the key is written back byte for byte (I1).
- **Given** `"runtime":"mach9"`, **when** each of `setBackend`, `setSync`, `setBottleOptions`, `setHighRes`, `setBottleUser`, `setWindowsVersion`, `setAppHud` and `installEntry` into that bottle runs, **then** the key survives. (test)
- **Given** a legacy settings.json, **when** each of those saves runs with its current value, **then** the file is byte for byte the same. (test)
- **Given** `"runtime":"arm"`, **then** `bottleSettings` throws `CorruptData`. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`.

## MB2 · The prefix has the last word
`bottleRuntime(home, name)` shall read the PE machine of `drive_c/windows/system32/kernel32.dll`: 0xAA64 gives mach9, 0x8664 or 0x14C bodega; a missing, empty or short file falls back to the stored value. It reads files only, so it is safe inside `Isolate.run`. `BottleInfo.runtime` is this effective kind. Wine of one architecture shall never run a prefix of the other (I4).
- **Given** a kernel32 stub with machine 0xAA64 and no key, **then** mach9; **given** 0x8664 and `"runtime":"mach9"`, **then** bodega; **given** an empty file, **then** the stored value. (test)
- **Given** the existing tests' fake wineboot, which writes only `syswow64/kernel32.dll`, **then** every bottle stays bodega. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`.

## MB3 · Every operation on the bottle's runtime
`_launchIn`, `createBottle`, `waitBottle`, `stopBottle`, `removeBottle`, `renameBottle`, `_serverRunning`, `_steamRunning` (`fixes.dart:136`) and `installEntry` (`catalog.dart:124`) shall use `runtimeDir(home, bottleRuntime(home, name))`. Stop and wait on a Mach9 bottle without its runtime return 0; remove deletes it without running `-k`.
- **Given** a Mach9 bottle and the fake Mach9 runtime, **when** each of those runs, **then** the calls reach `mach9-calls` and none reaches `current`'s fake. (test)
- **Given** a Mach9 bottle and no Mach9 runtime, **then** stop and wait return 0, remove deletes the folder, and a launch throws `RuntimeNotInstalled`. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`; `grep -n 'currentRuntime(' packages/engine/lib/*.dart` lists only `installRuntime`, SDL and `hasRuntime` uses.

## MB4 · Host preparation by kind
`hostPlatform.prepareBottle` calls (`engine.dart:200, 217, 659`, `apps.dart:385`) shall go through `_prepareBottle`, which does nothing for Mach9 bottles (no WineBus values, no x86 SDL). `_syncSdl` and `installSdl` shall do nothing when `current` has no `x86_64-unix`.
- **Given** a Mach9 bottle, **when** it launches, **then** `reg.log` has no WineBus line. (test)
- **Given** `current` without `x86_64-unix`, **then** `bodegaHome` does not throw. (test, `bundle_test`)
- **Check:** `fvm dart test test/runtimes_test.dart test/bundle_test.dart`.

## MB5 · Creating a Mach9 bottle
`createBottle(home, name, {runtime, mono = true, onStep})` with mach9 shall check the host (`RuntimeUnavailable`) and the runtime (`RuntimeNotInstalled`), write settings.json with `"runtime":"mach9"` before wineboot, run wineboot and `wineserver -w` as today, write MB6's registry values, then install Mono unless `mono` is false, reporting `BottleStep.prefix` then `mono`. A bodega `createBottle` is unchanged.
- **Given** the fake Mach9 runtime, **when** the fake wineboot runs, **then** settings.json already holds `runtime: mach9`. (test)
- **Given** `onStep`, **then** it receives `prefix`, then `mono`; with `mono: false`, only `prefix`, and no `msi-args`. (test)
- **Given** this Mac and the real runtime, **when** `bodega create --runtime mach9 m9t` runs, **then** it finishes and is timed. (headless V3)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MB6 · Registry values of a Mach9 prefix
At creation a Mach9 bottle shall get `HKCU\Software\Wine\WineDbg` `ShowCrashDialog` REG_DWORD 0 and `HKCU\Software\Wine\X11 Driver` `EmulateModeset` REG_SZ `Y`, through `reg add` with `backend: 'wine'`.
- **Given** a Mach9 creation, **then** `reg.log` holds both, and no WineBus value. (test)
- **Given** the real `m9t`, **then** `user.reg` holds both values. (headless V3)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MB7 · Wine Mono in each Mach9 prefix
`installMono(home, name)` shall run `msiexec /i <runtimes/mach9/wine-mono-11.3.0-x86.msi> /qn` in the bottle (re-downloading the MSI when it is missing, the only network use, I5), accept `_installerOk` {0,102,194,105}, else run `wineserver -k` and throw `WineToolFailed(WineTool.mono, code, log)` (code -1 after 10 minutes), and throw `InstallerNoExe` when it exits well but `drive_c/windows/mono/mono-2.0` is missing. It returns null for a bodega bottle or when Mono is present. The bottle stays after a failure.
- **Given** a fake MSI that exits 3, **then** `WineToolFailed(mono)` after `-k`, and the bottle exists. (test)
- **Given** one that exits 0 and leaves no `mono-2.0`, **then** `InstallerNoExe`. (test)
- **Given** a Mach9 creation, **then** `msi-args` is `/i <rt>/wine-mono-11.3.0-x86.msi /qn`. (test)
- **Given** the real `m9t`, **then** `drive_c/windows/mono/mono-2.0` exists. (headless V3)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MB8 · A missing Mono is shown, never fixed silently
`monoMissing(home, name)` shall be true only for a Mach9 bottle without `drive_c/windows/mono/mono-2.0`. No launch installs Mono; the user gets the app's warning (MA7), `bodega mono install` (MC4) and the `monoMissing` log hint (MG11).
- **Given** a Mach9 bottle without the folder, **then** true; with it, or a bodega bottle, false. (test)
- **Given** a Mach9 bottle without Mono, **when** a program launches, **then** no `msiexec` runs. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MB9 · The catalog
`installEntry(home, entry, {runtime = bodega})` shall create new bottles of `runtime` and use an existing bottle's own kind; `mapBackendFor(mach9, name)` gives wine for wine and auto otherwise, and auto is stored as no exception (null); installers run with `backend: 'auto'` on Mach9; Mono is installed for a new Mach9 bottle with the step `InstallStepKind.installingMono`. New catalog bottles stay bodega in the app until M3.
- **Given** an entry whose backend is dxmt and an existing Mach9 bottle, **then** no exception is stored for its exe. (test)
- **Given** `runtime: mach9` and a new bottle, **then** the steps include `creatingBottle`, `installingMono`, `runningInstaller` in that order. (test)
- **Check:** `fvm dart test test/mach9_test.dart test/catalog_test.dart`.

## MB10 · No network after install
Bottle creation and launches shall use no network, except MB7's re-download of a missing MSI (I5).
- **Given** a Mach9 runtime with its MSI, **when** a bottle is created and a program launched with `_download` replaced by one that throws, **then** both succeed. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.
