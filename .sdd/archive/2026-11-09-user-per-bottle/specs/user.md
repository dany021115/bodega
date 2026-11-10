# Spec · Windows user per bottle

## U1 · Storing the name
- The bottle's `settings.json` stores `user` only if the user chose one.
- Without `user`, the name is the Mac's (or the PC's on Linux): as today.

## U2 · Using it
- Every Wine process in the bottle starts with `USER=<nombre>`: Wine gives it to games
  as `GetUserName`, `%USERNAME%` and `C:\users\<nombre>` (`%USERPROFILE%`).

## U3 · Valid names
- From 1 to 20 characters, without `" / \ [ ] : ; | = , + * ? < >` or control characters, and not
  only dots or spaces. Leading and trailing spaces are trimmed.
- An invalid name changes nothing and says why.

## U4 · Changing the name
- Stops the bottle (it warns first, like "Pantalla de alta densidad" ("High-density display")).
- If `drive_c/users/<viejo>` exists, it renames it to `<nuevo>` (without following links). If
  `drive_c/users/<nuevo>` already exists, it touches nothing and gives an error.
- Sets the user's `TEMP` and `TMP` to `%USERPROFILE%\AppData\Local\Temp`.
- "Usar el del Mac" ("Use the Mac's") does the same toward the Mac's name and removes `user` from the settings.
- The same name it already has: it does nothing.

## U5 · Screen
- In Settings: "Usuario de Windows" ("Windows user") with the current name, "<nombre> (el de tu equipo)" ("<name> (your computer's)")
  if there is no custom one, and **Cambiar…** ("Change…").
- The dialog validates while typing (U3) and has **Guardar** ("Save"), **Usar <nombre del equipo>** ("Use <computer name>") (only
  if the bottle has a custom one) and Cancel. It warns that it closes whatever is open. The texts do not
  say "Mac" because the app also runs on Linux.

## Scenarios
- **Given** a bottle without `user`, **when** something is launched, **then** `USER` is the
  Mac's. (test)
- **Given** `user: Dany`, **when** something is launched, **then** `USER=Dany`. (test)
- **Given** `users/quasar` with `AppData/x` and a `Documents` link, **when** the name is changed to
  `Dany`, **then** `users/Dany/AppData/x` exists, the link is still a link and points
  to the same place, and `users/quasar` is gone. (test)
- **Given** `Dany` and then "Usar el del Mac", **then** `users/quasar` is back and no
  `user` is left in `settings.json`. (test)
- **Given** `a/b` or a 21-letter name, **then** an error, and nothing changes. (test)
- **Given** the real `Games` bottle with the name `Dany`, **when**
  `cmd /c echo %USERNAME% %USERPROFILE%` runs without windows, **then** it prints
  `Dany C:\users\Dany`. (verify, headless)
- **Given** Blur, **when** the user plays, **then** their name shows where the game
  shows the Windows user. (U, the user)
