# Bodega

Personal macOS launcher to play Windows games on Apple Silicon (M1-M4): Wine x86_64 under Rosetta 2, plus the graphics backends. Closed source, for one user. Answer in Spanish, in simple language. Code in English; UI in Spanish.

## Repo

Pub workspace (root `pubspec.yaml`):

- `packages/engine`: pure Dart. The engine and the `bodega` CLI. Knows nothing about Flutter.
- `apps/bodega`: the macOS app, with TeeShot's clean architecture.
- `wine/`: the recipe, patches and inputs that build Wine and its host libraries.
- `.sdd/`: specs, in Spanish. They are the source of truth: if one is wrong, say so and change it, don't code around it. Finished ones are in `.sdd/archive/`.

The Wine build lives in `wine/` (it was the `bodega-engine` repo, history included): its recipe and patches there, its GitHub Actions in `.github/workflows/`, where only the jobs that check out this repo run inside `wine/`. Its tarballs are in `../runtimes/`.

## Stack

Flutter 3.47 / Dart 3.13. These versions were chosen because TeeShot's own (freezed 2, build_runner 2.4) hang on modern Dart:

| Purpose | Package |
|---|---|
| State | flutter_bloc 9.1, bloc 9.2 |
| Models | freezed 4.0, freezed_annotation 3.1, json_serializable 6.15 |
| Navigation | go_router 18.1 |
| DI | get_it 9.3, injectable 3.0 |
| Network | dio 5.11, retrofit 4.10 |
| Errors | fpdart 1.2 (`Either<AppError, T>`) |
| Layout | responsive_framework 1.5 |
| Other | toastification, shared_preferences, url_launcher, flutter_svg, file_selector |
| Tests | bloc_test, mocktail |

Assets use `spider` (activated globally): `spider build` writes `lib/resources/`.

Freezed 4 syntax: `abstract class` for states and entities, `sealed class` for events.

## Commands

```
cd apps/bodega
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test && tool/check_layers.sh
flutter run -d macos

cd packages/engine
dart analyze && dart test
dart compile exe bin/bodega.dart -o ../../build/bodega
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) are gitignored: run build_runner after cloning.

## Layers

See `rules/architecture.md`. The short version: `domain/` is pure Dart, **only `data/` imports `package:engine`**, and `device/` doesn't import `data/` or `domain/`. `tool/check_layers.sh` enforces it.

## Lines not to cross

- D3DMetal is never bundled or downloaded by Bodega, nor copied from CrossOver: the user imports their own copy, and its license is their decision.
- Don't copy CrossOver's proprietary code, UI, data or brand (`crossover.tie`, `cxcompatdb`, CrossTie, closed helpers), and don't circumvent its licensing. Its LGPL Wine tree is fine.
- Don't help bypass anti-cheat: no hiding Wine from Easy Anti-Cheat, no swapping its modules.
- Catalog data comes from `highball-db` (CC0) at a pinned commit; the anti-cheat list is AreWeAntiCheatYet (MIT).

## Working here

- No `git commit` or `git push` without the user's approval. Leave a script and let them run it. Never add AI attribution to commits.
- Agents run Wine only headless. The user does anything with a window: games, launchers, installers.
- Never follow symlinks inside a bottle: `dosdevices/z:` points to `/`. Stop a bottle before deleting it.
- Don't delete `../runtimes/`: 335 MB over a slow Starlink link, from Cuba.
- Check against the real thing, not only mocks: real HTTPS and real bottles found what mocks and local servers didn't.
