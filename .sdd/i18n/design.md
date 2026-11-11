# Design · i18n

Paths: `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`; `engine/` is `packages/engine/`; `gc:` is `gym-coach/app/`. Bare Dart file names are unique in the repo.

## 1. gen-l10n
- `apps/bodega/l10n.yaml`:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppL10n
  required-resource-attributes: true
  untranslated-messages-file: lib/l10n/untranslated.json
  ```
  English is the template: the code is English and `.claude/CLAUDE.md:7` calls Spanish the translation (gym-coach does the opposite, `gc:l10n.yaml:4`). `required-resource-attributes` makes gen-l10n refuse a key without its `@key`. The report sits beside the ARBs because gen-l10n writes it without creating folders, and `build/` does not exist on a fresh clone.
- `flutter_localizations: {sdk: flutter}` and `intl: any` in `dependencies` (`apps/bodega/pubspec.yaml:31-55`), `generate: true` under `flutter:` (`:79`). Both packages are already in the root lockfile (`pubspec.lock:393-397`, `:536-543`): nothing new is downloaded.
- `lib/l10n/app_localizations*.dart` and `untranslated.json` are gitignored beside the build_runner outputs (`apps/bodega/.gitignore:50-53`). `flutter pub get`, `run` and `build` regenerate them, and CI and both packaging scripts run `flutter pub get` first (`test.yml:44`, `tool/package_linux.sh:40`, `tool/package_macos.sh:107`).
- `lib/l10n/l10n.dart` re-exports `package:bodega/l10n/app_localizations.dart` and adds a non-nullable `context.l10n` whose assert names the fix (pump through `wrapApp` or `wrapRouter`): `gc:lib/l10n/l10n.dart:7-23`, with absolute imports (`code-style.md:10`). gym-coach's `resolveAppLocale` (`gc:lib/l10n/l10n.dart:25-34`, Spanish fallback) is not copied.
- No `localeResolutionCallback`: it sees only the first preferred locale. Flutter 3.47's default `basicLocaleListResolution` (`packages/flutter/lib/src/widgets/app.dart:146` in the SDK) walks the whole ordered list (macOS `preferredLanguages`; on Linux `LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`), so `[fr, es]` gets Spanish, and falls back to `supportedLocales.first`, which gen-l10n sorts to `en`. Any other language and `LANG=C` get English, like `developmentRegion = en` (`project.pbxproj:263`).

## 2. Language choice
- `PreferenceKey.language` (`preference.dart:4-10`) with `getLanguage()` and `saveLanguage(String? code)`; null removes the key and means System.
- `LocaleBloc` in `lib/app/bloc/locale/`: `@lazySingleton` like `ViewModeBloc` (`view_mode_bloc.dart:11`); it reads `Preferences` in its constructor like `ThemeBloc` (`theme_bloc.dart:14-15`), so the first frame is already in the right language (gym-coach needs a load event, `gc:lib/main.dart:51`). One event, `LocaleEvent.set(String? code)` = `LocaleSetEvent`; state `LocaleState({String? code})`, null = System (Freezed 4 `copyWith` sets null back). A code missing from `AppL10n.supportedLocales`, saved or set, becomes System, so the state holds only `en`, `es` or null. `set` emits the new state before it saves, unlike `ViewModeBloc`, which saves first: the switch shows at once even when the write is slow.
- `main.dart`: `BlocProvider.value(value: getIt<LocaleBloc>())` joins the providers (`:48-61`). The `BlocBuilder<ThemeBloc>` (`:63`) becomes a private `_AppView` that watches the theme and selects the code, and `MaterialApp.router` (`:65-76`) gets `locale` (null follows the system), `localizationsDelegates: AppL10n.localizationsDelegates` (with the Material, Cupertino and Widgets delegates, so the text-field menu and default tooltips follow) and `supportedLocales: AppL10n.supportedLocales`. `title: 'Bodega'` stays: a brand.
- `router.dart:50` gets an `errorBuilder` with a localized `EmptyState`, instead of go_router's English "Page Not Found".
- Entry point: `LanguageMenu(expanded: expanded)` in the sidebar footer (`side_bar.dart:192-196`), between Backends (`:186-191`) and `AppVersion` (`:198`). Its anchor is a `SideBarItem` with `Icons.translate_rounded` and the label "Language" (`navLanguage`, "Idioma" in Spanish; `language_menu.dart:49-55`). `SideBarItem` already fits the 68 px rail (`side_bar_item.dart:77-79`), shows its label as a tooltip there (`:61-62`) and is a button for semantics (`:57-60`). The item opens a menu, not a page, so it is never the selected item.
- `lib/app/shared/widgets/language_menu.dart`: `LanguageMenu({required bool expanded})`, a `MenuAnchor` whose item opens and closes a menu of three `MenuItemButton`s (`:24-48`): System (`languageSystem`; null code), `English` and `Español`. The current one shows a check; for semantics, the three are one group and the current one is checked. The two names are constants, `LanguageMenu.english` and `LanguageMenu.spanish`, not keys: each is written in its own language, so it can be read whatever is active (`gc:lib/app/shared/widgets/language_switch.dart:16`). A choice adds `LocaleEvent.set` and applies at once, and the menu closes; the current one adds nothing. The menu has no title and no Close button.
- On 2026-11-11 the user replaced the Settings dialog that M3 first built (`settings_dialog.dart`) with this menu.
- No theme toggle (hidden on purpose, `main.dart:62`). No `AppleLanguages` write: native text follows the system. The menu bar's "Preferences…" item (`MainMenu.xib:36`) stays unwired: there is no dialog for it to open.

## 3. ARB conventions
- `app_en.arb` holds every message and its `@key`; `app_es.arb` holds `@@locale` and the messages only.
- Keys are lowerCamelCase, area first: `common` (Cancel ×11, Install ×7, Stop, Open, Close…), `nav`, `library`, `bottle`, `catalog`, `backend`, `setup`, `addApp`, `install`, `update`, `language`, `err` (one per `AppError` code), `issue`, `step`, `hint`, `graphics`; catalog prose as in §7.
- Every `@key` has a `description`: where the text shows and, for short labels and state words, the noun it goes with ("Chip on a bottle row: the bottle is stopped").
- Placeholders are declared in `@key` with `type` and `example`: `String` for names and paths, `int` for counts and exit codes, `double` with a gen-l10n `format` for percents (`percentPattern`) and sizes (`decimalPatternDigits`, `decimalDigits: 0`). The generated code formats them with intl's `NumberFormat` for the active locale ("1,234" and "1.234"; "42%" and "42 %"). Sizes are MB of 10^6 bytes, as Finder and GNOME Files count; two helpers divide by 2^20 and say MB today (`install_panel.dart:16`, `update_dialog.dart:12`).
- ICU `plural` for every count, two in one message when a sentence has two (`library_page.dart:166`); `select` for state words (`bottle_row.dart:30-34` → `:68`, `:71`), with its required `other`.
- One key per meaning, never merged because the English matches: "Closed", "Installed", "Automatic" agree with different Spanish nouns (botella, app, backend, GPU).
- When two keys of one meaning fold, the kept text is the variant most sites already use. A sidebar item that names a place and the title of the page or dialog it opens are one key, the place's name (`navLibrary`, `navBackends`); a command and the title of the dialog or page it opens are two (`navNewBottle`/`newBottleTitle`). The language item (`navLanguage`) opens a menu with no title.
- No sentence built from pieces: one message per sentence, or several whole sentences that always show together; sentences chosen apart are separate messages. A count inside a list of fragments joined by "·" may come in as a placeholder holding its own plural (`bottleDetailSummary`). A label quoted inside a sentence comes from its own key as a placeholder ("Automatic" in the misfit warning, `bottle_column.dart:264-276`).
- Desktop wording: click and double-click, never tap (`app_card.dart:111`, `app_row.dart:94`). Sentence case in both languages. English uses contractions (doesn't, can't, couldn't), as M1's copy does; Spanish keeps "tú".
- Settled copy:

| Today | Decision |
|---|---|
| "Sin soporte" and "Bloqueado" for `blocked` (`popular_app_card.dart:25`, `catalog_chips.dart:18`) | one key, "Not supported" / "Sin soporte", through one `catalogStatusText` |
| two bottle-name rules (`new_bottle_dialog.dart:40`, `rename_bottle_dialog.dart:49`) | one `bottleNameRule` with the engine's rule (`engine.dart:55-60`): letters without accents, numbers, - and _, up to 64, starting with a letter or number |
| "Agregar a (la) biblioteca" (`app_menu.dart:51`, `library_toggle.dart:57`) | "Add to library" / "Agregar a la biblioteca" |
| three progress texts (`install_panel.dart:16-24`, `update_dialog.dart:66-68`, `backend_card.dart:100`) | `downloadProgress(percent, received, total)` and `downloadProgressNoTotal(received)` for all three |
| seven "closes what is open" sentences (`stop_bottle.dart:13`, `bottle_column.dart:61`, `:85`, `:441`, `:458`, `probe_dialog.dart:42`, `windows_user_dialog.dart:63`) | `bottleStopConfirm(bottle)` in confirmations; `bottleChangeCloses` under settings that stop the bottle |

- Code: 49 `const Text` lose `const`; the `static const` tables with words (`backend_card.dart:19-24`, `bottle_column.dart:48-55`, `catalog_detail_page.dart:20-26`) become functions of `AppL10n`, while `windowsNames` (`bottle_column.dart:40-45`, product names) stays; the 7 `XTypeGroup` labels (e.g. `add_app_dialog.dart:22`) are built in the handler; the 6 toasts shown after an `await` take `final l10n = context.l10n;` before it and check `context.mounted`.

## 4. Engine codes
- New `engine/lib/failures.dart`, a `part of 'engine.dart'` like the others (`engine.dart:14-21`):
  ```dart
  sealed class EngineFailure implements Exception {
    const EngineFailure();
    /// English, for the CLI and logs. The app never shows it.
    String get message;
    @override
    String toString() => message;
  }
  final class BottleOpen extends EngineFailure {
    const BottleOpen(this.bottle);
    final String bottle;
    @override
    String get message => 'the bottle $bottle is open: bodega stop $bottle';
  }
  ```
  Messages keep the CLI's command hints, in English. The CLI prints `bodega: $e` (`bin/bodega.dart:254`; the `FormatException` branch goes).
- 31 final subclasses replace the 74 throws (66 literals, 3 computed, 5 `FormatException`):

| Subclass (fields) | Replaces | n |
|---|---|---|
| `BottleNotFound(bottle)` | `engine.dart:396` | 1 |
| `BottleExists(bottle)` | `engine.dart:181`, `:627`; `catalog.dart:87` | 3 |
| `BottleNotReady(bottle)` | `engine.dart:255`; `catalog.dart:91` | 2 |
| `BottleOpen(bottle)` | `engine.dart:629` | 1 |
| `BottleSetupFailed(log, timedOut)` | `engine.dart:197`, `:203` | 2 |
| `BadBottleName(name)` | `engine.dart:57` | 1 |
| `BadWindowsPath(PathProblem problem)` | `engine.dart:29`, `:32`, `:262` | 3 |
| `BadUserName(user, UserNameProblem problem)` | `backends.dart:637`, `:655` (`taken`) | 2 |
| `AppNotFound(bottle, key?)` | `apps.dart:178`, `:216`, `:384` (no key), `:391` | 4 |
| `AppAlreadyAdded(bottle)` | `apps.dart:149` | 1 |
| `MissingFile(path)` | `apps.dart:143` | 1 |
| `ChecksumMissing(file)` | `engine.dart:116` | 1 |
| `ChecksumMismatch(file)` | `engine.dart:124`, `:500`; `backends.dart:45`, `:352`; `catalog.dart:115` | 5 |
| `IncompleteArchive(archive, missing)` | `engine.dart:137`, `:514`; `backends.dart:56` | 3 |
| `CorruptData(source, detail)` | `apps.dart:62`; `backends.dart:501`; `fixes.dart:22` | 3 |
| `NoRuntime()` | `engine.dart:169` | 1 |
| `AlreadyInstalled(path)` | `engine.dart:110`; `backends.dart:288` | 2 |
| `NotAvailable(what, host)` | `backends.dart:34`, `:122`, `:229`; `engine.dart:494`; `platform.dart:26` | 5 |
| `NotDownloadable(backend)` | `backends.dart:36`, `:39` | 2 |
| `BackendNotInstalled(backend)` | `backends.dart:755`; `catalog.dart:84` | 2 |
| `BadChoice(ChoiceKind kind, value)` | `backends.dart:372`, `:378`, `:385`, `:507`, `:898`; `catalog.dart:58`; `fixes.dart:102` | 7 |
| `NoD3DMetal(source, missing)` | `backends.dart:166`, `:194`, `:249`, `:252`, `:259` | 5 |
| `CrossOverCopy()` | `backends.dart:235` | 1 |
| `MountFailed(image, detail)` | `backends.dart:145` | 1 |
| `Cancelled()`, `LicenseNotAccepted()` | `backends.dart:178`; `:180` | 2 |
| `CatalogBlocked(id)`, `NotHttps(url)` | `catalog.dart:81`; `:98` | 2 |
| `WineToolFailed(WineTool tool, exitCode, log)` | `engine.dart:191`; `catalog.dart:170`, `:189`; `backends.dart:681`, `:703`, `:722`; `fixes.dart:177` | 7 |
| `InstallerNoExe(exe, log)` | `catalog.dart:197` | 1 |
| `ProcessFailed(command, exitCode?, output)` | `engine.dart:149`, `:587`; `platform_linux.dart:430` | 3 |

- `BottleExists` and `BottleNotReady` carry the bottle's name only, so their CLI hints name its folder as `bottles/<bottle>` instead of `rm -rf "<dir>"`. `CatalogBlocked(id)` carries the id only, no title or status note: its message points to `bodega catalog show <id>`. `IncompleteArchive` names the runtime id (`engine-11.0`) as its archive when the files come from both tarballs (`engine.dart:137`). `CorruptData` for an unknown fix step names the source `fixes_data.dart`: the fixes are a JSON string with no path (`fixes.dart:22`). `NoD3DMetal` says "missing" also for a module that is a separate copy instead of the library itself (`backends.dart:259`). `BadChoice`'s `ChoiceKind` is `backend` (allows `auto`), `testBackend` (a probe's backend, never `auto`), `gpu`, `sync`, `windows`, `catalogApp` or `fix`.
- Other text becomes data. Each type has an English text for the CLI: an `english` field on the enums that need no data, a `describe…` function in `engine/lib/english.dart` (a part) for the records.

| Type | Replaces | Values |
|---|---|---|
| `HostIssue = ({HostIssueKind kind, String? subject, String? command})` | `platform.dart:4`; texts `platform_mac.dart:126-127`, `platform_linux.dart:115-134`, `gamepads.dart:70-82` | `noRosetta`, `unsupportedCpu`, `noVulkan`, `noAudio`, `padNoAccess` (subject: the pad's name only; the CLI's `pads` still lists its device node), `noSdl` |
| `BackendRole` from `backendRole` (was `backendUse`, `platform.dart:68`) | `platform_mac.dart:218-222`, `platform_linux.dart:241-243` | `dx11to12x64`, `dx10to11`, `everythingElse`, `dx8to12`, `everythingSlower` |
| `InstallStep = ({InstallStepKind kind, String? subject})` | `catalog.dart:101-192` | `unpinnedDownload` (host), `downloading`, `syncMismatch` (the bottle's sync), `creatingBottle` (bottle), `registry` (value), `runningInstaller`, `waiting` |
| `GptkStep` | `backends.dart:154`, `:174`, `:196` | `opening`, `acceptLicense`, `importing` |
| `LogHint`, each with its log marker | `_hints` (`engine.dart:363-375`); `hintsIn` (`:379`) returns `List<LogHint>` | `freeType`, `gnuTls`, `otherServer`, `cannotOpen`, `fixNotApplied` |
| `AntiCheatHint = ({String? game})` | `antiCheatHints` (`catalog.dart:236`), text `:271-274` | null: the EAC log names no game. No host: the app says "under Wine", and only the CLI's describer names the host |
| `UserNameProblem` | `badUser` (`backends.dart:617-626`) | `empty`, `tooLong`, `badCharacter`, `onlyDots`, `taken` |
| `PathProblem = ({String part, String path})` | `winPathProblem` (`engine.dart:43-51`) | the bad component and the whole path |
| `String?` | `'desconocida'` (`backends.dart:220`) | null: version unknown |

- Logs and CLI turn English: `# aviso` → `# note` (`engine.dart:579`); labels `usuario`, `resolucion`, `mandos` (`backends.dart:678`, `:700`, `platform_mac.dart:317`); origins `opcion`, `botella` (`backends.dart:743`, `:747`); `fixNotApplied` (`fixes.dart:125`); `_usage` (`bin/bodega.dart:6-31`) and the other CLI sites. No shim: hints are read only from the run that just ended (`library_bloc.dart:132-136`).

