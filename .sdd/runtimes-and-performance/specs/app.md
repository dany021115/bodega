# Spec · App

Requirements RA1..RA8 cover the app's side of `design.md` §7 and §9. `lib/` and `test/` are `apps/bodega/`'s. The rules of `.claude/rules/architecture.md`, `code-style.md` and `widget-standards.md` apply throughout.

## RA1 · Domain
- **Entities**
  - `Arch` shall gain `all`.
  - `DependencyStatus { installed, notInstalled, unknown }` shall replace `Dependency.installed` and `DependencyNeed`'s installed flag.
  - `BottleDependencies` shall gain `checkedAt` (`DateTime`).
- **Repository**
  - `download` shall return `List<String>` (paths), and `install` shall take one.
  - `HostCapabilities` shall gain `dxvkAsync` (true on the Mac).
- **Check:** `tool/check_layers.sh`; build_runner; `flutter analyze`.

## RA2 · Errors
`AppError` shall gain `installTimedOut(id, arch)`, mapped from `InstallTimedOut` in `appErrorOf` and worded in `error_text.dart` in both languages.
- **Check:** `test/app/text_test.dart`; a mapping case in `test/data/`.

## RA3 · The repository
`DependencyRepositoryImpl` shall work as follows:
- **Download.** It downloads each file of an item's list that `downloads/` lacks or holds with another SHA-256, one after another, reporting the summed received bytes over the summed sizes.
- **Install.** It passes the paths to `engine.installDependency(..., files:)`.
- **Status.** It maps `dependencyStatus` to `DependencyStatus`.

**Scenarios**
- **Given** `d3dx9 x86` with `downloads/directx-jun2010.exe` matching its pin, **then** `download` returns that path, and no `Downloader` is called.
- **Given** a two-file test item with the first file present, **then** only the second is fetched, and progress starts at the first file's size.
- **Given** a bottle with `syswow64` unreadable, **then** `bottle` gives `unknown` for the x86 rows that look there, and still returns the other rows.

**Check:** `test/data/dependency_repository_test.dart`.

## RA4 · The bloc
`DependenciesBloc` shall:
- set `checkedAt` when it loads a bottle;
- reload on a new `refresh` event;
- keep, with a failed item, the log path its failure carries, as `failedLog`.

**Scenarios**
- **Given** a load, **then** the state's `checkedAt` is the time from an injected clock.
- **Given** `refresh`, **then** the bottle is read again, and `checkedAt` moves.
- **Given** an install that fails with `WineToolFailed`, **then** the state holds the error, the item and its log path.

**Check:** `test/app/dependencies_bloc_test.dart`.

## RA5 · The section's list
`DependenciesSection` shall keep "For your programs" and add "All runtimes": one row per table row, with:
- its name;
- its one line;
- its status per architecture, or a single status for `all`;
- an Install button when something is not installed.

At the top it shall show "Checked at <time>" (`MaterialLocalizations.formatTimeOfDay`) and "Check again". Unknown rows show "Unknown", with no Install button. The buttons are off while the bottle is open, as today.

**Scenarios**
- **Given** fourteen rows with `vcrun2008` x86 installed and x64 not, **then** its row reads "32-bit: Installed" and "64-bit: Not installed", with Install for the 64-bit side.
- **Given** `corefonts` `all` not installed, **then** its row shows one status and one Install.
- **Given** a row `unknown`, **then** "Unknown" shows, and it has no Install.
- **Given** "Check again" tapped, **then** `refresh` is added.

**Check:** `test/app/dependencies_section_test.dart`.

## RA6 · Details, and the dialog's hand-picked mode removed
**Details**
- A failed item with a log shall show "Details", which calls `showLogDialog` with that path.
- "Choose the installer file…" shall show only for items with one download.

**Dialog**
- `NeedsDialog`'s hand-picked mode and the "Install a runtime…" button shall be removed, with their tests and ARB keys.

**Scenarios**
- **Given** a failure with a log, **when** "Details" is tapped, **then** the log dialog opens with that path.
- **Given** a failed `corefonts` download (eleven files), **then** no "Choose the installer file…" shows.

**Check:** `test/app/dependencies_section_test.dart`; `test/app/needs_dialog_test.dart` (the app mode only).

## RA7 · The async switch
The bottle's Settings and the run options shall show "Async shader compilation" with its line, only when `HostCapabilities.dxvkAsync` is true. It is saved through the bottle repository as `avx` is.
- **Given** the Mac capabilities, **then** the switch shows, and toggling it saves `dxvkAsync: true`.
- **Given** Linux's capabilities, **then** it does not show.
- **Check:** `test/app/bottle_detail_page_test.dart` or the run-options test, new cases.

## RA8 · Text and everything green
**Text**
- Every new string shall be in `app_en.arb` (with its `@key`) and `app_es.arb`.
- The one-line description is a table keyed by id with a default.
- Statuses and arches are worded in exhaustive switches in `dependency_text.dart`.
- Product names are shown as they are.

**Check:**
- `test/l10n_parity_test.dart`; `test/app/text_test.dart` (each status, `Arch.all`, each id's line, `en` and `es`);
- `test/app/pages_test.dart` renders the section with the list, at its widths, in `en` and `es`;
- `flutter analyze && flutter test && tool/check_layers.sh`, with the output in `verify.md`.
