# Spec · Native text and tooling

Requirements N1..N16. `lib/`, `test/`, `macos/` and `build/` are under `apps/bodega/`, where the app's commands run; other paths start at the repo root. The release build is `build/macos/Build/Products/Release/Bodega.app` (`tool/package_macos.sh:111`). **(USER)**: only the user can check it, on a real Mac or Linux box.

## N1 · Permission prompts
The four usage descriptions shall be English in `macos/Runner/Info.plist` (`:27-34`) and `macos/Runner/en.lproj/InfoPlist.strings`, and Spanish in `macos/Runner/es.lproj/InfoPlist.strings`, which takes today's text as it is.

| Key | English |
|---|---|
| `NSDownloadsFolderUsageDescription` | Bodega looks in Downloads for the Game Porting Toolkit you downloaded from Apple, to install D3DMetal. |
| `NSLocalNetworkUsageDescription` | Games use the local network for LAN matches with other computers in your home. |
| `NSMicrophoneUsageDescription` | Windows games use the microphone for voice chat. |
| `NSCameraUsageDescription` | A Windows program wants to use the camera. |

- **Given** the sources, **when** `plutil -lint` runs on the three files, **then** each is OK, and `plutil -extract <key> raw` reads the same English in `Info.plist` and `en.lproj`.
- **Given** a release build, **when** `plutil -p` reads `Contents/Resources/es.lproj/InfoPlist.strings`, **then** it prints the four keys with the Spanish text.
- Check: `plutil -lint` and `plutil -extract` on the sources; `flutter build macos --release`, then `plutil -p` on both built `InfoPlist.strings`.

## N2 · Spanish declared to macOS
The Xcode project shall declare Spanish: `es` in `knownRegions` (`macos/Runner.xcodeproj/project.pbxproj:265-268`), `CFBundleLocalizations` = `en`, `es` in `Info.plist`, and `es` variants of `InfoPlist.strings` and `MainMenu.xib` (`:379-387`) in Runner's Resources, edited with a tool, never by hand (`design.md` §8).
- **Given** the sources, **when** `plutil -extract objects.33CC10E52044A3C60003C045.knownRegions json -o - Runner.xcodeproj/project.pbxproj` runs in `macos/`, **then** it prints `en`, `Base` and `es` (today `["en","Base"]`), and `plutil -extract CFBundleLocalizations json -o - Runner/Info.plist` prints `["en","es"]`.
- **Given** a release build, **when** its bundle is listed, **then** `Contents/Info.plist` has the same `CFBundleLocalizations`, and `Contents/Resources/` holds `en.lproj/InfoPlist.strings`, `es.lproj/InfoPlist.strings` and `es.lproj/MainMenu.strings`.
- Check: `plutil -lint` on `project.pbxproj`; the two `plutil -extract`; `flutter build macos --release`, then `ls` of the bundle's `.lproj` folders.

## N3 · Menu bar
`macos/Runner/es.lproj/MainMenu.strings` shall translate every string of `macos/Runner/Base.lproj/MainMenu.xib`, which stays the English source, with the words of macOS's own Spanish menus, and every `.lproj/*.strings` file under `macos/Runner/` shall be UTF-8.
- **Given** `xcrun ibtool --export-strings-file` of `Base.lproj/MainMenu.xib` (65 strings: 52 items, 12 menus, the window title), **when** its keys are compared with those of `es.lproj/MainMenu.strings` (both through `plutil -convert json`), **then** they are the same and only "Bodega" and "Zoom" keep their English value; the words are TextEdit's Spanish ones (`/System/Applications/TextEdit.app/Contents/Resources/Edit.loctable`, `es`), such as "Edición", "Visualización", "Ventana", "Salir de Bodega". Two titles have no match there, and neither shows on screen: the main menu's own, "Main Menu", and the Spelling submenu's, "Spelling" (TextEdit's is "Spelling and Grammar").
- **Given** the strings files, **when** `file macos/Runner/*.lproj/*.strings` runs, **then** it prints "UTF-8 text" for each, or "ASCII text" for one that is all ASCII, as `en.lproj/InfoPlist.strings` is, which is UTF-8 too. What matters is no UTF-16 and no BOM: `ibtool` exports UTF-16, which git stores and diffs as binary.
- Check: the `ibtool` and `plutil` key comparison; `file`.

## N4 · Spanish on a real Mac (USER)
On a Mac, the menu bar, the permission prompts and AppKit's own panels shall follow the system language and Bodega's per-app language.
- **Given** macOS in Spanish and `tccutil reset Microphone com.dany021115.bodega`, **when** Bodega opens, **then** the microphone prompt it asks at launch (`macos/Runner/MainFlutterWindow.swift:25-27`) shows the Spanish text, the menus read "Edición", "Ventana" and "Ayuda", and the file picker's cancel button reads "Cancelar".
- **Given** macOS in English and Bodega set to Español in System Settings › General › Language & Region › Applications, **when** Bodega opens, **then** the same is Spanish, and so is the app with its own language on System; removing the entry brings English back.
- Check: screenshots on the user's Mac.

