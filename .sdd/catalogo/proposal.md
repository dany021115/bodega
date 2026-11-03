# Propuesta: catalogo

## Por qué

El usuario quiere instalar aplicaciones desde una lista, como en "Install a Windows Application" de CrossOver. Hoy Bodega solo lanza un `.exe` que ya existe, sin saber instalar ni recordar qué hay instalado. Además, el DXMT oficial no incluye la opción que necesitan los launchers con Chromium.

## Qué

- **Catálogo** dentro del motor, con 7 aplicaciones (datos abiertos de `highball-db`, CC0): Steam, Rockstar, EA app, Ubisoft Connect, Battle.net, Epic y GOG Galaxy.
- **Estado honesto** en vez de estrellas: `tested` (probado por ti), `reported` (reportado), `untested` (sin probar) y `blocked` (bloqueado, no se instala).
- **Instalar:** `bodega catalog install <id>` baja el instalador oficial, crea una botella para esa aplicación, aplica sus ajustes, ejecuta el instalador, comprueba el resultado y la añade a la biblioteca.
- **Biblioteca y lanzar:** `bodega apps` y `bodega open <botella>`.
- **Ajustes que faltan:** msync por botella, variables por programa y registro.
- **DXMT parcheado:** el backend `dxmt` pasa a ser el fork de Highball, con la opción entre procesos activada.
- **Arreglo de `auto`:** Blur, que es D3D9, iba a DXMT porque su binario menciona `d3d10` y `dxgi.dll`.

## Fuera de alcance

- La app Flutter, iconos y pantallas (cambio `app-flutter`).
- Las 44 recetas y 737 fichas de juegos; `legendary` e instaladores offline de GOG; winetricks.
- "Instalar otra aplicación": ya se puede con `create` + `run`; la app lo envolverá.
- msync por programa, catálogo por red y desinstalar (hoy, `stop` + `rm -rf`).

## Impacto

- **`bodega/packages/engine`:**
  - nuevos: `lib/catalog.dart`, `lib/catalog_data.dart` (el JSON como texto Dart, porque `dart compile exe` no lleva archivos) y `test/catalog_test.dart`;
  - cambian: `lib/backends.dart`, `lib/engine.dart` y `bin/bodega.dart`.
- **En disco:** `bottles/<b>/app.json`, `settings.json` con `sync` y `env`, y `downloads/`.
- **`bodega-engine`:** sin cambios. Sin minutos de CI.
- **`Bodega/runtimes/terceros/`:** ya tiene el tarball del fork de DXMT.
- **Instalación real del usuario:** hay que reinstalar `dxmt` (U1).

## Decisiones

| # | Duda | Decisión | Motivo |
|---|---|---|---|
| 1 | Dónde va el catálogo | JSON dentro de la app | Las recetas deciden qué se descarga y ejecuta; bajarlas de la red exigiría firmarlas |
| 2 | Primera lista | Las 7, con Epic y GOG Galaxy en `blocked` | Igual que la pantalla de referencia, sin prometer lo que no funciona |
| 3 | Valoración | Cuatro estados, con su nota y fuente | Sin estrellas inventadas |
| 4 | Botellas | Una por aplicación, con el `id` como nombre | Aísla fallos y ajustes; cada una ocupa unos 540 MB (medido en `prueba`) |
| 5 | DXMT | Sustituir el oficial por el fork, no un backend aparte | Pasa la sonda en 32 y 64 bits, con y sin msync (`design.md` §6). Un backend más solo confundiría. Falta confirmarlo con Blur (U2) |
| 6 | msync | Por botella; cambiarlo para la botella | Modo mezclado = salida 1 (medido). **Coste:** los juegos abiertos desde la botella de Steam van sin msync; Highball reporta ~40 % menos FPS |
| 7 | Formato | Plano, no la lista de pasos de Highball | Las 7 solo necesitan registro → instalador → ejecutable. Más corto y fácil de mostrar |
| 8 | Instalador | Siempre con `wine`, sin capas; códigos válidos 0, 102, 194 y 105 | Lo hace Highball; esos tres son 1638, 3010 y 1641 truncados a 8 bits (`HB/Recipe.swift:154-156`) |
| 9 | Restos del instalador | Esperar a que el servidor termine; si el `.exe` ya está, 60 s como mucho; 30 min en total. Luego `-k` | Battle.net y Rockstar dejan servicios con el entorno de instalación (`HB/Recipe.swift:586-597`). Sin el reinicio, el primer arranque hereda ese entorno |
| 10 | Descargas | Solo HTTPS, también en redirecciones; SHA-256 si la entrada lo fija; aviso si no | 6 de los 7 enlaces cambian y no admiten SHA fijo |
| 11 | Prueba decisiva | Steam con tu cuenta (U3), ejecutada por ti | Los agentes no ejecutan instaladores descargados: el modo automático lo bloqueó, y hay que ver ventanas e iniciar sesión |

## Riesgos

- **Ningún launcher se ha probado en Bodega.** Los estados `reported` vienen de Highball, sobre sus builds, y nuestro DXVK no es el suyo.
- **Fork de DXMT:** es un binario de un tercero con pocos usuarios y una sola persona detrás. Se fija por SHA-256, sin compilarlo nosotros. Licencia LGPL, según la exploración previa (`02-graphics.md`).
- **Instaladores sin checksum:** solo protege HTTPS y el dominio oficial.
- **`dxvk`, requisito de Rockstar y Epic:** versión 1.10.3, distinta a la de Highball.
- **Si Steam falla en U3:** este cambio queda útil como motor, pero hay que revisar las rutas de launchers (`INFORME-FINAL.md` §7.2) antes de seguir con la app.
