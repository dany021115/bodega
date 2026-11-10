# Proposal · d3dmetal-and-backends

## Why
- Blur closed because its bottle was forced to D3DMetal, which does not work for a
  32-bit DirectX 9 game. The app gives no warning: the user chooses blindly.
- Installing D3DMetal today means reading a guide and finding a folder by hand. The user wants to
  choose a version and hit Install.

## What
**A. Knowing which backend suits each game**
- The engine reads the exe once and reports its bits and its DirectX (`DX9 · 32 bits`). It is the same
  read that Automatic already does, pulled out into a function so it is not repeated.
- Each app (card and row) shows that label. Steam gets no label.
- When a backend that does not fit is chosen by hand (bottle or "Ejecutar con opciones" ("Run with options")), a
  notice appears below: "Blur es de 32 bits con DirectX 9: D3DMetal no le sirve. Usa Automático." ("Blur is 32-bit with DirectX 9: D3DMetal does not work for it. Use Automatic.")
- Each backend on the Backends page says what it is for ("DirectX 11 y 12, solo 64 bits" ("DirectX 11 and 12, 64-bit only")).
  Instead of a separate table, one line on each card: it says the same thing and looks right on Linux.

**B. Installing D3DMetal by choosing a version**
- The D3DMetal card lists the Game Porting Toolkit versions: 3.0 (tested) and
  4.0 (beta, untested), and the version you already have.
- "Instalar" ("Install") → if the dmg is already in Downloads, it uses it; if not, it opens Apple's official download
  in the browser (you log in and it downloads) and waits for it to appear in Downloads.
  "Ya lo tengo: elegir dmg…" ("I already have it: choose dmg…") also works.
- Bodega mounts the dmg and opens the one inside. Apple's window asks you to accept the license, and
  you accept it. Then Bodega imports D3DMetal, unmounts everything and runs the check.
- The text guide goes away.

## Impact
- Engine: `backends.dart`, `platform.dart`, `platform_mac.dart`, `platform_linux.dart`
  (new functions; `autoBackend` reuses the read). No changes to saved settings.
- App: a new bloc (`GraphicsBloc`), `BackendRepository`, `AppCard`, `AppRow`,
  `bottle_column.dart`, `run_options_dialog.dart`, `backend_card.dart`, `Info.plist`
  (`NSDownloadsFolderUsageDescription`). `d3dmetal_instructions.dart` is deleted.
- Linux: no D3DMetal; its DXVK ships vkd3d-proton and works for everything, so there are no
  notices there. Only the label shows.
- Rule B2 still stands: Bodega neither downloads nor hosts D3DMetal; the user's browser downloads it
  with the user's account, and the user accepts the license.
