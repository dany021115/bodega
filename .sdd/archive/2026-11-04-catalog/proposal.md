# Proposal: catalog

## Why

The user wants to install applications from a list, as in CrossOver's "Install a Windows Application". Today Bodega only launches an `.exe` that already exists, without knowing how to install anything or remembering what is installed. Also, the official DXMT does not include the option that Chromium-based launchers need.

## What

- **Catalog** inside the engine, with 7 applications (open data from `highball-db`, CC0): Steam, Rockstar, EA app, Ubisoft Connect, Battle.net, Epic and GOG Galaxy.
- **An honest status** instead of stars: `tested` (tested by you), `reported` (reported by others), `untested` (not tested) and `blocked` (blocked, not installable).
- **Install:** `bodega catalog install <id>` downloads the official installer, creates a bottle for that application, applies its settings, runs the installer, checks the result and adds it to the library.
- **Library and launching:** `bodega apps` and `bodega open <botella>`.
- **Missing settings:** per-bottle msync, per-program variables and the registry.
- **Patched DXMT:** the `dxmt` backend becomes Highball's fork, with the cross-process option turned on.
- **`auto` fix:** Blur, which is D3D9, went to DXMT because its binary mentions `d3d10` and `dxgi.dll`.

## Out of scope

- The Flutter app, icons and screens (the `flutter-app` change).
- The 44 recipes and the 737 game records; `legendary` and GOG offline installers; winetricks.
- "Install another application": it can already be done with `create` + `run`; the app will wrap it.
- Per-program msync, a network catalog and uninstalling (today, `stop` + `rm -rf`).

## Impact

- **`bodega/packages/engine`:**
  - new: `lib/catalog.dart`, `lib/catalog_data.dart` (the JSON as Dart text, because `dart compile exe` does not bundle files) and `test/catalog_test.dart`;
  - changed: `lib/backends.dart`, `lib/engine.dart` and `bin/bodega.dart`.
- **On disk:** `bottles/<b>/app.json`, `settings.json` with `sync` and `env`, and `downloads/`.
- **`bodega-engine`:** no changes. No CI minutes.
- **`Bodega/runtimes/terceros/`:** already has the DXMT fork tarball.
- **The user's real installation:** `dxmt` has to be reinstalled (U1).

## Decisions

| # | Question | Decision | Reason |
|---|---|---|---|
| 1 | Where the catalog lives | JSON inside the app | Recipes decide what is downloaded and run; fetching them from the network would require signing them |
| 2 | First list | All 7, with Epic and GOG Galaxy as `blocked` | Same as the reference screen, without promising what does not work |
| 3 | Rating | Four statuses, each with its note and source | No made-up stars |
| 4 | Bottles | One per application, with the `id` as its name | Isolates failures and settings; each one takes about 540 MB (measured on `prueba`) |
| 5 | DXMT | Replace the official one with the fork, not a separate backend | It passes the probe in 32 and 64 bits, with and without msync (`design.md` §6). One more backend would only confuse. Still to be confirmed with Blur (U2) |
| 6 | msync | Per bottle; changing it stops the bottle | Mixed modes = exit 1 (measured). **Cost:** games opened from the Steam bottle run without msync; Highball reports ~40 % fewer FPS |
| 7 | Format | Flat, not Highball's list of steps | The 7 only need registry → installer → executable. Shorter and easier to show |
| 8 | Installer | Always with `wine`, no layers; valid codes 0, 102, 194 and 105 | Highball does this; those three are 1638, 3010 and 1641 truncated to 8 bits (`HB/Recipe.swift:154-156`) |
| 9 | Installer leftovers | Wait for the server to exit; if the `.exe` is already there, 60 s at most; 30 min in total. Then `-k` | Battle.net and Rockstar leave services running with the install environment (`HB/Recipe.swift:586-597`). Without the restart, the first launch inherits that environment |
| 10 | Downloads | HTTPS only, redirects included; SHA-256 if the entry pins one; a warning if not | 6 of the 7 links change and cannot take a pinned SHA |
| 11 | Deciding test | Steam with your account (U3), run by you | Agents do not run downloaded installers: auto mode blocked it, and someone has to see the windows and log in |

## Risks

- **No launcher has been tested in Bodega.** The `reported` statuses come from Highball, on its builds, and our DXVK is not theirs.
- **DXMT fork:** it is a third-party binary with few users and a single person behind it. It is pinned by SHA-256, and we do not build it ourselves. LGPL license, according to the earlier research (`02-graphics.md`).
- **Installers without a checksum:** only HTTPS and the official domain protect them.
- **`dxvk`, required by Rockstar and Epic:** version 1.10.3, different from Highball's.
- **If Steam fails in U3:** this change is still useful as an engine, but the launcher approaches (`INFORME-FINAL.md` §7.2) have to be reviewed before moving on to the app.
