# Exploration: i18n

Phase: explore. Sources: four read-only reports (presentation strings; non-UI and engine text; tests and CI; app shell and platform files), re-checked against the code on 2026-11-10. No code was changed.

Paths: `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`. `engine/` is `packages/engine/`. `gc:` is `gym-coach/app/`. Dart file names are unique across the app and the engine, so tables use bare names once the folder is clear.

## 1. Problem

- Bodega is public on GitHub under the GPL-3.0-or-later (`.claude/CLAUDE.md:3`), and from 1.4.2 the app takes its updates from this repository (`AGENTS.md:18`). The UI is Spanish only, so most people who find the repository cannot use the app.
- The Language rule (`.claude/CLAUDE.md:7`) puts everything in git in English: "The only Spanish in the repo is the app's Spanish UI text, which the `i18n` change moves to the Spanish translation file." Today Spanish sits in every layer: widgets, a bloc, `data/`, `domain/`, engine errors and progress steps, catalog prose, the CLI, logs, tests, `Info.plist` and the Linux desktop entry.

What i18n means for Bodega:

1. Every text the app shows comes from `lib/l10n/app_en.arb` or `lib/l10n/app_es.arb`, read through `context.l10n` (Flutter gen-l10n, set up as in gym-coach).
2. The language follows the system. An in-app setting can override it.
3. `domain/` and `data/` return codes, never sentences. Only `app/` turns them into words.
4. The engine, the CLI and logs are English only. The app words engine results from codes.
5. Text the OS shows for the app (macOS permission prompts and menu bar, the Linux desktop entry) exists in both languages and follows the system language.
6. Games and Wine keep the system language, as today: Wine inherits `LANG` and `LC_ALL` (`platform_linux.dart:65-66`) or `__CF_USER_TEXT_ENCODING` (`platform_mac.dart:83`).

## 2. Current state

### Where the Spanish is

| Area | Spanish the user can see | Detail |
|---|---|---|
| App presentation (`lib/app/presentation`, `lib/app/shared`, `lib/main.dart`) | **343 call sites in 42 of 106 files**: 311 to translate (298 live, 13 in two dead widgets), 32 already English or neutral | **231 distinct messages** (227 live), about 1,000 words |
| Blocs (`lib/app/bloc`, 16 blocs) | 1 | `run_options_bloc.dart:88` builds an `AppError` sentence |
| `lib/data/` | 14 sentences in 6 files | 10 `throw '…'`, `add_app_repository_impl.dart:19`, `repository_call.dart:22`, `downloader.dart:86`, `:100` |
| `lib/domain/` | 1 sentence, 1 formatted label | `exe_graphics.dart:22-25` (`warning`), `:19` (`label`) |
| `lib/device/` | 0 | `AppToast` takes a finished `String` |
| Engine errors (`engine/lib/`) | **74 `throw`s, all Spanish**: 66 string literals, 3 computed strings, 5 `FormatException` | `repositoryCall` turns each into `AppError.engine(message)` |
| Engine text that is not an error | 6 host issues, `backendUse` (2 platforms), 7 install steps, 3 D3DMetal steps and `'desconocida'`, 5 log hints, 1 anti-cheat hint, 4 user-name problems, 1 path problem | all reach the app as finished strings |
| Catalog prose (`catalog_data.dart`) | **56 strings in 7 entries** | 7 `statusNote`, 2 `flaky`, 13 `notes`, 17 `symptom`, 17 `fix`; titles are product names |
| CLI (`engine/bin/bodega.dart`, 366 lines) | 34 sites | `_usage` (`:6-31`, starts with "uso:"), labels such as `pista:`, `nota:`, `estado:`; it also prints the engine texts and the catalog prose |
| Logs | 7 words or notes | `# aviso` (`engine.dart:579`); labels `usuario`, `resolucion` (`backends.dart:678`, `:700`) and `mandos` (`platform_mac.dart:317`); origins `opcion`, `botella` (`backends.dart:743`, `:747`); `fixNotApplied` (`fixes.dart:125`). The in-app log viewer shows them |
| macOS bundle | 4 usage descriptions (`apps/bodega/macos/Runner/Info.plist:27-34`) | the menu bar (`Base.lproj/MainMenu.xib`) is English only |
| Linux desktop entry | `Comment=` (`packaging/linux/bodega.desktop:4`) | one file feeds the .deb, the AppImage and the Arch package |

Already English: `fixes_data.dart` (166 strings, generated, CLI only) and the window title "Bodega".

