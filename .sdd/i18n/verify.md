# i18n · M3 verification (T31)

After this run, the sidebar's language menu replaced the Settings dialog (2026-11-11, design §2), so this file's mentions of the dialog and `settings_dialog.dart` describe M3 as it was verified then.

Run on 2026-11-10, 20:41 to 20:58 EST, on the dev Mac (Flutter 3.47.0, Dart 3.13.0, Xcode 27).

- Where: the merged M3 sandbox, a scratch copy of the repo. Its `base` tree has the same blobs as the real repo's `HEAD` (`4134b54`, branch `feat/i18n`), apart from `wine/` and `.sdd/`, which the sandbox leaves out. All of M3 sits on top: 46 changed files and 9 new ones.
- `tool/version.sh check` ran in the real repo. It only reads, as do `git grep` and `git log`.

## Result

**Green.** Every automated check passes. Nothing needed a fix. The sandbox's sources are byte for byte what they were before this run: the SHA-256 of `git diff base` plus every untracked file is `90d894cb…42a3`, both before and after, so codegen and the build changed no tracked file. Nothing was committed, and nothing in the real repo was written.

After the sandbox was merged into the repo, the checks ran again in the repo itself and passed: `flutter gen-l10n` (untranslated.json `{}`), build_runner, `flutter analyze` (no issues), `flutter test` (626 passed), `tool/check_layers.sh` (Layers OK), `dart format` (0 changed), `plutil -lint` on `Info.plist` and every `.lproj` strings file, `dart analyze` (no issues) and `dart test` (161 passed, 3 skipped) in `packages/engine`, and `tool/version.sh check`.

## Commands and their last lines

Full logs are in a scratch folder outside the repo.

### apps/bodega

1. `flutter gen-l10n`: exit 0. `lib/l10n/untranslated.json` is `{}`.
   ```
   Because l10n.yaml exists, the options defined there will be used instead.
   To use the command line arguments, delete the l10n.yaml file in the Flutter project.
   ```
2. `dart run build_runner build --delete-conflicting-outputs`: exit 0. It wrote no outputs because they were already current. A fresh copy (see "Extra checks") wrote all 71 of them.
   ```
     0s injectable_generator:injectable_config_builder on 952 inputs: 952 skipped
     Built with build_runner/aot in 1s; wrote 0 outputs.
   ```
3. `flutter analyze`: exit 0.
   ```
   Analyzing bodega...
   No issues found! (ran in 2.2s)
   ```
4. `flutter test`: exit 0. 626 tests, none skipped. That is 589 before M3, plus 32 from T25/T26 and 5 from T35.
   ```
   00:35 +625: test/data/update_repository_test.dart: an AppImage takes the place of the running one (A4)
   00:35 +626: All tests passed!
   ```
5. `tool/check_layers.sh`: exit 0.
   ```
   Layers OK
   ```
6. Format check. CI has no format step, so this is the local one: `dart format --set-exit-if-changed --output=none` over the 261 hand-written Dart files in `apps/bodega/{lib,test}` and `packages/engine/{lib,test,bin}`, leaving out `*.g.dart`, `*.freezed.dart`, `*.config.dart` and `lib/l10n/app_localizations*.dart`. Exit 0.
   ```
   Formatted 261 files (0 changed) in 0.46 seconds.
   ```
7. `flutter build macos --release`: exit 0, in 60 s.
   ```
   Building macOS application...
   ✓ Built build/macos/Build/Products/Release/Bodega.app (51.9MB)
   ```
   The bundle's `.lproj` folders, under `Bodega.app/Contents/Resources/`:
   ```
   Base.lproj/MainMenu.nib
   en.lproj/InfoPlist.strings
   es.lproj/InfoPlist.strings
   es.lproj/MainMenu.strings
   ```
   - `plutil -extract CFBundleLocalizations json -o - Contents/Info.plist` gives `["en","es"]`.
   - `CFBundleDevelopmentRegion` is `en`.
   - `CFBundleName` is `Bodega`.
   - `plutil -p` on the built `es.lproj/InfoPlist.strings` gives the four Spanish usage texts. On `en.lproj`, it gives the four English ones.
   - The built `es.lproj/MainMenu.strings` passes `plutil -lint` and is identical to its source.

