# App foundation

## B1 · Project
`apps/bodega`, created with `flutter create --platforms=macos --org com.dany021115 --project-name bodega`. `com.apple.security.app-sandbox` removed from both `.entitlements` files. Window with a minimum size of 720×480 (`MainFlutterWindow.swift`) and the title Bodega.

**Check:** `flutter build macos` finishes; the app opened with `open` launches Wine (`design.md` §7).

## B2 · Layers
The structure of `TS/lib`: `main.dart`, `di.dart`, `app/{router.dart,bloc,presentation,shared/widgets}`, `data/{api,entities,repository,service}`, `device/{router,theme,helpers}`, `domain/{entities,repository}`, `resources`.

Rules:
- `domain/` does not import `flutter`, `dart:io`, `engine`, `data/`, `device/` or `app/`.
- `data/` is the only layer that imports `package:engine`.
- `device/` does not import `data/` or `domain/`.
- Absolute `package:bodega/…` imports. One widget per file in `widgets/`. UI in Spanish, code in English.

**Check (T15):** a `grep` that fails if `domain/` imports any of that, or if another layer imports `package:engine`.

## B3 · Theme
`device/theme/{color,radius,spacing,typography,theme}.dart`, like TeeShot. Dark by default, burgundy accent, `AppTextStyle.fontFamily` set to `null` for SF Pro. `ThemeBloc` in `app/bloc/theme/` with the preference in `shared_preferences`.

**Scenario (test `ThemeBloc`):** it starts dark; `toggle` switches it and the choice is saved.

## B4 · Router
`enum AppRoute` and `GoRouter` in `app/router.dart`; `RouterManager`, `PageTransitions` and `StackObserver` in `device/router/`. `ShellRoute` with `MainShell` for the four sections. Navigation is by id.

Redirect: without a runtime or without Rosetta, always to `/setup`; with both, `/setup` leads to `/library`.

**Scenario (test `router`):** the redirect returns those routes in each case.

## B5 · Breakpoints
`ResponsiveBreakpoints.builder` with the values from `TS/lib/main.dart:170-175`. From `DESKTOP` up, a sidebar with text, and two columns in the catalog grid; below that, a compact icon bar and one column.

**Scenario (widget test `MainShell`):** at 1000 px the text shows; at 600 px, only the icons.

## B6 · Errors and notices
A sealed `AppError` in `domain/entities/`: `EngineError(message)`, `NetworkError(message)` and `UnknownError(message)`. Repositories catch whatever the engine throws and return `Left`. Blocs keep it in the state. `AppToast` in `device/helpers/`.

**Scenario (repository test):** an engine error arrives as `Left(EngineError)` with its text.

## B7 · Injection and generated code
get_it and injectable with `@InjectableInit`, `preResolve` for `SharedPreferences`, a `build.yaml` like TeeShot's without `envied`. `*.g.dart`, `*.freezed.dart` and `di.config.dart` in `.gitignore`, and excluded from the analyzer.

**Check:** `dart run build_runner build` generates without errors and `flutter analyze` comes out clean.

## B8 · Assets
7 SVGs from `simple-icons` in `assets/icons/catalog/`, with `spider.yaml` and constants in `resources/`. They are painted with the brand color, or with the theme's color if the brand color is black.

## B9 · Repo rules
`.claude/CLAUDE.md`, and `rules/{architecture,code-style,widget-standards}.md`, adapted from TeeShot, without the iOS-specific parts, and with what is specific to this repo: versions, the engine only in `data/`, and `.sdd`.