Estimated ARB size: about 227 presentation messages, about 80 codes from below `app/` (errors about 45, host issues 12, backend roles 5, install steps 7, D3DMetal 4, hints 6, graphics 2) and 56 catalog strings. That is **about 360 keys per locale** (gym-coach has 924).

### Tests that assert Spanish

| Where | What | Count |
|---|---|---|
| Widget tests (15 files) | finders on copy that lives in `lib/app` | 100 fixed + 21 templated (12 of them `findsNothing`) |
| Widget tests | Spanish test data the widget only displays | 25 |
| Bloc tests | copy written outside presentation | `graphics_bloc_test.dart:43-48` (`ExeGraphics.label`, `.warning`), `run_options_bloc_test.dart:110` |
| Bloc, router and data tests | `AppError.engine/network/unknown('…')` built from Spanish text | 36 in 14 files |
| Data tests | copy from `data/` or the engine | `add_app_repository_test.dart:73`, `update_repository_test.dart:158`, `bottle_repository_test.dart:84` |
| Engine tests (8 files) | thrown messages, steps, hints, log notes | about 52 (e.g. `engine_test.dart:306`, `catalog_test.dart:306-307`) |

- `library_page_test.dart:136` pins today's plural bug: `'1 apps en 1 botellas'`.
- Two checks test nothing: `pages_test.dart:724` looks for `'Elegir carpeta…'`, removed in 79f772f. `engine/test/options_test.dart:290` (`isNot(contains(startsWith('Creando')))`) becomes one when steps turn English.
- The overflow fixtures are Spanish (`pages_test.dart:86-87`), and so are two skip reasons (`engine_test.dart:444`, `linux_test.dart:113`). Test names and comments are already English.

## 3. Files and symbols involved

### 3.1 App presentation (`lib/app/`)

| Feature | Files with copy | To translate | Already EN | Largest |
|---|---|---|---|---|
| `presentation/bottles` | 11 / 11 | 118 | 14 | `bottle_column.dart` 55, `run_options_dialog.dart` 16, `new_bottle_dialog.dart` 13 |
| `shared` | 12 / 21 | 55 | 6 | `update_dialog.dart` 11, `install_panel.dart` 10 |
| `presentation/catalog` | 5 / 7 | 38 | 5 | `detail_action.dart` 14, `catalog_detail_page.dart` 11 |
| `presentation/backends` | 4 / 4 | 35 | 5 | `backend_card.dart` 15, `gptk_section.dart` 14 |
| `presentation/add_app` | 2 / 3 | 31 | 0 | `add_app_dialog.dart` 25 |
| `presentation/library` | 2 / 3 | 22 | 0 | `library_page.dart` 14, `library_card.dart` 8 (dead) |
| `presentation/setup` | 4 / 4 | 11 | 1 | `runtime_card.dart` 5 |
| `bloc` (16 blocs) | 1 / 48 | 1 | 0 | `run_options_bloc.dart` |
| `main.dart`, `di.dart`, `app/router.dart`, `resources/` | 1 / 5 | 0 | 1 | `main.dart:66` `title: 'Bodega'` |
| **Total** | **42 / 106** | **311** | **32** | |

- Most repeated: `Cancelar` ×11, `Instalar` ×7, `Parar` ×6, `Abrir` ×5, `Cerrar` ×4, `Nueva botella` ×4, `Gráficos` ×4.
- Of the 343 sites: 50 interpolate a value, 16 are built from pieces at run time, 6 pick a plural by hand, 8 format a number or size by hand, 30 depend on Spanish gender, 15 are tooltips, 4 semantics labels, 6 toasts, 7 file-picker labels. No dates are shown.
- Copy that cannot read `context.l10n` as written: 49 `const Text(…)`; 4 `static const` tables (`BackendCard._descriptions` `backend_card.dart:19-24`, `BottleColumn.windowsNames` and `.panels` `bottle_column.dart:40-55`, `CatalogDetailPage._sourceLabels` `catalog_detail_page.dart:20-26`); 7 `XTypeGroup` labels (e.g. `add_app_dialog.dart:22`); 6 toasts shown after an `await`.
- Shared widgets with no copy of their own (callers pass it): `EmptyState`, `StatusChip`, `GradientButton`, `CollapsibleSection`, `DetailSection`, `SideBarItem`, and `AppToast` in `device/`.

Representative call sites:

