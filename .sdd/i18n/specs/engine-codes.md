# Spec · Engine codes

Requirements E1..E15: what the engine, the CLI, logs, `data/` and `domain/` carry instead of sentences (`design.md` §4, §5). `lib/` and `test/` are `apps/bodega/lib/` and `apps/bodega/test/`, where the app's commands run; `engine/` is `packages/engine/`, where `dart test` and `dart run bin/bodega.dart` run; other paths start at the repo root. How `app/` words the codes and shows errors is `app-text.md` (L6, L8, L9); the smoke run at release is N13. **(USER)**: only the user can check it, on a real Mac or Linux box.

**The engine grep**, at the repo root, is clean when it prints nothing; "no Spanish" below means no match for its pattern:
`grep -rniE '[áéíóúüñ¿¡]|\b(botellas?|falta|instalad[oa]s?|instalador|desconocid[oa]|aviso|pista|nota|usuario|resolucion|mandos|opcion|carpeta|uso|ruta|hay|existe|arreglo|sistema|soportad[oa]|disponible|nombre|licencia|juegos?|prueba|sonda|roto|nada|uno|valor|una|los|las|para|esta|con)\b' packages/engine --include='*.dart'`

## E1 · Engine failures are types
The engine shall throw only final subclasses of the sealed `EngineFailure implements Exception` (design §4), with typed fields, never a `String` or a `FormatException`.
- **Given** a home without the bottle `nope`, **when** `runInBottle`, `waitBottle` or `stopBottle` runs on it, **then** each throws `BottleNotFound` with `bottle == 'nope'` (`engine_test.dart:301-307`).
- **Given** the names `''`, `-x`, `a b` and 65 letters, **when** `bottleDir` checks them, **then** each throws `BadBottleName` with that `name` (`engine_test.dart:135-137`, today `throwsFormatException`).
- **Check:** `dart test` in `engine/`; `grep -rnE '\bthrow\b' packages/engine/lib | grep -vE 'throw (const )?[A-Z][A-Za-z0-9]*\('` and `grep -rn FormatException packages/engine/lib` print nothing (today 69 and 5 lines).

## E2 · Hints and steps are codes
`hintsIn`, `antiCheatHints`, `installEntry` and `installD3DMetalDmg` shall report `LogHint`, `AntiCheatHint`, `InstallStep` and `GptkStep` values (design §4), never text.
- **Given** a log with the FreeType, GnuTLS, `version mismatch` and `wine: failed to open` markers, **when** `hintsIn` reads it, **then** it returns `freeType`, `gnuTls`, `otherServer` and `cannotOpen`, once each; a clean log gives none (`engine_test.dart:310-329`).
- **Given** an EAC log that ends `finished with: 206` and names `POLYGON.`, **when** `antiCheatHints` runs, **then** it returns `[(game: 'POLYGON')]`; with no `ProcessTitle` line, `[(game: null)]` (`catalog_test.dart:288-317`).
- **Given** a catalog install into an existing bottle with another sync, **when** it reports its steps, **then** the first is `syncMismatch` and none is `creatingBottle` (`options_test.dart:271-291`); a D3DMetal import from a test dmg reports `GptkStep.importing` (`backends_test.dart:425-476`, on the Mac).
- **Check:** `dart test` in `engine/`.

## E3 · Host issues, backend roles and problems are codes
The engine shall return host issues as `HostIssue` records with a `HostIssueKind`, backend roles as `BackendRole`, user-name and path problems as `UserNameProblem` and `PathProblem`, and an unreadable D3DMetal version as `null` (design §4).
- **Given** `''`, 21 letters, `a/b` and `...`, **when** `badUser` checks them, **then** it returns `empty`, `tooLong`, `badCharacter` and `onlyDots`; taking a user whose profile folder exists throws `BadUserName` with `taken` (`options_test.dart:155-172`).
- **Given** a pad Bodega cannot open and no SDL2, **when** `gamepadIssues` runs, **then** it returns `padNoAccess`, with the pad's name as `subject` and its install command, and `noSdl` (`gamepads_test.dart:50-70`).
- **Given** a D3DMetal import whose version cannot be read, **when** `installD3DMetalDmg` ends, **then** it returns `null`, and `BackendsState.gptkInstalled` becomes `(version: null)`, so the page still toasts (`gptk_section.dart:50-56`).
- **Check:** `dart test` in `engine/` (also `backendRole` at `linux_test.dart:188`, `PathProblem` at `engine_test.dart:141-143`); `flutter test test/app/backends_bloc_test.dart`.

