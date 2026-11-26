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
