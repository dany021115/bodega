# Tasks · arm64-windows-programs

## Engine

- [x] **T1 (AA1):** `isArm64Program` in `packages/engine/lib/backends.dart`, with its unit cases in `backends_test.dart`.
- [x] **T2 (AA2):** `ProgramNotForRuntime` in `failures.dart`, the refusal in `_launchIn`, and the two launches in `engine_test.dart` and `mach9_test.dart`.
- [x] **T3 (AA2):** `english_test`'s list (48 failures) and hint.

## App

- [x] **T4 (AA3):** `AppError.programNotForRuntime`, its mapping in `repository_call.dart`, its words in `error_text.dart`, and `errProgramNotForRuntime` in both ARBs.
- [x] **T5 (AA3, AA4):** the rows in `text_test` (45 codes) and `repository_call_test` (43 failures); `build_runner` and `gen-l10n`.

## More, on the user's word of 2026-11-26: before the launch

- [x] **T11 (AA3):** `arm64Apps` in `apps.dart`, with its test in `apps_test.dart`.
- [x] **T12 (AA5):** `LibraryApp.arm64`, `libraryApps`, `programFactsText`, and the two lists; the tests of the detail, the mapper and the rows in both languages.
- [x] **T13 (AA6):** `isArm64Program` on `AddAppRepository`, the bloc's state, and the dialog's notice; the dialog is told the bottle's engine by the page that opens it.
- [x] **T14 (AA4):** `programArch` and `_directxOf`, `probeProgram`, the `bodega probe` verb and its usage line.
- [x] **T15:** the ARBs' three keys, and `ARM64` in the parity test's names.
- [x] **T16:** `chore(deps)`: the lockfile's newer resolutions, on their own.

## Delivery

- [x] **T6:** `README.md`, the Native engine bullet: ARM64 Windows programs run there with no translation.
- [x] **T7:** `bump-version` (minor, 1.11.0+20) and `tool/version.sh check`.
- [x] **T8:** the checks of `specs/checks.md`, recorded in `verify.md`.
- [ ] **T9 (USER):** the checks of `specs/checks.md` a person runs, with a real ARM64 Windows program.
- [x] **T10:** the commits, the issue #30 and the pull request #31, on the user's word of 2026-11-26.

## Notes from apply

- The English list's count is a test of its own (`the list holds each of the 48 failures`): a new failure is a new number there, and the same in the app's two tables.
- `isArm64Program` returns false for a missing file on purpose: `_programPaths` may name an exe that no longer exists, and the launch fails later, as it did before this change.