### packages/engine

8. `dart analyze`: exit 0.
   ```
   Analyzing engine...
   No issues found!
   ```
9. `dart test`: exit 0. 161 tests passed and 3 were skipped. The skips are "the disk is case-insensitive, like a Mac disk", and twice "BODEGA_TEST_RUNTIME is not set", since agents never run Wine.
   ```
   00:44 +160 ~3: test/catalog_test.dart: installedApps
   00:49 +161 ~3: All tests passed!
   ```

### T29's checks

10. The scan: T29's `es_leftovers.py`, a script outside the repo, run as `python3 -I es_leftovers.py <sandbox>`. Exit 0.
    ```
    -- 373 messages, 5821 fragments of 5+ characters that differ from their English; 0 hit(s)
    ```
11. `grep -nE 'prueba|sin-paquete' apps/bodega/README.md tool/package_macos.sh`: no output (exit 1).
12. N14's rules grep, ``grep -n 'user reads in Spanish\|throws `String`' .claude/rules/*.md``: no output (exit 1).
13. N14's repo grep, `git grep --untracked -lIP '[áéíóúñÁÉÍÓÚÑ¿¡]' -- . ':!.sdd'` at the sandbox root:
    ```
    apps/bodega/lib/app/presentation/settings/settings_dialog.dart
    apps/bodega/lib/l10n/app_es.arb
    apps/bodega/macos/Runner/es.lproj/InfoPlist.strings
    apps/bodega/macos/Runner/es.lproj/MainMenu.strings
    ```
    These are the allowed files plus `settings_dialog.dart`, which T29's Check allows. The sandbox has no `wine/`, so I ran `git grep -lIP '[áéíóúñÁÉÍÓÚÑ¿¡]' -- wine` in the real repo: no output (exit 1). For comparison, the real repo before M3 lists `color.dart`, `app_es.arb` and `Info.plist`.
14. L19's grep, in `apps/bodega`:
    ```
    lib/app/presentation/settings/settings_dialog.dart:18:  static const spanish = 'Español';
    ```
15. The engine grep, at the root: no output (exit 1).

### T35's checks

16. `grep -nE '\bbodega [a-z]' packages/engine/lib/catalog_data.dart apps/bodega/lib/l10n/app_*.arb`: no output (exit 1). The ARBs' messages also have no `rm -rf`, `--backend` or `gh release`.
17. In a scratch copy where the Mac `checkHost` returns two issues (`noRosetta` and `noVulkan`), `BODEGA_HOME=<empty> dart run bin/bodega.dart backend list` exits 1, with nothing on stdout. Both stderr lines start with `bodega: `:
    ```
    bodega: Rosetta 2 is missing: Windows games run on it: softwareupdate --install-rosetta --agree-to-license
    bodega: Vulkan is missing: games draw with it, through DXVK
    ```
18. T35's new cases ran and passed in steps 4 and 9:
    - `text_test.dart:1828`: `errBottleExists` reads "A bottle named steam already exists." in `en`.
    - "it names no Automatic option, in either language: the run-with-options dialog has none (L12)".
    - `update_repository_test.dart`: "a failed attach leaves no mount folder behind (A5)". It ran here, since `/usr/bin/hdiutil` exists.
    - `english_test.dart`: "a missing checksum names the release of its tarball, engine or hostlibs (E4)".

### Version

19. `tool/version.sh check` in the real repo: exit 0.
    ```
    OK: version 1.5.0 (tag v1.4.2).
    ```
    `tool/version.sh get` prints `1.5.0`. On the branch, `git log -p main..HEAD -- apps/bodega/pubspec.yaml` changes the `version:` line once, `1.4.2+11` → `1.5.0+12` (N16). The sandbox's pubspec holds the same `1.5.0+12`.

### Extra checks

