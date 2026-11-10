# Spec · App text

What the app shows, and in which language. `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`, and commands run in `apps/bodega`; bare Dart file names are unique in the repo. "The parity test" is `test/l10n_parity_test.dart` (design §9). `test/app/app_locale_test.dart` pumps `BodegaApp` with mocked blocs in `getIt`; `test/app/text_test.dart` checks `lib/app/shared/text/` and the ARB forms in both locales through `lookupAppL10n`. (USER): only the user can check it, on a real Mac or Linux box.

## L1 · Text from the ARBs
Every text the app shows (labels, tooltips, semantics, toasts, dialogs, file-picker labels) shall come from `lib/l10n/app_en.arb`, the template, or `lib/l10n/app_es.arb` through `context.l10n`, and only brand and product names, ids such as the version tag (`v1.5.0`) and the two language names shall stay in Dart.
- **Given** both ARBs, **when** the parity test runs, **then** they have the same keys, every `@key` has a description and `lib/l10n/untranslated.json` is `{}`; with a key deleted from `app_es.arb`, it fails and names the key.
- **Given** every case of `pages_test.dart` rendered in `es`, **then** no `Text` or tooltip shows an `app_en.arb` message that differs from its Spanish one (a hardcoded English literal).
- **Check:** `flutter test test/l10n_parity_test.dart test/app/pages_test.dart test/app/main_shell_test.dart test/app/setup_page_test.dart` (`pages_test.dart` stubs the sidebar and has no setup page case).

## L2 · The system's language
With no saved choice, the app shall take its language from the system's ordered list through Flutter's default list resolution over `AppL10n.supportedLocales` (`en`, `es`), with no resolution callback, so the first supported language in the list wins and a list with neither gives English.
- **Given** the system list `[fr_FR, es_ES]`, **when** `BodegaApp` starts, **then** `Localizations.localeOf` is `es`.
- **Given** `[de_DE]`, `[C]` (Linux with `LANG=C`) or `[en_GB, es_ES]`, **then** it is `en`.
- **Check:** `flutter test test/app/app_locale_test.dart`, with `tester.platformDispatcher.localesTestValue`.

## L3 · The real system's language (USER)
On a real Mac and a real Linux box, the app shall open in the language that the system's list resolves to (L2).
- **Given** macOS with Español first in System Settings › General › Language & Region, or Français then Español, or English with Bodega set to Español under Applications there, **when** Bodega opens, **then** its screens and the text-field menu are Spanish; with only Français, English.
- **Given** Linux, **when** `/opt/bodega/bodega` or the AppImage starts from a terminal with `LANG=es_ES.UTF-8`, `LANGUAGE=fr:es` or `LANG=C`, **then** it opens in Spanish, Spanish and English.
- **Check:** the user's screenshots on the Mac and on a Linux box, in `verify.md`.

## L4 · Settings dialog
The app shall offer the language in a Settings dialog, opened from a gear item in the sidebar footer, that holds only three choices: System, English and Español.
- **Given** the shell at 1000 px, **then** a "Settings" item sits between Backends and the version (`side_bar.dart:183-190`); at 600 px only its gear shows, with the tooltip "Settings" and button semantics.
- **Given** the dialog in `en` and in `es`, **then** it has one Language section of three radios (System from the ARB; `English` and `Español` the same in both locales), the active one checked and in a group, a Close button and no theme switch; choosing Español adds `LocaleEvent.set('es')`, and System adds `set(null)`.
- **Check:** `flutter test test/app/main_shell_test.dart test/app/settings_dialog_test.dart`.

## L5 · The choice applies at once and is kept
A choice shall apply at once, without a restart, and be saved under `PreferenceKey.language`, where no value means System, so the next start shows it from the first frame.
- **Given** `BodegaApp` in `en`, **when** Español is chosen in Settings, **then** `Localizations.localeOf` is `es` on the next frame and the open dialog reads in Spanish.
- **Given** a saved `es`, **when** `LocaleBloc` is built, **then** its first state is `es`, with no event; a saved `fr` reads as System; choosing System calls `saveLanguage(null)`, which removes the key, and the system's list applies again (L2).
- **Check:** `flutter test test/app/locale_bloc_test.dart test/app/app_locale_test.dart`.

