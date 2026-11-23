# Spec · App

Requirements MA1..MA11: the Flutter app (`APP` is `apps/bodega/`): domain, errors, repositories, blocs, the engine card, the new bottle dialog, the bottle column, run options, text and tests (`design.md` §3.3, §3.4, §7). Every task's check is `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter gen-l10n && fvm flutter analyze && fvm flutter test && tool/check_layers.sh` in `APP`; the specific test is named below. Only `data/` imports the engine (`tool/check_layers.sh`).

## MA1 · The role map test starts green
`test/app/text_test.dart:2928-2942` shall include `BackendRole.dx9to11: 'DirectX 9 with DXVK, and 10 and 11 with DXMT'`, so the stream starts green with the uncommitted dxvk9 work.
- **Given** the tree today, **when** the test runs, **then** it passes. (test)
- **Check:** `fvm flutter test test/app/text_test.dart`.

## MA2 · Domain
`domain/entities` shall gain `runtime_kind.dart`, `runtime_block.dart`, `mach9_step.dart`, `bottle_step.dart` and the Freezed `runtime_info.dart` (design §3.3); `Bottle` and `BottleDetail` gain `@Default(RuntimeKind.bodega) runtime`, `BottleDetail` `@Default(false) monoMissing`; `WineTool.mono`, three `LogHint` values and `InstallStep.installingMono()`. `HostCapabilities` does not change, so `test/data/runtime_repository_test.dart` compiles unedited.
- **Check:** `tool/check_layers.sh`; `fvm flutter analyze`.

## MA3 · Errors
`AppError` shall gain `runtimeNotInstalled`, `runtimeUnavailable`, `runtimeNotTrusted`, `runtimeTooOld` and `backendNotForRuntime`, each with `{String? detail}`, mapped from the five engine failures in `appErrorOf` (exhaustive, `data/service/repository_call.dart`), and `WineToolFailed(mono)` to `wineToolFailed(WineTool.mono)`. Their words (design §5) live in `error_text.dart`; messages give app advice, never `bodega` commands; `detail` is never shown.
- **Given** each failure, **then** its `AppError`. (test, `repository_call_test`)
- **Given** each code in en and es, **then** its text. (test, `text_test`)
- **Check:** `fvm flutter test test/data/repository_call_test.dart test/app/text_test.dart`.

## MA4 · Repositories
`BackendRepository` shall gain `runtimes()` and `installRuntime(kind, {file, onProgress, onStep})` (false when cancelled, through `cancelDownload()`), whose Mach9 path is design §3.3's four steps (Downloader for the MSI and, without a file or matching app, the DMG; `installMach9`; delete only its own downloads). `readyBottles()` returns only ready bodega bottles; `graphics` computes misfits with `backendFitsFor` over the bottle's kind. `BottleRepository.create` gains `runtime` (default bodega) and `onStep`, in the order `createBottle(mono:false)`, `setWindowsVersion`, `setBackend`, `installMono` for Mach9; new `installMono(name)`; `list` fills `Bottle.runtime`; `_detail` fills `runtime`, `monoMissing` and `installedBackends` from `listBackends(runtime:)`, without `listRuntimes` (it runs in `Isolate.run`).
- **Given** a Linux `TestHome`, **then** `runtimes()` gives only bodega; a `MacPlatform` subclass with `mach9Block` null gives a mach9 entry. (test)
- **Given** a bottle whose settings say `"runtime":"mach9"`, **then** `readyBottles` leaves it out. (test)
- **Given** a Mach9 bottle, **then** misfits are only wine with DX12; its detail has `runtime` mach9, `monoMissing` true, and `installedBackends` `[]` without the runtime and `[wine, dxmt, mtld3d]` with a fake tree. (test)
- **Given** a legacy bottle, **then** `bottle_repository_test:39-53` still gives `['wine']`. (test)
- **Check:** `fvm flutter test test/data`.

## MA5 · BackendsBloc and the engine card
`BackendsBloc` shall load `runtimes` in `_load`, handle `installRuntime` events (from a file, from the found app, downloaded), mark `busy: 'mach9'`, show the step and progress, and cancel through `cancelDownload`. `presentation/backends/widgets/engine_card.dart` ("Native engine (Mach9)") shall sit before the backend loop (`backends_page.dart:51-55`), with "Graphics for the Rosetta engine" above the existing cards, both only when a mach9 entry exists that is not blocked as `appleSiliconOnly` or `notThisHost`. It shows design §7's states, the download and disk sizes from `mach9Release`, the Dock note, Install, "Choose file…" (a `.dmg` or `.app`, from `/Applications`), progress with a live region and Cancel. It is never a `BackendInfo` or `BackendCard` and never on Setup.
- **Given** `backends_bloc_test`'s setUp stubbing `runtimes()`, **then** installs from download, app and file, cancel and a failure emit the expected states. (test)
- **Given** each card state at 720, 801, 1150 and 1921 px in en and es, **then** it renders with no overflow and no English on Spanish screens, with copy-details for the new errors. (widget test + U, `pages_test`)
- **Given** `setup_page_test`, **then** it passes unedited. (test)
- **Check:** `fvm flutter test test/app/backends_bloc_test.dart test/app/pages_test.dart test/app/setup_page_test.dart`.