- **Fresh copy, as CI sees it.** I copied only the 368 files git would commit (no generated file, no `.dart_tool`) and ran test.yml's app step: `flutter pub get --offline`, then build_runner, `flutter analyze`, `flutter test` and `tool/check_layers.sh`.
  - Exit 0. `pub get` wrote the three `app_localizations*.dart` and `untranslated.json` = `{}`.
  - build_runner: "Built with build_runner/aot in 23s; wrote 71 outputs."
  - `flutter analyze`: "No issues found!"
  - `flutter test`: "00:32 +626: All tests passed!"
  - `tool/check_layers.sh`: "Layers OK".
  - `dart analyze` in the engine: "No issues found!".

  The copy was deleted afterwards.
- **Requirement test files**, rerun with `--reporter json`: 398 tests, all passed, none skipped.
  - `app_locale_test` 9, `catalog_text_test` 9, `locale_bloc_test` 10, `main_shell_test` 12, `pages_test` 186, `settings_dialog_test` 7, `text_test` 141, `l10n_parity_test` 24.
- **E7.** With an empty `backends/dxvk/wine` folder, `backend list` prints `wine: installed`, `dxmt: not installed`, `dxvk: installed`, `d3dmetal: not installed`.
  - `grep -qx 'dxvk: installed'` exits 0, and every line matches `^[a-z0-9]+: (installed|not installed)$`.
  - `tool/smoke_linux.sh:46` holds that grep.
- **N7.** `git check-ignore` matches the four generated l10n files (`apps/bodega/.gitignore:56-57`). Git would track only `app_en.arb`, `app_es.arb` and `l10n.dart` in `lib/l10n`.
- **N8, N15, L14.** N8's grep lists only `test/support/pump.dart`. N15's grep and L14's grep print nothing.
- **Hygiene.**
  - `git diff --check base` is clean, and the new files have no trailing spaces.
  - `bash -n tool/package_macos.sh` passes.
  - `.github/workflows/test.yml` parses, with the steps checkout, "desktop entry", flutter-action, "engine" and "app", and `packaging/linux/**` in its `paths:`.
  - The packaging scripts rewrite only `Exec=` of the desktop entry, and the PKGBUILD's sums are `SKIP`.
  - Relative imports appear only for the test helpers (`../support/pump.dart`, `_home.dart`).
  - There are no stray `*.orig`, `*.rej`, `*.bak` or `*.rb` files, so T27's xcodeproj script stayed out of the repo.

## Requirements

