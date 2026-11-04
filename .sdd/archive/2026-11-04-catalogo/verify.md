# Verificación: catalogo

2026-11-04, M2 Pro, macOS 27.0.1. Base `83934de` más T11 y T12 sin commit. `H` es un `BODEGA_HOME` temporal, ya borrado.

| Requisito | Estado | Evidencia |
|---|---|---|
| C1 Datos | cumplido | Test `catalog data`; 7 entradas en orden |
| C2 Estados | cumplido | `catalog list`; Steam pasa a `tested` tras U3 |
| C3 Listar y buscar | cumplido | Salidas abajo; test `catalogEntries` |
| C4 Detalle | cumplido | `show steam`; `show nope` sale con 1 |
| I1 Comprobaciones | cumplido | Bloqueadas y backend ausente salen con 1 sin crear botella; test `installEntry` |
| I2 Orden | cumplido | Instalación real de Steam; test `installEntry` |
| I3 Descarga | cumplido, con límite | Descarga HTTPS real de Steam con su aviso; `http://` y SHA erróneo en test. `--proto-redir` no se ejercitó con una redirección real |
| I4 Instalador | cumplido, con límite | Steam real; 194 y 5 en test. **MSI solo con Wine falso:** Epic, único MSI, está bloqueada |
| I5 Registro | cumplido | `reg query` con Wine real en `real runtime` |
| I6 Espera y parada | cumplido | Test `waits for the server`; Steam real terminó y el primer arranque fue en frío |
| I7 Comprobar | cumplido | Test `missing exe` |
| I8 Biblioteca | cumplido | `bodega apps` en tu carpeta real lista `steam` |
| I9 Abrir | cumplido | `open steam` real: `backend dxmt (exe)` |
| I10 Avance y notas | cumplido | Salida de tu `catalog install steam` |
| I11 Aviso de EAC | cumplido, con límite | Test con líneas del log real y prueba en vivo con el CLI. El log real ya no existe. No avisa si `open` ya volvió |
| A1 msync por botella | cumplido | `WINEMSYNC=0` y `=1` leídos dentro de Wine; repetir no para nada; `foo` rechazado |
| A2 Variables por programa | cumplido | Tests `settings` e `installedApps` |
| A3 DXMT parcheado | cumplido | Instalado con su SHA; `OK` en 64 y 32 bits; variable presente; Muck corrió con él |
| A4 Auto y D3D9 | cumplido | Test `resolve`; tu Blur imprimió `backend wine (auto)` |

## Aceptación del usuario

| Prueba | Resultado | Evidencia |
|---|---|---|
| U1 DXMT en tu carpeta | OK | `OK` en 64 y 32 bits |
| U2 Blur | Parcial | `backend wine (auto)` y salida 0; falta tu confirmación de que se juega igual |
| U3 Steam | **OK** | Instala, abre, inicia sesión, descarga y lanza juegos |
| U3 Muck (AppID 1625450) | **OK, según el usuario** | 09:44:15 a 09:47:50 por Steam. `Player.log`: `Direct3D 11.0 [level 11.1]`, `Renderer: Apple M2 Pro`; backend `dxmt` |
| U3 POLYGON (AppID 1241100) | **Falla** | EAC: `Failed to map the anti-cheat module`, error 206, tras pedir el módulo `linux64`. El usuario confirma que también falla en CrossOver |
| U4 Otro launcher | No hecha | Opcional |
| U5 Lista y detalle | Comprobado por el agente | `catalog list`, `show steam` y `apps`; falta tu opinión sobre si se entiende |

## Observaciones

- **Solo Steam está probado.** Rockstar, EA, Ubisoft y Battle.net siguen como `reported` o `untested`.
- **Sin FPS:** Muck "salió bien" según el usuario, sin medidas ni comparación con CrossOver. El coste de ir sin msync en esa botella no se ha medido.
- **`open` vuelve antes de tiempo si el launcher se relanza:** en la actualización de Steam salió con `exit=42` mientras Steam seguía. La app Flutter debe seguir la botella, no ese proceso.
- **Sin H.264:** `GStreamer doesn't support H.264 decoding` en el log de Steam. Algunos vídeos pueden no reproducirse.
- **Otros errores sin efecto visible en el log de Steam:** `Steam Client Service` no arranca y `gldriverquery.exe` no encuentra `SDL2.dll`.
- **Fork de DXMT:** binario de terceros, fijado por SHA-256, sin compilarlo nosotros.

## Salidas

```
$ dart analyze
No issues found!
$ dart format (comprobación)
Formatted 7 files (0 changed) in 0.04 seconds.
$ dart test
00:14 +24 ~2: All tests passed!
backendEnv      +1: All tests passed!
resolve         +1: All tests passed!
settings        +1: All tests passed!
installBackend  +1: All tests passed!
catalog data    +1: All tests passed!
catalogEntries  +1: All tests passed!
installEntry    +8 ~1: All tests passed!
installedApps   +1: All tests passed!
antiCheatHints  +1: All tests passed!
fake runtime    +1: All tests passed!
$ compile
Generated: build/bodega
$ bodega catalog list
steam             Steam                     tested
rockstar          Rockstar Games Launcher   reported
ea-app            EA app                    reported
ubisoft-connect   Ubisoft Connect           reported
battle-net        Battle.net                untested
epic-games        Epic Games Launcher       blocked
gog-galaxy        GOG Galaxy                blocked
-> 0
$ catalog list STEAM / zzz
steam             Steam                     tested
-> 0
$ catalog show steam
Steam (steam)
estado: tested: Probado en Bodega el 2026-11-04 (M2 Pro, macOS 27.0.1): instala, abre, inicia sesión, descarga
backend: dxmt, sync: none
fuente: gauthierpiarrette/highball-db f0bf6a2, recipes/launchers/steam.json (CC0-1.0); verificado: 2026-08-24,
$ catalog show nope
bodega: no está en el catálogo: nope (bodega catalog list)
-> 1
$ catalog install epic-games / gog-galaxy (bloqueadas)
bodega: Epic Games Launcher está bloqueada: Comprueba permisos de Windows que Wine no guar
-> 1
bodega: GOG Galaxy está bloqueada: Se instala, pero en Wine 11 muestra el inicio de sesión
-> 1
       0
$ usos incorrectos
catalog -> 64
open -> 64
sync x -> 64
install a b c -> 64
$ install + create + sync
H/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
create -> 0
H/backends/dxmt
OK    D3D11 64 bits  
OK    D3D11 32 bits  
-> 0
$ catalog install rockstar con dxvk ausente
bodega: dxvk no está instalado: bodega backend install dxvk
-> 1
       0
botella detenida
sync none -> 0
repetido -> 0
bodega: sync desconocido: foo (msync, none)
run -> 0
backend dxmt (opcion)
DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1 WINEMSYNC=0 
botella detenida
run -> 0
WINEMSYNC=1
DXMT_ALLOW en wine: 0
stop -> 0
$ real runtime
create: 0:00:11.909168
install: 0:00:20.573848
00:41 +2: All tests passed!
$ tu carpeta real
steam  Steam  Program Files (x86)/Steam/steam.exe
apps -> 0
wine: instalado;dxmt: instalado;dxvk: instalado;d3dmetal: instalado;
steam             Steam                     tested
```
