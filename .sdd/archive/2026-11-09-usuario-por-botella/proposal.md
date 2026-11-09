# Propuesta · usuario-por-botella

## Por qué
Los juegos ven como usuario de Windows el nombre del Mac (`quasar`). El usuario quiere
elegir, por botella, el nombre que salga en los juegos.

## Qué
- Cada botella puede tener su **usuario de Windows**. Sin elegir, sigue el del Mac.
- En Configuración de la botella: "Usuario de Windows: quasar" con **Cambiar…**, un diálogo
  con el nombre y la opción "Usar el del Mac".
- Al cambiarlo, Bodega para la botella, **renombra la carpeta del perfil**
  (`C:\users\<viejo>` → `<nuevo>`) para que las partidas guardadas y los enlaces a las
  carpetas del Mac sigan ahí, y deja `TEMP`/`TMP` apuntando al perfil nuevo.
- Todo lo que Bodega lance en esa botella (juegos, `wineboot`, `reg`, arreglos) va con ese
  nombre.

## Impacto
- Motor: `engine.dart` (`wineEnv`), `backends.dart` (ajustes de la botella y la función
  que cambia el usuario). Nada en las plataformas: vale igual en Mac y Linux.
- App: `BottleDetail`, `BottleRepository`, `BottleDetailBloc`, `bottle_column.dart` y un
  diálogo nuevo.
- Botellas existentes: no cambian hasta que el usuario elija un nombre.