| path:line | Today | Needs |
|---|---|---|
| `app_card.dart:217` | `'Opciones de ${app.title}'` | a placeholder; English order is `{title} options` |
| `library_page.dart:166` | `'${visible.length} apps en $shownBottles botellas'` | two ICU plurals in one message |
| `bottle_row.dart:30-34` → `:68`, `:71` | `_state` returns `'abierta'`, spliced into `'Botella ${bottle.name}, $_state'` | whole messages with a `select` |
| `bottle_row.dart:113`, `bottle_detail_page.dart:66` | `'1 app'` or `'$count apps'`, picked by hand twice | one ICU plural |
| `install_panel.dart:16-24`, `update_dialog.dart:12` | `'Descargando · $percent % · … de …'`; MiB labelled "MB", two helpers | one size and percent helper with locale number formats |
| `bottle_column.dart:264-276` | titles joined with `', '` inside `'… no le sirve a: …. Usa Automático.'` | the option label "Automático" as one shared key |
| `gptk_section.dart:55-56` | one toast: a sentence plus a second one picked by a ternary | two keys or a `select` |
| `app_card.dart:111`, `app_row.dart:94` | `'Doble toque para abrir'` | desktop wording: double-click |

### 3.2 Text that reaches the screen from below `app/`

| Carrier | Defined | Fed by | Shown at |
|---|---|---|---|
| `AppError.engine/network/unknown(String message)` | `lib/domain/entities/app_error.dart:9-11` | `lib/data/service/repository_call.dart:16-25`: `on String`, `on FormatException`, `'Error de red: …'`, raw `'$e'` | 14 `.message` sites in 11 files, e.g. `shell_body.dart:42`, `setup_page.dart:43`, `install_panel.dart:58`, `update_dialog.dart:85`, `add_app_dialog.dart:237` |
| `HostIssue {title, detail, command}` | `host_issue.dart:9-13`; engine typedef `platform.dart:4` | `platform_mac.dart:126-127`, `platform_linux.dart:115-133`, `gamepads.dart:70-82` | `requirement_card.dart:26`, `:28` |
| `BackendInfo.use` | `backend_info.dart:15` | `backendUse`: `platform_mac.dart:218-222`, `platform_linux.dart:241-243` | `backend_card.dart:80` |
| `onStep(String)` | `install_repository.dart:19`, `backend_repository.dart:33` | `catalog.dart:101-192`; `backends.dart:154`, `:174`, `:196` | `install_panel.dart:48`, `backend_card.dart:98` |
| Hints (`List<String>`) | `library_repository.dart:51`, `:53` | `hintsIn` (`engine.dart:363-379`), `antiCheatHints` (`catalog.dart:236`, text `:271-274`) | toast `shell_body.dart:36`, `bottle_tag.dart:45`, `bottle_column.dart:208` |
| User-name and path problems (`String?`) | `bottle_repository.dart:30`, `add_app_repository.dart:6` | `badUser` (`backends.dart:617-626`), `winPathProblem` (`engine.dart:43-51`), `add_app_repository_impl.dart:19` | `windows_user_dialog.dart:70`, `add_app_dialog.dart:139` |
| `ExeGraphics.label`, `.warning()` | `exe_graphics.dart:19`, `:22-25` | written in `domain/` | `run_options_dialog.dart:84`, `bottle_column.dart:271` |
| `CatalogApp.statusNote`, `flaky`, `notes`, `knownIssues` | `catalog_app.dart:9-28` | `catalog_data.dart` | `catalog_detail_page.dart:78-114`, `install_panel.dart:51-53`, `popular_app_card.dart:51` |
| `AppUpdate.notes` | `app_update.dart` | GitHub release body | `update_dialog.dart:43` (content, not UI copy) |

### 3.3 Engine (`engine/lib/`, `engine/bin/`)

| File | `throw`s | Other text the app shows | CLI or log only |
|---|---|---|---|
| `engine.dart` | 18 + 4 `FormatException` (`:29`, `:32`, `:57`, `:262`) | 5 log hints `:365-374`; `winPathProblem` `:43-51` | throws `:494`, `:500`, `:514` (`installSdl`); `# aviso` `:579` |
| `backends.dart` | 28 + 2 computed (`:637`, `:755`) | D3DMetal steps `:154`, `:174`, `:196`; `'desconocida'` `:220`; `badUser` `:617-626` | throws `:34`, `:36`, `:39`, `:229`, `:235`, `:352`; labels `:678`, `:700`; origins `:743`, `:747` |
| `catalog.dart` | 9 + 1 computed (`:84`) | install steps `:125-192`; anti-cheat hint `:271-274` | throw `:98`; steps `:101`, `:103` |
| `apps.dart` | 7 | | |
| `fixes.dart` | 2 + 1 `FormatException` (`:22`) | | throw `:102`; `fixNotApplied` `:125` |
| `platform.dart`, `platform_linux.dart` | `platform.dart:26`, `platform_linux.dart:430` | host issues `platform_linux.dart:115-133`; `backendUse` `:241-243` | |
| `platform_mac.dart`, `gamepads.dart` | | host issues `platform_mac.dart:126-127`, `gamepads.dart:70-82`; `backendUse` `platform_mac.dart:218-222` | label `mandos` `platform_mac.dart:317` |
| `catalog_data.dart` | | 56 prose strings | the CLI prints them too |
| `bin/bodega.dart` | | | 34 sites; prints errors at `:254` (`$e`) |
| **Total** | **74** | | **13** engine sites reached only by the CLI |

