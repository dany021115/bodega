# Tasks · user-per-bottle

- [x] T1 Engine: `user` in `BottleSettings` (read it, store it only if set); `wineEnv` sets
  `USER` from the bottle settings. Tests: without `user` = the Mac's; with `user` = that one.
- [x] T2 Engine: `setBottleUser(home, name, String? user)`: validates (U3), stops the bottle,
  renames `users/<viejo>` without following links, saves, `reg add` of `TEMP`/`TMP`. Tests:
  rename with the link intact, back to the Mac's, target already exists, invalid names.
- [x] T3 App data/domain: `BottleDetail.user` (null = the Mac's) and `macUser`;
  `BottleRepository.setUser`. `tool/check_layers.sh` clean.
- [x] T4 App: `setUser` event in `BottleDetailBloc` + bloc_test.
- [x] T5 App: "Usuario de Windows" ("Windows user") row in Settings, and the dialog (validates while typing,
  Save / Use the Mac's / Cancel, a warning that it closes the bottle). Widget test.
- [x] T6 `dart analyze && dart test`, `flutter analyze && flutter test &&
  tool/check_layers.sh`, macOS build.
- [x] V1 (verify, headless) Test bottle `prueba-usuario` (deleted afterwards) with `Dany`: `cmd /c echo %USERNAME% %USERPROFILE%`.
- [ ] U1 (user) Blur shows the chosen name.
