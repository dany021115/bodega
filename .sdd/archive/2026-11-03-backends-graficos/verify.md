# Verificación: backends-graficos

2026-11-03, M2 Pro, macOS 27.0.1, commit `414cdbe`. `H` es un `BODEGA_HOME` temporal, ya borrado. Copia de D3DMetal: la de Whisky, sin modificarla.

**Límite:** todo esto es sin ventanas. La sonda crea el dispositivo y limpia una textura, o espera un fence, pero **no presenta fotogramas**. Ningún juego real ha corrido con DXMT, DXVK o D3DMetal: eso son U2–U5, pendientes del usuario.

| Requisito | Estado | Evidencia |
|---|---|---|
| B1 Instalar dxmt/dxvk | cumplido | Salidas abajo; tarball alterado sin rastro; test `installBackend`. Descarga real de dxvk hecha en T9 |
| B2 Importar d3dmetal | cumplido | Enlaces a `../../external/libd3dshared.dylib`; CrossOver rechazado; test `importD3DMetal` (dos layouts, módulo ausente, `.so` de otro tamaño) |
| B3 Listar | cumplido | `backend list`; test `listBackends` |
| B4 Comprobar | cumplido | Todos `OK` con los 4 backends; `FALLA` con Wine falso en `fake runtime cycle`. Con el Wine real no se ha visto un `FALLA` desde que `import` recrea los enlaces (T10 sí lo vio antes del arreglo) |
| S1 Ajustes | cumplido | JSON en minúsculas; `foo` rechazado; JSON roto da salida 1 y nombra el archivo; test `settings` |
| S2 Orden | cumplido | `opcion` > `exe` > `botella` > `auto`, abajo y en test `resolve` |
| S3 Auto | cumplido | Test `resolve` con PE falsos (64/32 bits, mayúsculas, UTF-16, sin PE); con la sonda real eligió `d3dmetal` |
| S4 Entorno | cumplido | Variables leídas de `cmd /c set` dentro de Wine; sin `DYLD_*`, `WINEARCH` ni `LANG` |
| S5 No instalado | cumplido | Salida 1 con la orden exacta, antes de lanzar |
| S6 Trazabilidad | cumplido | `# backend` en el log y en la salida de `run` |
| S7 Compatibilidad | cumplido | `--hud` tras el programa llega al programa; `create` sin `# backend` (test) |

## Pendiente del usuario

- **U1:** instalar en la carpeta real y `backend test`.
- **U2:** Blur con `--hud`.
- **U3:** un juego DX11 con DXMT.
- **U4:** un juego DX12 con D3DMetal.
- **U5:** FPS frente a CrossOver.

## Observaciones

- El primer caso con D3DMetal tardó unos 38 s en T10 y T11. Causa sin confirmar (probablemente Rosetta traduciendo el framework).
- `--hud` pone `MTL_HUD_ENABLED=1`, pero no se ha visto el contador: necesita ventana.
- En un primer pase, el `grep` de S4 estaba mal escrito y el `-> 0` del JSON roto era el código de `cut`. Se repitieron: ver el bloque 2.
- Este Mac no tiene Warframe instalado: su botella de CrossOver solo pesa 310 MB.

## Salidas

