# Propuesta: backends-graficos

## Por qué

Bodega solo tiene las DLL de Wine. Blur (DX9) va bien, pero los juegos DX10/11 van por wined3d y DX12 por vkd3d, que es la ruta más floja. El usuario quiere todos los backends y elegirlos como en CrossOver, con D3DMetal como requisito. La prueba corta (`spike.md`) confirma que los cuatro arrancan sobre nuestro runtime.

## Qué

- **Backends:** `wine` (wined3d + vkd3d, ya incluido), `dxmt`, `dxvk`, `d3dmetal`, y `auto`, que elige uno.
- **Instalar:** `dxmt` y `dxvk` se bajan de GitHub con URL y SHA-256 fijados. `d3dmetal` lo importa quien usa la app, desde una carpeta suya; Bodega nunca lo descarga ni lo incluye.
- **Comprobar:** `bodega backend test` crea un dispositivo real con la sonda. Hace falta porque una copia mal hecha de D3DMetal carga, responde a `dxgi` y solo se cae al crear el dispositivo.
- **Elegir:** ajuste por botella, excepción por exe y opción puntual en `run`. Se guarda en `settings.json`.
- **Medir:** `run --hud` activa el contador de Metal.

## Fuera de alcance

- La app Flutter y la pantalla que explicará cómo instalar D3DMetal.
- vkd3d-proton, d9vk, MetalFX, DLSS, el shim de timestamps de Highball y otras variables `D3DM_*`.
- DXMT posterior a v0.80, y compilar backends en CI.
- Dependencias de juegos (vcredist, etc.) y base de datos de juegos.
- Afirmar "mejor que CrossOver": este cambio deja lo necesario para medirlo, y la comparación es U5.

## Impacto

- **`bodega/packages/engine`:**
  - `lib/backends.dart` nuevo;
  - `lib/probe_data.dart` generado (la sonda en base64, unos 170 KB);
  - cambios en `lib/engine.dart` y `bin/bodega.dart`;
  - `tool/probe.c` y `tool/build_probe.sh`;
  - tests.
- **En disco:** `$BODEGA_HOME/backends/{dxmt,dxvk,d3dmetal}/` y `bottles/<b>/settings.json`.
- **`bodega-engine`:** sin cambios. Sin gastar minutos de CI.

## Decisiones

| # | Duda | Decisión | Motivo |
|---|---|---|---|
| 1 | Copia de D3DMetal para probar | **La de tu Whisky** (sin descarga) o `renderer/d3dmetal` de la plantilla de Sikarugir | Las dos pasan la sonda con los enlaces conservados (`spike.md`, Corrección) |
| 2 | Carga sin `DYLD_*` | Layout `wine/` + `external/`, con cada `.so` como enlace a `libd3dshared.dylib` | Probado; respeta el diseño actual y evita el borrado de SIP |
| 3 | Ajustes | `bottles/<b>/settings.json`: backend y excepciones por exe | Lo que necesitará la interfaz |
| 4 | Auto | Busca texto en el exe, no solo imports: `d3d12.dll` → d3dmetal (64 bits) o wine; `d3d11`/`d3d10`/`dxgi` → dxmt; el resto → wine. Solo usa lo instalado | También ve las DLL cargadas dinámicamente. Tiene límites (launchers), y por eso siempre manda el ajuste manual |
| 5 | Versiones | DXMT v0.80 oficial y DXVK-macOS 1.10.3 | Ya compilados y probados; no gastan CI. Se puede actualizar en otro cambio |
| 6 | FPS | `run --hud` | Sin medir no hay comparación con CrossOver |
| 7 | Backend pedido y no instalado | Error con la instrucción para instalarlo; nunca cae en otro en silencio | Una elección manual no debe cambiar sin avisar |
| 8 | 32 bits con D3DMetal | Si DXMT está instalado, se encadena detrás | Lo hace Highball (`HB/Bottle.swift:61-63`); probado en `spike.md` (Corrección), lo repite T10 |
| 9 | Copiar de CrossOver | `import` rechaza rutas dentro de `CrossOver.app` | Regla del proyecto |

## Riesgos

- La sonda no presenta fotogramas: un backend puede pasarla y verse mal en un juego. Lo cierran U3–U5.
- D3DMetal 3.0 no tiene timestamp queries; algún juego DX12 puede fallar (`HB/Bottle.swift:51-59`).
- `auto` se equivoca con launchers y con exes que no mencionan D3D.
- Licencia de Apple (`exploration.md` §7): decisión ya tomada por el usuario. Si la app se publica algún día, hay que revisarlo.
- Solo Warframe parece servir para DX11/DX12 en este Mac, y añade su launcher.