## N5 · Linux desktop entry
`packaging/linux/bodega.desktop`, which the `.deb`, the AppImage and the Arch package ship rewriting only `Exec=` (`packaging/linux/build_deb.sh:23`, `build_appimage.sh:20`, `packaging/arch/PKGBUILD:33`), shall keep its English `Comment` and add `Comment[es]`, `GenericName`, `GenericName[es]`, `Keywords` and `Keywords[es]`, validated in CI.
- **Given** the file, **when** `desktop-file-validate packaging/linux/bodega.desktop` runs, **then** it exits 0, and the file reads `Comment[es]=Lanzador para jugar juegos de Windows con Wine` (its text before `ed53a40`), `GenericName=Game launcher`, `GenericName[es]=Lanzador de juegos`, `Keywords=wine;windows;games;launcher;` and `Keywords[es]=wine;windows;juegos;lanzador;`.
- **Given** a pull request that touches `packaging/linux/**`, which joins `test.yml`'s `paths:` (`:6-11`), **when** `test` runs, **then** a step installs `desktop-file-utils` and validates the file, and an invalid entry fails the run, such as one whose `Keywords=` line is deleted, so its `Keywords[es]` has no base key. A list without its final `;` is not invalid: desktop-file-utils made that `;` optional in 0.23, and Ubuntu 24.04 ships 0.27.
- Check: `desktop-file-validate` on Linux; the pull request's `test` run.

## N6 · Spanish on a real Linux desktop (USER)
On Linux, the launcher shall show Bodega's entry in the session language.
- **Given** the `.deb` or the Arch package installed and a session with `LANG=es_ES.UTF-8`, **when** the user searches the launcher (GNOME Activities, KDE Kickoff) for "juegos", **then** Bodega shows up, with the Spanish description where the launcher shows one; in an `en_US.UTF-8` session, "games" finds it, in English.
- Check: screenshots on the user's Linux box.

## N7 · gen-l10n
The app shall generate `AppL10n` with Flutter gen-l10n from `lib/l10n/app_en.arb` (the template) and `lib/l10n/app_es.arb`, set up as `design.md` §1 says (`l10n.yaml`, `flutter_localizations`, `intl`, `generate: true`), and shall keep the generated files out of git.
- **Given** a fresh clone, **when** `flutter pub get`, build_runner and `flutter analyze` run as in `test.yml:44-46`, **then** `lib/l10n/` holds `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_es.dart` and `untranslated.json` with `{}`, and analyze finds no issues.
- **Given** a message in `app_en.arb` without its `@key`, **when** `flutter gen-l10n` runs, **then** it fails with `Resource attribute "@<key>" was not found`.
- **Given** the committed change, **when** `git ls-files lib/l10n` runs, **then** it lists only `app_en.arb`, `app_es.arb` and `l10n.dart`, and `git check-ignore` matches the four generated files (new lines beside `apps/bodega/.gitignore:50-53`).
- Check: those commands, in `apps/bodega`.

## N8 · Pump helpers
`test/support/pump.dart` shall give `wrapApp` and `wrapRouter` (`design.md` §9), which install `AppL10n`'s delegates and locales and pin `en` unless the test passes another locale, and every widget test shall pump through them.
- **Given** `tester.platformDispatcher.localesTestValue = [Locale('es')]`, **when** a page is pumped through `wrapApp`, **then** `Localizations.localeOf` is `en` and the text English; with `locale: Locale('es')`, Spanish.
- **Given** a bare `MaterialApp` without the delegates, **when** a widget reads `context.l10n`, **then** the assert fails with a message that names `wrapApp` and `wrapRouter`.
- **Given** the finished change, **when** `grep -rlE 'MaterialApp(\.router)?\(' test` runs, **then** it lists only `test/support/pump.dart` (today 20 sites in 15 files; 18 in 14 once `app_tile_test.dart` goes). The second scenario's bare app is built through the tear-off `MaterialApp.new` in `test/app/pump_test.dart`, so the grep holds.
- Check: `flutter test test/app/pump_test.dart` for the first two; the `grep`.

## N9 · ARB parity test
`test/l10n_parity_test.dart` shall fail when the ARBs differ in keys, a `@key` lacks its `description` or outlives its message, a placeholder lacks its `type` or `example` (L12), a message's placeholders differ from those its `@key` declares, a Spanish message copies its English one, or `untranslated.json` is not `{}`.
- **Given** a key only in `app_en.arb`, or a `@key` without `description`, **when** the test runs, **then** it fails naming the key.
- **Given** `app_es.arb` drops a declared placeholder, the second plural argument of the library count (`library_page.dart:166`) included, or uses an undeclared one, **when** the test runs, **then** it fails naming the key.
- **Given** a Spanish message equal to its English one, **when** the test runs, **then** it fails, unless nothing is left after removing ICU syntax, placeholders, digits, punctuation and allowlisted words: brand and product names (e.g. `Backends`, `D3DMetal`) and words the Spanish UI uses unchanged (`app`, `apps`, so `bottleAppCount` passes).
- Check: `flutter test test/l10n_parity_test.dart`; each fault also runs there on small in-test ARB maps, so the failing paths stay tested.

