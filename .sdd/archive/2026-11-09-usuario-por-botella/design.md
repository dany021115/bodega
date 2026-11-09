# Diseño · usuario-por-botella

## 1. Un solo sitio: `wineEnv`
`wineEnv(prefix, …)` arma el entorno de todo proceso de Wine. Lee `user` de
`<prefix>/../settings.json` y, si hay, pone `USER`. Así `wineboot`, `reg` y los arreglos
usan el mismo nombre que los juegos: si alguno usara el del Mac, Wine recrearía
`users/quasar`. Un prefijo sin botella (el temporal de `installRuntime`) no tiene ajustes:
queda el del Mac.

## 2. `TEMP`/`TMP` con `reg add`, no editando `user.reg`
En el registro están como ruta fija `C:\users\quasar\…`. En vez de reescribir el archivo
(Wine guarda los caracteres no ASCII con escapes propios), Bodega ejecuta `reg add` dentro
de la botella, sin ventanas, con el valor de Windows por defecto: `REG_EXPAND_SZ`
`%USERPROFILE%\AppData\Local\Temp`. Así siguen al nombre en cambios futuros.

## 3. Lo que no se toca
- "User Shell Folders" ya usan `%USERPROFILE%`; "Shell Folders" las reescribe shell32.
- `ProfileImagePath` lo pone al día Wine en la próxima actualización del prefijo.
- Las rutas `Z:\Users\quasar\…` son del Mac.

## 4. El nombre del Mac
El que Wine usaría sin Bodega: `USER` del entorno de `baseEnv` (Mac y Linux lo copian del
padre). Se usa para saber cómo se llama la carpeta vieja y para "Usar el del Mac".
