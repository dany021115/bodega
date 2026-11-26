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

## AA5 · A row says what the program is

`LibraryApp` shall carry `arm64`, filled by `libraryApps` from `arm64Apps` once per bottle. The rows and cards of the bottle and of the library shall show, as the fact before the DirectX: `ARM64` on the Native engine, and `ARM64 · needs the Native engine` on the Rosetta engine. A row with neither fact shows nothing, as today.

- **Given** a bottle with an ARM64 exe and an x64 one, **then** the detail's apps hold `arm64` true and false.
- **Given** both engines and both languages, **then** `programFactsText` gives `ARM64 · DX9 · 32 bits`, `ARM64 · needs the Native engine`, or the DirectX alone.
- **Check:** `flutter test test/data/bottle_repository_test.dart test/app/text_test.dart`.

## AA6 · The add-program dialog warns, and only where it can happen

The add-app dialog shall be told whether its bottle runs on the Native engine, and shall show `addAppArm64Notice` under the chosen program when the file is ARM64 and the bottle is not. On the Native engine it says nothing, since the program runs there.

- **Given** an ARM64 program in a Rosetta bottle, **then** the notice is on screen.
- **Given** the same in a Native bottle, **then** it is not.
- **Check:** `flutter test test/app/add_app_bloc_test.dart test/app/add_app_dialog_test.dart`.
