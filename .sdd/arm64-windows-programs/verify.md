# Verify · arm64-windows-programs

Run on 2026-11-26, on Linux x86_64 (Arch, kernel 7.3.5), Dart 3.14.0, Flutter 3.47, on
`feat/arm64-windows-apps` from `main` at `5d2a9d4` (`v1.10.0`).

## The headless checks

| Check | Result |
|---|---|
| `cd packages/engine && dart analyze` | `No issues found!` |
| `cd packages/engine && dart test` | `514` passed, `13` skipped, none failed |
| `cd apps/bodega && flutter analyze` | no errors; `113` `info`, all the pre-existing `package:flutter/material.dart` deprecation of Flutter 3.47 (the same count as before this branch) |
| `cd apps/bodega && flutter test` | `1023` passed, `6` skipped, `9` failed |
| `cd apps/bodega && bash tool/check_layers.sh` | `Layers OK` |
| `tool/version.sh check` | `OK: version 1.11.0 (tag v1.10.0).` |

The nine failures are `test/data/update_repository_test.dart`, which calls `/usr/bin/shasum`
(`test/data/update_repository_test.dart:22`): macOS only, present since `79f772f`, and the same nine
before this branch.

## The new cases, as tests

- `backends_test.dart` (`exeGraphics and backendFits (G1, G3)`): `0xAA64` and `0xA641` are ARM64;
  `0x8664`, `0x14C`, a missing path and eight bytes of text are not.
- `engine_test.dart` (`an ARM64 program needs the native engine (AA1)`): a Rosetta bottle refuses
  `C:\Games\Arm64 Game.exe` and `C:\Games\ec.exe` with `ProgramNotForRuntime`, writes no log, and
  still runs `C:\Games\x64.exe` beside them.
- `mach9_test.dart` (`an ARM64 program runs on the native engine (AA1)`): a Native bottle launches
  `C:\Games\arm.exe`.
- `english_test.dart`: the failure is in the list (48) and its message keeps
  `bodega create --runtime mach9 <bottle>`.
- `text_test.dart` and `repository_call_test.dart`: the code and its mapping (45 codes, 43 failures),
  and `errProgramNotForRuntime` in both languages.
- `l10n_parity_test.dart`: the two ARBs hold the same keys, and `ARM64` is a name of the allowlist.
- `apps_test.dart`: `arm64Apps` gives the ARM64 and ARM64EC keys of a bottle, and not the x64 one.
- `bottle_repository_test.dart`: the detail's apps say which are ARM64.
- `add_app_bloc_test.dart` and `add_app_dialog_test.dart`: the chosen ARM64 program is marked, and the dialog's notice shows on the Rosetta engine only.
- `text_test.dart`: `programFactsText` in both languages, with and without the DirectX, on both engines.
- `backends_test.dart`: `programArch` and `probeProgram`'s two lines, and no DirectX for a program that names none.

## The probe, for real

Three files: an ARM64 PE naming `d3d11.dll`, an x64 one naming `d3d9.dll`, and eight bytes of text.

```
$ dart run bin/bodega.dart probe arm.exe
…/arm.exe: arm64, DX11
It runs only on the native engine (Mach9).
exit=0
$ dart run bin/bodega.dart probe x64.exe
…/x64.exe: x64, DX9
exit=0
$ dart run bin/bodega.dart probe junk.exe
…/junk.exe is not a Windows program
exit=1
```

## The launch refusal, for real

A temporary `BODEGA_HOME` with a fake `runtimes/current`, a bottle whose prefix is ready, and a
70-byte PE whose machine is `0xAA64`:

```
$ BODEGA_HOME=$home dart run bin/bodega.dart run t 'C:\Games\Arm64 Game.exe'
bodega: Arm64 Game.exe is an ARM64 Windows program, and Bodega's Wine (x86_64) cannot run it:
bodega create --runtime mach9 <bottle>, then add it there
exit=1
```

and `bottles/t/logs` stayed empty: nothing ran.

## Not done here

- **A real ARM64 Windows program:** none at hand. The header is what the engine decides on, and
  Wine's own half belongs to Mach9.
- **The app's error panel:** the words are tested through `AppError.localized` in both languages;
  no screenshot was taken.