## L6 · A switch rewords what is on screen
Errors, install and D3DMetal steps, run hints and the hint toast shall stay in state as codes and be worded in `build`, so a language switch rewords what is already shown.
- **Given** an install panel with an `InstallStep`, a bottle tag whose tooltip has a `RunHint` and an error panel with an `AppError`, **when** the same state is pumped in `en` and then in `es`, **then** each shows its `es` words and none of its `en` words.
- **Given** the same hint reported twice, **then** `LibraryState` holds one `RunHint` value and no text.
- **Check:** `flutter test test/app/pages_test.dart test/app/library_bloc_test.dart`.

## L7 · Flutter's own text
The app shall pass `AppL10n.localizationsDelegates` and `AppL10n.supportedLocales` to `MaterialApp.router` (`main.dart:65-76`), so Flutter's own text (text-field menu, default tooltips) follows the active language, and an unknown route shall show a localized page instead of go_router's English "Page Not Found".
- **Given** `BodegaApp` in `es`, **then** `MaterialLocalizations.of` and `CupertinoLocalizations.of` give `MaterialLocalizationEs` and `CupertinoLocalizationEs`; in `en`, the English ones.
- **Given** the router sent to `/nope`, **then** the `EmptyState` of its `errorBuilder` shows in the active language, and "Page Not Found" does not.
- **Check:** `flutter test test/app/app_locale_test.dart test/app/pages_test.dart` (group "the routes").

## L8 · Codes worded in `app/`
Every code that reaches `app/` (each `AppError` code, host issue, backend role, install and D3DMetal step, run hint, user-name and path problem, the graphics label and the misfit warning) shall be worded in both languages by an exhaustive `switch` in `lib/app/shared/text/`, with no `_ =>` over an enum or a union.
- **Given** one value of each code, **when** it is worded in `en` and in `es`, **then** the text is not empty, names the bottle, path or log it carries, and gives no CLI command (`bodega stop`, `rm -rf`): renaming an open bottle (`engine.dart:629`) says to stop it in Bodega.
- **Given** a code with no case, **when** `flutter analyze` runs, **then** it reports the switch as not exhaustive.
- **Check:** `flutter test test/app/text_test.dart`; `flutter analyze` after deleting one case in a scratch copy.

## L9 · Details are copied, never shown
An error's `detail` (the engine's English message, a tool's stderr, Dio's text) shall never be rendered, and each error panel (design §6) shall offer "Copy details" when it is set, while toasts show the message only.
- **Given** an `AppError` with `detail: 'stderr: boom'` on each error panel and in the update dialog, **then** `boom` is not on screen and "Copy details" is; **when** it is clicked, **then** the clipboard holds the detail and a "Copied" toast shows; with no detail, there is no button.
- **Check:** `flutter test test/app/pages_test.dart test/app/update_dialog_test.dart`.

## L10 · Plurals
Every count shall be worded with an ICU `plural`, two in one message when a sentence has two counts (`library_page.dart:166`).
- **Given** the library header in `en`, **then** 1 app in 1 bottle reads "1 app in 1 bottle", and 3 in 2 reads "3 apps in 2 bottles" (`library_page_test.dart:136` pinned the old bug); the message alone gives "2 apps in 3 bottles" for 2 in 3, which the page cannot show, since it counts the bottles of the apps it shows.
- **Given** `es`, **when** either count of that header, or a bottle's app count (`bottle_row.dart:113`, `bottle_detail_page.dart:66`), goes from 2 to 1, **then** the text changes in more than its digit.
- **Check:** `flutter test test/app/library_page_test.dart test/app/text_test.dart`.

## L11 · Gender
A word that agrees with a noun shall have one key per noun, never one shared because the English matches.
- **Given** "Installed" on a catalog app (`catalog_chips.dart:30`) and on a backend (`backend_card.dart:66`), and "Automatic" for the graphics backend (`bottle_column.dart:257`) and for the GPU (`:493`), **then** each pair is two keys whose texts are equal in `en` and differ in `es`.
- **Check:** `flutter test test/app/text_test.dart`.

## L12 · Placeholders and whole sentences
Each sentence shall be one message whose variable parts are placeholders declared in its `@key` with a `type` and an `example`, so no sentence is joined from pieces and a label quoted inside one comes in as a placeholder from its own key.
- **Given** a placeholder declared in `@key` but missing from one message, or a message that uses an undeclared one, **when** the parity test runs, **then** it fails and names the key and the placeholder.
- **Given** the options tooltip of an app (`app_card.dart:217`), **then** `en` reads "Steam options" for Steam; a bottle row's label (`bottle_row.dart:68`, `:71`) is one `select` message with a different text for each state; the misfit warning (`bottle_column.dart:264-276`) contains the active language's text of the Automatic option.
- **Check:** the parity test; `flutter test test/app/text_test.dart`.

