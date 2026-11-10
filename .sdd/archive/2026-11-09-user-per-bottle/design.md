# Design · user-per-bottle

## 1. A single place: `wineEnv`
`wineEnv(prefix, …)` builds the environment of every Wine process. It reads `user` from
`<prefix>/../settings.json` and, if it is set, sets `USER`. That way `wineboot`, `reg` and the fixes
use the same name as the games: if any of them used the Mac's name, Wine would recreate
`users/quasar`. A prefix without a bottle (the temporary one from `installRuntime`) has no settings:
it keeps the Mac's name.

## 2. `TEMP`/`TMP` with `reg add`, not by editing `user.reg`
In the registry they are stored as a fixed path, `C:\users\quasar\…`. Instead of rewriting the file
(Wine stores non-ASCII characters with its own escapes), Bodega runs `reg add` inside
the bottle, without windows, with the Windows default value: `REG_EXPAND_SZ`
`%USERPROFILE%\AppData\Local\Temp`. That way they follow the name in future changes.

## 3. What is not touched
- "User Shell Folders" already use `%USERPROFILE%`; shell32 rewrites "Shell Folders".
- Wine brings `ProfileImagePath` up to date on the next prefix update.
- The `Z:\Users\quasar\…` paths belong to the Mac.

## 4. The Mac's name
The one Wine would use without Bodega: `USER` from the `baseEnv` environment (Mac and Linux copy it from the
parent). It is used to know what the old folder is called, and for "Usar el del Mac" ("Use the Mac's").