## MA6 · New bottle dialog
`NewBottleBloc` shall gain `@Default(RuntimeKind.bodega) runtime`, `runtimeChanged` (resets graphics to auto), the `BottleStep`, and an outcome where the bottle was made but Mono failed. The dialog shows Engine as the first of three `Expanded` dropdowns only when Mach9 is installed and usable, with Native preselected (D26); Graphics is keyed `ValueKey('graphics ${state.runtime}')` with that runtime's names; the note follows the engine. If three dropdowns do not fit at 720×480 the form scrolls. Without Mach9 the dialog is as today.
- **Given** `new_bottle_bloc_test`'s existing stubs, **then** they still match; new cases: `runtimeChanged` resets graphics, submit passes the runtime, a Mono failure leaves the bottle made. (test)
- **Given** `new_bottle_dialog_test`, **then** it fits at 720×480, shows exactly one "Automatic", and switching the engine raises no assertion. (widget test)
- **Check:** `fvm flutter test test/app/new_bottle_bloc_test.dart test/app/new_bottle_dialog_test.dart`.

## MA7 · Bottle column
The column shall show an Engine fact, hide AVX and DLSS for Mach9 bottles, and show the Mono warning with "Install Wine Mono" (`BottleDetailBloc.installMono`) when `monoMissing`.
- **Given** a Mach9 bottle detail with Mono missing, **then** the fact, the warning and the button render at every width in en and es, and no AVX or DLSS switch. (widget test + U)
- **Given** `bottle_detail_bloc_test`, **then** `installMono` success and failure. (test)
- **Check:** `fvm flutter test test/app/pages_test.dart test/app/bottle_detail_bloc_test.dart`.

## MA8 · Run with options
`run_options_dialog.dart:195-203` shall hide AVX for Mach9 bottles; its Graphics list is the bottle's `installedBackends` (MA4).
- **Check:** `fvm flutter test test/app/pages_test.dart`.

## MA9 · Text
New keys shall go into both ARBs with `@` descriptions, types and examples in `app_en.arb`, one key per meaning: `backendsRosettaGraphics`, `engineNativeTitle`, `engineNativeDescription`, `engineNativeIncludes`, `engineNativeDock`, `engineSizeDownload`, `engineSizeFromApp`, `engineOwnCopy`, `engineUseApp`, `engineUntested`, `engineNeedsMacos`, `engineUpdate`, seven `engineStep…`, `bottleEngine`, `engineNative`, `engineRosetta`, `newBottleNoteNative`, `newBottleNativeHint`, `newBottleInstallingMono`, `newBottleMonoFailed`, `engineNativeChip`, `engineRosettaChip`, `bottleMonoMissing`, `bottleInstallMono`, five error keys, three hint keys, the Mono wine-tool word and `installStepMono`. Words for codes live in a new `app/shared/text/runtime_text.dart` and in `error_text.dart`, `hint_text.dart`, `step_text.dart`, all exhaustive. `l10n_parity_test`'s `_sameInBothLanguages` gains Mach9, mtld3d, DXMT, vkd3d-proton, wined3d, Wine Mono and .NET; `vkd3d-proton` gets no backend description (`text_test` 636-672).
- **Check:** `fvm flutter gen-l10n`; `fvm flutter test test/l10n_parity_test.dart test/app/text_test.dart`.

## MA10 · Mappers
`data/service/code_mapper.dart` shall map `RuntimeKind`, `RuntimeBlock`, `Mach9Step`, `BottleStep`, `WineTool.mono`, the new `LogHint`s (`logHintOf`, `library_repository_impl.dart:144`) and `InstallStepKind.installingMono` (`installStepOf`) with exhaustive switches.
- **Check:** `fvm flutter test test/data/step_mapper_test.dart test/data/host_codes_test.dart`.

## MA11 · End to end on a fake runtime (optional)
A data test on Linux CI shall create a Mach9 bottle end to end against a fake Mach9 runtime folder, through `BottleRepository.create(runtime: mach9)`, and find `runtime` mach9 in its detail. It needs E5 and E6.
- **Check:** `fvm flutter test test/data/bottle_repository_test.dart`.
