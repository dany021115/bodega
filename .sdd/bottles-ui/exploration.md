# Exploration: bottles-ui

## Problem

You want Bodega to be organized like CrossOver, and to bring back what we left aside. Today these are two different ideas:

- **CrossOver revolves around the bottle:** you pick one in the sidebar and right there you see its applications, its configuration and its actions.
- **Bodega revolves around the application:** each bottle has only one, and Library and Bottles are separate sections.

Moving screens around is not enough. The one-application-per-bottle rule lives in the engine, and Steam already breaks it: Muck is installed inside that bottle and Bodega doesn't see it.

## Where the reference comes from

`crossover-sources-26.3.0.tar.gz` **is no use for this**: it has the same SHA-256 as `investigacion-launcher/src/cx-26.3/`, and it only contains `wine`, `gstreamer`, `gnutls`, `moltenvk`, `ghostscript`, `busybox`, `glib`, `freetype`, `dxvk`, `vkd3d`, `po4a`, `cabextract`, `android` and `makedep`. No interface at all.

The interface is closed source, in `~/Applications/CrossOver.app`. From there we take, only as a reference:

- The features of each screen, in `Contents/Resources/es.lproj/*.strings`.
- The layout, by decoding `Base.lproj/{MainWindow,BottleView}.nib` with REA.

No icons, text, nibs or data are copied: only organization and features, with our own code. The `.claude/CLAUDE.md` rule against copying its UI still holds when understood this way, and it is worth writing that down in `propose`.

## How CrossOver organizes its screens

**Main window** (`MainWindow.nib`, 1150×800), split in two:

| Area | Size | Content |
|---|---|---|
| Sidebar, translucent | 261 px wide | Logo at the top (100 px), a short list (55 px), the list of bottles (653 px) and a bottom strip (55 px) |
| Content | 910 px wide | The bottle view, or the install view |

**Bottle view** (`BottleView.nib`, 936×801):

| Area | Size | Content |
|---|---|---|
| Header | 856×100 | Large title, rating stars, and on the right short facts and two buttons |
| Center | 626×661 | `Software instalado` ("Installed software"): icons, with right-click `Abrir` ("Open") and `Ejecutar con opciones…` ("Run with options…"). Supports drag and drop. Has a text for when it is empty |
| Right column, scrollable | 270×661 | Two standalone buttons and four collapsible sections |

The sections of the right column, in order. The layout comes from the nib; which section each one is, I infer from its text and from how many controls it has:

1. **Bottle actions:** 4 buttons. Among them: open C:, quit all applications, install missing dependencies, and delete.
2. **Advanced settings:** 2 dropdowns (graphics and another one) and 4 rows with a switch (DLSS, msync, high resolution and another one).
3. **Control panels:** a list that fills in when opened.
4. **Bottle details:** status, type, description and a table.

**Other screens,** from their text:

- **Run command:** program, bottle, arguments, environment variables, Metal HUD, don't advertise AVX, save as launcher, and log options.
- **New bottle:** name and type. Also used to duplicate and to restore from an archive.
- **Install** (`PackageView`, and your screenshot): popular, search, details, notes, choose bottle, choose installer, advanced options, `Instalar a través de Steam` ("Install via Steam") and `Instalar una aplicación no listada` ("Install an unlisted application").
- **Menu:** new bottle, duplicate, rename, export, import, delete, open shell, and quit or force quit the bottle.
- **Preferences:** bottle and program folders, installer cache with a button to empty it.

## What Bodega has

**One application per bottle, in the engine:**

- `packages/engine/lib/catalog.dart:176`: `_writeApp` writes a single `app.json`.
- `catalog.dart:189`: `addApp` rejects a second application.
- `catalog.dart:249`: `BottleInfo` has a single `app`; it is filled by `_bottleInfo` (`:258`) and `installedApps` (`:269`).
- `catalog.dart:275`: `openApp(home, bottle)` opens "the" application, without saying which one.
- `catalog.dart:84` and `engine.dart:189`: install and create reject a bottle that already exists, so you can't install into an existing one.
- `packages/engine/bin/bodega.dart:58,69`: the `open` and `apps` commands depend on this.
- There are 22 references in the engine tests.

**The same in the app:**

- `domain/entities/library_app.dart:8-10` and `bottle.dart:13`: one `LibraryApp` per bottle.
- `domain/repository/library_repository.dart:12`: `open(bottle)`, with no application.
- `data/repository/catalog_repository_impl.dart:19,41`: what is installed is a map from id to bottle.
- `data/repository/add_app_repository_impl.dart:37`: `freeBottles` are the ones with no application; with several per bottle it no longer makes sense.
- `data/repository/install_repository_impl.dart:27`: the download fails if the bottle already exists.
- Callers of open: `install_panel.dart:128`, `detail_action.dart:26` and `library_card.dart:85`.
- 35 files in `lib` and `test` name these classes.

**Navigation and screens:**