### 3.4 App shell, tests and tooling

- `apps/bodega/pubspec.yaml`: no `flutter_localizations`, no `intl`, no `generate: true` (dependencies `:31-55`, `flutter:` `:79-88`). No `l10n.yaml`, no `lib/l10n/`.
- `lib/main.dart:65-76`: `MaterialApp.router` sets no `localizationsDelegates`, `supportedLocales` or `locale`, so Material's own strings (text-field menu, default tooltips) are English next to the Spanish copy. `:63` wraps the app in a `BlocBuilder<ThemeBloc>`; `:62` notes that the theme toggle has no UI.
- No settings screen. The sidebar (`side_bar.dart:91-190`) holds the brand, Biblioteca, BOTELLAS with Nueva botella, Backends and `AppVersion` (`:190`). Collapsed, it is a 68 px rail (`:65`).
- Preferences: `PreferenceKey` (`lib/data/service/preference.dart:4-10`) with typed getters and setters (`:18-50`). `ThemeBloc` (`theme_bloc.dart:14-15`) and `ViewModeBloc` (`view_mode_bloc.dart:15-16`) read them in their constructors.
- `lib/app/router.dart:50` builds the `GoRouter` with no `errorBuilder`, so an unknown route shows go_router's English "Page Not Found".
- Tests: no `test/support/`, no shared pump helper. 20 `MaterialApp`s in 15 files: 17 plain and 3 `MaterialApp.router` (`pages_test.dart` 3; `main_shell_test.dart`, `app_tile_test.dart`, `app_row_test.dart` 2 each). 10 pass a theme, 4 add the `ResponsiveBreakpoints` builder.
- `pages_test.dart:353` renders every screen at widths 720, 801, 1150 and 1921, in one locale. It is the overflow test (`code-style.md:26`).
- CI: `.github/workflows/test.yml:40-48` runs `flutter pub get` (`:44`), build_runner, `flutter analyze`, `flutter test` and `tool/check_layers.sh`. Its `paths:` filter (`:6-11`) already covers ARB files.
- Layers: `apps/bodega/tool/check_layers.sh:22-29`. Nothing forbids `package:bodega/l10n/` in `domain/` or `data/` yet.
- `packages/engine/` has no `analysis_options.yaml`.

### 3.5 Native shells and packaging

| File | Today | What i18n needs |
|---|---|---|
| `apps/bodega/macos/Runner/Info.plist:27-34` | 4 Spanish usage descriptions: Downloads folder, local network, microphone, camera | English raw values; `en.lproj` and `es.lproj` `InfoPlist.strings` |
| `Info.plist:5-6`; `apps/bodega/macos/Runner.xcodeproj/project.pbxproj:263-268` | development region `en`; `knownRegions = (en, Base)`; no `CFBundleLocalizations` | add `es`; `CFBundleLocalizations` = en, es |
| `apps/bodega/macos/Runner/Base.lproj/MainMenu.xib` | 61 items (52 with titles) in 12 menus, English only; "Preferences…" (`:36`) has no action | `es.lproj/MainMenu.strings` |
| `apps/bodega/macos/Runner/MainFlutterWindow.swift:25-27` | asks for the microphone in `awakeFromNib`, before Flutter draws | nothing: that prompt can only use the bundle's strings, in the system language |
| `packaging/linux/bodega.desktop:3-4` | `Name=Bodega`; `Comment=` in Spanish only; no `GenericName` or `Keywords` | English `Comment=` plus `Comment[es]=`; `GenericName` and `Keywords` with `[es]` |
| `apps/bodega/linux/runner/my_application.cc:48`, `:52` | window title "Bodega" | nothing (brand) |

## 4. Reference implementation: gym-coach

