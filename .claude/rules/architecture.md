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
- The engine throws `String` and `FormatException`; wrap every call in `repositoryCall`, which returns them as `Left(EngineError)`, and `DioException` as `Left(NetworkError)`
- `EngineHome` holds the data root; never call `bodegaHome` elsewhere
- Name clashes with the engine's functions: `import 'package:engine/engine.dart' as engine;`
- Downloads go through `Downloader`: HTTPS only, resumable, with progress. Don't use `dio.download`

## BLoCs
- All in `app/bloc/{name}/`, with Freezed events and one state with `@Default` fields and `copyWith`
- What must outlive a page (an install, what's open) is `@lazySingleton` and provided in `main.dart`
- What belongs to one page is `@injectable` and provided by that page
- Errors go in the state as `AppError?`; the page shows them

## Repositories
- Interface in `domain/repository/`, implementation in `data/repository/` with `@LazySingleton(as: Interface)`
- Methods return `Future<Either<AppError, T>>`

## Navigation
- `enum AppRoute` and the `GoRouter` in `app/router.dart`; paths in `RouterManager`
- Navigate by id: `RouterManager.go(AppRoute.library, context: context)`
- The redirect to `/setup` is `setupRedirect`, a pure function with its test

## Text
- Every UI string is in `lib/l10n/app_en.arb` (the template) and `app_es.arb`; widgets read `context.l10n.key` (`package:bodega/l10n/l10n.dart`)
- Only `app/` and `device/` build sentences. `domain/`, `data/` and blocs hold values: enums, ids, numbers, a typed `AppError`
- Errors are shown with `error.text(context.l10n)` (`app/shared/error_text.dart`); an `EngineError` shows the engine's English as is
- Engine `HostIssue`s and `Hint`s carry an `id` and `args`; `app/shared/engine_text.dart` translates the known ids and falls back to the engine's text
- Keys are lowerCamelCase, prefixed by area (`common`, `bottles`, `library`…); the Spanish file keeps the Spanish UI word for word

## DI
- Everything is registered with Injectable annotations, not by hand
- After adding one, run build_runner

## Host platform
- `HostPlatform` lives in `packages/engine/lib/platform.dart`. `MacPlatform` and `LinuxPlatform` are `part of 'engine.dart'`
- The engine uses the global `hostPlatform`. Tests replace it
- Anything that depends on the system (paths, env, tools, backends, sync, checks) goes in the platform, not in engine constants
- The app reads `HostCapabilities` and `HostIssue` through `RuntimeStatus`, and never imports the engine outside `data/`
- On Linux, Wine and the dxvk layer ship in the package, at `/opt/bodega/runtime` and `/opt/bodega/backends`. `LinuxPlatform.prepareHome` registers them in `~/.local/share/bodega` by link, or by copy when running from an AppImage
- D3D layers are copied into each prefix. A launch enables them per process with `WINEDLLOVERRIDES`
