---
paths:
  - "apps/bodega/lib/**/*.dart"
  - "apps/bodega/test/**/*.dart"
---

# Code Style Rules

## Imports
- Absolute: `package:bodega/...`. Never relative
- Order: dart core, external packages, `package:bodega`, as `dart format` and the analyzer leave them

## Freezed
- Events: `sealed class`, with `const factory {Name}Event.action() = {Name}ActionEvent;`
- State and entities: `abstract class`, with one factory and `@Default` fields
- Getters need `const {Name}._();`

## Naming
- Files: `snake_case.dart`, matching the main class
- BLoC files: `{name}_bloc.dart`, `{name}_event.dart`, `{name}_state.dart`
- Code in English; everything the user reads in Spanish

## Tests
- Every BLoC with `bloc_test` and repositories mocked with `mocktail`
- Repositories that touch the engine run against a temporary home (`test/data/_home.dart`)
- `test/app/pages_test.dart` renders each screen at the window sizes that matter, with long texts: add new screens there, because it catches overflows
