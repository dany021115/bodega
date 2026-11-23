# Spec · Engine and CLI

Requirements DE1..DE12: the engine's runtimes, program reading, proposals, installs, Bodega's own fixes and the `ini` step, and their CLI verbs (`design.md` §1–§7). `engine/` is `packages/engine/`, where `dart test` and `dart run bin/bodega.dart` run. **The test home** is a temporary `BODEGA_HOME` with a fake runtime and the fake Wine of `engine_test.dart`; **the bottle** is a ready bottle `b` in it. **The fake installer** is a local file whose SHA-256 the test pins in place of the real one, and which the fake Wine "runs" by writing a file without Wine's mark at the marker the test names, and exiting with the code the test sets.

## DE1 · One part, one data file, generated data untouched
The engine shall hold the change in `engine/lib/dependencies.dart` (a `part`), `engine/lib/bodega_fixes_data.dart` (a library, hand-written), and edits to `fixes.dart`, `failures.dart`, `english.dart`'s tests and `bin/bodega.dart`. `fixes_data.dart` and `tool/import_fixes.py` shall not change.
- **Given** the branch, **when** `git diff --stat <base> -- packages/engine tool` runs, **then** it lists no `fixes_data.dart` and no `import_fixes.py`.
- **Check:** that command.

## DE2 · The runtime table
`const dependencies` shall hold the six rows of `design.md` §2, in that order, with their URLs, SHA-256, sizes, file names (`<id>-<arch>.exe`), arguments, DLLs, markers, imports and `windows`, and a comment naming where the pins come from (winetricks `20260125-next`, LGPL-2.1-or-later, by function name; highball-db `recipes/tweaks/vcrun2022.json` at `7a008d5`, CC0), with no code copied.
- **Given** `dependencies`, **then** the test reads the six ids in order, every URL starts with `https://download.microsoft.com/` or `https://download.visualstudio.microsoft.com/`, every SHA-256 is 64 lowercase hex characters, and `vcrun2008`'s x86 file is `(…/5D8C65CB-…/vcredist_x86.exe, 8742bcbf…d92, 4483040, vcrun2008-x86.exe, [/q])`.
- **Given** `BODEGA_NETWORK_TESTS=1`, **when** the network test runs, **then** each of the twelve files downloads with its pinned size and SHA-256; without the variable it is skipped.
- **Check:** `dart test test/dependencies_test.dart`; once, `BODEGA_NETWORK_TESTS=1 dart test test/dependencies_test.dart`, output pasted in `verify.md`.

## DE3 · Installed is read from the bottle
`dependencyInstalled(home, bottle, id, arch)` shall be true only when the row's marker resolves (the `*` folder matched without case among real folders, no link followed) to a regular file that starts with `MZ` and whose first 128 bytes hold neither `Wine builtin DLL` nor `Wine placeholder DLL`. `bottleDependencies(home, bottle)` gives the twelve `(id, arch, installed)`.
- **Given** the bottle with Wine's own `msvcr90.dll` (the mark in its first bytes) in `windows/winsxs/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_deadbeef/`, **then** `vcrun2008 x86` is not installed; with a file there without the mark it is; with the folder named `x86_Microsoft.VC90.CRT_1fc8b3b9a1e18e3b_9.0.30729.6161_x-ww_d08d0375` it still is.
- **Given** the folder replaced by a link to a real folder holding such a file, **then** it is not installed; **given** a file there that does not start with `MZ`, **then** it is not installed.
- **Check:** `dart test test/dependencies_test.dart`.

## DE4 · Reading a program
`scanProgram(path)` shall return `(bits, imports, assemblies, besideIt)` as `design.md` §3 says, in another isolate, reading only headers and import tables, and null for a file that is not a PE for x86 or x86-64.
- **Given** a PE32 fixture importing `KERNEL32.dll` and `MSVCR90.dll`, delay-loading `mfc90u.dll`, with a manifest naming `Microsoft.VC90.CRT`, beside `binkw32.dll`, **then** the scan is `(32, {kernel32.dll, msvcr90.dll, mfc90u.dll}, {microsoft.vc90.crt}, {binkw32.dll})`.
- **Given** a PE32+ fixture importing `VCRUNTIME140.dll`, **then** `bits` is 64 and `imports` holds `vcruntime140.dll`.
- **Given** a fixture whose import table points past the end of the file, **then** the scan returns what it read before that point and throws nothing; **given** a text file or an ARM64 PE, **then** null.
- **Given** a 300 MB file made of a fixture's headers and zeros, **then** the scan reads fewer than 1 MB of it (counted by the test through a wrapper, or timed under one second).
- **Check:** `dart test test/dependencies_test.dart`.

