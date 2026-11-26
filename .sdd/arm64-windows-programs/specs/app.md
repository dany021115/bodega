# Spec · the app

Requirements AA3..AA4. `APP` is `apps/bodega/`; every check is `cd APP && flutter analyze && flutter test && tool/check_layers.sh`.

## AA3 · One code, worded like the rest

`engine.ProgramNotForRuntime` shall become `AppError.programNotForRuntime(program)`: the engine's runtime is dropped, because the words do not name it. `appErrorOf` shall keep the engine's message as `detail`, and never word it.

`errProgramNotForRuntime` shall exist in both ARBs, name the program, say the Rosetta engine cannot run it, and give the two ways out: moving the bottle to the Native engine, or adding the program to a bottle on it. English and Spanish, no command lines (L8).

- **Given** the engine failure, **then** `appErrorOf` gives that code with the message as `detail`.
- **Given** both languages, **then** the text holds the program's name, gives no `bodega ...` command, and leaves the detail out.
- **Check:** `flutter test test/data/repository_call_test.dart test/app/text_test.dart test/l10n_parity_test.dart`.

## AA4 · Nothing else moves

No new screen, switch or bottle setting: the failure reaches the screen that launched the program, as any other. `text_test`'s table and its count (45 codes), `repository_call_test`'s (43 failures) and `l10n_parity_test` shall pass untouched except for the new rows.

- **Check:** `flutter analyze && flutter test && tool/check_layers.sh`.
