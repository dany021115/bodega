# Spec · Installing D3DMetal by choosing a version

## I1 · Versions
- A fixed list in the engine: GPTK 3.0 (tested with Bodega) and 4.0 (beta, untested), each one
  with its official Apple link (3.0: the direct dmg; 4.0: the downloads search).
- The card shows the installed version, read from the `Info.plist` of
  `D3DMetal.framework` (`CFBundleShortVersionString`), or "No instalado" ("Not installed").
- Mac only (`capabilities.d3dmetal`). On Linux the card does not exist, same as today.

## I2 · Getting the dmg
- Looks in `~/Downloads` for the newest `Game_Porting_Toolkit_<versión>*.dmg`.
- If it is not there: opens Apple's link in the browser and checks Downloads every 3 s while
  it waits ("Esperando la descarga…" ("Waiting for the download…"), with Cancel). `.crdownload`/`.download` files do not count.
- "Ya lo tengo: elegir dmg…" ("I already have it: choose dmg…") is always there.
- Bodega never downloads the dmg on its own (rule B2).

## I3 · Installing from the dmg
- Mounts the dmg without showing it in Finder. If there is a `redist/lib` inside, it imports from there.
- If there is an `Evaluation environment*.dmg` inside, it opens it with macOS (`open`): Apple's
  window asks to accept the license and **the user accepts it**. Bodega waits, up to 5 min,
  for a volume with `redist/lib/external/D3DMetal.framework`.
- Imports with `importD3DMetal(<volumen>/redist)`: the same checks and symlinks as today.
- Unmounts both volumes, also if something fails.
- Replaces whatever version was there. When done, it shows the installed version and runs the check.

## Scenarios
- **Given** a dmg built with the `redist/lib/{external,wine}` structure, **when** it is
  installed, **then** D3DMetal ends up imported (symlinks) and nothing is left mounted. (test, Mac)
- **Given** `~/Downloads` with `Game_Porting_Toolkit_3.0.dmg` and an older one, **then** the
  newest one is chosen; a `.crdownload` does not count. (test)
- **Given** Apple's real dmg, **when** the user hits Install on 3.0, **then**
  Apple's license shows up, the user accepts it, and the check gives OK. (U)
- **Given** that the user declines the license, **then** after 5 min (or on Cancel) it shows
  "No se aceptó la licencia" ("The license was not accepted") and nothing is left mounted. (U)