| Req | Status | Evidence |
|---|---|---|
| L4 | Met | `main_shell_test` (12 pass): "Settings at 1000 px it sits between Backends and the version", "at 600 px only its gear shows, a button with a tooltip", "a click opens the dialog at 1000.0/600.0 px". `settings_dialog_test` (7 pass): "one Language section of three choices, and Close (en)" and "(es)", "the active choice is checked, in a group" for System, English and Español, "a language adds its code, and System adds null", "Close shuts it". The test finds no `Switch` or `SwitchListTile`, so there is no theme switch. `English` and `Español` are the dialog's constants. |
| L5 | Met | `locale_bloc_test` (10 pass): a saved `es` is the first state, with no event. A saved `fr` or `""` reads as System. "a choice applies and is saved". "System goes back to no choice, and removes the saved one". `app_locale_test` (L5 group, 3 pass): "Spanish switches the app and the open dialog", "a saved choice shows from the first frame", "System forgets the choice, and the system list decides". In the code: `PreferenceKey.language`; `saveLanguage(null)` removes the key; `LocaleBloc` reads `Preferences` in its constructor; `_AppView` passes `locale`. |
| L18 | Met | `pages_test` (186 pass): 79 cases run in `(en)` and 79 in `(es)`. That includes 15 width groups at 720, 801, 1150 and 1921 px in each locale, among them "the Settings dialog fits at … px (en/es)". |
| L19 | Met | L19's grep prints only `settings_dialog.dart:18` (`'Español'`). T29's scan finds 0 hits. |
| N1 | Met | `plutil -lint` passes `Info.plist`, `en.lproj/InfoPlist.strings` and `es.lproj/InfoPlist.strings`. For each of the four keys, `plutil -extract <key> raw` gives the same English in `Info.plist` and in `en.lproj`, and it is the text of N1's table. The `es.lproj` values equal the Spanish in `base`'s `Info.plist`. In the release build, `plutil -p` on `es.lproj/InfoPlist.strings` prints the four Spanish texts, and on `en.lproj` the English ones. |
| N2 | Met | `plutil -lint` passes `project.pbxproj`. `knownRegions` is `["en","Base","es"]`. `CFBundleLocalizations` is `["en","es"]` in the source and in the built `Info.plist`. The bundle holds `en.lproj/InfoPlist.strings`, `es.lproj/InfoPlist.strings` and `es.lproj/MainMenu.strings`. The project diff has an `InfoPlist.strings` variant group (en, es) in Resources and `es` in the `MainMenu.xib` group. |
| N3 | Met (see spec issue 3) | `xcrun ibtool --export-strings-file` of `Base.lproj/MainMenu.xib` and `es.lproj/MainMenu.strings`, both through `plutil -convert json`, have the same 65 keys. Only "Bodega" and "Zoom" keep their English value. Spot-checked words: Edición, Visualización, Ventana, Ayuda, Salir de Bodega, Acerca de Bodega; T27 checked them all against TextEdit's `Edit.loctable`. `file` gives "Unicode text, UTF-8 text" for both `es.lproj` files and "ASCII text" for `en.lproj/InfoPlist.strings`. |
| N5 | Met in the sources; the real validator runs only in CI | `bodega.desktop` keeps `Comment=` and holds exactly `Comment[es]=Lanzador para jugar juegos de Windows con Wine`, `GenericName=Game launcher`, `GenericName[es]=Lanzador de juegos`, `Keywords=wine;windows;games;launcher;` and `Keywords[es]=wine;windows;juegos;lanzador;`. `test.yml` has the "desktop entry" step, which installs `desktop-file-utils` and runs `desktop-file-validate`, and `packaging/linux/**` is in its `paths:`. T28's desk check (not the real tool) passes: 0 errors, warnings or style notes. `desktop-file-validate` is not installed on this Mac, and installing is not allowed: T28's CI run will run it (USER, not run). Its negative half cannot fail (spec issue 2). |
| N14 | Met | The rules grep finds nothing. `.claude/CLAUDE.md:7` names `app_es.arb`, `es.lproj/*.strings` and the `[es]` keys. The Commands block lists `flutter gen-l10n`. The generated-files line names `app_localizations*.dart` and `untranslated.json`. `architecture.md:35` is a "Text" section. The repo grep lists only the translation files plus `settings_dialog.dart` (spec issue 1), and `wine/` in the real repo has none. |
| E4 | Met | `dart test test/english_test.dart`: 10 pass. They include "each failure is in English and keeps its hint", "the list holds each of the 31 failures", and T35(f)'s "a missing checksum names the release of its tarball, engine or hostlibs (E4)", whose tags are in English. |
| E6 | Met | With an empty `BODEGA_HOME`, no arguments exits 64, and stderr starts with `usage: bodega install <engine.tar.gz> <hostlibs.tar.gz>`. `catalog show nope` exits 1 with one stderr line, `bodega: unknown catalog app: nope (bodega catalog list)`. `catalog show steam`, `backend list`, `fix list` and `pads` exit 0, and their output has 0 matches for the engine grep's pattern. T35(d): two host issues give two stderr lines, each starting `bodega: ` (step 17). |
| E8 | Met | The engine grep prints nothing, and `dart test` passes. The non-ASCII path case uses `ø` (`engine_test.dart:143`), and neither grep lists it. |
| L8 | Met | `text_test` (141 pass) includes "in en, each code is worded, names what it carries, gives no command and leaves its detail out (L8, E13)", the same in `es`, and "an open bottle says to stop it, where the engine says bodega stop (L8)". For T35(a), `errBottleExists` gives no advice in either ARB. In a scratch copy with the `BottleExistsError` case removed from `error_text.dart`, `flutter analyze` exits 1: `non_exhaustive_switch_expression` at `lib/app/shared/text/error_text.dart:15:37`. |
| L12 | Met | `l10n_parity_test` (24 pass) includes "the real ARBs use the placeholders they declare, in both files (N9, L12)" and the small-map faults for a missing or undeclared placeholder. `text_test`'s L12 cases cover "the menu button of an app names it", the bottle row's one `select` message, and the bottle's misfit warning, which quotes the Automatic of the active language. For T35(b), "it names no Automatic option, in either language", and `graphicsMisfitWarning` has no `{automatic}` in either ARB while `bottleMisfitWarning` keeps it. |
| L16 | Met | `catalog_text_test` (9 pass): "in English, each app reads as the engine writes it (N10, L16)", "in Spanish, each app keeps that shape, every string translated", "each app says what to do, never a bodega command, in the engine and in Spanish (design §7)". `pages_test`: "the Steam page shows its prose" in `en` and `es`. T35's grep prints nothing. |
| N10 | Met | `catalog_text_test`'s fault cases each name the id and field: "an id with no keys", "a note the ARBs have not followed", "a flaky note or a known issue the data added, or a note it dropped", "a fix that gives a command instead of saying what to do", "a Spanish text left in English or empty, or a field one language lacks". |

