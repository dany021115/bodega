# Spec · Runtimes

Requirements MR1..MR13: runtime kinds, availability, the Mach9 and Wine Mono pins, installing and updating Mach9, and the engine contract shared with the app (`design.md` §1–§3). `ENG` is `packages/engine/`. **The test Mac** is `useMac()` with `hostPlatform` a `TestMac(...)` (`ENG/test/_mac.dart`), `<tmp>` the test's temporary folder and `home` the data root `<tmp>/bodega`. **The fake Mach9.app** is `<tmp>/Applications/Mach9.app` with an XML `Info.plist` (`CFBundleIdentifier` `app.mach9`, `CFBundleShortVersionString` `0.4.0`, `LSMinimumSystemVersion` `26.4`) and `Contents/Resources/wine` holding design §2.1's files as scripts (`bin/wine` a relative symlink into `lib/wine/aarch64-unix/wine.app/Contents/MacOS/wine`, which prints `wine-11.21-test`).

## MR1 · Two runtime kinds
The engine shall know `RuntimeKind {bodega, mach9}`, each with an English name, and `listRuntimes(home)` shall give one `RuntimeInfo` per kind the host knows: bodega alone on Linux, bodega then mach9 on the Mac. For mach9 it fills `installed`, `id` (the folder `runtimes/mach9` points at), `version` (from `runtime.json`), `checked` (`version == mach9Release.version`), `blocked` (MR2) and `app` (MR4's `findMach9App`, plist read only, no codesign). For bodega, `version` is null and `checked` true.
- **Given** a Linux host, **when** `listRuntimes` runs, **then** it gives one entry, bodega. (test)
- **Given** the test Mac with `mach9-0.5.0` installed, **then** the mach9 entry has `installed: true`, `version: '0.5.0'`, `checked: false`. (test)
- **Given** the fake Mach9.app under the test Mac's `applications`, **then** `app` is `(path: <tmp>/Applications/Mach9.app, version: '0.4.0')`. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`.

## MR2 · Where Mach9 can run
`HostPlatform.mach9Block` shall be null only on a Mac where `sysctl -n hw.optional.arm64` prints 1 and `sw_vers -productVersion` is 26.4 or later, computed once; else `appleSiliconOnly` or `macosTooOld`; Linux gives `notThisHost`. Install, create and launch on a blocked host throw `RuntimeUnavailable(mach9, reason)`. The Rosetta host check (`needsHost`) and `HostCapabilities` shall not change.
- **Given** `TestMac(mach9Block: RuntimeBlock.macosTooOld)`, **then** the mach9 entry has `blocked: macosTooOld`, and `installMach9` and `createBottle(runtime: mach9)` throw `RuntimeUnavailable` with that reason. (test)
- **Given** this Mac (macOS 27.2.1, arm64), **then** `MacPlatform().mach9Block` is null. (headless V2)
- **Check:** `fvm dart test test/runtimes_test.dart test/mach9_test.dart`; `git diff -- packages/engine/lib/platform.dart` leaves `HostCapabilities` as it is.

## MR3 · The release pin
`mach9Release` shall hold the Mach9 pin (v0.4.0, `https://github.com/athei/mach9/releases/download/v0.4.0/Mach9.dmg`, sha256 `3b5dd83ee7b08d55e6c4a84dabb32db994dc6a5bfb2a1500fb50d0b45436e6d9`, file `Mach9-0.4.0.dmg`, bundle id `app.mach9`, team `WLKUUJD25W`, minimum version 0.4.0, minimum macOS 26.4) and, in the same record, the Wine Mono pin (11.3.0, `https://dl.winehq.org/wine/wine-mono/11.3.0/wine-mono-11.3.0-x86.msi`, sha256 `df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3`), so a Mach9 bump re-checks Mono against the new `appwiz.cpl`. Tests may replace it, as they replace `fixesSource`; the app only reads it.
- **Given** the shipped engine, **then** both sha256 values are as above and both URLs are HTTPS. (test)
- **Given** a Mach9 pin bump, **when** `strings lib/wine/aarch64-windows/appwiz.cpl` (or the i386 one) of the new tree is searched, **then** it holds the Mono sha256 of the record. (headless V2)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MR4 · Sources
`installMach9(home, {source, pinned, mono, onStep, cancelled})` shall take a `.dmg` or a `.app` as `source`; with none, the Mach9.app that `findMach9App()` finds in `hostPlatform.applicationDirs` when its version equals the pin, else the pinned DMG downloaded to `downloads/Mach9-0.4.0.dmg`. `pinned: true` means the caller downloaded the pinned DMG, whose sha256 must then match (`ChecksumMismatch`). The release tarball is never a source. The MSI is `mono` or downloaded, and its sha256 is always checked, before any copy.
- **Given** the fake Mach9.app and no `source`, **then** it installs from the app with `runtime.json` `source: app`. (test)
- **Given** an MSI whose hash differs, **then** `ChecksumMismatch` before any copy, and no `.tmp-*` is left. (test)
- **Given** a DMG made with `hdiutil create -srcfolder` around the fake app, **then** it installs and no mount is left. (test, macOS only; skipped elsewhere with "needs hdiutil")
- **Check:** `fvm dart test test/mach9_test.dart`.

## MR5 · Trust of what was copied
Before copying, the source app's plist shall have bundle id `app.mach9` and a version ≥ 0.4.0 (else `RuntimeTooOld(version, '0.4.0')`) and `LSMinimumSystemVersion` no higher than the host's. The whole app is copied, and its copy shall have `signingTeam(copy, deep: true)` equal to `WLKUUJD25W` (`codesign --verify --deep --strict` on the whole copied Mach9.app, then `codesign -dv`) and the same version, else `RuntimeNotTrusted(source, reason)`: a source `.app` can change during the copy, so the check is on the copy, whose seal covers every file. Bodega never signs anything of Mach9's.
- **Given** `TestMac(team: 'XXXXXXXXXX')` or a bundle id `com.other`, **then** `RuntimeNotTrusted`. (test)
- **Given** a source whose `aarch64-windows/kernel32.dll` changes while it is copied (a TestMac whose deep check rejects the changed file), **then** `RuntimeNotTrusted` and nothing left. (test)
- **Given** version 0.3.1, **then** `RuntimeTooOld('0.3.1', '0.4.0')`; **given** 0.5.0, **then** it installs with `checked: false`. (test)
- **Given** a copy of `/Applications/Mach9.app` with one byte changed in a file outside `wine.app`, **then** `MacPlatform().signingTeam(copy, deep: true)` throws. (headless V2)
- **Check:** `fvm dart test test/mach9_test.dart`; `grep -nE "codesign[^\n]*(--force|--sign|-s )" packages/engine/lib/mach9.dart packages/engine/lib/runtimes.dart` prints nothing.

## MR6 · Copied unmodified, then checked
The app shall be copied by `hostPlatform.copyTree` (Mac: `/usr/bin/ditto --noqtn`; Linux and TestMac: `cp -a`) into `runtimes/.tmp-mach9-<v>/Mach9.app`, checked (MR5), and its `Contents/Resources/wine` renamed to `runtimes/.tmp-mach9-<v>/engine`, the rest deleted. Nothing shall then write, sign, strip, edit or move anything under `engine/` (I3), nor touch the source or its quarantine. After that: design §2.1's required files exist, `bin/wine` is still a symlink, `signingTeam` (verify only) passes on `wine.app`, `bin/wineserver`, `aarch64-unix/ntdll.so` and `compatdb.so`, and `bin/wine --version` starts with `wine-` (else `ProcessFailed`).
- **Given** the fake app without `lib/wine/d3d9/mtld3d`, **then** `IncompleteArchive`, with no `.tmp-*` and no link left. (test)
- **Given** a successful install, **then** `engine/bin/wine` is a symlink. (test)
- **Given** a real install from `/Applications/Mach9.app`, **then** `codesign --verify --strict` passes on the copied `wine.app` and `wine --version` starts with `wine-11.21`. (test, opt-in `BODEGA_TEST_MACH9`; headless V2)
- **Check:** `fvm dart test test/mach9_test.dart`; `grep -nE "xattr|writeAsString|copySync" packages/engine/lib/mach9.dart` shows no write under `engine/`.

## MR7 · Layout and links
A successful install shall leave `runtimes/mach9-<v>/{engine/, wine-mono-11.3.0-x86.msi, runtime.json}` (`{"kind":"mach9","version":"<v>","source":"app|dmg|download","checked":<bool>}`) and point `runtimes/mach9` at `mach9-<v>`, switched atomically before the DMG is detached; `runtimes/current` shall never move because of Mach9 (I2). `AlreadyInstalled` when the link already names `mach9-<v>`; a `mach9-<v>` it does not name (an install killed before the link) is not installed and is replaced.
- **Given** an existing `current`, **when** Mach9 installs, **then** `current` resolves to the same folder before and after. (test)
- **Given** 0.4.0 installed, **when** 0.4.0 installs again, **then** `AlreadyInstalled`. (test)
- **Given** `mach9-0.4.0` with no link and a `.tmp-mach9-0.4.0` left over, **when** 0.4.0 installs, **then** it succeeds and only `mach9` and `mach9-0.4.0` remain. (test)
- **Given** two installs of the same version at once, **then** one installs and the other is `AlreadyInstalled`; across processes, a held `runtimes/.mach9.lock` makes an install wait. (test; headless)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MR8 · Updating
Installing a newer version shall be the same call. It shall throw `BottleOpen` when a Mach9 bottle runs, checked before copying and again before switching, then switch the link and delete the `mach9-*` folders the link does not name, except one a Mach9 bottle still runs on (opened between the second check and the switch), which the next install deletes. No `runtime use` or `runtime remove` in v1.
- **Given** 0.4.0 installed, **when** 0.5.0 installs, **then** `runtimes/mach9` points to `mach9-0.5.0` and `mach9-0.4.0` is gone. (test)
- **Given** a Mach9 bottle whose fake `wineserver -w` hangs, **then** `BottleOpen` before the copy starts. (test)
- **Given** a bottle that opens on 0.4.0 after the second check, **when** 0.5.0 installs, **then** `mach9-0.4.0` stays; **when** 0.6.0 installs after it closes, **then** only `mach9-0.6.0` remains. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MR9 · Failure and cancel leave nothing
Every failure or `cancelled()` returning true (`Cancelled`) shall leave no `.tmp-*`, no changed link and no mounted volume (I6); `runtimes/.mach9.lock` stays (an empty file). An install killed midway is cleaned by the next one (MR7). The data layer deletes only the files it downloaded itself, and only after a failure about a file (`ChecksumMismatch`, `RuntimeNotTrusted`, `IncompleteArchive`).
- **Given** `cancelled` true after `copying`, **then** `Cancelled`, and `runtimes/` is as before. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MR10 · Resolving a kind's folder
`runtimeDir(home, kind)` shall return the resolved link: bodega throws `NoRuntime` as `currentRuntime` does; mach9 throws `RuntimeNotInstalled(mach9)` when `runtimes/mach9` is missing or dangling.
- **Given** no `runtimes/mach9`, or one pointing nowhere, **then** `RuntimeNotInstalled`. (test)
- **Check:** `fvm dart test test/runtimes_test.dart`.

## MR11 · HostPlatform seams
`HostPlatform` shall gain `mach9Block`, `signingTeam(path, {deep})`, `copyTree(from, to)` and `applicationDirs` (Mac: `/Applications`, `$HOME/Applications`; Linux: `[]`). `TestMac` gains `{mach9Block, team = 'WLKUUJD25W', applications}`, copies with `cp -a`, and its `signingTeam` returns `team` or throws `RuntimeNotTrusted` when it is null; `const TestMac()` compiles everywhere it is used today, and `NoHost` (`switch_test.dart`) still compiles.
- **Given** the existing engine tests, **then** they pass unedited (design §8). (test)
- **Check:** `fvm dart analyze && fvm dart test` in `ENG`.

## MR12 · Never bundled
Mach9 shall never be copied into Bodega.app. `tool/package_macos.sh`'s runtime loop (`:138-143`) shall skip `current|mach9|mach9-*|.tmp-*`, and `bodegaHome`/`_registerBundled` shall leave `runtimes/mach9*` untouched.
- **Given** a home with `runtimes/mach9` and `mach9-0.4.0`, **when** `bodegaHome` runs with a bundle, **then** both are unchanged. (test, `bundle_test`)
- **Check:** `grep -n 'mach9' tool/package_macos.sh` shows the skip; `fvm dart test test/bundle_test.dart`.

## MR13 · The shared contract
`package:engine/engine.dart` shall export design §3.1–§3.2 in one step (E1), through two new parts `runtimes.dart` and `mach9.dart` added to `engine.dart:14-24`, so the app's data layer can build on it while the rest of the engine lands.
- **Given** E1, **then** the app's A6 compiles against it, and every type, enum value, failure and signature of design §3.1–§3.2 exists. (test)
- **Check:** `fvm dart analyze` in `ENG` and `APP`.
