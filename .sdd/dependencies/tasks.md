# Tasks · dependencies

**Conventions**
- `engine/` is `packages/engine/`, where `dart` runs; `lib/` and `test/` are `apps/bodega/`'s, where `flutter` runs; other paths start at the repo root. `<base>` is the commit the branch starts from (T1).
- Every task ends green: `dart analyze && dart test` in `engine/`, and from T11 on `flutter analyze && flutter test && tool/check_layers.sh` in `apps/bodega`. Run `flutter gen-l10n` after an ARB edit and build_runner after a Freezed or Injectable one.
- **(USER)**: only the user can do it (a game, which opens windows). The agent never commits or pushes; the work stays in the working tree (DN7).

## M1 · Engine and CLI

- [x] **T1** Starting point (design §9, Q10; DN3): if pull request #20 is merged, `git switch --no-track -c feat/dependencies origin/main`; if not, the same from `feat/switch-keys-firmware`, to move onto `main` before this change's own pull request. Then `tool/version.sh bump minor`, the `version:` line alone.
  **Check:** `git branch --show-current` prints `feat/dependencies`; `git rev-parse --abbrev-ref '@{u}'` fails (no upstream); `tool/version.sh check` prints the new version against the last tag.
  **Done 2026-11-16:** #20 was still open, so the branch starts from `feat/switch-keys-firmware` at 40faa18 (`1.7.0+15`); `<base>` is 40faa18. `@{u}` fails with `no upstream configured`. `bump minor` changes nothing yet ("1.7.0 already covers this level (from v1.6.0)"), since #20's 1.7.0 is not tagged; the bump to 1.8.0 comes when the branch moves onto `main` after `v1.7.0` (T22).
- [x] **T2** The runtime table (DE2): new `engine/lib/dependencies.dart` behind one more `part` line, with `Dependency`, `DependencyFile` and `const dependencies` from design §2, and the comment on where the pins come from; new `engine/test/dependencies_test.dart` with the table's cases and the network test behind `BODEGA_NETWORK_TESTS=1`.
  **Check:** `dart test test/dependencies_test.dart`; once, `BODEGA_NETWORK_TESTS=1 dart test test/dependencies_test.dart` (about 85 MB), output kept for `verify.md`.
  **2026-11-16:** `BODEGA_NETWORK_TESTS=1 dart test test/dependencies_test.dart -n "Microsoft's server"` downloaded the twelve installers in about a minute: `01:00 +1: All tests passed!`, every size and SHA-256 as pinned.
