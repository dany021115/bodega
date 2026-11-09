# Exploración · usuario-por-botella

## Problema
Los juegos ven como usuario de Windows el nombre del usuario del Mac (`quasar`). El usuario
quiere elegir, por botella, el nombre que ven los juegos (perfil, partidas, LAN…).

## Cómo decide Wine el nombre (código del Wine de CrossOver 26.3, `~/Downloads/sources/wine`)
- `dlls/ntdll/unix/loader.c:432` `set_home_dir()`: `user_name = getenv("USER")`; si falta,
  el de `getpwuid`. Quita lo que haya antes de `/` o `\`.
- `dlls/ntdll/unix/env.c:1051`: lo pasa a Windows como `WINEUSERNAME`.
- `dlls/advapi32/advapi.c:48,73` (`GetUserNameA/W`) y `dlls/kernelbase/sync.c:1530` leen
  `WINEUSERNAME`: es el nombre que ven los juegos.
- `dlls/userenv/userenv_main.c:302-306`: `USERNAME` y `USERPROFILE` = `C:\users\<nombre>`.
- `programs/wineboot/wineboot.c:867-896`: "Volatile Environment" (`USERPROFILE`, `USERNAME`,
  `APPDATA`…) se rehace en cada arranque de Wine. `:1655` `update_user_profile` escribe
  `ProfileImagePath`.
- `dlls/shell32/shellpath.c:2118`: las carpetas del shell salen de "User Shell Folders",
  que están como `%USERPROFILE%\…` (siguen al nombre solas) y se copian a "Shell Folders".

**Conclusión:** basta con lanzar todo lo de esa botella con `USER=<nombre>`.

## Lo que hay en una botella real (`bottles/Games/prefix`)
- `drive_c/users/quasar/`: `AppData`, `Desktop`, `Saved Games`… y **enlaces** a las carpetas
  del Mac: `Documents → /Users/quasar/Documents`, `Downloads`, `Music`, `Pictures`, `Videos`.
  Wine los crea al hacer el prefijo; un perfil nuevo no los tendría.
- `user.reg`: 37 líneas con `quasar`. Las de "User Shell Folders" usan `%USERPROFILE%`;
  pero `[Environment]` tiene **rutas fijas**: `"TEMP"="C:\\users\\quasar\\AppData\\Local\\Temp"`
  y `TMP`. "Shell Folders" también tiene rutas fijas, pero shell32 las reescribe al usarlas.
- `system.reg` (13) y `userdef.reg` (26): casi todo son rutas `Z:\Users\quasar\…` del Mac
  (el motor, fuentes): **no se tocan**, son el Mac de verdad.

Si se cambia el nombre sin más, Wine usa `C:\users\<nuevo>` vacío: las partidas guardadas en
`AppData`/`Saved Games` del perfil viejo "desaparecen" y `TEMP` apunta a la carpeta vieja.

## Código de Bodega implicado
### Motor (`packages/engine/lib`)
- `engine.dart:69` `wineEnv(prefix, parent, extra)`: el entorno de **todo** proceso de Wine
  (lanzar, `wineboot`, `reg`, arreglos…). Llamadas: `engine.dart:140,446,456`,
  `fixes.dart:134`, `platform_mac.dart:308`. Aquí entra `USER`.
- `platform_mac.dart:54` / `platform_linux.dart:54` `baseEnv`: hoy copian `USER` del Mac/PC.
- `backends.dart:388` `BottleSettings`, `:512` `_saveSettings`, `:580` `setBottleOptions`,
  `:855` `bottleSettings`: donde se guardaría el nombre (`settings.json`).
- `backends.dart:607` `setHighRes`: molde de "cambio que para la botella y toca el prefijo".
- `engine.dart:338` `stopBottle`, `engine.dart:616` `renameBottle`, `engine.dart:172`
  `createBottle`.

### App (`apps/bodega/lib`)
- `app/presentation/bottles/widgets/bottle_column.dart:355` sección "Configuración"
  (dropdowns de Gráficos/Windows, interruptores).
- `app/presentation/bottles/widgets/rename_bottle_dialog.dart:13`: molde de diálogo con texto.
- `domain/entities/bottle_detail.dart`, `domain/repository/bottle_repository.dart:23-27`,
  `data/repository/bottle_repository_impl.dart`, `app/bloc/bottle_detail/`.

## Restricciones
- Nunca seguir symlinks dentro de la botella: renombrar `users/<viejo>` mueve los enlaces,
  no lo que apuntan (`Directory.renameSync` no los sigue).
- Parar la botella antes de tocar el prefijo (como `setHighRes`).
- Las rutas `Z:\Users\quasar\…` son del Mac: no se cambian.
- Wine solo headless desde el agente; el juego lo prueba el usuario.
- Linux usa el mismo `wineEnv`: sirve igual allí.

## Dudas abiertas
1. **Cambiar el nombre en una botella con partidas:** propongo parar la botella, renombrar
   `drive_c/users/<viejo>` a `<nuevo>` y reescribir `TEMP`/`TMP` del registro. Así se
   conservan partidas y enlaces.
2. **Nombres válidos:** como Windows: hasta 20 caracteres, sin `" / \ [ ] : ; | = , + * ? < >`,
   no vacío ni solo puntos/espacios. ¿Vale?
3. **Sin nombre elegido:** se queda el del Mac, como hoy (botellas existentes no cambian).
4. **¿También al crear la botella?** Propongo que solo esté en Configuración (YAGNI); se
   puede poner al crear más adelante.
5. **¿Afecta a Steam?** Steam usa su propia cuenta; no cambia. Sí cambia lo que los juegos
   leen con `GetUserName` y las carpetas del perfil.
