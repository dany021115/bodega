# Tasks · i18n

`P` = `packages/engine`; `A` = `apps/bodega`. The agent does not commit or push.

- [x] T1 `A` setup (design §1): `flutter_localizations`, `intl`, `generate: true`,
  `l10n.yaml`, `lib/l10n/` with the template, `context.l10n`, the delegates in
  `main.dart`, the generated files in `.gitignore`, the `Text` rules in
  `.claude/rules/architecture.md`.
- [x] T2 `P` English everywhere (errors, CLI output, hints, host checks, install
  steps, catalog notes), and `id` + `args` on `HostIssue`, `Hint` and
  `Progress`, `UserProblem` from `badUser` (design §4). Tests updated.
- [x] T3 `A` domain and data (design §2–4): typed `AppError`s, `HostIssue.id`,
  the `Hint` and `ProgressStep` entities, no sentences in `domain/` or `data/`;
  `app/shared/error_text.dart`, `engine_text.dart` and `graphics_text.dart`.
- [x] T4 `A` bottles: `presentation/bottles/`, their blocs and tests.
- [x] T5 `A` library, catalog, add app and install: their pages, blocs, shared
  widgets and tests.
- [x] T6 `A` shell, setup, backends, updates, `device/` and the rest of
  `app/shared/`, their blocs and tests.
- [x] T7 `A` macOS `Info.plist` and `es.lproj/InfoPlist.strings` (design §6).
  **Not built:** the project file was edited on Linux; U2 checks it.
- [x] T8 Merge the ARB fragments (309 keys); `build/untranslated.json` empty; no
  Spanish left in `lib/` outside `app_es.arb` (comments included); the L1 test.
  The Spanish is today's text, checked against `HEAD`, except the library
  summary, which said "1 botellas" and now has plurals.
- [x] T9 `P`: `dart analyze` clean, `dart test` 148 pass. `A`: build_runner,
  `flutter analyze` clean, `flutter test` 312 of 319 pass (the 7 failures are
  `update_repository_test` on Linux, from before: it calls `/usr/bin/shasum`,
  which only macOS has), `check_layers.sh` OK, `flutter build linux --release`
  OK. Instead of a window, a throwaway test rendered the shell and the library
  to PNG in each locale: English and Spanish as expected.
- [ ] U1 (user) `flutter run -d macos` with the Mac in Spanish: same UI as
  before. With the Mac in English (System Settings › Language & Region, or
  `defaults write com.dany021115.bodega AppleLanguages '(en)'`): the UI in
  English.
- [ ] U2 (user) A permission prompt (microphone) in each language.
