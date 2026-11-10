# Proposal · user-per-bottle

## Why
Games see the Mac's name (`quasar`) as the Windows user. The user wants to
choose, per bottle, the name that shows up in games.

## What
- Each bottle can have its own **Windows user**. If none is chosen, the Mac's is still used.
- In the bottle's Settings: "Usuario de Windows: quasar" ("Windows user: quasar") with **Cambiar…** ("Change…"), a dialog
  with the name and the "Usar el del Mac" ("Use the Mac's") option.
- When it changes, Bodega stops the bottle, **renames the profile folder**
  (`C:\users\<viejo>` → `<nuevo>`) so that the saves and the links to the
  Mac's folders stay there, and leaves `TEMP`/`TMP` pointing to the new profile.
- Everything Bodega launches in that bottle (games, `wineboot`, `reg`, fixes) runs with that
  name.

## Impact
- Engine: `engine.dart` (`wineEnv`), `backends.dart` (the bottle settings and the function
  that changes the user). Nothing in the platforms: it works the same on Mac and Linux.
- App: `BottleDetail`, `BottleRepository`, `BottleDetailBloc`, `bottle_column.dart` and a
  new dialog.
- Existing bottles: they do not change until the user picks a name.
