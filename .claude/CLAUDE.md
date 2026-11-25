# Bodega

Open-source launcher to play Windows games on Apple Silicon Macs and on x86_64 Linux, and Nintendo Switch games on the Mac through an emulator the user installs. On the Mac each bottle runs on one of two engines, fixed at creation: Bodega's x86_64 Wine under Rosetta 2, plus the graphics backends, or the Native engine, Mach9 (an arm64 Wine, Zlib), which Bodega copies unmodified into `runtimes/mach9-<version>` and never bundles. Public on GitHub, under the GPL-3.0-or-later; `wine/` is LGPL-2.1-or-later. Answer the user in Spanish, in simple language.

## Language

Everything that goes into git is in English: code, comments, docs, `.sdd/` specs (this overrides the `sdd` skill's Spanish default), commit messages, branch names, tags, pull request titles and bodies, workflow and step names, and script messages. The only Spanish in the repo is the translation: `apps/bodega/lib/l10n/app_es.arb`, `apps/bodega/macos/Runner/es.lproj/*.strings` and the `[es]` keys of `packaging/linux/bodega.desktop`; besides them, only the language menu's own name for Spanish, which is written in Spanish. Talking to the user stays in Spanish.

## Repo

Pub workspace (root `pubspec.yaml`):

- `packages/engine`: pure Dart. The engine and the `bodega` CLI. Knows nothing about Flutter. Runs on macOS and on Linux (x86_64, Ubuntu 24.04+).
- `apps/bodega`: the app, for macOS and Linux, with TeeShot's clean architecture.
- `wine/`: the recipe, patches and inputs that build Wine and its host libraries.
- `.sdd/`: specs, in English. They are the source of truth: if one is wrong, say so and change it, don't code around it. Finished ones are in `.sdd/archive/`.

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

Freezed 4 syntax: `abstract class` for states and entities, `sealed class` for events and for unions with several factories, like `AppError`.

## Commands

```
cd apps/bodega
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n   # after editing an ARB (flutter pub get, run and build also run it; build_runner does not)
flutter analyze && flutter test && tool/check_layers.sh
flutter run -d macos

cd packages/engine
dart analyze && dart test
dart compile exe bin/bodega.dart -o ../../build/bodega

# Mach9, the Native engine (agents: only in a temporary BODEGA_HOME, and see Lines not to cross)
bodega runtime list
bodega runtime install mach9 [Mach9.dmg|Mach9.app] [--mono <wine-mono.msi>]
bodega create --runtime mach9 <bottle>     # without --runtime: Bodega's engine
bodega mono install <bottle>
bodega rules <bottle> [--backend <b>] [--hud] <program>   # the WINE_COMPATDB a launch would send
bodega backend list --runtime mach9
bodega catalog install <id> [bottle] --runtime mach9

tool/package_linux.sh   # .deb (needs dpkg-deb), .tar.gz, AppImage and Arch .pkg.tar.zst (needs makepkg) in dist/ (releases: workflow release-linux, manual only)
tool/version.sh get|bump|check   # SemVer in apps/bodega/pubspec.yaml
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, and gen-l10n's `lib/l10n/app_localizations*.dart` and `untranslated.json`) are gitignored: run build_runner after cloning; `flutter pub get` runs gen-l10n.

## Layers

See `rules/architecture.md`. The short version: `domain/` is pure Dart, **only `data/` imports `package:engine`**, and `device/` doesn't import `data/` or `domain/`. `tool/check_layers.sh` enforces it. What the user reads comes from the ARBs in `apps/bodega/lib/l10n/`, and only `app/` words it: see the "Text" section of `rules/architecture.md`.

## Lines not to cross

- D3DMetal is never bundled or downloaded by Bodega, nor copied from CrossOver: the user imports their own copy, and its license is their decision.
- Don't copy CrossOver's proprietary code, UI, data or brand (`crossover.tie`, `cxcompatdb`, CrossTie, closed helpers), and don't circumvent its licensing. Its LGPL Wine tree is fine.
- Don't help bypass anti-cheat: no hiding Wine from Easy Anti-Cheat, no swapping its modules.
- Catalog data comes from `highball-db` (CC0) at a pinned commit; the anti-cheat list is AreWeAntiCheatYet (MIT).
- Per-game configurations (`packages/engine/lib/fixes_data.dart`) are generated by `tool/import_fixes.py` from `highball-db`'s `db/games`, `recipes/games` and a summary of `db/reports` (CC0) at a pinned commit; don't edit the file by hand. `umu-database` is GPL-3.0: don't copy it. Not shipped either: highball-db's `db/derived` (ODbL), ProtonDB's data, PCGamingWiki's and AppleGamingWiki's (CC BY-NC-SA) and Lutris' installers.
- Bodega's own per-game fixes live in `packages/engine/lib/bodega_fixes_data.dart`, written by hand, each with how and when it was verified; a game added by hand matches one by its exe's file name.
- The Windows runtimes' files (the table in `packages/engine/lib/dependencies.dart`) are downloaded from each vendor's own server (Microsoft, NVIDIA) when the user asks, checked against their pinned size and SHA-256, and never stored in the repo or in Bodega's packages. The only exceptions are the core fonts and `d3dcompiler_47`, which no vendor serves any more: they come from the copies winetricks uses (the `pushcx/corefonts` and `mozilla/fxc2` repositories), pinned at a commit and by SHA-256. Cabinets are opened with Wine's own `extrac32`, not winetricks or `cabextract`.
- Switch emulators, keys, firmware and games are never bundled or downloaded by Bodega. One link is allowed: the emulator's official download page, which the app opens in the browser, as it opens Apple's page for D3DMetal; it lives only in the emulator table of `packages/engine/lib/switch.dart` and in the tests that check it. No other URL, domain or forge path (owner/repo) of an emulator project, of nxnative, or of their downloads, keys, firmware or games anywhere in the repo, its commits or its pull requests; names that identify and do not link, such as app file names (`Ryujinx.app`), bundle ids and Flatpak ids, are fine, and legal documents may be cited.
- Mach9 is downloaded from its latest GitHub release, checked against GitHub's digest and Apple's signature with Mach9's team (`WLKUUJD25W`), or copied from the user's `Mach9.app`, never bundled in Bodega.app; a new version passes the probe before it stays. Its Wine Mono is the version Mach9's `appwiz.cpl` names, from that version's GitHub release, checked against its digest. Never re-sign, edit or move anything inside Mach9's tree (`runtimes/mach9-<v>/engine`), the source app included; Bodega only verifies its signature. Strip quarantine only from Bodega's own copy (`ditto --noqtn`), never from the source. Wine Mono goes only into prefixes, never into Mach9's tree.
- Agents may run wineboot, `msiexec /qn` and the probe (`bodega backend test`) in Mach9 bottles, headless, and nothing else; games and launchers in them are the user's.
- Bodega never reads, validates or decrypts keys, firmware or game files: it checks that they exist, and lists a folder only to tell empty from not, or to find game files, native apps and `.keys` files by name; of a native app it reads only what the nxnative line below names. Only at the user's pick, it copies the user's own `.keys` files as they are where the emulator reads them, as the emulator's own "Install keys" does, and it hands the user's own firmware to the emulator's own installer (`--install-firmware`), which asks in its window (the user's decision of 2026-11-12).
- No text explains how to obtain or dump keys, firmware or games, or how to make an nxnative app: UI, ARB descriptions, docs, `.sdd/`, comments, commits, pull request titles and bodies. Of an emulator, text says only that it is missing, that Bodega opens its official download page, and that its app goes in Applications; of the keys and the firmware, only that they come from the user's own console and how Bodega puts them in place.
- No titledb data, eShop images or Nintendo logos; "Nintendo Switch" only as descriptive text.
- Bodega strips quarantine only from what it ships, never from an emulator.
- Bodega opens the Mac apps users make of their own Switch games with nxnative, and nothing more: it never builds one, never runs nxnative's scripts, and never asks for, finds or passes `prod.keys` for it; of such an app it reads only `DMTitleID` and `CFBundleExecutable` from its `Info.plist`, and its quarantine attribute. nxnative is named without any link.

## Working here

- No `git commit` or `git push` without the user's approval. Leave a script and let them run it. Never add AI attribution to commits.
- Agents run Wine only headless. The user does anything with a window: games, launchers, installers, and the Switch emulator, which agents never start.
- Never follow symlinks inside a bottle: `dosdevices/z:` points to `/`. Stop a bottle before deleting it.
- Don't delete `../runtimes/`: 335 MB over a slow link.
- Check against the real thing, not only mocks: real HTTPS and real bottles found what mocks and local servers didn't.
- Versioning and release rules are in `AGENTS.md`: run the `bump-version` skill before any commit.
