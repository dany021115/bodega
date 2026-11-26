# Proposal · arm64-windows-programs

## Why

Some Windows programs are built for Windows on ARM: their PE header says `0xAA64` (ARM64) or `0xA641` (ARM64EC). Only an arm64 Wine can load them, and Bodega has one: the Native engine (Mach9). Two things are wrong today:

1. **Bodega reads them as "not a PE on x86".** `_peBits` (`packages/engine/lib/backends.dart:996`) answers null for anything but `0x8664` and `0x14C`, so `exeGraphics` and `scanProgram` give null, `resolveBackend` falls to auto, and auto picks `wine` (`backends.dart:940`).
2. **The launch then fails inside Wine**, in a bottle on the Rosetta engine, with a message about a file that cannot be loaded. Nothing tells the user the program needs the other engine, and nothing says which one.

An ARM64 Windows program in a Native bottle already runs, since Mach9's Wine is aarch64: nothing else has to change.

## What

**In**
- **Engine:** `isArm64Program(path)` reads the PE machine (`0xAA64` or `0xA641`; a missing file and a non-PE are false), and `_launchIn` throws `ProgramNotForRuntime` before resolving a backend, when the launch is on the Rosetta engine. On the Native engine the launch goes ahead untouched.
- **App:** the new failure becomes `AppError.programNotForRuntime`, worded in both languages: the program, the Rosetta engine, and the two ways out (move the bottle to the Native engine, or add the program to a bottle on it).
- **Tests:** the machine field of a real PE stub, the refusal on the Rosetta engine, the launch on the Native engine, and the wording in both languages.

**Out (each its own change)**
- Compiling a Windows program to arm64: not possible from a binary, and not needed, since FEX runs x86 and x64 inside an arm64 Wine.
- Preferring a game's native macOS version when `nativeMac` is true in the catalog data: the app shows the fact today; opening it needs a path Steam owns.
- Shader cache pre-warming, and Bodega's own arm64 engine line (`wine/README.md:106`), which needs an engine build and a loader.

## Decisions

| # | Question | Decision | Reason |
|---|---|---|---|
| A1 | Where is the program's architecture read? | `isArm64Program` beside `_peMachine`, exported | The header is the only truth; the catalog says nothing about a program's architecture |
| A2 | What about ARM64EC? | Treated as ARM64 (`0xA641`) | It is an arm64 image; only an arm64 Wine loads it |
| A3 | Where does the refusal happen? | In `_launchIn`, after `_programPaths`, before `resolveBackend` | Every launch goes through it (CLI `run`, the library, installers), and wine builtins carry no path |
| A4 | A missing file? | Not ARM64: the check is about a header, and a missing exe fails later as today | Keeps `C:\Games\Game.exe` lookups that end in nothing behaving as before |
| A5 | What does the app show? | One error, no new screen: the program's name and the two ways out | The refusal is rare; a dialog would need state the app does not keep |
| A6 | Version | 1.11.0+20, a minor bump | New behaviour, no data format change |

## Impact

- **Engine:** `backends.dart` (`isArm64Program`), `engine.dart` (`_launchIn`), `failures.dart` (one failure), `english_test`'s exhaustive list (48 failures) and hint.
- **App:** `app_error.dart`, `repository_call.dart`, `error_text.dart`, the two ARBs, `text_test` (45 codes), `repository_call_test` (43 failures).
- **Users:** a Native bottle runs ARM64 Windows programs; a Rosetta bottle says why it cannot.
- **Compatibility:** nothing on disk changes; `settings.json`, `apps.json` and the runtimes are untouched.

## Risks

| Risk | Mitigation |
|---|---|
| A misread header refuses a working program | Only two machine values count, the file must exist, and x86/x64 are unaffected |
| An ARM64 program relies on x64 code Mach9's FEX does not provide | The program has ARM64EC on its side, or it fails inside Wine as it would in Mach9.app |
| The message promises a fix no bottle delivers | It names the two actions the app has: move the bottle, or a Native bottle |

## Version
1.11.0+20 (`tool/version.sh bump minor`).
