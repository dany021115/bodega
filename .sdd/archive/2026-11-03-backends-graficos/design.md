# Diseño: backends-graficos

Solo lo que no es obvio.

## 1. Una capa por backend, resuelta por proceso

`_start` recibe un mapa extra que se suma a `wineEnv`. No se copian DLL al prefijo: cambiar de backend es cambiar una variable (parche `0003`, `BE/patches/0003-ntdll-winedllpath-prepend.patch`). Es el mismo efecto que el `cxcompatdb.so` cerrado de CrossOver, con una pieza abierta.

`CX_ACTIVE_GRAPHICS_BACKEND` hay que ponerla a mano: en CrossOver la pone ese módulo cerrado, y el árbol LGPL la lee en `CX/dlls/win32u/d3dkmt.c:719-724`.

## 2. D3DMetal: un solo binario y sin `DYLD_*`

`d3d11.so`, `d3d12.so`, `dxgi.so` y los demás son **enlaces simbólicos** a `../../external/libd3dshared.dylib`. Tienen `LC_RPATH @loader_path` y cargan `@rpath/D3DMetal.framework/D3DMetal`. Como dyld resuelve el enlace, `@loader_path` es `external/`, donde está el framework, y todos los módulos son la misma imagen.

Si se copian como archivos separados, dyld carga imágenes distintas y el proceso salta a una dirección inválida al crear el dispositivo (`spike.md`, Corrección). Por eso `import` recrea siempre los enlaces, aunque el origen los haya perdido, y rechaza un `.so` que no pese lo mismo que la biblioteca.

No hace falta `DYLD_*`, así que no choca con SIP, que lo borra al arrancar `/bin/sh` (`_launch`, `P/lib/engine.dart`).

## 3. Por qué hace falta la sonda

Una copia mal hecha de D3DMetal carga, responde a `dxgi` y solo se cae al crear el dispositivo: le pasó a la propia prueba de este cambio, que culpó a la copia de Whisky sin motivo. Sin `backend test`, eso parecería un fallo del juego.

La sonda va embebida en base64 porque `dart compile exe` no lleva archivos consigo y la futura app tampoco debería depender de una ruta del repo. Es un PE de 60–70 KB compilado con `zig cc`.

- `tool/build_probe.sh` regenera `lib/probe_data.dart`.
- `zig` se instala en un venv temporal y no entra en el repo.
- Es lo único generado.

## 4. Auto busca texto, no imports

Un parser de imports no ve las DLL cargadas con `LoadLibrary`, y muchos motores lo hacen así. Buscar el nombre en el binario es más corto y acierta en más casos, a cambio de falsos positivos: un exe que mencione `d3d12.dll` sin usarlo irá por D3DMetal. Si se equivoca, el ajuste manual lo corrige, y por eso S6 deja a la vista qué se eligió y por qué.

## 5. Cambiar de backend en una botella en uso

Los servicios de la botella conservan el entorno del primer proceso (trampa 4 del prototipo), pero la capa se resuelve en cada proceso nuevo, y el servidor se apaga 3 s después del último cliente (`CX/server/main.c:48`).

// ponytail: no se detecta un cambio con otro juego abierto en la misma botella. El log dice qué backend usó cada uno. Se añade un aviso si da problemas reales.

## 6. La licencia se muestra, no se decide

`import` imprime el aviso (B2) y no pregunta nada: esa conversación es de la interfaz. El rechazo de `CrossOver.app` es un guardarraíl contra un error fácil, no una medida de seguridad: resuelve enlaces, pero una copia manual de los archivos lo esquiva.