- `app/shared/widgets/side_bar.dart:20-28`: Library, Catalog, Bottles and Backends.
- `app/shared/widgets/main_shell.dart:13-15`, `app/router.dart:79-108` and `device/router/manager.dart:7-15`: routes for those four sections.
- `app/presentation/bottles/bottle_detail_page.dart`, `widgets/bottle_settings_card.dart` and `widgets/bottle_logs_card.dart`: almost everything in the right column already exists, but on a separate screen.
- `app/shared/widgets/app_icon.dart:23`: logos by catalog id; everything else gets an initial.
- `LibraryBloc` already tracks what is open **per bottle** (`library_bloc.dart:37`), just like CrossOver's `Estado` ("Status"). That doesn't need to change.

**What the engine already allows and the app doesn't offer:**

- `engine.dart:220`: `runInBottle` accepts arguments, backend and HUD.
- `backends.dart:44,65`: `hud` sets `MTL_HUD_ENABLED`.
- `backends.dart:261`: `programs` stores backend and variables per program.
- `engine.dart:185`: `createBottle` already creates empty bottles.

**What the engine doesn't have:**

- `engine.dart:58`: `winemenubuilder.exe=d`, and no reading of `.lnk` files.
- `engine.dart:79`: `ROSETTA_ADVERTISE_AVX=1` hard-coded; `extra` can change it, but not remove it, and the report says that to turn it off you have to remove it.
- High resolution, Windows version, duplicate, rename, export, import, and PE icons (`backends.dart:431` only reads the bitness).

## Checked with your files

All read-only:

| Question | Result | What it means |
|---|---|---|
| Are applications detected by their `.lnk` files? | 3 in `steam`, in `Public/Desktop`, `ProgramData` and `users/quasar`. All 3 resolve to `C:\Program Files (x86)\Steam\steam.exe`. A 30-line reader is enough | Viable. Duplicates by target have to be removed. `games` has 0, because Blur was not installed |
| Can real icons be extracted? | `steam.exe`: 39 icons, the largest a 256 px PNG. `Blur.exe`: 1 DIB of 32 px | Viable, with no dependencies. The PNG goes straight through; the DIB needs a BMP header |
| Are Steam games visible? | `steamapps/appmanifest_*.acf`: Muck (1625450) and Steamworks Common Redistributables (228980) | Viable, hiding the redistributables. Still to test whether `-applaunch` works well |
| Is duplicating expensive? | APFS; `steam` takes 2.7 GB and `games` 538 MB | With `cp -c` it is almost instant. `dosdevices/z:` points to `/`, so that link must never be followed |
| Are the Wine tools there? | `winecfg`, `regedit`, `taskmgr`, `control`, `cmd`, `wineconsole`, `uninstaller` and `explorer` are there | The control panels come almost for free |

**Not checked:** no `.lnk` or icon has been opened from Dart yet, and the Wine tools have a window, so you test them.

## Per-bottle and per-application settings

According to `INFORME-FINAL.md` §5.3 and §6.1:

- **High resolution:** `RetinaMode=y` plus `LogPixels` ×2. It affects the whole prefix and requires restarting the bottle.
- **DLSS:** `D3DM_ENABLE_METALFX` (macOS 26+) with D3DMetal; `DXMT_ENABLE_NVEXT=1` with DXMT.
- **AVX:** remove `ROSETTA_ADVERTISE_AVX`.
- **HUD:** `hud` already exists, but `--hud` showed no counter in Blur. **Unresolved:** a switch that does nothing would be misleading.

## Constraints

- TeeShot's architecture and tooling; only `data/` imports `package:engine`; `tool/check_layers.sh` enforces it.
- UI in Spanish. `test/app/pages_test.dart` must cover every new screen.
- Minimum window of 720×480: a 261 sidebar, the center and a 270 column **do not fit**. Below `DESKTOP`, the sidebar switches to icons and the column must go below or be collapsed.
- Without breaking data: `steam` and `games` already have `app.json`, and must keep working without reinstalling.
- The CLI must not break: `open <bottle>` and `apps`.
- Agents: Wine only headless, no commit or push, no following links inside a bottle.
- Nothing that helps bypass anti-cheat. D3DMetal is still imported by you.

## Outside this change

For the next SDD, on the engine: GStreamer (0 `libgst*` versus 83 in CrossOver), SDL2 for controllers (0 versus 2), dependencies such as VC++/.NET, and Epic and GOG. No purpose here: registration, ratings, publishing bottles, and stars.

## Open questions

To settle in `propose`, with my recommendation:

1. **Does Library still exist?** CrossOver has no view of all applications, according to its files. **I recommend** keeping it as the first entry in the sidebar: it is more convenient, and it is one of the few things where Bodega is already better.
2. **Steam games as applications?** **I recommend** yes, by reading the manifests: it is what shows the most in daily use. It depends on testing `-applaunch`.
3. **How much in this change?** **I recommend** milestones: first multiple applications and the main screen; then settings and `Ejecutar con opciones`; last, duplicate, rename, export, import and Preferences.
4. **Where do the Backends go?** CrossOver doesn't manage them because it bundles them. **I recommend** putting them in Preferences or at the bottom of the sidebar.
5. **How close should the look be?** **I recommend** copying the organization and keeping our burgundy palette.
6. **Screenshots:** they no longer block, because the nib gives the layout, but not the appearance. If you want it to look more alike, send me one of the main window with a bottle selected.
