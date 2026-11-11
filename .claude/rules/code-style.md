---
paths:
  - "apps/bodega/lib/**/*.dart"
  - "apps/bodega/test/**/*.dart"
---

# Code Style Rules

## Imports
- Absolute: `package:bodega/...`. Never relative, except in tests for the helpers under `test/` (`../support/pump.dart`, `_home.dart`): `test/` has no `package:` URI
- Order: dart core, external packages, `package:bodega`, as `dart format` and the analyzer leave them

## Freezed
- Events: `sealed class`, with `const factory {Name}Event.action() = {Name}ActionEvent;`
- State and entities: `abstract class`, with one factory and `@Default` fields
- A union with several factories, like `AppError`, is a `sealed class`, so a `switch` over it is exhaustive
- Getters need `const {Name}._();`

## Naming
- Files: `snake_case.dart`, matching the main class
- BLoC files: `{name}_bloc.dart`, `{name}_event.dart`, `{name}_state.dart`
- Code in English; what the user reads comes from `lib/l10n/` through `context.l10n`

## Tests
- Every BLoC with `bloc_test` and repositories mocked with `mocktail`
- Repositories that touch the engine run against a temporary home (`test/data/_home.dart`)
- Widget tests pump through `wrapApp` or `wrapRouter` (`test/support/pump.dart`), pinned to `en`: a bare `MaterialApp` fails `context.l10n`'s assert
- Assertions and fixtures are English; Spanish is reached only through `lookupAppL10n(const Locale('es'))`, never a Spanish literal
- `test/app/pages_test.dart` renders each screen at the window sizes that matter, with long texts, in `en` and in `es`: add new screens there, because it catches overflows
