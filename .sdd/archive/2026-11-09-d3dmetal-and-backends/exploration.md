# Exploration · d3dmetal-and-backends

## Problem

1. **The user does not know which backend suits each game.** It happened with Blur: the bottle
   was forced to `d3dmetal` and the game (32-bit, DirectX 9) closed. D3DMetal only works
   for 64-bit with DX11/DX12; DXVK has no d3d9; DXMT is D3D10/11. Nothing in the app says so.
2. **Installing D3DMetal is a text guide** ("elige una carpeta con `wine/` y `external/`" ("choose a folder with `wine/` and `external/`")).
   The user wants: a list of Game Porting Toolkit versions → choose → install.
   Bodega cannot download it itself (Apple ID login + Apple's license; rule
   B2 "Bodega never downloads D3DMetal"). What was agreed: Bodega opens the official download in the
   browser, the user logs in and downloads the `.dmg`, and Bodega does everything else.

## Code involved

### Engine (`packages/engine/lib`)
- `platform_mac.dart:170` `autoBackend(home, exePath)`: already reads the exe; looks for
  `d3d12.dll`, `d3d11.dll`, `d3d10`, `dxgi.dll`, `d3d9.dll` (without NULs) and uses `_peBits`.
  It returns only the backend name; what it detects (bits + DirectX) is lost. It has to be
  pulled out into a reusable function (e.g. `exeGraphics(path) → (bits, directx)`).
- `platform_linux.dart:233` `autoBackend`: dxvk if present, otherwise wine (it does not look at the exe).
  `mapBackend` turns dxmt/d3dmetal into dxvk.
- `backends.dart:521` `_peBits(path)`: 64/32/null from the PE header.
- `backends.dart:486` `resolveBackend(...)`: option → program exception → bottle → auto.
- `backends.dart:66` `importD3DMetal(home, folder)`: accepts a folder with `wine/`+`external/`
  **or with `lib/`** (`src = '$real/lib'`), rejects `/CrossOver.app/`, requires
  `wine/x86_64-windows/{d3d11,d3d12,dxgi}.dll`, their `.so` files, `external/libd3dshared.dylib`,
  `external/D3DMetal.framework`, and recreates the `.so` files as symlinks.
- `engine.dart:465-513` `installSdl(home, {dmg})`: an already proven pattern of
  `hdiutil attach -nobrowse -readonly -mountpoint` + copy + `hdiutil detach`. It serves as the
  template for mounting Apple's dmg.
- `backends.dart:601` `backendTest(home, name, backend)`: the "Comprobar" ("Check") that runs afterwards.
- Installed version: not stored anywhere. It can be read from
  `backends/d3dmetal/external/D3DMetal.framework/.../Info.plist`
  (`CFBundleShortVersionString`; today it gives `3.0` on this Mac).

### App (`apps/bodega/lib`)
- `app/presentation/backends/widgets/d3dmetal_instructions.dart:7`: the current guide (it goes away).
- `app/presentation/backends/widgets/backend_card.dart:37` "Elegir carpeta…" ("Choose folder…") →
  `BackendsEvent.importD3DMetal(folder)` (`backends_event.dart:10`,
  `backends_bloc.dart:58`, `backend_repository.dart:22`, `backend_repository_impl.dart:81`).
- `app/presentation/backends/backends_page.dart`: the "which backend for what" table would go here.
- Bottle selector: `bottles/widgets/bottle_column.dart:341` ("Gráficos" ("Graphics") dropdown,
  `BottleDetailEvent.setBackend`).
- Per-run selector: `bottles/widgets/run_options_dialog.dart:146` ("Gráficos" dropdown).
- New bottle: `bottles/new_bottle_dialog.dart:178` ("Gráficos" dropdown; there are no apps here yet).
- Per-app label: `shared/widgets/app_card.dart:27` (already draws a chip in the footer:
  `footerChip`/`bottleLabel`) and `shared/widgets/app_row.dart:12`.
- `domain/entities/library_app.dart:16` `exe`: path of each app's exe (to analyze it).

## Game Porting Toolkit data (researched)

| GPTK | D3DMetal | Status | Tested in Bodega |
|---|---|---|---|
| 1.x (2023) | 1.x | old | no |
| 2.x (2024–25) | 2.x | old | no |
| 3.0 (WWDC25, updated 5-Dec-2025) | 3.0 | stable | **yes** (check OK) |
| 4.0 (WWDC26) | 4.0 | beta | no |

- Direct download (needs a signed-in developer Apple ID, free):
  `https://download.developer.apple.com/Developer_Tools/Game_Porting_Toolkit_3.0/Game_Porting_Toolkit_3.0.dmg`.
  Public page: `https://developer.apple.com/games/game-porting-toolkit/`.
- Inside: `Game_Porting_Toolkit_3.0.dmg` contains **another dmg**,
  `Evaluation environment for Windows games 3.0.dmg`, which **shows Apple's license when
  opened**. Inside that one: `redist/lib/{external,wine}` → exactly what `importD3DMetal`
  already accepts when given `<volumen>/redist`.
- License (GPTK 4 License.pdf): only the components in `/redist` are redistributable, for
  non-commercial use. It has export-control terms that each user accepts when they download it
  themselves, with their own account; Bodega neither hosts nor downloads it.

## Project constraints
- D3DMetal is never bundled, downloaded or copied from CrossOver (B2, `importD3DMetal`).
- Wine only headless from the agent; do not follow symlinks inside a bottle.
- On Linux there is no D3DMetal (`capabilities.d3dmetal == false`): the section is not shown.
- Clean architecture (domain/data/device/app), bloc + freezed, tests with a simulated Mac on
  Linux (`test/_mac.dart`): the exe detection cannot depend on the real OS.
- Steam (`steam.exe`): no label or notice (the real game's exe is not that one).

## Open questions
1. **License of the inner dmg**: `hdiutil attach` stops and asks to accept the license.
   Proposal: Bodega shows "Al instalar aceptas la licencia de Apple" ("By installing, you accept Apple's license") and the user
   accepts it with a button (Bodega answers `Y` to hdiutil), or the user opens the dmg
   themselves in Finder. I lean toward the first, with the license text visible.
2. **Waiting for the download**: watch `~/Downloads` for `Game_Porting_Toolkit_*.dmg`
   (polling every few seconds while the screen is open) + a manual button
   "Ya lo tengo: elegir dmg…" ("I already have it: choose dmg…"). No background service.
3. **Version list**: hard-coded (4 rows). Only 3.0 marked "Probada" ("Tested");
   4.0 "Beta"; 1.x/2.x: shown or hidden? I propose showing only 3.0 and 4.0.
4. **Replacing a version**: importing over it already works (it recreates the folder); what is missing is showing
   the installed version by reading the `Info.plist`.
5. **Backend notice**: only when the user **chooses** something that does not fit (not in
   Automatic). Analyzing the exe means reading the whole file: do it once and store the
   result, not on every repaint.
