# Tareas · usuario-por-botella

- [x] T1 Motor: `user` en `BottleSettings` (leer, guardar solo si hay); `wineEnv` pone
  `USER` desde los ajustes de la botella. Tests: sin `user` = el del Mac; con `user` = ese.
- [x] T2 Motor: `setBottleUser(home, name, String? user)`: valida (U3), para la botella,
  renombra `users/<viejo>` sin seguir enlaces, guarda, `reg add` de `TEMP`/`TMP`. Tests:
  renombrado con enlace intacto, vuelta al del Mac, destino ya existe, nombres inválidos.
- [x] T3 App datos/dominio: `BottleDetail.user` (nulo = el del Mac) y `macUser`;
  `BottleRepository.setUser`. `tool/check_layers.sh` limpio.
- [x] T4 App: evento `setUser` en `BottleDetailBloc` + bloc_test.
- [x] T5 App: fila "Usuario de Windows" en Configuración y diálogo (valida al escribir,
  Guardar / Usar el del Mac / Cancelar, aviso de que cierra la botella). Widget test.
- [x] T6 `dart analyze && dart test`, `flutter analyze && flutter test &&
  tool/check_layers.sh`, build macOS.
- [x] V1 (verify, headless) Botella de prueba `prueba-usuario` (borrada después) con `Dany`: `cmd /c echo %USERNAME% %USERPROFILE%`.
- [ ] U1 (usuario) Blur muestra el nombre elegido.