## E4 · English messages keep the command hints
Each `EngineFailure` shall have an English `message`, which `toString()` returns, and every other code an English text (an `english` field on enums without data, a `describe…` function in `engine/lib/english.dart` for records); both keep the command hint today's text gives.
- **Given** `BottleOpen('steam')`, **when** printed, **then** it reads `the bottle steam is open: bodega stop steam` (design §4).
- **Given** one instance of each of the 31 subclasses and of every code, **when** read, **then** each text is non-empty, has no Spanish, and keeps its hint: `bodega stop <bottle>` (`BottleNotReady`, `BottleOpen`, `LogHint.otherServer`), `bodega install <engine.tar.gz> <hostlibs.tar.gz>` (`NoRuntime`), `gh release download` (`ChecksumMissing`), `bodega backend install` or `import d3dmetal` (`BackendNotInstalled`; `NotDownloadable` for d3dmetal), `bodega catalog list` or `bodega fix list` (`BadChoice`), `bodega run <bottle>` (`AppNotFound` with no key), `rm -rf "<path>"` (`AlreadyInstalled`).
- **Given** `(game: 'POLYGON')` and `(game: null)`, **when** described, **then** the anti-cheat text names `POLYGON`, or no game, and error 206.
- **Check:** `dart test test/english_test.dart` in `engine/` (new).

## E5 · English logs
The engine shall write its logs in English: `# note` (was `# aviso`, `engine.dart:579`), the labels `user`, `resolution` and `pads` (`backends.dart:678`, `:700`, `platform_mac.dart:317`), the origins `option` and `bottle` (`backends.dart:743`, `:747`) and the `fixNotApplied` note (`fixes.dart:125`), which `hintsIn` reads back as `LogHint.fixNotApplied`.
- **Given** Steam already open and a game whose fix needs launch variables, **when** `openApp` runs it, **then** its log has a `# note` line with the English `fixNotApplied`, and `hintsIn` returns `[LogHint.fixNotApplied]` (`fixes_test.dart:229-239`).
- **Given** a backend chosen by an option or by the bottle, **when** `resolveBackend` runs, **then** the origin is `option` or `bottle` (`backends_test.dart:245`, `:315`, `:318`); the pads log ends in `-pads.log` (`apps_test.dart:477`).
- **Check:** `dart test` in `engine/`; the engine grep.

## E6 · English CLI
`bodega` shall print its usage, labels, results, catalog prose and failures in English, a failure as `bodega: <message>` on stderr with exit code 1 (`bin/bodega.dart:253-256`, without the `FormatException` branch), keeping the hints of E4.
- **Given** no arguments, **when** `dart run bin/bodega.dart` runs, **then** stderr starts with `usage: bodega install <engine.tar.gz> <hostlibs.tar.gz>` (`:6-31`) and the exit code is 64.
- **Given** an empty `BODEGA_HOME`, **when** `bodega catalog show nope` runs, **then** stderr is one line that starts with `bodega: `, names `nope` and keeps `bodega catalog list`, and the exit code is 1.
- **Given** an empty `BODEGA_HOME`, **when** `catalog show steam`, `backend list`, `fix list` and `pads` run, **then** their output has no Spanish.
- **Check:** those commands in `engine/` with `BODEGA_HOME=$(mktemp -d)`, their output piped through `grep -iE` with the engine grep's pattern.

