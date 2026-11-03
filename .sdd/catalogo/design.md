# Diseño: catalogo

Solo lo que no es obvio. `HB` = `gauthierpiarrette/highball`; `HBDB` = `gauthierpiarrette/highball-db` en el commit `f0bf6a2`.

## 1. Entrada plana, no pasos

Highball interpreta una lista de pasos porque sus recetas también hacen juegos y ajustes (`HB/Sources/HighballKit/Recipe.swift:8-54`). Las 7 de este cambio solo necesitan registro, instalador y ejecutable, siempre en ese orden. Una entrada plana evita el intérprete y es lo que la pantalla quiere leer. Si las recetas de juegos entran más adelante, se añade entonces.

Se pierde `winetricks`, que solo usa GOG Galaxy, y está `blocked`. También `pin.renderer` pasa a ser `backend` de la entrada.

## 2. `installEntry` recibe la entrada

`bodega catalog install` busca el `id` y llama a `installEntry(home, entry, …)`. Los tests pasan entradas propias con URL `file://`, sin parámetros extra ni tocar los datos reales.

Los tiempos de I6 son parámetros con valor por defecto, para no esperar 60 s en un test.

## 3. Espera tras el instalador

`wineserver -w` termina cuando se va el último cliente, pero Battle.net y Rockstar dejan procesos vivos, así que `-w` no volvería nunca. Parar justo al salir tampoco vale: un programa de arranque puede salir con el trabajo todavía en marcha en un hijo. Por eso:

```
done = wineserver -w (sin esperar)
repetir cada 2 s hasta: done terminó | (exe existe y pasó la gracia) | pasó el máximo
wineserver -k
```

Es la misma idea que `installerGrace = 60` de Highball (`HB/…/Recipe.swift:510,605-611`), sin su tabla de procesos: como la botella es nueva, todo lo que corre en ella es del instalador. El `-w` pendiente termina solo cuando `-k` apaga el servidor.

// ponytail: el reloj de gracia empieza al salir el instalador, no cuando aparece el exe. Basta para estos 7.

## 4. msync por botella

Medido en esta prueba: con un servidor sin msync, un cliente con `WINEMSYNC=1` sale con 1. También comprobado: `wineserver -w` con `WINEMSYNC=1` funciona contra un servidor sin msync, así que `_wineserver` no necesita cambios.

La receta de Steam deja la botella en msync y solo apaga msync en la ventana de Steam, reiniciando el servidor al abrirla (`HBDB/recipes/launchers/steam.json`). Eso exige saber en qué modo está el servidor y reiniciarlo solo. Por botella es mucho más simple, pero tiene el coste de la decisión 6: los juegos abiertos desde esa botella van sin msync. Si U3 lo confirma como un problema real, msync por programa es el siguiente paso.

## 5. Descarga

`_download` (`P/lib/backends.dart:193`) gana los flags de HTTPS y el `.part`. `file` queda permitido solo para la URL inicial: `--proto-redir =https` impide que una redirección llegue a otro protocolo. `catalog data` comprueba que ninguna entrada real use `file://`.

Sin `sha256` no hay caché: un instalador viejo podría no funcionar, y el archivo pesa poco (sus descargadores bajan el resto).

## 6. Comprobado antes de escribir esto

En una botella temporal, ya borrada, con el runtime real:

| Prueba | Resultado |
|---|---|
| Fork de DXMT: contiene `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN` | Sí, 2 coincidencias; el oficial, 0 |
| `backend test t dxmt` con el fork | `OK` en 64 y 32 bits |
| Sonda con el fork, `WINEMSYNC=0` y la variable | `OK` en 64 y 32 bits, "Apple M2 Pro", nivel 11_0 |
| Servidor sin msync + cliente con `WINEMSYNC=1` | Salida 1 |
| `Blur.exe`: `d3d9` / `d3d10` / `dxgi.dll` / `d3d11.dll` / `d3d12.dll` | 12 / 1 / 1 / 0 / 0 líneas: `auto` lo mandaba a DXMT |

**Sin comprobar:** la sonda no abre ventanas, así que esto no demuestra que un launcher se vea bien. El instalador de Steam no se llegó a ejecutar: el modo automático bloqueó bajarlo y ejecutarlo, y queda para U3.
