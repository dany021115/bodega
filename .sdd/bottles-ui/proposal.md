# Proposal: bottles-ui

## Why

You want Bodega to be organized like CrossOver. Today each bottle has a single application and the configuration is on another screen, and that hides real things: Muck is installed inside your `steam` bottle and Bodega doesn't see it.

## What

**The bottle becomes the center,** with CrossOver's layout:

```
┌──────────┬───────────────────────────────┬─────────────────┐
│ Library  │ steam                  · Open │ ▾ Actions        │
│ Install  │                               │   Run…           │
│          │  [Steam]   [Muck]             │   Open C:        │
│ BOTTLES  │                               │ ▾ Settings       │
│ • steam  │                               │   Graphics  [▾]  │
│   games  │                               │   msync     (•)  │
│          │                               │ ▾ Panels         │
│ + New    │                               │ ▾ Details        │
│ Backends │                               │   Logs           │
│ Preferen.│                               │                  │
└──────────┴───────────────────────────────┴─────────────────┘
```

**In milestones, each one buildable and tested by you:**

| Milestone | What it delivers |
|---|---|
| **1. Multiple applications and main screen** | Multiple applications per bottle; detection through `.lnk`; Steam games; real icons; sidebar with bottles; bottle screen; Library with everything |
| **2. Settings and options** | Full right column: high resolution, DLSS, AVX, Windows version, control panels, terminal, open C:. `Ejecutar con opciones` ("Run with options"). Install into an existing bottle or with a local installer |
| **3. Management** | New bottle, duplicate, rename, export, import and Preferences (folder, cache and theme) |

## Out of scope

- **For the engine SDD:** GStreamer, SDL2, dependencies such as VC++/.NET, Epic and GOG, a different backend per game inside Steam, and updating bottles when the engine changes.
- **No purpose here:** registration, ratings, stars and publishing bottles.
- **Later, if needed:** dragging `.exe` files in, opening them from Finder, `.app` launchers in the Dock, a graceful shutdown of a bottle, and Steam libraries in other folders.
- **Translucent macOS window:** it needs a native plugin, and the sidebar can use a surface color instead.

## Impact

- **`packages/engine`:** `app.json` becomes `apps.json` without losing data; new functions with their tests. `bodega open <bottle>` still opens the same thing.
- **`apps/bodega`:** the sidebar, the routes and Library change. The `/bottles` list goes away, and the bottle detail is rebuilt. Catalog, Backends, the install panel and the first-run flow are kept.
- **`.claude/CLAUDE.md`:** makes clear what is taken from CrossOver.
- **Your bottles:** `steam` and `games` keep working without reinstalling.

## Decisions

| # | Topic | Decision | Cost |
|---|---|---|---|
| 1 | What is taken from CrossOver | Organization and features. None of its icons, nibs, data or its own text | It will look similar without being the same |
| 2 | Look | Our own burgundy palette and theme | Light and dark themes remain ours |
| 3 | Library | Stays as the first entry, with the applications of all bottles | CrossOver doesn't have it: it is an improvement |
| 4 | Detection | `.lnk` files and Steam manifests are read when listing, without being saved | An odd shortcut can slip in: that is why `Ocultar` ("Hide") exists |
| 5 | `Abierta` ("Open") status | Per bottle, like CrossOver's `Estado` ("Status") | With two applications in an open bottle, both show it |
| 6 | Opening | Double click or Enter on the bottle screen; `Abrir` ("Open") button in Library | A single click doesn't launch a game by mistake |
| 7 | Backends | Entry at the bottom of the sidebar | It is something CrossOver doesn't need, because it bundles them |
| 8 | Icons | From the `.exe`, without dependencies and with a cache | The brand logo is kept for what isn't installed |
| 9 | Steam games | They open with `steam.exe -applaunch <id>` and use Steam's backend | Choosing another backend per game is left for the engine SDD |
| 10 | Copy and export | `cp -cR` and `tar`, from the system | No custom format: a plain `.tar.gz` |

## Risks

- **`-applaunch` untested:** it has a window, so you test it (U3). If it fails, Steam games stay visible but open Steam.
- **Metal HUD:** `--hud` showed no counter in Blur. It gets tested with Muck (U7). If it doesn't show up, the switch is removed, because one that does nothing is misleading.
- **DLSS and high resolution:** we can only check that the values get written. You judge the effect with a game, and DLSS may not be testable.
- **It is big:** milestone 1 touches the engine and 35 files of the app. It goes in milestones, and the next one doesn't start without your test.
- **Installing from the app:** U3 of the previous change is still unconfirmed, and this change touches it in milestone 2.