## E7 · The line the smoke test greps
`backend list` shall print one `<backend>: installed` or `<backend>: not installed` line per backend (`bin/bodega.dart:199`), the exact line `tool/smoke_linux.sh:46` greps, which changes in the same commit; N13 (USER) runs the smoke test at release.
- **Given** a `BODEGA_HOME` holding an empty `backends/dxvk/wine` folder, **when** `dart run bin/bodega.dart backend list` runs on the Mac, **then** `grep -qx 'dxvk: installed'` on its output exits 0, as in the smoke test, and every line matches `^[a-z0-9]+: (installed|not installed)$`.
- **Check:** that command; `grep -n "grep -qx 'dxvk: installed'" tool/smoke_linux.sh` prints line 46.

## E8 · No Spanish in the engine
No file in `packages/engine/` (code, comments, test fixtures and skip reasons, `catalog_data.dart` included, design §7) shall hold Spanish (the app: L19).
- **Given** the finished change, **when** the engine grep runs, **then** it prints nothing (today 314 lines in 20 files).
- **Given** the non-ASCII path case (`engine_test.dart:139`, today `ñ`), **when** the engine grep and N14's repo-wide grep run, **then** neither lists it: it uses a letter outside both, such as `ø`.
- **Check:** the engine grep; `dart test` in `engine/`.

## E9 · `AppError` is a union of codes
`AppError` (`app_error.dart:7-12`) shall be a Freezed `sealed class` that implements `Exception`, with one factory per code of design §5 (31), each with its typed fields and an optional `detail`, and no `engine(String)` or `message`.
- **Given** two `AppError.bottleOpen('steam', detail: 'x')`, **when** compared, **then** they are equal, and `detail` reads `'x'` on `AppError` without a cast.
- **Given** the variables `GOOD=1` and `bad`, **when** the run options are submitted, **then** the state's error is `AppError.badEnvLine(2, 'bad')` and nothing launches (`run_options_bloc_test.dart:103-123`).
- **Check:** `flutter analyze`; `flutter test test/data/repository_call_test.dart test/app/run_options_bloc_test.dart`; `grep -rn 'AppError.engine' lib test` prints nothing.

## E10 · `data/` maps failures in one switch
`repositoryCall` (`repository_call.dart:9-27`) shall pass a thrown `AppError` as it is and map an `EngineFailure` through `appErrorOf`, one exhaustive switch with no default, to the code of the same name with `detail: failure.message` (`BadWindowsPath`, `MissingFile` and `ChecksumMissing` to `badPath`; `NotAvailable`, `NotDownloadable`, `BadChoice`, `CatalogBlocked` and `NotHttps` to `unknown`), a `DioException` to `network(detail: …)` and anything else to `unknown(detail: '$e')`.
- **Given** a call that throws `BottleOpen('steam')`, **when** wrapped, **then** it returns `Left(AppError.bottleOpen('steam', detail: 'the bottle steam is open: bodega stop steam'))`; `NotHttps(url)` gives `Left(AppError.unknown(detail: …))`.
- **Given** a call that throws a `DioException`, a `StateError('x')` or `AppError.downloadCut(10, 20)`, **when** wrapped, **then** it returns `network(detail: …)`, `unknown(detail: 'Bad state: x')` or the same `downloadCut`.
- **Given** a home without the bottle `missing`, **when** `BottleRepository.detail` runs, **then** it returns `bottleNotFound('missing')` with the engine's message as `detail` (`bottle_repository_test.dart:81-85`).
- **Check:** `flutter test test/data`, with `test/data/repository_call_test.dart` (new); `grep -rnE '_ =>|default:' lib/data` prints only the switch on the OS in `update_repository_impl.dart`.

