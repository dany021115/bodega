# Exploration · user-per-bottle

## Problem
Games see the Mac user's name (`quasar`) as the Windows user. The user
wants to choose, per bottle, the name the games see (profile, saves, LAN…).

## How Wine decides the name (code of CrossOver 26.3's Wine, `~/Downloads/sources/wine`)
- `dlls/ntdll/unix/loader.c:432` `set_home_dir()`: `user_name = getenv("USER")`; if missing,
  the one from `getpwuid`. It strips whatever comes before `/` or `\`.
- `dlls/ntdll/unix/env.c:1051`: passes it to Windows as `WINEUSERNAME`.
- `dlls/advapi32/advapi.c:48,73` (`GetUserNameA/W`) and `dlls/kernelbase/sync.c:1530` read
  `WINEUSERNAME`: it is the name the games see.
- `dlls/userenv/userenv_main.c:302-306`: `USERNAME` and `USERPROFILE` = `C:\users\<nombre>`.
- `programs/wineboot/wineboot.c:867-896`: "Volatile Environment" (`USERPROFILE`, `USERNAME`,
  `APPDATA`…) is rebuilt on every Wine start. `:1655` `update_user_profile` writes
  `ProfileImagePath`.
- `dlls/shell32/shellpath.c:2118`: the shell folders come from "User Shell Folders",
  which are stored as `%USERPROFILE%\…` (they follow the name on their own) and are copied to "Shell Folders".

**Conclusion:** it is enough to launch everything in that bottle with `USER=<nombre>`.

## What a real bottle contains (`bottles/Games/prefix`)
- `drive_c/users/quasar/`: `AppData`, `Desktop`, `Saved Games`… and **links** to the Mac's
  folders: `Documents → /Users/quasar/Documents`, `Downloads`, `Music`, `Pictures`, `Videos`.
  Wine creates them when it makes the prefix; a new profile would not have them.
- `user.reg`: 37 lines with `quasar`. The "User Shell Folders" ones use `%USERPROFILE%`;
  but `[Environment]` has **fixed paths**: `"TEMP"="C:\\users\\quasar\\AppData\\Local\\Temp"`
  and `TMP`. "Shell Folders" also has fixed paths, but shell32 rewrites them when it uses them.
- `system.reg` (13) and `userdef.reg` (26): almost all are Mac paths, `Z:\Users\quasar\…`
  (the engine, fonts): **they are not touched**, they are the real Mac.

If the name is simply changed, Wine uses an empty `C:\users\<nuevo>`: the saves in
the old profile's `AppData`/`Saved Games` "disappear", and `TEMP` points to the old folder.

## Bodega code involved
### Engine (`packages/engine/lib`)
- `engine.dart:69` `wineEnv(prefix, parent, extra)`: the environment of **every** Wine process
  (launching, `wineboot`, `reg`, fixes…). Calls: `engine.dart:140,446,456`,
  `fixes.dart:134`, `platform_mac.dart:308`. This is where `USER` goes in.
- `platform_mac.dart:54` / `platform_linux.dart:54` `baseEnv`: today they copy `USER` from the Mac/PC.
- `backends.dart:388` `BottleSettings`, `:512` `_saveSettings`, `:580` `setBottleOptions`,
  `:855` `bottleSettings`: where the name would be stored (`settings.json`).
- `backends.dart:607` `setHighRes`: template for "a change that stops the bottle and touches the prefix".
- `engine.dart:338` `stopBottle`, `engine.dart:616` `renameBottle`, `engine.dart:172`
  `createBottle`.

### App (`apps/bodega/lib`)
- `app/presentation/bottles/widgets/bottle_column.dart:355` "Configuración" ("Settings") section
  (Graphics/Windows dropdowns, switches).
- `app/presentation/bottles/widgets/rename_bottle_dialog.dart:13`: template for a dialog with a text field.
- `domain/entities/bottle_detail.dart`, `domain/repository/bottle_repository.dart:23-27`,
  `data/repository/bottle_repository_impl.dart`, `app/bloc/bottle_detail/`.

## Constraints
- Never follow symlinks inside the bottle: renaming `users/<viejo>` moves the links,
  not what they point to (`Directory.renameSync` does not follow them).
- Stop the bottle before touching the prefix (like `setHighRes`).
- The `Z:\Users\quasar\…` paths belong to the Mac: they are not changed.
- Wine only headless from the agent; the user tests the game.
- Linux uses the same `wineEnv`: it works the same there.

## Open questions
1. **Changing the name in a bottle with saves:** I propose stopping the bottle, renaming
   `drive_c/users/<viejo>` to `<nuevo>` and rewriting `TEMP`/`TMP` in the registry. That way
   saves and links are kept.
2. **Valid names:** like Windows: up to 20 characters, without `" / \ [ ] : ; | = , + * ? < >`,
   not empty and not only dots/spaces. OK?
3. **No name chosen:** the Mac's name stays, as today (existing bottles do not change).
4. **Also when creating the bottle?** I propose it only lives in Settings (YAGNI); it
   can be added to bottle creation later.
5. **Does it affect Steam?** Steam uses its own account; that does not change. What does change is what games
   read with `GetUserName`, and the profile folders.