## N10 · Catalog keys test
`test/app/catalog_text_test.dart` shall fail when an entry of `engine.catalogEntries()` (7 today) lacks its ARB prose or its English prose differs from `catalog_data.dart` (`design.md` §7).
- **Given** a new entry, or a changed note or fix in `catalog_data.dart`, **when** the test runs before the ARBs follow, **then** it fails naming the id and the field.
- **Given** the `es` locale, **when** the test runs, **then** every entry has the English shape (status note, flaky, as many notes and issues) and no string equal to its English one.
- Check: `flutter test test/app/catalog_text_test.dart`.

## N11 · Every screen in both locales
`test/app/pages_test.dart` shall run its width loop (`:353`: 720, 801, 1150 and 1921 px) in `en` and in `es`, the Settings dialog included.
- **Given** the loop, **when** `flutter test test/app/pages_test.dart --reporter expanded` runs, **then** each test shows once per locale (`nothing overflows at 720.0 px (es)`) and all pass.
- **Given** an `app_es.arb` value padded until it overflows at 720 px, **when** the test runs, **then** only `(es)` tests fail.
- Check: that run; the padding as a temporary edit, reverted after.

## N12 · Layer rule
`apps/bodega/tool/check_layers.sh` shall fail when `lib/domain`, `lib/data`, `lib/device` or `lib/di.dart` imports `package:bodega/l10n/`.
- **Given** the finished change, with the generated files present, **when** it runs, **then** it prints `Layers OK`: gen-l10n's `import 'app_localizations_en.dart';` passes the absolute-import rule (`:29`).
- **Given** a temporary `import 'package:bodega/l10n/l10n.dart';` in a file under `lib/data/`, **when** it runs, **then** it prints `NO: only app/ and main.dart import package:bodega/l10n/` and that line, and exits 1.
- Check: `tool/check_layers.sh` in `apps/bodega`, as CI does (`test.yml:48`).

## N13 · Smoke test
`tool/smoke_linux.sh:46` shall grep the English CLI line `dxvk: installed`, in the same commit that turns `packages/engine/bin/bodega.dart:199` English.
- **Given** the English CLI, **when** `release-linux` runs with `smoke` on, **then** each package prints `smoke <kind>: OK`.
- Check: that commit's diff holds both lines; the `smoke` run at release, which the user starts.

## N14 · Rules and docs
`.claude/CLAUDE.md` and `.claude/rules/` shall carry the rules of `design.md` §10, and outside `.sdd/` the only Spanish left in git shall be the translation files and the Settings dialog's name for Spanish (L19).
- **Given** the rules, **when** ``grep -n 'user reads in Spanish\|throws `String`' .claude/rules/*.md`` runs, **then** it finds nothing (today `code-style.md:21`, `architecture.md:24`); `.claude/CLAUDE.md` names the Spanish files and allows that one name (`:7`), lists `flutter gen-l10n` (`:42-54`) and `app_localizations*.dart` (`:56`); `architecture.md` has a "Text" section.
- **Given** the committed change, **when** `git grep -lIP '[áéíóúñÁÉÍÓÚÑ¿¡]' -- . ':!.sdd'` runs at the repo root, **then** it lists only `apps/bodega/lib/l10n/app_es.arb`, `apps/bodega/macos/Runner/es.lproj/*.strings` and `apps/bodega/lib/app/presentation/settings/settings_dialog.dart`, whose `Español` L19 and design §2 require, plus `bodega.desktop` if an `[es]` value has an accent (today: 65 files).
- Check: those two greps; reading the diff of `.claude/`.

## N15 · Dead widgets removed
`lib/app/presentation/library/widgets/library_card.dart`, and `lib/app/presentation/bottles/widgets/app_tile.dart` with `test/app/app_tile_test.dart`, its only user, shall be deleted, not translated.
- **Given** the change, **when** `grep -rnwE 'LibraryCard|AppTile' lib test` runs, **then** it finds nothing, and `flutter analyze` and `flutter test` pass.
- Check: that `grep`; `flutter analyze && flutter test`.

## N16 · Version
The change shall raise the version once, to 1.5.0, before its first commit (proposal.md §Version).
- **Given** `tool/version.sh bump minor` applied, **when** `tool/version.sh check` runs before each commit, **then** it prints `OK: version 1.5.0 (tag v1.4.2).`, and `tool/version.sh get` prints `1.5.0`.
- **Given** the branch, **when** `git log -p -- apps/bodega/pubspec.yaml` runs, **then** it shows at most one change to the `version:` line.
- **Given** the branch on `main`, **when** `tag-version` runs (`tag-version.yml:26-37`), **then** `v1.5.0` points at a commit that holds the whole change, and no other tag moved.
- Check: `tool/version.sh get` and `check`; `git ls-remote --tags origin` after the push.