## E11 · `data/` and `domain/` carry codes, never sentences
`data/` and `domain/` shall hold no user-facing text: the 14 data sentences become the codes of design §5, mappers copy codes and never engine text, `HostIssue`, `BackendInfo`, `CatalogApp` and `ExeGraphics` lose their text, and steps, hints and problems arrive as `InstallStep`, `GptkStep`, `RunHint`, `UserNameProblem` and `PathProblem`.
- **Given** a dmg whose SHA-256 does not match, **when** `UpdateRepository.download` runs, **then** it returns `Left(AppError.checksumMismatch(<file>))` and deletes the file (`update_repository_test.dart:147-160`).
- **Given** a missing exe and one in a folder named `odd:`, **when** `pathProblem` runs, **then** it returns `PathProblem.missing(<path>)` and `PathProblem.windowsName(part: 'odd:', path: <path>)` (`add_app_repository_test.dart:65-75`).
- **Given** a corrupt pinned tarball already in `downloads/`, **when** `BackendRepository.download` runs, **then** it returns `Left(AppError.checksumMismatch(…))` and the tarball is gone (`backend_repository_impl.dart:65-71` catches `engine.EngineFailure`).
- **Check:** `flutter test test/data`; `grep -rn "throw '" lib/data` prints nothing; `grep -nE 'statusNote|knownIssues|List<String> notes|String\? flaky|String use|get label|warning\(|String (title|detail)' lib/domain/entities/{host_issue,backend_info,catalog_app,exe_graphics}.dart` prints only `CatalogApp`'s `title` (today 10 lines); L19's grep.

## E12 · Codes cross the layers unworded
Each engine code shall reach `app/` through a domain twin and an exhaustive mapper in `data/`, and be worded only in `lib/app/shared/text/` (L8), so a new engine code fails analysis until every layer handles it (design §5).
- **Given** a temporary new `LogHint` value with its English text, **when** `flutter analyze` runs, **then** it reports the `data/` mapper as not exhaustive; once the domain value and its mapping exist, it reports the switch in `hint_text.dart`.
- **Given** a temporary new `EngineFailure` subclass, **when** `flutter analyze` runs, **then** it reports `appErrorOf` as not exhaustive.
- **Check:** `flutter analyze` after each temporary edit in a scratch copy, as L8 does; `tool/check_layers.sh` (N12).

## E13 · `detail` is raw text, for copying only
`detail` shall hold the raw text behind a code (the engine's English message, a tool's stderr, Dio's text), set in `data/` and never used to word a code; the screens and "Copy details" are L9.
- **Given** `appPath` in a writable folder and a file that is not a dmg, **when** `UpdateRepository.install` runs on the Mac, **then** it returns `processFailed` for `/usr/bin/hdiutil` with its exit code and hdiutil's stderr as `detail` (`update_repository_impl.dart:201-208`, `:251-255`).
- **Given** every code built with `detail: 'DETAIL-7f3'`, **when** it is worded in `en` and in `es`, **then** no text contains `DETAIL-7f3`.
- **Check:** `flutter test test/data/update_repository_test.dart test/app/text_test.dart`.

## E14 · Hints de-duplicated by value
`LibraryBloc` shall add a hint to a bottle's card, and toast it, only when no equal `RunHint` is there yet (`library_bloc.dart:196-215`), as it compared text before (L6).
- **Given** a running bottle, **when** two anti-cheat checks both find `antiCheat(game: 'POLYGON')`, **then** the card holds it once and `toastId` is 1 (`library_bloc_test.dart:220-239`).
- **Given** a closing run, **when** its hints are `antiCheat(game: 'A')`, `antiCheat(game: 'B')` and `log(LogHint.freeType)` twice, **then** the card holds three hints, in that order, and `toastId` is 3.
- **Check:** `flutter test test/app/library_bloc_test.dart`.

## E15 · Real bottles and devices (USER)
On a real Mac and a real Linux box, codes from real bottles and devices shall reach the screen in the active language, with no Spanish from the engine and no CLI command.
- **Given** Steam already open in a bottle on the Mac, **when** the user opens a game that has a fix from Bodega and closes it, **then** the fix-not-applied hint shows once, on the card and in one toast, and switching the language in Settings rewords the card.
- **Given** the user's Game Porting Toolkit dmg, **when** they import D3DMetal, **then** each step and the final toast read in the active language.
- **Given** a pad Bodega cannot open on Linux, **when** the user opens a bottle's Gamepads section, **then** the issue names the pad, in the active language, with its install command.
- **Check:** screenshots on the user's Mac and Linux box, in English and in Spanish.