## DE5 · Proposals
`appNeeds(home, bottle, key)` shall work out each app's needs by `design.md` §4's table, every time, storing nothing.
- **Given** Blur's fixture (`blur.exe`, PE32, importing `msvcr90.dll`) registered in the bottle and Bodega's `blur` fix, **then** its needs are one dependency `(vcrun2008, x86, recommended, knownFix, fix: blur, installed: false)` and no setting.
- **Given** a PE32 `tool.exe` importing `mfc100.dll` and `msvcr100.dll`, **then** one need `(vcrun2010, x86, recommended, notInWine, dll: mfc100.dll)`; **given** it imports only `msvcr100.dll`, **then** `(vcrun2010, x86, optional, imported, dll: msvcr100.dll)`; **given** `msvcr100.dll` also beside it, **then** no need.
- **Given** a PE32+ importing `vcruntime140.dll`, **then** `(vcrun2022, x64, optional, imported)`.
- **Given** a need whose runtime is installed (DE3), **then** it stays, with `installed: true`.
- **Given** a Steam game key, **then** no file is read for it and its needs come from fixes only.
- **Given** `nfs13.exe` registered and the `need-for-speed-most-wanted-2012` fix on the Mac host, **then** its needs hold one setting `(need-for-speed-most-wanted-2012, Sound, Reverb, 0, <state>)` (DE9); on the Linux host none.
- **Check:** `dart test test/dependencies_test.dart`.

## DE6 · Installing a runtime
`installDependency(home, bottle, id, arch, {file})` shall follow `design.md` §5's ten steps.
- **Given** the fake installer for `vcrun2008 x86`, **when** it installs, **then** the fake Wine got the installer with `/q`, then `reg add HKCU\Software\Wine\DllOverrides /v <dll> /t REG_SZ /d native,builtin /f` for `atl90`, `msvcm90`, `msvcp90`, `msvcr90` and `vcomp90`, in that order, and `dependencyInstalled` is true; the returned log is the installer's, labelled `vcrun2008-x86`.
- **Given** `vcrun2022 x86`, **then** a `reg add HKCU\Software\Wine\AppDefaults\<the installer's file name> /v Version /d win10` ran before the installer.
- **Given** an installer whose SHA-256 differs from the pin, **then** `ChecksumMismatch`, and nothing ran in the bottle.
- **Given** the installer exits 1, **then** `WineToolFailed(WineTool.installer, 1, log)`, and no `reg add DllOverrides` ran; **given** it exits 3010, **then** it counts as done.
- **Given** it exits 0 but writes no marker, **then** `DependencyNotInstalled(vcrun2008, x86, log)`.
- **Given** the bottle's wineserver running, **then** `BottleOpen(b)` before anything else; **given** `vcrun2099` or `arm64`, **then** `BadChoice(ChoiceKind.dependency, …)`.
- **Given** no `file`, **then** the installer comes from `_download` into `downloads/vcrun2008-x86.exe` (a `file://` URL in the test, as `_download` admits for tests), and a second install reuses it without fetching.
- **Given** Wine's own `x86_microsoft.vc90.crt_…_deadbeef.manifest` and `x86_microsoft.vc90.atl_…_deadbeef.manifest` in `winsxs/manifests`, **when** vcrun2008 x86 installs, **then** the installer runs with neither there, and after a good install `bottles/b/wine-manifests/` holds nothing; **when** the installer exits 1, **then** both are back in `winsxs/manifests` as they were.
- **Given** the fake wineserver busy for 2 seconds after the last `reg` (its `hang` file, removed by a timer), **then** `installDependency` returns only once it is idle, and a second install right after does not throw `BottleOpen`.
- **Check:** `dart test test/dependencies_test.dart`.