## L13 · Sizes and percents
Sizes and percents shall be formatted for the active locale by the formats of their placeholders (intl's `NumberFormat`), and sizes shall be MB of 10^6 bytes, as Finder and GNOME Files count.
- **Given** a download at 1,234,000,000 of 2,468,000,000 bytes, **then** the progress text has `50%`, `1,234 MB` and `2,468 MB` in `en`, and `50 %` (with U+00A0), `1.234 MB` and `2.468 MB` in `es`.
- **Given** 150 × 2^20 bytes (`pages_test.dart`, "the downloading panel fits at … px"), **then** it shows `157 MB`, not `150 MB` as today (`install_panel.dart:16`).
- **Check:** `flutter test test/app/text_test.dart test/app/pages_test.dart`.

## L14 · Desktop wording
Copy shall use desktop words in both languages: click and double-click, never tap or touch.
- **Given** an app card and an app row (`app_card.dart:111`, `app_row.dart:94`), **then** their semantics hint says to double-click to open, in both locales.
- **When** `grep -niE '\btap|\btouch|toque|\btoca' lib/l10n/app_*.arb` runs, **then** it prints nothing.
- **Check:** `flutter test test/app/app_card_test.dart test/app/app_row_test.dart`; the grep above.

## L15 · One meaning, one text
A meaning shall have one key, used wherever it shows, and the copy settled in design §3 shall replace today's variants.
- **Given** a blocked catalog app, **then** the catalog chips (`catalog_chips.dart:18`) and the add-app card (`popular_app_card.dart:25`) show the same text; a bad name shows the same `bottleNameRule` in the new-bottle and rename dialogs (`new_bottle_dialog.dart:40`, `rename_bottle_dialog.dart:49`); the app menu and the library toggle say "Add to library" alike (`app_menu.dart:51`, `library_toggle.dart:57`).
- **Given** a download in the install panel, the update dialog and a backend card, **then** all three show `downloadProgress`, or `downloadProgressNoTotal` when the total is unknown.
- **Check:** `flutter test test/app/pages_test.dart test/app/new_bottle_dialog_test.dart test/app/update_dialog_test.dart`.

## L16 · Catalog prose by app id
The catalog's prose (status note, flaky note, notes and known issues) shall come from ARB keys per entry and field, worded by app id in `catalog_text.dart`, with the English text in `catalog_data.dart` as its source.
- **Given** each entry of `engine.catalogEntries()`, **when** `catalogProse(id, en)` is read, **then** it equals the entry's text field by field; an id with no keys fails the test and is named.
- **Given** `es`, **then** each entry keeps the shape (as many notes and issues, a flaky note only where English has one) with no string equal to its English one, and the Steam detail page shows `catalogProse('steam', es)`.
- **Check:** `flutter test test/app/catalog_text_test.dart test/app/pages_test.dart`.

## L17 · Release notes as written
The update dialog shall show a release's notes and its package command as published, untranslated, in either locale.
- **Given** an update whose notes are `Fixes for Blur` with a `.deb` command, **when** the dialog renders in `en` and in `es`, **then** both show the notes (`update_dialog.dart:43`) and the command unchanged.
- **Check:** `flutter test test/app/update_dialog_test.dart`.

## L18 · No overflow in either language
No screen, dialog or panel shall overflow in either language at the widths that matter: 720, 801, 1150 and 1921 px (`pages_test.dart:353`).
- **Given** every case of `pages_test.dart` with its long texts, the Settings dialog included, **when** each renders at each width in `en` and in `es`, **then** no overflow or other exception is reported.
- **Check:** `flutter test test/app/pages_test.dart`.

## L19 · No Spanish in the app's Dart code
No Dart file in `lib/` (outside the generated `lib/l10n/`) or `test/` shall hold Spanish in code, comments or fixtures, except the name `Español` in the Settings dialog, and tests shall reach Spanish only through `lookupAppL10n(const Locale('es'))` (the engine: `engine-codes.md`).
- **When** `grep -rniE '[áéíóúñ¿¡]|\b(botellas?|instalar|cancelar|abrir|cerrar|parar|elegir|nueva|agregar|carpeta|una|los|las|para|esta|con)\b' lib test --include='*.dart' --exclude-dir=l10n` runs, **then** it prints only the `Español` line of `settings_dialog.dart`.
- **Check:** the grep above.
