# Exploration: flutter-app

**Paths:** `P` = `bodega/packages/engine`; `TS` = `~/Documents/GitHub/TeeShot/TeeShot`; `SF` = `~/Documents/GitHub/SuperFuel23`. Read-only; nothing in this exploration has been built or tested.

## 1. Problem and scope

Bodega only works from the command line. The user wants the desktop app, like CrossOver, inside this repo as a **monorepo**, with TeeShot's architecture and tools: clean architecture, a structured `go_router`, an organized `theme` folder, code generation, breakpoints, `dio` "and the other stuff in there".

Screens already agreed: catalog with search and install with progress, library, per-bottle settings (backend and msync), "install another application" and instructions for installing D3DMetal.

## 2. TeeShot's architecture

Sources: `TS/.claude/CLAUDE.md`, `TS/.claude/rules/{architecture,code-style,widget-standards}.md`, `TS/.claude/skills/create-feature`.

```
lib/
├── main.dart            # MultiBlocProvider + MaterialApp.router
├── di.dart / di.config.dart   # get_it + injectable
├── app/
│   ├── router.dart      # GoRouter, enum AppRoute, ShellRoute
│   ├── bloc/            # global blocs (nav, theme…)
│   ├── presentation/{feature}/  # page, bloc/, widgets/
│   └── shared/widgets/  # main_shell, custom_loading, empty_state…
├── data/
│   ├── api/             # rest_client (retrofit), catch_error (AppError)
│   ├── constants/  entities/  repository/  service/  utils/
├── device/
│   ├── router/          # manager, observer, transitions
│   ├── theme/           # color, radius, spacing, theme, typography
│   └── helpers/         # app_toast
├── domain/
│   ├── entities/        # freezed, immutable
│   └── repository/      # interfaces
└── resources/           # assets generated with spider
```

