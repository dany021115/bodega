---
paths:
  - "apps/bodega/lib/**/*.dart"
---

# Architecture Rules

## Layer Dependencies
- `domain/` is pure Dart: no `flutter`, `dart:io`, `package:engine`, `data/`, `device/` or `app/`
- `data/` implements `domain/`, and is the only layer that imports `package:engine`
- `device/` does NOT import from `data/` or `domain/`
- `app/` can import from the other layers

## Where Each Thing Goes
- Entities and repository interfaces → `domain/`
- Repository implementations, DTOs, the API, services → `data/`
- Theme, router helpers, toasts, breakpoints → `device/`
- BLoCs, pages, widgets, router config → `app/`

`AppError` lives in `domain/entities/`, not in `data/` as in TeeShot, so that repository interfaces don't import the data layer.

## The Engine as a Data Source
- Repositories turn engine types into domain entities
- The engine throws `EngineFailure`; wrap every call in `repositoryCall`, which maps it to an `AppError` code in one exhaustive switch (`appErrorOf`), a `DioException` to `network` and anything else to `unknown`
- `EngineHome` holds the data root; never call `bodegaHome` elsewhere
- Name clashes with the engine's functions: `import 'package:engine/engine.dart' as engine;`
- Downloads go through `Downloader`: HTTPS only, resumable, with progress. Don't use `dio.download`

## BLoCs
- All in `app/bloc/{name}/`, with Freezed events and one state with `@Default` fields and `copyWith`
- What must outlive a page (an install, what's open) is `@lazySingleton` and provided in `main.dart`
- What belongs to one page is `@injectable` and provided by that page
- Errors, steps and hints go in the state as codes (`AppError?`, `InstallStep`, `RunHint`); the page words them

## Text
- What the user reads lives in `lib/l10n/`: `app_en.arb` is the template and holds each key's `@key` (a description, and each placeholder's type and example); `app_es.arb` is the Spanish translation. Read it with `context.l10n` (`package:bodega/l10n/l10n.dart`)
- A new key goes into both ARBs, or `test/l10n_parity_test.dart` fails. One key per meaning, never shared because the English matches
- gen-l10n is not build_runner: run `flutter gen-l10n` after editing an ARB (`flutter pub get`, `run` and `build` also run it)
- Errors are codes: an `AppError` is worded by `error.localized(l10n)` (`app/shared/text/error_text.dart`). Its `detail` (the engine's English message, a tool's stderr) is never rendered; `CopyDetailsButton` copies it
- No user-facing copy in `domain/` or `data/`: they return codes, and the page phrases them
- Only `app/` and `main.dart` import `package:bodega/l10n/` (`tool/check_layers.sh`)
- Words for codes live in `app/shared/text/`, one file per family, in exhaustive switches without `_ =>`, so a new code fails analysis until it is worded. Only tables keyed by a `String` (backend names, catalog ids and source fields) keep a default

## Repositories
- Interface in `domain/repository/`, implementation in `data/repository/` with `@LazySingleton(as: Interface)`
- Methods return `Future<Either<AppError, T>>`

## Navigation
- `enum AppRoute` and the `GoRouter` in `app/router.dart`; paths in `RouterManager`
- Navigate by id: `RouterManager.go(AppRoute.library, context: context)`
- The redirect to `/setup` is `setupRedirect`, a pure function with its test

## DI
- Everything is registered with Injectable annotations, not by hand
- After adding one, run build_runner

## Host platform
- `HostPlatform` lives in `packages/engine/lib/platform.dart`. `MacPlatform` and `LinuxPlatform` are `part of 'engine.dart'`
- The engine uses the global `hostPlatform`. Tests replace it
- Anything that depends on the system (paths, env, tools, backends, sync, checks) goes in the platform, not in engine constants
- `HostPlatform.emulators` gives the host's `EmulatorHost`. Switch's engine code and its emulator table live in `packages/engine/lib/switch.dart`. The table's `page`, the emulator's official download page, is the one link of Switch's code: the app gets it through `SwitchStatus` and opens it with `launchUrl`
- The app reads `HostCapabilities` and `HostIssue` through `RuntimeStatus`, and never imports the engine outside `data/`
- On Linux, Wine and the dxvk layer ship in the package, at `/opt/bodega/runtime` and `/opt/bodega/backends`. `LinuxPlatform.prepareHome` registers them in `~/.local/share/bodega` by link, or by copy when running from an AppImage
- D3D layers are copied into each prefix. A launch enables them per process with `WINEDLLOVERRIDES`
