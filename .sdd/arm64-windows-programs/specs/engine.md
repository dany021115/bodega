# Spec · the engine

Requirements AA1..AA2. `ENG` is `packages/engine/`; every check is `cd ENG && dart analyze && dart test`.

## AA1 · An ARM64 program is told apart

`isArm64Program(path)` shall be true when the file's PE machine is `0xAA64` or `0xA641`, and false for `0x8664`, `0x14C`, a file that is not a PE, and a path where nothing exists. It reads the header only, never the body.

- **Given** `fakePe(path, 0xAA64, '')` and `fakePe(path, 0xA641, '')`, **then** true.
- **Given** `0x8664`, `0x14C`, eight bytes of text, or a path with no file, **then** false.
- **Check:** `dart test test/backends_test.dart` (`exeGraphics and backendFits (G1, G3)`).

## AA2 · The Rosetta engine refuses it, the Native engine runs it

`_launchIn` shall throw `ProgramNotForRuntime(<the exe's file name>, <the bottle's kind>)` after `_programPaths` and before resolving a backend, when the launch's bottle is on the Rosetta engine and `scan` is a path. Nothing shall be logged, since nothing ran. On the Native engine the same program shall launch as any other, and x86 and x64 programs shall keep launching on either engine.

`ProgramNotForRuntime.message` shall be English, name the program and the engine, and keep the command that unblocks it:

```
bodega create --runtime mach9 <bottle>
```

- **Given** a Rosetta bottle with `C:\Games\Arm64 Game.exe` (`0xAA64`), **then** `ProgramNotForRuntime` with `program` `Arm64 Game.exe` and `runtime` `bodega`, and the bottle's `logs/` holds no new file.
- **Given** the same bottle and an ARM64EC exe, **then** the same failure.
- **Given** the same bottle and an x64 exe beside them, **then** it runs as today.
- **Given** a Native bottle and an ARM64 exe, **then** it launches.
- **Given** the shipped engine, **then** `english_test`'s list holds the failure once and its message contains the hint above.
- **Check:** `dart test test/engine_test.dart test/backends_test.dart test/mach9_test.dart test/english_test.dart`.

## AA3 · The ARM64 programs of a bottle are listed

`arm64Apps(home, bottle)` shall give the keys of the apps whose exe is ARM64 or ARM64EC, read like a launch reads it (`_appProgram`, then `_programPaths`), and nothing for an exe that cannot be resolved. It reads the files once per call, so a UI asks once per bottle.

- **Given** a bottle with an ARM64 exe, an ARM64EC one and an x64 one registered, **then** the first two keys.
- **Given** a bottle that does not exist, **then** `BottleNotFound`.
- **Check:** `dart test test/apps_test.dart` (`an ARM64 program is told apart from the rest (AA1)`).

## AA4 · `bodega probe <path>`

`probeProgram(path)` shall give `<path>: <arch>, <DirectX>` — `arch` one of `x86`, `x64`, `arm64`, `arm64ec`, and `no DirectX` when the file names none — and, for the two ARM64 ones, a second line: `It runs only on the native engine (Mach9).` It shall be null for a file that is no PE, which the CLI reports on stderr with exit status 1.

`_directxOf` reads the strings of any PE, so an ARM64 program reports its DirectX; `exeGraphics` keeps answering null for it, so the backends are chosen as before.

- **Given** an ARM64 PE naming `d3d11.dll`, **then** the two lines above and exit 0.
- **Given** an x64 PE naming nothing, **then** `<path>: x64, no DirectX` and one line.
- **Given** eight bytes of text, **then** null, and the CLI's message with exit 1.
- **Check:** `dart test test/backends_test.dart test/english_test.dart`; `dart run bin/bodega.dart probe <file>` (recorded in `verify.md`).