| gym-coach | Bodega target | Copy or adapt |
|---|---|---|
| `gc:l10n.yaml:3-8`: `arb-dir: lib/l10n`, template `app_es.arb`, class `AppL10n`, untranslated report in `../docs/generated/` | `apps/bodega/l10n.yaml` | Adapt: template `app_en.arb`; report under `build/` (gitignored, `apps/bodega/.gitignore:33`) |
| `gc:pubspec.yaml:12-14` (`flutter_localizations`, `intl: any`), `:105` (`generate: true`) | `apps/bodega/pubspec.yaml` | Copy |
| `gc:lib/l10n/l10n.dart:7-23`: re-export plus a non-nullable `context.l10n` whose assert names the fix | `lib/l10n/l10n.dart` | Copy with absolute imports (`code-style.md:10`); drop `resolveAppLocale` (`:25-34`, falls back to Spanish) |
| `gc:lib/main.dart:146-149`: delegates, `supportedLocales`, `locale:` from the bloc, `localeResolutionCallback` | `lib/main.dart:65-76` | Adapt: no resolution callback (§7.2); one small view under `MultiBlocProvider` watches theme and locale |
| `LocaleBloc` (`gc:lib/app/bloc/locale/locale_bloc.dart:18-39`): a load event (`gc:lib/main.dart:51`), raw `SharedPreferences`, only `selected(code)` (`locale_event.dart:5-6`), an `update(clearLanguage:)` workaround (`locale_state.dart:15-21`) | `lib/app/bloc/locale/` | Adapt: read `Preferences` in the constructor like `ThemeBloc`; `@lazySingleton` like `ViewModeBloc`; one `set(String? code)` event where null means System; plain Freezed 4 `copyWith` |
| `LanguageSwitch` on the welcome screen: each language named in its own language (`language_switch.dart:16`), active one from `Localizations.localeOf` (`:23`), `Semantics(button, selected)` (`:38-42`) | the Settings dialog (§7.3) | Adapt: add System; same naming and semantics |
| `gc:test/support/pump.dart:10-15`: `wrapApp` pinned to `es` | `test/support/pump.dart` | Adapt: pin `en`; optional theme and breakpoints builder; add `wrapRouter` for the 3 router tests |
| `gc:test/l10n_parity_test.dart:42-85`: keys both ways, nothing copy-pasted, placeholders, empty report | `test/l10n_parity_test.dart` | Adapt: compare every placeholder declared in `@key` (`_placeholdersOf`, `:27-31`, keeps only the first plural or select argument); allowlist brand words for the copy-paste check (Backends, DLSS, msync, Terminal, GameMode, D3DMetal, Game Porting Toolkit) |
| `gc:lib/app/shared/text/error_text.dart:12-41`: exhaustive `localized(l10n)`, no `_ =>` | `lib/app/shared/text/error_text.dart` and siblings | Copy the pattern. Most of Bodega's codes start in the engine, so mapping takes two hops (engine to data, data to app) |
| Rules `gym-coach/.claude/CLAUDE.md:464-482`: keys in both ARBs, gen-l10n is not build_runner, widget tests through `wrapApp`, errors are codes, no copy in `domain/` or `data/` | `.claude/rules/architecture.md`, `code-style.md`, `.claude/CLAUDE.md` | Copy |
| Generated `app_localizations*.dart` and `untranslated.txt` are committed | | Adapt: gitignore them, as Bodega does with all generated code (`.gitignore:50-53`) |

What changes on a desktop app:

- **Ordered language lists.** macOS passes `[NSLocale preferredLanguages]` and updates it when the user changes it. Linux passes `g_get_language_names()`, built from `LANGUAGE`, `LC_ALL`, `LC_MESSAGES` and `LANG`, always ending in `C`. gym-coach's `localeResolutionCallback` sees only the first entry. Flutter's default list resolution walks the whole list and falls back to `supportedLocales.first`, which gen-l10n sorts as `[en, es]` (`gc:lib/l10n/app_localizations.dart:95-98`).
- **Where the switch lives.** gym-coach puts it on the welcome screen. Bodega has no settings screen, and `/setup` is not a reliable place: with the runtime bundled, it sends the user straight to the library (`router.dart:37-39`, `packaging/macos/README.md:39`).
- **Live switch.** `Localizations` rebuilds the tree without a restart. Text already stored in bloc state (`LibraryState.toast` and `hints`, `error.message`, `InstallState.step`) stays in the old language; codes fix that.
- **Native text.** Permission prompts, the menu bar and the desktop entry live outside Flutter and follow the OS language. On macOS the per-app language in System Settings should also apply once the bundle declares `es` (to verify on a Mac).
- **Material built-ins.** The text-field menu and default tooltips switch language once `AppL10n.localizationsDelegates` (which includes the Material, Cupertino and Widgets delegates) is installed.

