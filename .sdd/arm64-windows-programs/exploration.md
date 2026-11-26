# Exploration · arm64-windows-programs

What exists today, and what was learned while writing the change. Line numbers are those of `v1.10.0` plus this branch.

## 1. How a program's architecture is read today

- `_peMachine` (`packages/engine/lib/backends.dart:1004`) reads the `e_lfanew` offset in the DOS header, checks `PE\0\0`, and returns the 16-bit machine field.
- `_peBits` (`backends.dart:996`) turns `0x8664` into 64 and `0x14C` into 32, and **anything else into null**, ARM64 included.
- Two callers depend on that null:
  - `exeGraphics` (`backends.dart:957`), which feeds `resolveBackend` and the backend cards;
  - `_scanProgram` (`dependencies.dart:997`), which feeds the runtime proposals.

So an ARM64 program has no bits and no DirectX. `resolveBackend` finds no choice, and `hostPlatform.autoBackend(home, exePath)` answers `wine` for a null `exePath`.

## 2. What happens on a launch today

- `_programPaths` (`engine.dart:322`) resolves the exe and hands `scan` to `_launchIn`; wine builtins (`reg`, `wineboot`, `msiexec`) come back with `scan: null`.
- `_launchIn` (`engine.dart:348`) then resolves the backend and starts the bottle's Wine.
- A bottle on the Rosetta engine runs Bodega's `x86_64` Wine: it cannot map an ARM64 image, so the program fails inside Wine, and the user sees a load error in a log, not a reason.
- A bottle on the Native engine runs Mach9's `aarch64` Wine, which loads an ARM64 image as its own architecture. No change is needed there.

## 3. What an arm64 Wine changes about this

- Mach9's tree carries `lib/wine/aarch64-windows/kernel32.dll` and `lib/wine/i386-windows/kernel32.dll` (`.sdd/mach9-runtime/design.md:80`): the Windows side of the runtime is arm64 with 32-bit x86 builtins.
- x86 and x64 programs run through FEX; an ARM64 program needs no translation at all, which is the only case where the Native engine runs a game with no emulator in the way.

## 4. What was checked while writing this change

- `fakePe` (`packages/engine/test/backends_test.dart:36`) writes a 70-byte PE with any machine, which is enough for `isArm64Program` and for a launch refusal without a real game.
- `fakeMach9Wine` and `mach9Bottle` (`packages/engine/test/runtimes_test.dart:43,82`) build a Native bottle whose Wine logs its calls, so the "it launches" side is provable headless.
- No real ARM64 Windows program was at hand; the header is what the engine reads, and the user's check is in `verify.md`.

## 5. Why not something larger

- **Compiling a program to arm64:** the source is missing, the protected ones (JITs, self-modifying code, DRM) cannot be translated ahead of time, and a translated binary is a derivative work.
- **ARM64 builds in the catalog:** highball-db has no field for a program's architecture, and Bodega reads the exe anyway, which is the truth for the file in front of it.
- **Native macOS version:** the catalog's `nativeMac` is a fact about the game, not a path Bodega owns; Steam launches those itself.
