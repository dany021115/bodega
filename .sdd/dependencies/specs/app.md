# Spec · App

Requirements DA1..DA9: the app's side of `design.md` §8. `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`, where `flutter test` runs. The rules of `.claude/rules/architecture.md`, `code-style.md` and `widget-standards.md` hold throughout; only `data/` imports the engine.

## DA1 · Domain
`domain/entities/dependency.dart` shall hold, as Freezed entities and enums, `Arch { x86, x64 }`, `Need { recommended, optional }`, `NeedReason { knownFix, notInWine, imported }`, `SettingState { applied, notApplied, noFile }`, `Dependency(id, name, arch, bytes, installed)`, `DependencyNeed(dependency, need, reason, dll?, fix?)`, `SettingNeed(fix, game, section, name, value, state)`, `AppNeeds(key, title, dependencies, settings)` with `hasRecommended`, `BottleDependencies(all, apps)` and the union `NeedItem.runtime(id, arch) | NeedItem.settings(fix)`, with no Flutter, `dart:io` or engine import. `domain/repository/dependency_repository.dart` shall declare `bottle(name)`, `needs(bottle, key)`, `catalogKey(catalogId)`, `download(id, arch, onProgress)` with `cancelDownload()`, `install(bottle, id, arch, file)` and `applySettings(bottle, fix)`, each a `Future<Either<AppError, T>>`: the bloc downloads, then installs, as `InstallBloc` does (wording of 2026-11-16, in apply).
- **Check:** `tool/check_layers.sh`; `flutter analyze`.

## DA2 · Errors
`AppError` shall gain `dependencyNotInstalled(id, arch)` and `unexpectedLink(path)`, mapped from DE10's failures in `appErrorOf`'s exhaustive switch, and worded in `error_text.dart` in both languages; `BadChoice(ChoiceKind.dependency)` maps as other `BadChoice`s do.
- **Check:** `test/app/text_test.dart` (both codes, `en` and `es`); `test/data/` mapping cases.

## DA3 · The repository
`DependencyRepositoryImpl` shall turn DE3's and DE5's results into DA1's entities, and install as `design.md` §8 says: a file in `$BODEGA_HOME/downloads/<id>-<arch>.exe` whose SHA-256 matches the pin is used as it is; otherwise `Downloader.fetch` writes it there with progress and cancel, then `engine.installDependency(..., file:)` runs. A given `file` skips the download.
- **Given** a file already in `downloads/vcrun2008-x86.exe` whose SHA-256 the test pins, **then** `download` returns it and calls no `Downloader`; **given** one that does not match, **then** `Downloader.fetch` writes the pinned URL to that same path.
- **Given** a bottle holding Blur (a real 32-bit PE named `Blur.exe`) and Microsoft's `msvcr100.dll`, **then** `bottle` gives twelve runtimes with `vcrun2010 x86` installed, and Blur's recommended `vcrun2008 x86` by its fix; `needs` gives the same for its key.
- **Given** an unknown bottle, **then** `install` and `applySettings` give `BottleNotFoundError`. The install itself is the engine's (DE6), tested there with its fake runtime.
- **Check:** `test/data/dependency_repository_test.dart`.

## DA4 · The bloc
`DependenciesBloc` (`@lazySingleton`, provided in `main.dart`) shall load a bottle's data, run one job at a time from a queue of items (runtimes, then settings), report its phase (`downloading` with received and total, `installing`, `applying`), reload the bottle when the job ends, keep the error with the item it failed on, and start a job from a picked file for that item.
- **Given** two runtimes queued, **then** the states go downloading → installing for the first, then for the second, then idle with the bottle reloaded.
- **Given** the first item fails, **then** the error and that item stay in the state and the second does not start.
- **Given** a job running, **when** another install is asked, **then** it is refused (no second job), and the state says busy.
- **Check:** `test/app/dependencies_bloc_test.dart` (bloc_test, repository mocked with mocktail).

## DA5 · The dialog
`NeedsDialog` shall show, for an app, its needs not installed or applied, recommended checked and optional not, each with its name, arch (32-bit or 64-bit), size in MB, need and reason, settings as `[Section] Name = value` with the game's title, and the line that installs reach every program in the bottle; by hand, every runtime and arch not installed, none checked. "Install" queues the checked items and closes; "Not now" closes.
- **Given** Blur's needs, **then** "Visual C++ 2008", "32-bit", "4.5 MB", "Recommended" and Blur's reason show, its box is checked, and "Install" queues `(vcrun2008, x86)`.
- **Given** an app with only optional needs, **then** none is checked and "Install" is off until one is.
- **Check:** `test/app/needs_dialog_test.dart` through `wrapApp`.

## DA6 · When the dialog opens by itself
After "Add program" registers an app, and after a catalog install ends in `InstallPhase.done`, the app shall ask for that app's needs and open the dialog when one recommended item is not done; never for detected apps.
- **Given** the add-app flow done with Blur's key and Blur's needs, **then** the dialog opens over the bottle page; **given** needs with optional items only, **then** it does not open.
- **Given** a catalog install done for an entry whose app has no recommended need, **then** no dialog.
- **Check:** `test/app/add_app_dialog_test.dart`, `test/app/install_bloc_test.dart` or the panel's test, new cases.

## DA7 · The section
`DependenciesSection` shall sit in `BottleColumn` after Settings, as a `CollapsibleSection`, listing the apps with needs, each item with its state (installed; not installed with its size; applied; not applied; "open the game once first" for `noFile`) and its "Install" or "Apply" button; the job's progress in a `Semantics(liveRegion: true)`; "Install a runtime…" for the dialog by hand. While the bottle is open, the buttons are off and a line says to stop it first. A failed download shows the error with "Choose the installer file…", which opens a picker for `.exe` files and starts DA4's job from it.
- **Given** the Games bottle's shape (Blur with `vcrun2008 x86` not installed, NFS13 with its setting not applied), **then** both apps show with their items and buttons.
- **Given** the bottle open, **then** the buttons are disabled and the line shows.
- **Check:** `test/app/dependencies_section_test.dart`; `test/app/pages_test.dart` renders the bottle page with the section open at its widths, in `en` and `es`, and the dialog.

## DA8 · Text
Every string of DA5–DA7 shall come from `app_en.arb` (with its `@key`) and `app_es.arb`, worded in `app/shared/text/dependency_text.dart` in exhaustive switches over DA1's enums; product names (`Visual C++ 2008`) and a setting's `[Section] Name = value` are shown as they are; a fix's reason is a table keyed by fix id (`blur`, `need-for-speed-most-wanted-2012`) with a default.
- **Check:** `test/l10n_parity_test.dart`; `test/app/text_test.dart` (each enum value and each fix id, `en` and `es`).

## DA9 · Everything green
- **Check:** `flutter analyze && flutter test && tool/check_layers.sh` in `apps/bodega`, output pasted in `verify.md`.