## 5. Project constraints

- **Layers** (`.claude/rules/architecture.md:4-7`, enforced by `apps/bodega/tool/check_layers.sh:22-29`): `domain/` is pure Dart; only `data/` imports `package:engine`; `device/` imports neither `data/` nor `domain/`; imports are absolute.
  - `lib/l10n/` is new and outside the four layers. Only `app/` and `main.dart` may import it: add a `check_layers.sh` rule against `package:bodega/l10n/` in `lib/domain`, `lib/data` and `lib/device`.
  - gen-l10n's own `import 'app_localizations_en.dart';` passes the absolute-import rule (it does not start with `./`). `lib/l10n/l10n.dart` must import `package:bodega/l10n/app_localizations.dart`; gym-coach's is relative (`gc:lib/l10n/l10n.dart:3`, `:5`).
- **No user-facing copy in `domain/` or `data/`** (gym-coach's rule, adopted here). Broken today by `exe_graphics.dart:19-25`, the 14 data sentences, and the mappers that copy engine text into entities: `runtime_repository_impl.dart:26-30`, `gamepad_repository_impl.dart:29-33`, `backend_repository_impl.dart:32`, `install_repository_impl.dart:57`, `library_repository_impl.dart:107`, `:116`, `bottle_repository_impl.dart:71`, `catalog_repository_impl.dart:28-39`. `AppError` stays in `domain/` (`architecture.md:20`); if `data/` throws it, it must implement `Exception`.
- **gen-l10n is not build_runner.** Checked on Flutter 3.47.0 in a throwaway workspace that copies Bodega's layout:
  - `flutter: generate: true` is required. `synthetic-package` is gone, so the output lands in `lib/l10n/`.
  - `flutter pub get` (in the app or at the workspace root), `flutter build` and `flutter run` regenerate. `dart pub get`, build_runner, `flutter analyze` and `flutter test` do not. CI runs `flutter pub get` first (`test.yml:44`), and so do both packaging scripts (`tool/package_linux.sh:40-42`, `tool/package_macos.sh:107-109`).
  - A missing key or a dropped placeholder still exits 0 and analyzes clean. Only a parity test catches it.
  - `flutter_localizations` and `intl` 0.20.3 are already in `pubspec.lock` as transitive dependencies (`:393-397`, `:536-543`), so nothing new is downloaded.
  - The generated code passes Bodega's lints.
- **Freezed 4** (`code-style.md:13-16`): `sealed class` events, `abstract class` states and entities. `copyWith` can set a nullable field back to null (`library_bloc.freezed.dart:910`). A new `AppError` and the new code types need a build_runner run; generated files stay gitignored (`.claude/CLAUDE.md:56`).
- **Blocs and DI** (`architecture.md:30-33`): app-wide blocs are `@lazySingleton` and provided in `main.dart`; errors live in state as `AppError?`. Injectable registers everything.
- **Tests** (`code-style.md:24-26`): every bloc with `bloc_test` and mocked repositories; `pages_test.dart` covers every screen.
- **Versioning**: a feature, so one minor bump per delivery: 1.4.2+11 to 1.5.0+12 with `tool/version.sh bump minor` (`tool/version.sh:62`, `:70`; `AGENTS.md:8-10`), then the `bump-version` skill and `tool/version.sh check` before the commit. `.sdd/` and docs alone do not bump (`AGENTS.md:11`).
- **Language and workflow**: code, comments, tests, commit messages, branch names and PRs in English (`.claude/CLAUDE.md:7`, `AGENTS.md:3`). No commit or push without the user's approval, and no AI attribution.
- **Rule text this change contradicts**: `code-style.md:21` ("everything the user reads in Spanish") and `architecture.md:24` ("The engine throws `String` and `FormatException`"). `widget-standards.md:20` asks for `SelectableText` on errors worth copying: decide what that text is (§7.8).

## 6. Risks

| Risk | Where | Mitigation |
|---|---|---|
| Sentences built from pieces (16 sites) | `bottle_row.dart:30-34` → `:68`, `:71`; `bottle_detail_page.dart:66` + `:217`; `install_panel.dart:16-24`; `update_dialog.dart:65-68`; `gptk_section.dart:55-56`; `bottle_column.dart:264-276`; `anti_cheat_section.dart:60`; `catalog_detail_page.dart:125`; `backend_card.dart:80` | one whole message per sentence; `select` for state words; quoted labels ("Automático", "Puede fallar") passed in from their own key |
| Plurals (6 sites) | `library_page.dart:166` (no plural at all), `bottle_row.dart:113`, `bottle_detail_page.dart:66`, `:217` | ICU `plural`, with two plural arguments where a message has two counts |
| Gender (30 sites) | feminine: botella, app, GPU, versión; masculine: backend, mando | one key per noun context; never merge keys because the English matches ("Closed", "Installed", "Automatic") |
| `const` and async gaps | 49 `const Text`, 4 `static const` tables, 7 `XTypeGroup` labels, 6 toasts after an `await` | drop `const`; tables become functions of `AppL10n`; read `context.l10n` before the `await` |
| Text frozen in state | `LibraryState.toast` and `hints`, `error.message`, `InstallState.step`, `gptkStep` | keep codes in state and word them in `build`, so a live switch re-translates |
| Engine messages written for the CLI | 14 messages tell a GUI user to run `bodega stop`, `rm -rf` or `gh release download`; renaming an open bottle shows `engine.dart:629` | codes let the app give GUI advice; the CLI keeps its command hints, in English |
| Breadth of the engine refactor | 74 throws, 8 kinds of non-error text, about 52 engine assertions, 36 `AppError` constructions in app tests | one sealed failure type, one exhaustive mapper, tests that assert on types instead of text |
| CLI output | `bin/bodega.dart:254` prints the caught object; `tool/smoke_linux.sh:46` greps the CLI's `dxvk: instalado` | `EngineFailure.toString()` returns the English message; change the smoke test in the same commit as the CLI text |
| Hint markers and de-duplication | `fixNotApplied` (`fixes.dart:125`) is both the log note and a `_hints` key (`engine.dart:372`); hints de-dupe by string (`library_bloc.dart:203`) | codes compare by value. Hints are read only from the run that just ended (`library_bloc.dart:132-136`), so the marker can turn English with no compatibility shim |
| Missing keys fail silently | gen-l10n falls back to the template | parity test that compares every declared placeholder |
| All widget tests break at once | 20 `MaterialApp`s hit the `context.l10n` assert, about 130 tests | `wrapApp` and `wrapRouter` as their own first task |
| Checks that test nothing | 12 `findsNothing` on copy, `pages_test.dart:724`, `options_test.dart:290` | point them at keys or types, or delete them |
| Overflow in the longer language | Spanish runs longer; `pages_test.dart:353` uses one locale | loop the widths over both locales |
| Inconsistent copy | "Sin soporte" vs "Bloqueado" (`popular_app_card.dart:25`, `catalog_chips.dart:18`); two name rules (`new_bottle_dialog.dart:40`, `rename_bottle_dialog.dart:49`); "Agregar a (la) biblioteca" (`app_menu.dart:51`, `library_toggle.dart:57`); three download-progress formats; seven ways to say "closes what is open" | one key per meaning, settled in propose |
| A half-done release | presentation strings without engine codes give an English UI with Spanish errors | no release between milestones (§7.14) |

## 7. Open questions for propose

1. **Which ARB is the template?** **Default: `app_en.arb`**, with `app_es.arb` as the translation. `.claude/CLAUDE.md:7` already calls Spanish "the Spanish translation file", and the code is English. A missing Spanish key then falls back to English, and the parity test still fails the build. gym-coach does the opposite (`gc:l10n.yaml:4`).
2. **Fallback for a system language that is neither Spanish nor English?** **Default: English**, with no resolution callback. Flutter's default list resolution walks the user's whole ordered list (so `[fr, es]` still gets Spanish) and ends on `supportedLocales.first`, which is `en`. `LANG=C` on Linux lands on English too, and it matches `developmentRegion = en`. If a callback is ever needed, use `localeListResolutionCallback`, which sees the whole list.
3. **Is there a language switch, and where?** **Default: yes, in a Settings dialog** opened from a gear button in the sidebar footer, next to `AppVersion` (`side_bar.dart:190`), an icon with a tooltip on the 68 px rail. Options: System, English, Español, each language named in its own language. The dialog can also hold the theme toggle that has no UI yet (`main.dart:62`). Wiring macOS "Preferences…" (`MainMenu.xib:36`) can wait.
4. **Persistence?** **Default: `PreferenceKey.language`** (`preference.dart:4-10`), a `String?` where no value means System. A `@lazySingleton` `LocaleBloc` reads it in its constructor like `ThemeBloc` (`theme_bloc.dart:14-15`), so the first frame already has the right language. One event: `set(String? code)`. No `AppleLanguages` write: native text follows the system.
5. **The CLI's language?** **Default: English only.** The engine has no Flutter, no `intl` and no assets (`catalog_data.dart:2`), and the app never runs the CLI.
6. **Info.plist, menu bar and Linux desktop entry?** **Default: localize them in this change**, following the system language. macOS: English raw values, `InfoPlist.strings` for `en` and `es`, `es` in `knownRegions`, `CFBundleLocalizations`, and `es.lproj/MainMenu.strings`, made in Xcode rather than by editing `project.pbxproj` by hand. Linux: `Comment[es]`, `GenericName[es]` and `Keywords[es]` in `bodega.desktop`, checked with `desktop-file-validate`. No AppStream metainfo yet.
7. **How do engine texts become codes?** **Default:**
   - Engine: a sealed `EngineFailure implements Exception`, with about 25 final subclasses holding typed fields (bottle, path, log, exit code, detail), replaces the 74 throws. Its English `message` and `toString()` serve the CLI and logs.
   - Non-error text becomes enums or records: `HostIssueKind` (plus subject and command), `BackendRole`, `InstallStep`, `GptkStep`, `LogHint`, `AntiCheatHint`, `UserNameProblem` and a path-problem record. The `'desconocida'` version becomes `null`. Each one gets an English describer for the CLI.
   - `data/`: `repositoryCall` catches `EngineFailure` and maps it, in one exhaustive switch, to a domain `AppError` union of codes. Dio errors become `network(detail)`, anything else `unknown(detail)`. The 14 data sentences throw codes directly.
   - `app/`: `lib/app/shared/text/error_text.dart` (`localized(l10n)`, no `_ =>`), plus siblings for host issues, steps, hints, graphics and the catalog. `ExeGraphics.label` and `.warning` move there.
   - Defensive cases the UI already guards fold into `unknown`, saving about 15 keys.
8. **Show the raw `detail`?** gym-coach never renders it. **Default: no.** Messages show typed fields such as the bottle or the log path. `detail` (tool stderr or Dio text, already English) goes only into a "Copy details" action on the error panels where `widget-standards.md:20` wants copyable errors.
9. **Catalog prose (56 strings)?** **Default: English text in `catalog_data.dart`** (for the CLI and as the fallback) plus ARB keys per entry and field, worded by `app.id` in `lib/app/shared/text/catalog_text.dart`, with a test that every catalog id has its keys. The alternative, `{es, en}` fields in the data like `gc:lib/app/shared/text/exercise_name.dart:8-12`, leaves Spanish in the engine, which the rule forbids.
10. **Which language do tests assert in?** The rule leaves no Spanish in test files. **Default:** `wrapApp` and `wrapRouter` pin `en`, and assertions use English text. `pages_test.dart` renders each screen in both locales. Spanish-only behaviour (plurals, gender) is checked through `lookupAppL10n(const Locale('es'))` instead of Spanish literals. Spanish fixtures and mock messages become English.
11. **Commit or ignore the generated `app_localizations*.dart`?** **Default: ignore** them, like the other generated files (`apps/bodega/.gitignore:50-53`), and add `flutter gen-l10n` to the Commands in `.claude/CLAUDE.md`. gym-coach commits them.
12. **Dead widgets?** **Default: delete** `library/widgets/library_card.dart` (not referenced anywhere) and `bottles/widgets/app_tile.dart` (used only by `test/app/app_tile_test.dart`) instead of translating their 13 strings.
13. **Rule text?** **Default:** amend `.claude/CLAUDE.md:7` so the platform translation files (`es.lproj/*.strings`, the `[es]` keys in `bodega.desktop`) also count as allowed Spanish; rewrite `code-style.md:21` and `architecture.md:24` and `:33`; add gym-coach's i18n rules to `architecture.md`.
14. **One delivery or several?** **Default: one change and one minor bump (1.5.0)**, applied in milestones: (1) setup, `wrapApp`, the parity test and the presentation strings; (2) codes from the engine, `data/` and `domain/`; (3) the settings switch and the native files. No release between milestones.

## Outside this change

- Translating `.sdd/`, docs and scripts, and the README and license: separate work running now.
- `fixes_data.dart`: already English, generated by `tool/import_fixes.py`.
- GitHub release notes in the update dialog (`update_dialog.dart:43`): content, shown as written.
- The language games and Wine run in.
- AppStream metainfo for Linux software centers.
- `packaging/macos/README.txt` (was `LEEME.txt`): translated and renamed with the docs work, so the DMG ships it in English.
