# Tareas: interfaz-botellas

**Convenciones.** `P` = `packages/engine`; `A` = `apps/bodega`. **(USUARIO)**: lo haces tú. El agente no hace commit ni push. Tras cada hito: `dart run build_runner build`, `flutter analyze`, `flutter test` y `tool/check_layers.sh` en `A`, y `dart analyze` y `dart test` en `P`.

## Hito 1: varias aplicaciones y pantalla principal
- [x] **T1** `apps.json` y migración (M1), clave (M2), `addApp`, `hideApp`, `openApp` y `listBottles` (M6), con el CLI.
  **Comprobación:** tests de M1, M2 y M6. En una copia de `steam` en `BODEGA_HOME` temporal, `bodega apps` y `open` dan lo de antes.
- [x] **T2** `readLnk` (M3), detección (M4), juegos de Steam (M5) e iconos (M7).
  **Comprobación:** sus tests, y un test temporal contra tu `steam` y tu `Blur.exe`: Steam, Muck e iconos.
- [x] **T3** Domain, data y `LibraryBloc`: aplicaciones por botella, abrir por clave (V5, V6), con el catálogo y agregar adaptados (V7).
  **Comprobación:** tests de `LibraryBloc`, `CatalogRepository` y `AddAppBloc`.
- [x] **T4** `SideBar` con botellas (V1) y rutas (V2). Ventana de 1150×800.
  **Comprobación:** tests de `SideBar` y `router`.
- [x] **T5** Pantalla de botella (V3), `AppTile` y `AppIcon` (V4), logs en diálogo. Biblioteca (V5).
  **Comprobación:** tests de widget y `pages_test.dart` a los 4 anchos.
- [ ] **T6 (USUARIO)** Commit del hito 1 con el script que deja el agente, y `flutter run -d macos`. **Se espera:** `steam` con Steam y Muck y sus iconos; `games` con su aplicación; Biblioteca con las de todas. **Prueba U1 a U4.**

## Hito 2: ajustes y opciones
- [ ] **T7** Ajustes (M8), alta resolución (M9), versión de Windows (M10), lanzar con opciones (M11) e instalar en existente (M12).
  **Comprobación:** sus tests; y en una botella temporal real, sin ventana, `winecfg -v` responde lo puesto y `reg query` devuelve `RetinaMode` y `LogPixels`.
- [ ] **T8** Acciones (V8), configuración avanzada (V9) y paneles de control (V10).
  **Comprobación:** tests de `BottleDetailBloc` y de widget; `pages_test.dart`.
- [ ] **T9** Ejecutar con opciones (V11) e instalar con opciones (V12).
  **Comprobación:** tests de `RunOptionsBloc` e `InstallBloc`; `pages_test.dart`.
- [ ] **T10 (USUARIO)** Commit del hito 2, y **prueba U5 a U8.**

## Hito 3: gestión
- [ ] **T11** Duplicar y renombrar (M13), exportar e importar (M14), caché (M15).
  **Comprobación:** sus tests; y con una botella temporal real, sin ventana, un programa corre en la copia, en la renombrada y en la importada, y `z:` sigue siendo un enlace.
- [ ] **T12** Nueva botella e importar (V13), duplicar, renombrar y exportar (V14), Preferencias (V15).
  **Comprobación:** tests de `NewBottleBloc`, `BottleDetailBloc` y `PreferencesBloc`; `pages_test.dart`.
- [ ] **T13** `.claude/CLAUDE.md` y `rules/`: qué se toma de CrossOver, las clases nuevas y `AppTile`.
  **Comprobación:** existen esos textos, y `check_layers.sh` pasa.
- [ ] **T14** Compilación final: `flutter build macos`, abrirla con `open` en una carpeta temporal y confirmar que arranca y llama al motor, como en `app-flutter`.
  **Comprobación:** salida pegada en `verify`. El agente no juzga cómo se ve.
- [ ] **T15 (USUARIO)** Commit final con el script que deja el agente, y **prueba U9 a U11.**

## Aceptación del usuario
En tu Mac, con `flutter run -d macos`.

- [ ] **U1** Barra lateral: Biblioteca, Instalar, tus botellas y Backends. Estrecha la ventana. **Se espera:** a menos de 800 px, solo iconos; sin desbordes.
- [ ] **U2** Abre `steam` y luego `games`. **Se espera:** iconos reales de Steam, Muck y Blur. Doble clic en Blur abre; un clic no.
- [ ] **U3** Doble clic en Muck. **Se espera:** Steam lo lanza. Si no, dime qué hace. **Es lo más incierto del hito.**
- [ ] **U4** Oculta algo y vuelve a entrar; abre otra aplicación con la botella ya abierta. **Se espera:** no vuelve a salir, y `Abierta` hasta que todo se cierre.
- [ ] **U5** Instala Rockstar en una botella nueva, y otra aplicación del catálogo en una existente, si quieres. **Se espera:** progreso real, cancelar, y aparece en su botella. Es la U3 pendiente de `app-flutter`.
- [ ] **U6** Abre unidad C:, terminal y cada panel de control. **Se espera:** abren.
- [ ] **U7** `Ejecutar con opciones` en Muck, con HUD. **Se espera:** contador en pantalla. Si no sale, el interruptor se quita.
- [ ] **U8** En una botella de prueba: alta resolución y versión de Windows. **Se espera:** avisa antes de cerrar, se ve nítido y `winver` lo confirma.
- [ ] **U9** Crea una botella, duplícala, renómbrala y bórrala. **Se espera:** avisa, y cada una funciona.
- [ ] **U10** Exporta una e impórtala. **Se espera:** aparece y abre.
- [ ] **U11** Preferencias: carpeta, caché y tema. **Se espera:** `Vaciar` deja en cero. Dime qué mejorarías del aspecto.