### Bloque 1
```
$ git log -1
414cdbe Daniel Medina <danielmedina151102@gmail.com> engine: graphics backends with per-bottle and per-exe selection (SD
0
       0
$ dart analyze
No issues found!
$ dart format check
Formatted 5 files (0 changed) in 0.02 seconds.
$ dart test
00:03 +12 ~1: All tests passed!
$ compile
Generated: build/bodega
$ usage
backend -> 64
backend test -> 64
$ install + create
H/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
log: 2026-11-03T14-36-30.664099Z-wineboot.log
create -> 0
$ B1 tarball alterado
bodega: checksum incorrecto en /private/tmp/claude-501/-Users-quasar/c
       0
$ B1 d3dmetal no se descarga
bodega: d3dmetal no se descarga: bodega backend import d3dmetal <carpeta>
-> 1
$ B3 list antes
wine: instalado
dxmt: no instalado
dxvk: no instalado
d3dmetal: no instalado
$ S5 sin instalar
bodega: dxmt no está instalado: bodega backend install dxmt
-> 1
$ B1 instalar
H/backends/dxmt
H/backends/dxvk
bodega: ya instalado: /private/tmp/claud
$ B2 rechaza CrossOver
bodega: no se importa desde CrossOver.app: usa tu propia copia de D3DMetal
-> 1
       0
$ B2 import Whisky
H/backends/d3dmetal
compruébalo: bodega backend test <botella> d3dmetal
su uso se rige por la licencia de Apple del Game Porting Toolkit
atidxx64.so -> ../../external/libd3dshared.dylib
d3d11.so -> ../../external/libd3dshared.dylib
d3d12.so -> ../../external/libd3dshared.dylib
dxgi.so -> ../../external/libd3dshared.dylib
nvapi64.so -> ../../external/libd3dshared.dylib
$ B4 test
[wine] exit=0
OK    D3D11 64 bits  
OK    D3D12 64 bits  
[dxmt] exit=0
OK    D3D11 64 bits  
OK    D3D11 32 bits  
[dxvk] exit=0
OK    D3D11 64 bits  
OK    D3D11 32 bits  
[d3dmetal] exit=0
OK    D3D11 64 bits  
OK    D3D12 64 bits  
OK    D3D11 32 bits  
$ S4 entorno d3dmetal + hud
backend d3dmetal (opcion)
WINEDLLOVERRIDES=winemenubuilder.exe=d
WINEDLLPATH_PREPEND=H/backends/d3dmetal/wine:H/backends/dxmt/wine
DYLD/WINEARCH/LANG: 0
$ S4 wine sin capa
0
CX_ACTIVE_GRAPHICS_BACKEND=wined3d
$ S7 args tras el programa
backend wine (auto)
--hud
$ S1 S2 S6
backend d3dmetal (auto)
backend dxvk (botella)
backend dxmt (exe)
backend wine (opcion)
bodega: backend desconocido: foo (auto, wine, dxmt, dxvk, d3
{
  "backend": "dxvk",
  "programs": {
    "probe.exe": {
      "backend": "dxmt"
    }
  }
}
bodega: /private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratch
{roto
 ^

-> 0
$ limpieza
stop -> 0
0
```

### Bloque 2
```
$ S4 d3dmetal --hud
CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
CX_APPLEGPTK_LIBD3DSHARED_PATH=H/backends/d3dmetal/external/libd3dshared.dylib
MTL_HUD_ENABLED=1
$ S4 dxvk
WINEDLLOVERRIDES=winemenubuilder.exe=d;d3d10core,d3d11=n,b
WINEDLLPATH_PREPEND=H/backends/dxvk/wine
$ S1 JSON roto
exit=1
bodega: H/bottles/t/settings.json no es válido: FormatException: Unexp
$ limpieza
stop=0
```

## Aceptación del usuario (en curso)

**U1: OK.** Carpeta real: `backend install dxmt`, `backend install dxvk`, `backend import d3dmetal` desde Whisky y `backend test prueba`, con los 9 casos en `OK`.

**U2: pendiente de saber si aparece el contador.** Blur con `--backend wine --hud` terminó con `exit=0` a los 77 s, sin errores nuevos en el log.

**Tiempos de la sonda en la botella real (`run`, del inicio hasta `.exit`):**

| Caso | Tiempo |
|---|---|
| d3dmetal D3D12, botella fría | 5,2 s |
| d3dmetal D3D12, seguido | 0,7 s |
| d3dmetal D3D11, seguido | 30,7 s |
| d3dmetal D3D11, tras 6 s | 32,5 s |
| d3dmetal D3D11, botella fría | 35,2 s |
| dxmt D3D11, botella fría | 2,2 s |
| wine D3D11, botella fría | 3,0 s |
| wine `cmd`, botella fría | 1,5 s |

Con D3DMetal, D3D11 tarda unos 30 s **cada vez**, no solo la primera, y D3D12 no. Causa sin investigar: puede ser inicialización de D3D11 o algo de la propia sonda, que no tiene ventana. Hay que mirarlo en un juego real. `auto` no se ve afectado, porque manda D3D11 a DXMT. Sustituye a la observación de arriba, que lo atribuía a la primera vez.

## Cierre (2026-11-03)

**U2:** Blur corrió con `--backend wine --hud`, pero el usuario no vio el contador de FPS. `--hud` pone `MTL_HUD_ENABLED=1` (bloque 2) y su efecto en pantalla sigue sin confirmar: con wined3d puede no aparecer, y con DXMT o D3DMetal no se ha probado.

**U3, U4 y U5: aplazadas por decisión del usuario.** Ningún juego real se ha ejecutado con DXMT, DXVK o D3DMetal, no hay FPS y no hay comparación con CrossOver. Por eso este cambio no permite afirmar "igual o mejor que CrossOver". El retraso de unos 30 s de D3DMetal en D3D11 sigue sin investigar.

Se archiva con 11 de 11 requisitos cumplidos en pruebas sin ventanas y esas pruebas con juegos pendientes.