## Not run

- **T32 (USER)**: a real Mac in English and Spanish (L3, N4, E15). N4 will also be the first check that the menus actually read Spanish. The built `es.lproj/MainMenu.strings` stays UTF-8, a straight copy of its source, while Xcode turned both `InfoPlist.strings` into UTF-16. Both forms are valid, and `plutil -lint` passes it.
- **T33 (USER)**: a real Linux box (L3, N6, E15, N13), including the `release-linux` smoke run at the first release.
- **T34 (USER)**: the branch to `main`, and `tag-version` creating `v1.5.0` (N16).
- **T28's CI run (USER)**: the pull request's `test` run, the only place `desktop-file-validate` itself runs (N5).

## Spec issues

All four are fixed in the specs since this run: N14; N5 and T28's Check; N3; N16 and T30.

1. **N14** (`native-and-tooling.md`, second scenario) says the repo grep lists only `app_es.arb` and `es.lproj/*.strings`, plus `bodega.desktop` if it has an accent. It also lists `apps/bodega/lib/app/presentation/settings/settings_dialog.dart`, whose `Español` constant L19 and design §2 require. tasks.md (T29's Check) and `.claude/CLAUDE.md:7` already allow it; N14's text should name it too.
2. **N5's second scenario and T28's Check** expect `desktop-file-validate` to reject a list without its final `;`. desktop-file-utils made trailing semicolons optional in 0.23 ("Downgrade trailing semicolons to optional (fdo#76902)", in its NEWS), and Ubuntu 24.04 ships 0.27, so that negative case cannot fail. This was T28's finding; it holds.
3. **N3** expects `file macos/Runner/*.lproj/*.strings` to report each file as UTF-8 text. `en.lproj/InfoPlist.strings` is pure ASCII, so `file` prints "ASCII text". That is valid UTF-8, and the point of the check, no UTF-16, holds. This was T27's finding; it holds.
4. **N16 and T30** quote `tool/version.sh check` as printing `OK: version 1.5.0 (tag v1.4.2)`, but the script ends the line with a period: `OK: version 1.5.0 (tag v1.4.2).` This is minor.

## Still open from the M3 tasks (not rechecked here, unless said)

- T27: two MainMenu titles have no TextEdit equivalent, and the About panel's copyright line stays English.
- T29: L19's and the scan's word lists miss some fixture words. `.claude/CLAUDE.md`'s Freezed line was reworded. The engine still cites an outside file by its Spanish name, "INFORME" (`packages/engine/lib/backends.dart:425`, `:694`); I confirmed both lines.
- The merge: `english_test.dart`'s two tags now carry an English note (`first-build`, `first-hostlibs`) instead of the real `primer-…` ones. If the real names should stay, the alternative is an ALLOW entry in T29's scan.
- tasks.md's T31 says the output goes into `verify.md`. This file is that record, copied from the report T31 wrote outside the repo.
