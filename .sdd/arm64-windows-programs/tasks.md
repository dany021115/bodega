# Tasks · arm64-windows-programs

## Engine

- [x] **T1 (AA1):** `isArm64Program` in `packages/engine/lib/backends.dart`, with its unit cases in `backends_test.dart`.
- [x] **T2 (AA2):** `ProgramNotForRuntime` in `failures.dart`, the refusal in `_launchIn`, and the two launches in `engine_test.dart` and `mach9_test.dart`.
- [x] **T3 (AA2):** `english_test`'s list (48 failures) and hint.

## App

- [x] **T4 (AA3):** `AppError.programNotForRuntime`, its mapping in `repository_call.dart`, its words in `error_text.dart`, and `errProgramNotForRuntime` in both ARBs.
- [x] **T5 (AA3, AA4):** the rows in `text_test` (45 codes) and `repository_call_test` (43 failures); `build_runner` and `gen-l10n`.

## Delivery

- [x] **T6:** `README.md`, the Native engine bullet: ARM64 Windows programs run there with no translation.
- [x] **T7:** `bump-version` (minor, 1.11.0+20) and `tool/version.sh check`.
- [x] **T8:** the checks of `specs/checks.md`, recorded in `verify.md`.
- [ ] **T9 (USER):** the checks of `specs/checks.md` a person runs, with a real ARM64 Windows program.
- [ ] **T10:** the commit and the pull request, which need the user's word; the issue comes first (`branch-pr`).

## Notes from apply

- The English list's count is a test of its own (`the list holds each of the 48 failures`): a new failure is a new number there, and the same in the app's two tables.
- `isArm64Program` returns false for a missing file on purpose: `_programPaths` may name an exe that no longer exists, and the launch fails later, as it did before this change.