- [x] **T3** Installed from the bottle (DE3): `dependencyInstalled` and `bottleDependencies`, the marker's `*` folder among real folders without case, no link followed, Wine's marks in the first 128 bytes.
  **Check:** `dart test test/dependencies_test.dart` (DE3's cases, the link case included).
- [x] **T4** Reading a program (DE4): `ProgramScan` and `scanProgram` in an isolate, import and delay-import tables through the section table, manifest assembly names, the DLLs beside the exe; a PE writer for the tests.
  **Check:** `dart test test/dependencies_test.dart` (DE4's fixtures, the broken table, the non-PE, the 300 MB file).
- [x] **T5** Bodega's fixes (DE7): `GameFix.steam` nullable, `exes`, `requires`; `FixStep` admits `ini` with `file` and `section`, and `active` leaves it out; new `engine/lib/bodega_fixes_data.dart` with design §6's two entries; `gameFixes()` reads both texts and throws `CorruptData` on a repeated id; `fixForApp` by exe file name; `fix list` and `fix show` print `-` for no Steam id and show `exes`, `requires` and `ini` steps.
  **Check:** `dart test test/fixes_test.dart` (DE7's cases; the existing ones unchanged); `git diff <base> -- packages/engine/lib/fixes_data.dart tool/import_fixes.py` prints nothing.
- [x] **T6** Proposals (DE5): `Need`, `NeedReason`, `DependencyNeed`, `SettingState`, `SettingNeed`, `AppNeeds` and `appNeeds`, by design §4's table; Steam keys from fixes only.
  **Check:** `dart test test/dependencies_test.dart` (DE5's cases on both hosts).
- [x] **T7** Installing (DE6, DE10): `installDependency` in design §5's eight steps; `DependencyNotInstalled`, `UnexpectedLink` and `ChoiceKind.dependency`; the fake installer in the tests.
  **Check:** `dart test test/dependencies_test.dart test/english_test.dart` (DE6's cases; DE10's messages).
- [x] **T7b** Wine's manifests and the idle wait (DE6; design §2 and §5 steps 5 and 9; the user approved this change of the spec on 2026-11-16, after T10's first real install left Wine's `msvcr90.dll` in place and a second install found the bottle open): `wineManifests` on each file, vcrun2008's moved to `bottles/<bottle>/wine-manifests/` before the run, put back if it fails, deleted after a good install; `waitBottle` before returning.
  **Check:** `dart test test/dependencies_test.dart` (DE6's two new cases).
  **2026-11-16:** both cases pass (29 passed, 1 skipped); the table's test checks that only vcrun2008 lists Wine's manifests.
- [x] **T8** Settings (DE8, DE9): `setIniValue`; `fixSettingState` and `applyFixSettings` with `%USERPROFILE%`, the link guard against the prefix and `HOME`, the bottle-open refusal, the temporary file renamed over.
  **Check:** `dart test test/fixes_test.dart` (DE8's table, DE9's cases).
- [x] **T9** CLI (DE11): `parseDeps`, the lines of `deps list` and `deps check` from engine functions, `deps install`, `fix apply`, the usage lines, the gate.
  **Check:** `dart test test/dependencies_test.dart`; `dart compile exe bin/bodega.dart -o ../../build/bodega` builds.
  **2026-11-16:** `depsVerb(args, out)` in the engine, as `switchVerb` is, instead of `parseDeps` (DE11 is reworded in the same sense). `dart analyze` clean; `dart test`: 319 passed, 4 skipped. Read-only runs on the user's `Games` bottle: `deps list` shows `vcrun2008 x86 installed` (the manual fix of 2026-11-12), `deps check` gives `recommended vcrun2008 x86 (fix blur) installed` for Blur, `setting [Sound] Reverb=0 applied` for NFS13 and `nothing to propose` for Plutonium.
- [x] **T10** M1 for real (DN4, DE12): in a scratch bottle (`build/bodega create deps-check`), `deps install deps-check vcrun2008 x86`, then `vcrun2022 x86` and `x64`; check the markers carry no Wine mark, `user.reg`'s overrides, `deps list` and `deps check` against a copy of Blur's exe registered there; `fix apply` against a copy of the NFS file in a test home; then `bodega stop deps-check` and remove it. Bring M1 into the working tree.
  **Check:** the commands and outputs, for `verify.md`; `dart analyze && dart test` in `engine/`.
  **2026-11-16:** in a fresh `deps-check`, back to back: vcrun2008 x86 (15 s), x64 (17 s), vcrun2022 x86 (20 s), x64 (31 s, downloads included), each `installed` in `deps list`; `msvcr90.dll` x86 (653,136 bytes) and x64 (641,360), `vcruntime140.dll` x86 and x64 and `vcruntime140_1.dll` are Microsoft's; `user.reg` holds the sixteen `native,builtin` overrides and `Version=win10` for both 2022 installers; no `wine-manifests/` left. `fix apply deps-check need-for-speed-most-wanted-2012` went through the profile's `Documents` link to the user's real file, already at `Reverb=0`, and left it byte for byte as it was. The scratch bottle stays until M3, to check the app against it; it is removed after T21.

## M2 · App

- [x] **T11** Domain (DA1): `domain/entities/dependency.dart` and `domain/repository/dependency_repository.dart`.
  **Check:** `tool/check_layers.sh`; build_runner; `flutter analyze`.
- [x] **T12** Errors (DA2): the two `AppError` codes, `appErrorOf`'s cases, `error_text.dart`'s words, both ARBs.
  **Check:** `flutter test test/app/text_test.dart test/l10n_parity_test.dart`.
- [x] **T13** Repository (DA3): `data/repository/dependency_repository_impl.dart`, the cached file, `Downloader`, `engine.installDependency(file:)`.
  **Check:** `flutter test test/data/dependency_repository_test.dart`.
- [x] **T14** Bloc (DA4): `app/bloc/dependencies/`, `@lazySingleton`, provided in `main.dart`.
  **Check:** `flutter test test/app/dependencies_bloc_test.dart`.
- [x] **T15** Text (DA8): the ARB keys with their `@key`, `app/shared/text/dependency_text.dart`.
  **Check:** `flutter gen-l10n`; `flutter test test/l10n_parity_test.dart test/app/text_test.dart`.
- [x] **T16** The dialog (DA5): `app/shared/widgets/needs_dialog.dart`, both modes.
  **Check:** `flutter test test/app/needs_dialog_test.dart`.
- [x] **T17** The section (DA7): `app/presentation/bottles/widgets/dependencies_section.dart` in `BottleColumn` after Settings; the open-bottle line; "Choose the installer file…".
  **Check:** `flutter test test/app/dependencies_section_test.dart`.
- [x] **T18** The dialog by itself (DA6): `AddAppState` keeps the new key at `done`; the add-app flow and the catalog install's `done` ask for needs and open the dialog when a recommended item is missing.
  **Check:** `flutter test test/app/add_app_dialog_test.dart test/app/install_bloc_test.dart` (new cases).
- [x] **T19** M2 green (DA9): `pages_test.dart` with the section and the dialog, `en` and `es`. Bring M2 into the working tree; run the app in debug for the user.
  **Check:** `flutter analyze && flutter test && tool/check_layers.sh`, output for `verify.md`.
  **2026-11-16:** `flutter analyze`: no issues; `flutter test`: 810 passed; `tool/check_layers.sh`: `Layers OK`. In the engine, `dart analyze`: no issues; `dart test`: 321 passed, 4 skipped. New tests: `test/data/dependency_repository_test.dart` (5), `test/app/dependencies_bloc_test.dart` (8), `needs_dialog_test.dart` (5), `dependencies_section_test.dart` (6), `dependencies_shell_test.dart` (2), the words of DA8 and the two error codes in `text_test.dart`, the section and the dialog at the four widths in `en` and `es` in `pages_test.dart`. The section showed an overflow in Spanish at 1150 px ("Abre el juego una vez primero" beside its line), now under it. Five older test files gained a quiet `DependenciesBloc` mock, and the Tools test scrolls to its buttons, which the new section pushes down.

## M3 · Checks, rules and delivery

- [x] **T20** Rules and docs (DN1, DN2): `.claude/CLAUDE.md`, `.claude/rules/architecture.md`; the installer check.
  **Check:** `git diff <base> -- .claude`; `git ls-files | grep -iE '\.(exe|msi|cab)$'` and `git diff --stat <base>`.
  **2026-11-16:** two lines in `.claude/CLAUDE.md` (Bodega's own fixes; Microsoft's installers) and two in `.claude/rules/architecture.md` (`DependenciesBloc` outlives the page; where an installer goes); `git ls-files | grep -iE '\.(exe|msi|cab)$'` prints nothing.
- [ ] **T21** **(USER)** Blur in a new bottle (DN5) and NFS13's setting from Bodega (DN6).
  **Check:** the user's accounts and the log counts, in `.sdd/dependencies/verify.md`.
- [ ] **T22** Delivery (DN3, DN7): `../dependencies-commit.sh`, four commits, no push.
  **Check:** `bash -n ../dependencies-commit.sh`; `tool/version.sh check`; the user runs the script.
