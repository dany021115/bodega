# App · mach9-parity

Requirements PA1..PA7. `APP` is `apps/bodega/`. Every check is `dart run build_runner build --delete-conflicting-outputs && flutter gen-l10n && flutter analyze && flutter test && tool/check_layers.sh` in `APP`. Only `data/` imports the engine. Every new text goes in both ARBs, worded in `app/shared/text/`.

## PA1 · Retina in a Mach9 bottle's Settings (PE2)
- **Domain:** `BottleDetail` shall gain `retina` (`RetinaMode { auto, on, off }`, default `auto`).
- **Settings section:**
  - in a Mach9 bottle, a dropdown "High resolution (Retina)" with Automatic, On and Off replaces the high-res switch;
  - one line under it says Automatic follows the main display, as Mach9 does;
  - a Rosetta bottle keeps its switch.
- **Choosing a value** sends `BottleDetailEvent.setRetina`. The repository calls `engine.setRetina` in a `repositoryCall`.
- **Given** a Mach9 detail, **then**:
  - the dropdown shows its value;
  - the switch is absent;
  - choosing Off sends `setRetina(off)`. (widget and bloc tests)
- **Given** a Rosetta detail, **then** the switch is there and the dropdown is not. (widget test)

## PA2 · Native engine options per app (PE7)
- **Domain:** `NativeOption { noForceNx, largeAddressAware, notDpiAware, cglOpenGl, vulkanWined3d }`, and `LibraryApp.nativeOptions` (a set), filled for apps of Mach9 bottles.
- **The app menu:** for an app of a Mach9 bottle, the app menu shall show "Native engine options…". This is the menu the library and the bottle's page share, where the HUD switch also lives (wording changed in apply; see `tasks.md` M2).
- **The dialog:**
  - five switches, each with its name and one line saying when it helps;
  - turning one sends `LibraryEvent.setNativeOption(bottle, key, option, on)` at once, and the dialog shows the saved state;
  - a note at the bottom says the options apply from the next launch of the game.
- **Given** an app of a Mach9 bottle, **then**:
  - the menu has the item, and the dialog lists the five switches with the app's state;
  - a switch sends the event. (widget and bloc tests)
- **Given** an app of a Rosetta bottle, **then** the item is absent. (widget test)

## PA3 · The catalog's engine (PE1, P13)
- On a catalog entry's detail page, when the target is "a bottle of its own" and Mach9 is installed and allowed, an Engine dropdown shall show Native engine (Mach9) or Rosetta engine:
  - Native is the default (Q1);
  - the install passes `runtime` to `installEntry`;
  - an existing bottle as target hides the dropdown, and the install keeps that bottle's engine.
- **Given** Mach9 installed, **then**:
  - the dropdown shows Native;
  - choosing Rosetta sends `runtime: bodega`. (widget and bloc tests)
- **Given** Mach9 not installed, **then** the dropdown is absent and the install is Rosetta's, as today. (widget test)

## PA4 · Check on the engine card (P14)
- The installed engine card shall have Check. It opens the probe dialog that the backend cards use, listing the ready Mach9 bottles, and runs `backendTest` for `mtld3d`, `dxmt` and `wine` in the chosen one. Each result shows as the backend cards show theirs.
- With no ready Mach9 bottle, Check is disabled, with a line that says a Native bottle is needed.
- **Given** two Mach9 bottles, one of them ready, **then** the dialog lists the ready one, and running it gives three results. (bloc and widget tests)

## PA5 · The engine in a game report (P12)
- `reportUrl` shall add `engine=Rosetta` or `engine=Native (Mach9)`, from the bottle's runtime.
- `.github/ISSUE_TEMPLATE/game-report.yml` shall gain the dropdown `engine` with those two options, required, after `backend`.
- **Given** a report from a Mach9 bottle, **then** the URL carries `engine=Native+%28Mach9%29`. (repository test)
- **Check:** the form's ids, read by the test that already checks `game-report.yml`, include `engine`.

## PA6 · Text
- Every new label, line and hint shall be in `app_en.arb` and `app_es.arb`, worded in `app/shared/text/` with exhaustive switches over `RetinaMode` and `NativeOption`.
- `test/l10n_parity_test.dart` passes.
- `text_test.dart` covers each enum value in both languages.

## PA7 · Fit
- `pages_test.dart` shall render, at 720, 801, 1150 and 1921 px, in `en` and `es`, with long names:
  - a Mach9 bottle's Settings with the dropdown;
  - the Native engine options dialog;
  - the catalog detail with the Engine dropdown;
  - the engine card with Check.
- None overflows.

## PA8 · "Move to the Native engine…" (PE12; added in apply)
- **Where:** in a Rosetta bottle's panel, beside its Engine fact, when the Native engine is installed (`BottleDetail.nativeInstalled`, read from the runtime's folder only).
- **Confirming:** a `confirm()` names the bottle and says what happens:
  - its programs, files and settings move to a new Native bottle of the same name;
  - the Rosetta one is deleted at the end;
  - its installed runtimes and its programs' registry don't move.
- **While it moves:** the panel shows the step.
- **When it is done:** the bottle reloads, on the Native engine, and a toast names what to install again, if anything.
- **On a failure:** the error shows with its details, and the bottle is as it was.
- **Given** a Rosetta detail with `nativeInstalled`, **then** the button is there, and confirming sends `BottleDetailEvent.moveToNative`; without `nativeInstalled`, or for a Native bottle, it is absent. (widget and bloc tests)
- `pages_test` renders the panel with the button and with a move in progress, at the four widths, in `en` and `es`.

