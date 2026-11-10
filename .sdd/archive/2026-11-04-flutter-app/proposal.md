# Proposal: flutter-app

## Why

Bodega already installs and opens applications, but only from the command line. What is missing is the desktop app, similar to CrossOver, with TeeShot's architecture and tools.

## What

**Monorepo:** `apps/bodega` (a macOS-only Flutter app) and `packages/engine` (the current engine), in a pub workspace.

**TeeShot's architecture:** `domain`/`data`/`device`/`app` layers, `go_router` with `AppRoute` and `RouterManager`, `device/theme` with one file per concern, bloc with freezed, repositories with `Either`, get_it and injectable, `responsive_framework`, `dio` and `retrofit`, toastification, spider and one widget per file.

**Screens**, with a sidebar:

| Section | What it does |
|---|---|
| **First launch** | Checks Rosetta and lets you choose the runtime tarballs |
| **Library** | Installed applications, open and stop, live status, and "Agregar otra aplicación" ("Add another application") |
| **Catalog** | The 7 applications, search, detail page, install with a progress bar and an anti-cheat warning |
| **Bottles** | List and detail: backend, msync, logs, run a program and delete |
| **Backends** | Install DXMT and DXVK with progress, import D3DMetal with instructions, and check with the probe |

**Engine additions:** list and delete bottles, read their settings and logs, check Rosetta and the runtime, accept an already downloaded installer, register a custom application and expose the pinned downloads.

## Out of scope

- Firebase, Sentry, RevenueCat, maps, Phoenix and the other pieces of TeeShot's mobile product.
- `envied`: Bodega has no keys. It gets added when it is needed.
- The 737 game entries from `highball-db`, `legendary`, and drag and drop of `.exe` files.
- Automatic updates, signing and distribution: it is for personal use.
- Measuring FPS in the interface, and the arm64 line.

## Impact

- **Root:** workspace `pubspec.yaml` and `pubspec.lock`; `.gitignore` with the generated files, like TeeShot.
- **`packages/engine`:** `resolution: workspace`, new functions and their tests. The `bodega` program stays the same.
- **`apps/bodega`:** new.
- **`.claude/`:** `CLAUDE.md` and `rules/`.
- **`bodega-engine`:** no changes.

## Decisions

| # | Question | Decision | Reason |
|---|---|---|---|
| 1 | Path and name | `apps/bodega`, package `bodega`, bundle `com.dany021115.bodega` | Tested in the spike |
| 2 | Versions | The current ones: `freezed` 4, `build_runner` 2.16, `injectable` 3, `go_router` 18, `retrofit` 4.10 | TeeShot's versions hang with Dart 3.13. These built and generated code (`design.md` §7) |
| 3 | `dio` | Downloads with progress and cancel, and `retrofit` for the anti-cheat list | They are real uses, and `curl` gives the app no progress |
| 4 | First launch | Choose the local tarballs with `file_selector` | The runtime repo is private |
| 5 | Icons | SVGs from `simple-icons` (CC0; all 7 are there) with `spider` | The brands still belong to their owners; personal use |
| 6 | Look | Dark by default, burgundy accent, sidebar | Your screenshot and "Bodega". It is changed in `AppColor` |
| 7 | Sections | Library, Catalog, Bottles, Backends | Approved |
| 8 | Rules | `.claude/CLAUDE.md` and `rules/` | So that the architecture holds |
| 9 | `AppError` | In `domain/entities/`, not in `data/api/` as in TeeShot | TeeShot breaks its own rule there: `domain` imports from `data` |
| 10 | Another application | Choose an `.exe`, a new or existing bottle, and say whether it is an installer | Covers Blur and any installer. One application per bottle |
| 11 | Open or closed | `wineserver -w` per bottle | Follows the whole bottle, not just one process: solves the Steam case |
| 12 | Generated files | Kept out of the repo, like TeeShot | `build_runner` has to be run after cloning |

## Risks

- **It is big:** about 13 coding tasks. It goes by milestones, each one buildable.
- **Interface not testable by agents:** they can build, pass tests and open the app, but not judge how it looks. You test that.
- **Interface freezes:** the engine does short synchronous reads. This has to be checked with the EAC log, of about 600 KB.
- **Untested launchers:** the catalog will keep saying `reportado` ("reported") or `sin probar` ("untested") for the others, and their install may fail.
- **D3DMetal instructions:** Apple's current image has not been checked with `import`; only the Whisky and Sikarugir copies have. The instructions will say so.
- **`simple-icons`:** the package is CC0, but the logos are trademarks. If the app is ever published, this has to be reviewed.