## DE7 · Bodega's own fixes
`bodega_fixes_data.dart` shall hold the two entries of `design.md` §6, and `gameFixes()` shall return the generated ones, then Bodega's.
- **Given** `gameFixes()`, **then** it holds the 18 generated fixes, then `blur` and `need-for-speed-most-wanted-2012`; a Bodega entry repeating a generated id makes it throw `CorruptData`.
- **Given** `fixForApp('/users/x/games/blur/blur.exe')`, **then** the `blur` fix; `fixForApp('steam:19680')` gives `alice-madness-returns` as today; a key whose file name no fix lists gives null.
- **Given** `GameFix.active` of the NFS fix, **then** it is empty, so a launch of `nfs13.exe` applies nothing and its log is as before.
- **Check:** `dart test test/fixes_test.dart` (new cases) and the existing fix tests unchanged.

## DE8 · The `ini` edit
`setIniValue(text, section, name, value)` shall change one key as `design.md` §6 says.
- **Given** `"[Display]\r\nWidth=2048\r\n[Sound]\r\nMusicVolume=8\r\nReverb=1\r\n[Gameplay]\r\n"`, **then** the result differs from it only in `Reverb=0`.
- **Given** `[sound]` and `reverb=1` in lower case, **then** the value changes; **given** LF line ends, **then** LF stays; **given** no `Reverb` in `[Sound]`, **then** `Reverb=0` follows the section's last line; **given** no `[Sound]`, **then** `[Sound]` and `Reverb=0` end the text, with its line end.
- **Given** a byte `0xE9` elsewhere in the file, **then** it is the same byte after the write.
- **Check:** `dart test test/fixes_test.dart`.

## DE9 · Applying a fix's settings
`fixSettingState(home, bottle, fix)` and `applyFixSettings(home, bottle, fixId)` shall resolve `%USERPROFILE%`, guard links and write as `design.md` §6 says, for the host's own `ini` steps.
- **Given** the bottle's profile `Documents` a link to `<tmp>/home/Documents` (the host's `HOME` in the test env) holding the NFS file with `Reverb=1`, **then** the state is `notApplied`; after `applyFixSettings`, the file holds `Reverb=0`, the state is `applied`, and no temporary file is left.
- **Given** no such file, **then** the state is `noFile` and `applyFixSettings` throws `MissingFile` with its path.
- **Given** the link pointing outside both the bottle and `HOME`, **then** `UnexpectedLink` and the file is unchanged.
- **Given** the bottle's wineserver running, **then** `BottleOpen`.
- **Given** a fix with no `ini` step for this host, **then** `applyFixSettings` does nothing.
- **Check:** `dart test test/fixes_test.dart`.

## DE10 · Failures
`DependencyNotInstalled(id, arch, log)` ("the installer of <id> (<arch>) finished, but Microsoft's files are not in the bottle: see <log>") and `UnexpectedLink(path)` ("a link in <path> leads outside the bottle and the home folder") shall be final `EngineFailure` subclasses with those English messages, and `ChoiceKind.dependency` shall read `dependency`.
- **Check:** `dart test test/english_test.dart` (one case each, message and `toString()`).

## DE11 · CLI
`bodega deps list|check|install` and `bodega fix apply` shall do what `design.md` §7 says, with usage lines, behind the host and runtime gate like `open`. The `deps` verbs are `depsVerb(args, out)` in the engine, which returns the work or null for a bad usage and writes its lines to `out`, as `switchVerb` does.
- **Given** `depsVerb`, **then** `['list', 'b']`, `['check', 'b', 'k']`, `['install', 'b', 'vcrun2008', 'x86']` and `['install', 'b', 'vcrun2008', 'x64', '/f.exe']` parse; `['install', 'b', 'vcrun2008']`, `['install', 'b', 'vcrun2008', 'arm64']` and `['nope']` give null, for which the CLI prints the usage and exits 64.
- **Given** the test home, **then** the `deps list` lines are twelve, each `<id> <arch> installed` or `<id> <arch> not installed <size> MB`; given Blur's fixture registered, the `deps check` line is `recommended vcrun2008 x86 (fix blur)`.
- **Given** a real scratch bottle (DN4), **when** `build/bodega deps list`, `deps check`, `deps install` and `fix apply` run, **then** they do what DE3, DE5, DE6 and DE9 say, output pasted in `verify.md`.
- **Check:** `dart test test/dependencies_test.dart`; DN4's run.

## DE12 · Everything green
- **Check:** `dart analyze && dart test` in `engine/`, output pasted in `verify.md`.