**Rules to respect:**
- `domain/` imports nothing from `data/`, `device/` or `app/`. `data/` implements the `domain/` interfaces. `device/` does not import `data/` or `domain/`. `app/` can import all of them (`architecture.md`).
- Repositories: interface in `domain/repository/`, implementation with `@LazySingleton(as: …)`, and methods that return `Future<Either<AppError, T>>` with fpdart (`TS/lib/data/repository/app_config_repository_impl.dart`; `AppError` in `TS/lib/data/api/catch_error.dart`).
- Bloc: freezed for events and state, a single state with `@Default` and `copyWith`, `@injectable` or `@singleton`. Global ones in `app/bloc/`, each screen's in `app/presentation/{feature}/bloc/` (example: `TS/lib/app/bloc/theme/`).
- Router: `enum AppRoute` and `GoRouter` in `TS/lib/app/router.dart:38`, `ShellRoute` with `MainShell` at `:248`, `RouterManager` with typed routes in `TS/lib/device/router/manager.dart`, and `PageTransitions` in `transitions.dart`. Navigation is by id, not by `extra` (the user's memory).
- Theme: `AppColor`, `AppRadius`, `AppSpacing`, `AppTextStyle` and `AppTheme`, one file each (`TS/lib/device/theme/`), plus `ThemeBloc`.
- Breakpoints: `responsive_framework`, mobile 0–450, tablet 451–800, desktop 801–1920, 4K from 1921 (`TS/lib/main.dart:168-176`).
- Widgets: one per file in `app/presentation/{feature}/widgets/`. No layout jumps: `Opacity` instead of `if` for elements that appear and disappear. Use the shared widgets, such as `CustomLoading` (`widget-standards.md`).
- Other: absolute `package:…` imports, UI in Spanish and code in English, `AppToast` with toastification (`TS/lib/device/helpers/app_toast.dart`).

## 3. Dependencies

| Group | Packages | Use in Bodega |
|---|---|---|
| Used the same way | `flutter_bloc`, `bloc`, `go_router`, `responsive_framework`, `get_it`, `injectable`, `fpdart`, `freezed`, `json_serializable`, `build_runner`, `toastification`, `shared_preferences`, `url_launcher`, `package_info_plus`, `flutter_svg`, `mocktail`, `spider` | As is |
| Need a real use | `dio`, `retrofit` | §5 |
| No clear use | `envied` | Bodega has no secrets (§8) |
| Do not apply | Firebase, Sentry, RevenueCat, maps, geolocation, notifications, Phoenix, TTS, ads | They belong to the mobile product or to login |

**Version pitfall.** TeeShot pins `freezed ^2`, `build_runner ^2.4` and `injectable ^2`, with the `@freezed class X with _$X` syntax. With modern Dart that breaks: `build_runner` 2.4 pulls in an analyzer that hangs on dot-shorthands (the user's memory, `wa_catalog`). This Mac has Dart 3.13 and Flutter 3.47. `SF/pubspec.yaml` is the modern reference: `freezed ^3.2`, `build_runner ^2.15`, `injectable ^3`, `json_serializable ^6.14`. In freezed 3 you write `abstract class` for state and `sealed class` for events. **We copy TeeShot's structure, not its versions.** The compatibility of `retrofit_generator` is still to be checked.

## 4. Monorepo

Today the repo has `packages/engine`, `.sdd/` and `build/`. `apps/` is missing.

- The app would go in `apps/bodega`, and the engine would stay as `packages/engine`, with a *pub workspace* at the root (Dart 3.13 supports it; not yet tested with Flutter and `build_runner`).
- The app imports `package:engine/engine.dart` and `data/` acts as the adapter. `domain/` never sees the engine.
- The `bodega` program still exists. `P/bin` and its tests should not change.
- macOS only: `flutter create --platforms=macos`.

## 5. Where `dio` fits

Today the app would not make any HTTP call of its own: the engine downloads with `curl` (`P/lib/backends.dart`, `_download`). Real uses:

1. **Downloads with a progress bar and cancel.** `curl` gives the app no progress. `Dio.download` does, with `onReceiveProgress`, `CancelToken` and `Range` to resume. `installEntry` needs to accept an installer that is already downloaded (§6).
2. **Anti-cheat list before downloading.** `db/anticheat.json` from `highball-db` (1,166 games, MIT) through `retrofit`, with a local cache. It delivers what was promised: warn before downloading a game. POLYGON is not on that list, so it does not cover every case.

## 6. What the engine is missing for the app

| Missing | Today | Ref |
|---|---|---|
| List bottles, including the ones that do not come from the catalog | `installedApps` only sees the ones that have `app.json` | `P/lib/catalog.dart:215` |
| Read a bottle's settings | `_settings` is private | `P/lib/backends.dart` |
| Delete a bottle | Does not exist | — |
| Check Rosetta and whether there is a runtime | Rosetta only in the CLI; `currentRuntime` throws an error | `P/bin/bodega.dart`; `P/lib/engine.dart:173` |
| Pass an already downloaded installer | `installEntry` always downloads | `P/lib/catalog.dart:66` |
| Know whether a bottle is still open | `exitOf` gets it wrong with launchers that relaunch themselves: Steam gave `exit=42` and was still alive (`verify.md` of `catalog`) | `P/lib/engine.dart:319` |
| Read a bottle's logs | They are only written | — |

For "still open", `waitBottle` is enough (`wineserver -w`, `P/lib/engine.dart:303`): it ends when the last process goes away and returns at once if there is no server.

## 7. Pitfalls

1. **Sandbox off:** the Flutter template turns on `com.apple.security.app-sandbox`. With it, Wine cannot be launched and nothing can be written outside the container (`INFORME-FINAL.md` §9.2).
2. **Blocking the interface:** the engine does synchronous reads (`antiCheatHints`, `_settings`, `importD3DMetal`). They are short, except the EAC log of about 600 KB and copying modules. It will have to be measured.
3. **The game does not depend on the app:** programs run detached. If Bodega is closed, they stay open, and on coming back the state has to be rebuilt from disk.
4. **Half-done install:** if the app is closed during an install, a bottle without `app.json` is left behind. The library must show it as incomplete and let the user delete it.
5. **Environment when opened from Finder:** `bodegaHome` reads `HOME`, and `wineEnv` copies `USER`, `LOGNAME` and `TMPDIR` from `Platform.environment`. This has to be confirmed outside Terminal.
6. **iOS rules in TeeShot:** the App Store ones do not apply. Their macOS equivalent does: `AppTextStyle.fontFamily` set to `null` gives SF Pro.
7. **`dart:io`:** TeeShot forbids it because of the web. Here it is macOS only and the engine uses it, but it still stays out of `domain/`.

## 8. Questions for the proposal

1. **Path and name:** `apps/bodega`, package `bodega`, bundle `com.dany021115.bodega`.
2. **`envied`:** Bodega has no keys. Leave it out until it is needed?
3. **First launch:** the runtime repo is private, so the app cannot download it without a token. A screen that picks the local tarballs with `file_selector`?
4. **Icons:** logos from `simple-icons` (their license, and whether all 7 are there, still to be confirmed), with their SVGs in `assets` and `spider`?
5. **Look:** dark theme by default, like your screenshot, with a sidebar on desktop. Any brand color?
6. **Bottles and backends screen:** a section of its own, or inside each application?
7. **Rules for the future:** should I create `.claude/CLAUDE.md` and `rules/` in this repo, as in TeeShot, so the architecture does not get lost?
