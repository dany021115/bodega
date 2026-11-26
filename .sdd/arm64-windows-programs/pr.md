# Issue and pull request · arm64-windows-programs

`branch-pr` asks for an approved issue first. Draft, in the repo's voice:

## Issue (title and body)

**Title:** feat: ARM64 Windows programs run on the Native engine, and say why the Rosetta one cannot

**Body:**

```
## Why

Some Windows programs are built for Windows on ARM (PE machine 0xAA64, or ARM64EC 0xA641). Only an arm64 Wine loads them, and Bodega has one: the Native engine (Mach9). Today Bodega reads their header as "not a PE on x86", falls back to auto, and the launch fails inside a Rosetta bottle's x86_64 Wine with a load error in the log and no reason.

## What

- `isArm64Program(path)` reads the PE machine; ARM64 and ARM64EC are told apart from x86, x64, non-PEs and missing files.
- A launch on the Rosetta engine throws `ProgramNotForRuntime` before resolving a backend, and nothing is logged because nothing ran.
- The app words it in both languages: the program's name, the Rosetta engine, and the two ways out (move the bottle to the Native engine, or add the program to a bottle on it).
- A Native bottle already runs such a program: no change there.

Spec: `.sdd/arm64-windows-programs/`.

## Out of scope

- Compiling a Windows program to arm64 (no source, unsound for JITs and protected binaries, a derivative work).
- Preferring a game's native macOS version automatically.
- Shader cache pre-warming, and Bodega's own arm64 engine line.
```

## Pull request body

```
## What

A program built for Windows on ARM needs an arm64 Wine, which only the Native engine (Mach9) has. Until now Bodega read its header as "not a PE on x86", picked `wine` on auto, and let the launch fail inside a Rosetta bottle's x86_64 Wine, with the reason buried in a log.

- **Engine:** `isArm64Program` (0xAA64 and 0xA641; false for x86, x64, a missing file and a non-PE), and `ProgramNotForRuntime` thrown by `_launchIn` before `resolveBackend` on the Rosetta engine. Nothing is logged, since nothing ran. The Native engine launches the same program untouched.
- **App:** `AppError.programNotForRuntime` and `errProgramNotForRuntime` in both ARBs: the program's name, the Rosetta engine, and the two ways out.
- **Docs:** `.sdd/arm64-windows-programs/`, and the README's Native engine bullet.
- **Version:** 1.11.0+20.

## Checks

- `packages/engine`: `dart analyze` no issues; `dart test` 513 passed, 13 skipped.
- `apps/bodega`: `flutter analyze` no errors; `flutter test` 1019 passed, 6 skipped (the 9 update tests that call `/usr/bin/shasum` fail on Linux, as they did before this branch); `tool/check_layers.sh` `Layers OK`.
- The PE cases, the refusal on the Rosetta engine, the launch on the Native engine, and the words in both languages are unit tests.
- Not done: a real ARM64 Windows program, which is the user's check (`specs/checks.md`, T9).

## Files

| File | Change |
|---|---|
| `packages/engine/lib/backends.dart` | `isArm64Program` |
| `packages/engine/lib/engine.dart` | the refusal in `_launchIn` |
| `packages/engine/lib/failures.dart` | `ProgramNotForRuntime` |
| `apps/bodega/lib/domain/entities/app_error.dart` | `programNotForRuntime` |
| `apps/bodega/lib/data/service/repository_call.dart` | the mapping |
| `apps/bodega/lib/app/shared/text/error_text.dart` | the words |
| `apps/bodega/lib/l10n/app_{en,es}.arb` | `errProgramNotForRuntime` |
| `README.md`, `.sdd/arm64-windows-programs/` | docs and spec |
```

## Commands, once the issue is approved

```sh
# issue first, with its status:approved label
gh issue create --title "feat: ARM64 Windows programs run on the Native engine" --body-file /tmp/issue.md

# then the branch, its commits (../bodega-arm64-windows-programs-commit.sh) and the PR
git push -u origin feat/arm64-windows-apps
gh pr create --base main --head feat/arm64-windows-apps \
  --title "feat: ARM64 Windows programs run on the Native engine" \
  --body-file /tmp/pr.md
gh pr edit --add-label "type:feature"
```
