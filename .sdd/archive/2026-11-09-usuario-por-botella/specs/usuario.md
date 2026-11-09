# Spec · Usuario de Windows por botella

## U1 · Guardar el nombre
- `settings.json` de la botella guarda `user` solo si el usuario eligió uno.
- Sin `user`, el nombre es el del Mac (o del PC en Linux): como hoy.

## U2 · Usarlo
- Todo proceso de Wine de la botella arranca con `USER=<nombre>`: Wine lo da a los juegos
  como `GetUserName`, `%USERNAME%` y `C:\users\<nombre>` (`%USERPROFILE%`).

## U3 · Nombres válidos
- De 1 a 20 caracteres, sin `" / \ [ ] : ; | = , + * ? < >` ni caracteres de control, y no
  solo puntos o espacios. Se quitan los espacios de los extremos.
- Un nombre inválido no cambia nada y dice por qué.

## U4 · Cambiar el nombre
- Para la botella (avisa antes, como "Pantalla de alta densidad").
- Si existe `drive_c/users/<viejo>`, lo renombra a `<nuevo>` (sin seguir enlaces). Si ya
  existe `drive_c/users/<nuevo>`, no toca nada y da error.
- Deja `TEMP` y `TMP` del usuario como `%USERPROFILE%\AppData\Local\Temp`.
- "Usar el del Mac" hace lo mismo hacia el nombre del Mac y borra `user` de los ajustes.
- El mismo nombre que ya tiene: no hace nada.

## U5 · Pantalla
- En Configuración: "Usuario de Windows" con el nombre actual, "<nombre> (el de tu equipo)"
  si no hay uno propio, y **Cambiar…**.
- El diálogo valida al escribir (U3) y tiene **Guardar**, **Usar <nombre del equipo>** (solo
  si la botella tiene uno propio) y Cancelar. Avisa de que cierra lo abierto. Los textos no
  dicen "Mac" porque la app también corre en Linux.

## Escenarios
- **Dado** una botella sin `user`, **cuando** se lanza algo, **entonces** `USER` es el del
  Mac. (test)
- **Dado** `user: Dany`, **cuando** se lanza algo, **entonces** `USER=Dany`. (test)
- **Dado** `users/quasar` con `AppData/x` y un enlace `Documents`, **cuando** se cambia a
  `Dany`, **entonces** existe `users/Dany/AppData/x`, el enlace sigue siendo enlace y apunta
  a lo mismo, y `users/quasar` ya no está. (test)
- **Dado** `Dany` y luego "Usar el del Mac", **entonces** vuelve `users/quasar` y no queda
  `user` en `settings.json`. (test)
- **Dado** `a/b` o un nombre de 21 letras, **entonces** error y nada cambia. (test)
- **Dado** la botella `Games` real con nombre `Dany`, **cuando** se ejecuta
  `cmd /c echo %USERNAME% %USERPROFILE%` sin ventanas, **entonces** sale
  `Dany C:\users\Dany`. (verify, headless)
- **Dado** Blur, **cuando** el usuario juega, **entonces** sale su nombre donde el juego
  muestra el usuario de Windows. (U, el usuario)