## 5. data/ and domain/
- `AppError` (`app_error.dart:7-12`) becomes a union of codes. It stays a Freezed `sealed class`, as at `:8`, because `error_text.dart` switches over it exhaustively (`code-style.md:15`'s `abstract` is for one-factory classes), and implements `Exception` because `data/` throws it. Checked with freezed 4.0.1: it builds, `detail` is readable on `AppError`, the switch is exhaustive, equality holds.
  ```dart
  @freezed
  sealed class AppError with _$AppError implements Exception {
    const factory AppError.bottleOpen(String bottle, {String? detail}) = BottleOpenError;
    const factory AppError.wineToolFailed(WineTool tool, int exitCode, String log, {String? detail}) = WineToolFailedError;
    // … one factory per code, each with {String? detail} …
    const factory AppError.network({String? detail}) = NetworkError;
    const factory AppError.unknown({String? detail}) = UnknownError;
  }
  ```
  Codes (31): `bottleNotFound`, `bottleExists`, `bottleNotReady`, `bottleOpen`, `bottleSetupFailed(log, timedOut)`, `badBottleName`, `badUserName(user, problem)`, `badPath(PathProblem)`, `appNotFound(bottle, key?)`, `appAlreadyAdded`, `badEnvLine(line, text)` (from `run_options_bloc.dart:88`), `noRuntime`, `alreadyInstalled`, `checksumMismatch`, `incompleteArchive`, `corruptData`, `backendNotInstalled`, `noD3DMetal`, `crossOverCopy`, `mountFailed`, `licenseNotAccepted`, `cancelled`, `wineToolFailed`, `installerNoExe`, `processFailed(command, exitCode?)`, `downloadCut(received, total)`, `updateNotInstallable`, `updateNoChecksum`, `updateNotWritable`, `network`, `unknown`. Fields follow the engine subclass of the same name, except that `corruptData(source)`, `mountFailed(image)` and `processFailed(command, exitCode?)` drop the engine's raw-text field (`CorruptData.detail`, `MountFailed.detail`, `ProcessFailed.output`), which would clash with `detail`: that text reaches `detail` inside the engine's message. A `?` field is a required nullable positional: `AppError.appNotFound('steam', null)`. `detail` holds the engine's English message, a tool's stderr or Dio's text.
- `repositoryCall` (`repository_call.dart:9-27`): `on AppError` stays; `on String` and `on FormatException` (`:16-19`) become `on engine.EngineFailure` → `appErrorOf(failure)`; `DioException` → `network(detail: …)` (`:20-23`); anything else → `unknown(detail: '$e')` (`:24-25`). `appErrorOf` is one exhaustive switch with no default branch, each case passing `detail: failure.message`. Subclasses map to the code of the same name, except: `BadWindowsPath`, `MissingFile` and `ChecksumMissing` become `badPath`, and five go to `unknown` because the UI never triggers them: `NotAvailable` (capabilities hide them, `backends_page.dart:48`), `NotDownloadable` (only pinned backends get a download button, `backend_card.dart:116`), `BadChoice` (choices come from lists), `CatalogBlocked` (no install button, `popular_app_card.dart:64-65`), `NotHttps` (the app passes the installer it downloaded).
- `backend_repository_impl.dart:67` catches `engine.EngineFailure` instead of `String` to delete a bad tarball. Mappers import the engine `as engine` (`architecture.md:26`): domain twins share names with engine types.
- The 14 data sentences become codes:

| Site | Code |
|---|---|
| `install_repository_impl.dart:29` | `bottleExists(id)`; `errBottleExists` gives no advice, since here the user names no bottle and the dropdown already offers that one |
| `backend_repository_impl.dart:54`, `downloader.dart:100` | `unknown(detail)`: the UI cannot reach them |
| `update_repository_impl.dart:132`, `:188`, `:189` | `updateNotInstallable` |
| `:146`, `:156` | `updateNoChecksum(asset)`, `checksumMismatch(asset)`: the asset's name, not its temp path |
| `:196`, `:215` | `updateNotWritable(folder)`, `incompleteArchive(dmg, 'Bodega.app')` |
| `:254` | `processFailed(program, exitCode, detail: stderr)`: the program's path (`/usr/bin/hdiutil`), not its command line |
| `add_app_repository_impl.dart:19` | returns `PathProblem.missing(path)` |
| `repository_call.dart:22`, `downloader.dart:86` | `network(detail)`, `downloadCut(received, total)` |

- Mappers stop copying engine text. `HostIssue` keeps `kind`, `subject`, `command` (`host_issue.dart:9-13`; `runtime_repository_impl.dart:26-30`, `gamepad_repository_impl.dart:29-33`). `BackendInfo.use` becomes `BackendRole? role` (`backend_info.dart:15`, `backend_repository_impl.dart:32`). `CatalogApp` drops `statusNote`, `notes`, `knownIssues`, and `flaky` becomes `bool` (`catalog_app.dart:21-29`, `catalog_repository_impl.dart:28-39`). Steps arrive as `InstallStep` and `GptkStep` (`install_repository.dart:19`, `backend_repository.dart:33`, `install_repository_impl.dart:57`); hints as a `RunHint` union, `log(LogHint)` or `antiCheat(game)` (`library_repository.dart:51`, `:53`; `library_repository_impl.dart:107`, `:116`); problems as `UserNameProblem?` (`bottle_repository.dart:30`, `bottle_repository_impl.dart:71`) and a `PathProblem` union, `missing` or `windowsName` (`add_app_repository.dart:6`). Domain twins are Freezed entities or enums; mappers switch exhaustively, so a new engine code fails the build until every layer handles it.
- State keeps codes, so a live switch rewords it: `InstallState.step` (`install_state.dart:17`), `BackendsState.gptkStep` (`backends_state.dart:25`), `LibraryState.hints` and `toast` (`library_state.dart:11`, `:14`; equality keeps the de-dup at `library_bloc.dart:203`). `installD3DMetalDmg` returns `String?`, so `BackendsState.gptkInstalled` (`:28`) becomes `({String? version})?` and an unknown version still fires the toast (`gptk_section.dart:50-56`).
- `ExeGraphics.label` (`exe_graphics.dart:19`) and `.warning` (`:22-25`) move to `app/shared/text/backend_text.dart`; `misfits` stays.

## 6. Words for codes: `lib/app/shared/text/`
- One file per family, each a function or extension taking `AppL10n` with an exhaustive `switch` and no `_ =>`, as `gc:lib/app/shared/text/error_text.dart:12-41`: `error_text.dart` (`AppError.localized(l10n)`), `issue_text.dart`, `step_text.dart`, `hint_text.dart`, `backend_text.dart` (roles, descriptions, graphics label and misfit warning), `catalog_text.dart` (§7, status and source labels), `problem_text.dart` (user names, paths), `progress_text.dart`. Tables keyed by a `String` (backend names, catalog sources) keep a default: the raw name for a label, `null` for a description the card can leave out.
- The 14 `.message` sites (e.g. `shell_body.dart:42`, `install_panel.dart:58`, `setup_page.dart:43`) call `error.localized(context.l10n)`. Messages never give commands: where the engine gives one, they give GUI advice (an open bottle says to stop it, not `bodega stop`, `engine.dart:629`), or none when no advice fits every place the code shows (`bottleExists`, §5).
- `detail` is never rendered. The error panels with `SelectableText` (`install_panel.dart:57`, `backends_page.dart:40`, `catalog_page.dart:75`, `setup_page.dart:42`, `new_bottle_dialog.dart:223`, `run_options_dialog.dart:217`, `add_app_dialog.dart:138` and its `_popularBody`, the catalog's error on the Others tab) and the update dialog's error (`update_dialog.dart:84`) show a shared `CopyDetailsButton` when `detail` is not null: it copies it to the clipboard and toasts "Copied". The button sits under the error; where the error sits in a bounded scroll (`new_bottle_dialog.dart`), it goes inside that scroll, under the text, so the text keeps its room at 720×480. `UpdateDialog` is `scrollable: true`, so it fits 720×480 with an error. Toasts show the message only.

## 7. Catalog prose
- `catalog_data.dart` (7 entries, 56 strings) turns English: the CLI prints it, and the engine has no Flutter, intl or assets (`catalog_data.dart:2`). `{es, en}` fields in the data (`gc:lib/app/shared/text/exercise_name.dart:8-12`) would leave Spanish in the engine.
- The prose says what to do in words that fit both the CLI and the GUI, never a `bodega` command: "stop the bottle and open it again", not `bodega stop steam`; "open it with the D3DMetal backend", not `bodega open --backend d3dmetal rockstar`.
- ARB keys per entry and field: `catalogSteamStatusNote`, `catalogEaAppFlaky`, `catalogSteamNote1`, `catalogSteamIssue1Symptom`, `catalogSteamIssue1Fix`.
- `catalogProse(String id, AppL10n l10n)` in `catalog_text.dart` returns `({String statusNote, String? flaky, List<String> notes, List<(String, String)> issues})?`, one case per id and `_ => null` (ids are strings). Read by `catalog_detail_page.dart:78-114`, `install_panel.dart:51-53`, `popular_app_card.dart:51`.
- `test/app/catalog_text_test.dart`, over `engine.catalogEntries()`: in `en`, `catalogProse` equals the entry's text field by field, so a catalog update cannot leave the app behind; in `es`, same shape and no string equal to its English one.

## 8. Native text
- `apps/bodega/macos/Runner/Info.plist:27-34` raw values turn English; the development region is `en` (`:5-6`). `Runner/en.lproj/InfoPlist.strings` and `Runner/es.lproj/InfoPlist.strings` hold the four `NS…UsageDescription` keys. `CFBundleLocalizations` (`en`, `es`) in `Info.plist` tells macOS that the app speaks Spanish although Flutter's strings are not in `.lproj`, which also lists Bodega for a per-app language in System Settings. `MainFlutterWindow.swift:25-27` asks for the microphone before Flutter draws: that prompt uses these strings, in the system language. `CFBundleName` stays out of `InfoPlist.strings`, so the app is "Bodega" in both languages; only the menu words around it change ("Acerca de Bodega").
- Known gap, no task: the About panel shows `NSHumanReadableCopyright` in English in both languages. `Info.plist` sets it to `$(PRODUCT_COPYRIGHT)` (`Runner/Configs/AppInfo.xcconfig:14`), and `.strings` files do not expand build settings, so a Spanish line would have to be written out whole in `es.lproj/InfoPlist.strings` by hand.
- `Runner/es.lproj/MainMenu.strings`: exported with `xcrun ibtool --export-strings-file` from `Base.lproj/MainMenu.xib` (52 titled items), then translated. Base stays the English source.
- Xcode project: `es` in `knownRegions` (`project.pbxproj:265-268`), an `InfoPlist.strings` variant group (en, es) in Resources, `es` in the `MainMenu.xib` group (`:379-387`). Not by hand: a made-up object id or a missing build file breaks the project quietly. Headless, a one-off Ruby script with the `xcodeproj` gem (1.27.0, installed with CocoaPods on the dev Mac), kept out of the repo; in Xcode, Project › Info › Localizations › +. Checked with `plutil -lint`, `flutter build macos`, and both `.strings` inside `Bodega.app/Contents/Resources/es.lproj/`.
- Linux: `packaging/linux/bodega.desktop:4` is already English. Add `Comment[es]`, `GenericName` and `GenericName[es]`, `Keywords` and `Keywords[es]` (lists end in `;`: house style, which no tool enforces, since desktop-file-utils 0.23 made that `;` optional). The file feeds the .deb, the AppImage and the Arch package (`packaging/arch/build_arch.sh:23`). `test.yml` gets a step that installs `desktop-file-utils` and runs `desktop-file-validate packaging/linux/bodega.desktop`; `packaging/linux/**` joins its `paths:` (`:6-11`).

## 9. Tests
- `test/support/pump.dart`: `wrapApp(Widget home, {Locale locale = const Locale('en'), ThemeData? theme, bool breakpoints = false})` and `wrapRouter(GoRouter router, {Locale locale = const Locale('en'), bool breakpoints = false})`, with `AppL10n` delegates and locales, pinned to `en` so the machine's language never matters (`gc:test/support/pump.dart:10-15`). Every `MaterialApp` in `test/` (20 in 15 files) goes through them: M1's first task, since each hits the `context.l10n` assert.
- Assertions read English; Spanish fixtures and mocks turn English (`pages_test.dart:86-87`; the 36 `AppError`s built from text become codes). Spanish behaviour is compared with `lookupAppL10n(const Locale('es'))` called with the same arguments, never a Spanish literal. `library_page_test.dart:136` asserts the fixed plural, "1 app in 1 bottle".
- `pages_test.dart:353` loops its four widths over `en` and `es`, and opens the language menu at the foot of a column, as in the sidebar. Its providers hold a mocked `LocaleBloc`, which the real sidebar of its group "the routes" reads.
- `test/l10n_parity_test.dart`, after `gc:test/l10n_parity_test.dart:42-85`: keys both ways; every `@key` has a description; every placeholder declared in `@key` appears in both messages and neither uses an undeclared one (a small ICU scan tells argument braces from branch braces; gym-coach's `_placeholdersOf`, `:27-31`, keeps only the first plural or select argument); no message equal in both files unless it is placeholders and allowlisted words: brand words (Bodega, Backends, Wine, D3DMetal, DXVK, DLSS, msync, GameMode, Game Porting Toolkit…), and words and units the Spanish UI uses unchanged (`app`, `apps`, `MB`, `bits`); `untranslated.json` is `{}`.
- `test/app/catalog_text_test.dart` (§7); `LocaleBloc` with `bloc_test` and a mocked `Preferences` (`code-style.md:24`).
- The language menu: `test/app/language_menu_test.dart` finds three entries, the current one checked, in `en` and `es`; an entry adds its choice and closes the menu, System adds `set(null)`, and the current entry adds nothing. `main_shell_test.dart` places the item and opens the menu at 1000 and 600 px. `app_locale_test.dart` adds the menu's event to the app's own `LocaleBloc`, since the setup page has no sidebar: the app switches at once and the choice is saved.
- Engine tests assert types and fields (`throwsA(isA<BottleNotFound>().having((f) => f.bottle, 'bottle', 'nope'))` at `engine_test.dart:306`), about 52 sites, and `catalog_test.dart:306-307` checks an `AntiCheatHint`. Each describer gets an English test. Skip reasons turn English (`engine_test.dart:444`, `linux_test.dart:113`).
- Checks that test nothing: `pages_test.dart:724` (a label removed in 79f772f) goes; `options_test.dart:290` checks step kinds; the 12 `findsNothing` on copy point at keys.
- `tool/check_layers.sh`, after `:27-28`: `check 'only app/ and main.dart import package:bodega/l10n/' 'package:bodega/l10n/' lib/domain lib/data lib/device lib/di.dart`. gen-l10n's own `import 'app_localizations_en.dart';` passes the absolute-import rule (`:29`).
- `tool/smoke_linux.sh:46` greps `dxvk: installed`, in the same commit as the CLI text (`bin/bodega.dart:199`).

## 10. Rules and docs
- `.claude/CLAUDE.md:7`: the only Spanish in the repo is the translation: `apps/bodega/lib/l10n/app_es.arb`, `apps/bodega/macos/Runner/es.lproj/*.strings` and the `[es]` keys of `packaging/linux/bodega.desktop`; besides them, only the language menu's own name for Spanish (§2, L19). The line describes that name without writing it, since an accented letter would put `CLAUDE.md` in N14's repo grep.
- `.claude/CLAUDE.md` Commands (`:42-54`): `flutter gen-l10n` after editing an ARB (`flutter pub get`, `run` and `build` also run it; build_runner does not). `:56` adds `app_localizations*.dart` and `untranslated.json` to the generated files. Its Freezed line (`:38`), which gave `sealed class` to events only, also gives it to unions with several factories, like `AppError`, as `code-style.md` does below. Layers points to `architecture.md`'s "Text" section.
- `code-style.md:21` → "Code in English; what the user reads comes from `lib/l10n/` through `context.l10n`". Freezed (`:13-16`): a union with several factories, like `AppError`, is a `sealed class`. Tests (`:23-26`): widget tests pump through `wrapApp` or `wrapRouter`; new screens go into `pages_test.dart`, which renders both locales.
- `architecture.md:24` → "The engine throws `EngineFailure`; `repositoryCall` maps it to an `AppError` code in one exhaustive switch, `DioException` to `network`, anything else to `unknown`". `:33` → "Errors, steps and hints go in the state as codes; the page words them".
- `architecture.md` gets a "Text" section with gym-coach's i18n rules (`gym-coach/.claude/CLAUDE.md:464-482`): a key goes into both ARBs (the parity test fails otherwise); gen-l10n is not build_runner; errors are codes and `detail` is never rendered; no user-facing copy in `domain/` or `data/`; only `app/` and `main.dart` import `lib/l10n/` (`check_layers.sh`); words for codes live in `app/shared/text/`, in exhaustive switches.
- `widget-standards.md:20`: `SelectableText` for errors worth copying, plus `CopyDetailsButton` when the error has a detail.
- `code-style.md` Imports (`:3-5`): tests import the helpers under `test/` by a relative path (`../support/pump.dart`, `_home.dart`), since `test/` has no `package:` URI; everything else stays absolute.

## 11. Delivery
M1 to M3 are commits on one branch that reach `main` together: `tag-version` tags on every push to `main` (`tag-version.yml:5-7`), and a partial app would show an English UI with Spanish errors. The version is raised once, to 1.5.0 (proposal.md §Version).
