# Tareas: app-flutter

**Convenciones.** `P` = `packages/engine`; `A` = `apps/bodega`. **(USUARIO)**: lo haces tú. El agente no hace commit ni push. Tras cada hito: `dart run build_runner build`, `flutter analyze` y `flutter test` en `A`, y `dart test` en `P`.

## Hito 1: base
- [x] **T1** Workspace (E1): raíz, `resolution: workspace`, `flutter create`, sin sandbox, ventana (B1), `.gitignore` y `build.yaml` (B7).
  **Comprobación:** `dart test` en `P`; `dart compile exe`; `flutter build macos --debug`.
- [x] **T2** Motor: E2–E9, con sus tests.
  **Comprobación:** `dart test` en `P`; `build/bodega catalog list` sigue igual.
- [x] **T3** `device/`: tema (B3), router sin pantallas (B4) y `AppToast` (B6). `di.dart` (B7), `AppError` (B6), breakpoints (B5) y `spider` con los 7 SVG (B8). `ThemeBloc`.
  **Comprobación:** test `ThemeBloc`; `flutter analyze`.
- [x] **T4** `MainShell` con barra lateral (B5) y `SetupBloc` con su pantalla (P1), con `Runtime` en `domain` y `data`. Redirección (B4).
  **Comprobación:** tests `SetupBloc`, `router` y de widget `MainShell`.
- [ ] **T5 (USUARIO)** Commit del hito 1 con el script que deja el agente, y abre la app: `flutter run -d macos`. **Se espera:** barra lateral, tema oscuro, y que al estrechar la ventana pase a iconos.

## Hito 2: catálogo y biblioteca
- [ ] **T6** `Catalog`: entidades, repositorio, `CatalogBloc`, lista y ficha (P2, P3).
  **Comprobación:** test `CatalogBloc`.
- [ ] **T7** `Install`: descarga con `dio`, `InstallBloc` y progreso (P4; `design.md` §4).
  **Comprobación:** test `InstallBloc`; test de repositorio con un servidor HTTP local: progreso, cancelar y `Range`.
- [ ] **T8** `Library`: `LibraryBloc`, abierta o cerrada, avisos y pantalla (P6–P8; `design.md` §5).
  **Comprobación:** test `LibraryBloc`.
- [ ] **T9** `AntiCheat`: `RestClient`, DTO, caché y sección en el catálogo (P5).
  **Comprobación:** test `AntiCheatRepository`.
- [ ] **T10 (USUARIO)** Commit del hito 2, y abre la app. **Se espera:** ves tu Steam, lo abres y lo paras desde la Biblioteca; el Catálogo busca y muestra fichas.

## Hito 3: botellas, backends y otra aplicación
- [ ] **T11** `Bottle`: lista y detalle (P10, P11).
  **Comprobación:** test `BottleDetailBloc`.
- [ ] **T12** `Backend`: lista, instalar, D3DMetal y comprobar (P12–P14).
  **Comprobación:** test `BackendsBloc`.
- [ ] **T13** Agregar otra aplicación (P9).
  **Comprobación:** test `AddAppBloc`.
- [ ] **T14** `.claude/CLAUDE.md` y `rules/` (B9).
  **Comprobación:** existen y nombran las versiones y las reglas de capas.

## Cierre
- [ ] **T15** Comprobación de capas (B2) con un script en `tool/check_layers.sh`, que falla si se rompe una regla.
  **Comprobación:** pasa; y falla si se añade a propósito un import prohibido, en una copia temporal.
- [ ] **T16** Compilación final: `flutter build macos`, abrirla con `open` y confirmar en un log temporal que arranca.
  **Comprobación:** salida pegada en `verify`. El agente no juzga cómo se ve.
- [ ] **T17 (USUARIO)** Commit final con el script que deja el agente.

## Aceptación del usuario
En tu Mac, con `flutter run -d macos` o la app compilada.

- [ ] **U1** Biblioteca: Steam aparece; ábrelo y párala. **Se espera:** `Abierta` hasta que se cierra de verdad, también si Steam se actualiza. Unos 3 s de retraso son normales.
- [ ] **U2** Catálogo: busca, abre fichas y comprueba los estados. **Se espera:** Epic y GOG no se pueden instalar.
- [ ] **U3** Instala una aplicación nueva, por ejemplo Rockstar. **Se espera:** barra de progreso real, botón de cancelar durante la descarga, y que siga aunque cambies de pantalla. Si Rockstar falla, debe verse el motivo y poder borrar la botella.
- [ ] **U4** Cancela una descarga. **Se espera:** no queda botella.
- [ ] **U5** Agregar otra aplicación con Blur, en una botella nueva o en `prueba`, y ábrelo. **Se espera:** aparece en Biblioteca y abre.
- [ ] **U6** Botellas: cambia el backend de una, cambia msync, mira un log y borra una botella de prueba. **Se espera:** aviso antes de cerrar o borrar.
- [ ] **U7** Backends: lee las instrucciones de D3DMetal y pulsa `Comprobar` en una botella cerrada. **Se espera:** `OK` por caso.
- [ ] **U8** Abre un juego con anti-cheat si tienes alguno. **Se espera:** aviso claro, sin bloquear la interfaz.
- [ ] **U9** General: cierra Bodega con un juego abierto y vuelve a abrirla. **Se espera:** el juego sigue y aparece `Abierta`. Dime qué mejorarías del aspecto.
