# Tareas · d3dmetal-y-backends

## Hito A · Gráficos del exe
- [x] T1 Motor: `exeGraphics(path)` en `backends.dart` (isolate), `autoBackend` de
  Mac la reusa. Tests: PE sintéticos DX9/32 (con `d3d10`), DX12/64, no-PE; Blur sigue en wine.
- [x] T2 Motor: `Platform.backendFits` (tabla G3 en Mac, siempre sí en Linux) y
  `backendUse(name)` ("Sirve para…"). Tests Mac y Linux simulado.
- [x] T3 App datos/dominio: entidad `ExeGraphics` (bits, directx, label, misfits),
  `BackendRepository.graphics(exes)`, `BackendInfo.use`. `tool/check_layers.sh` limpio.
- [x] T4 App: `GraphicsBloc` (load, caché) + bloc_test.
- [x] T5 App: etiqueta en `AppCard`/`AppRow` (no en `steam.exe`); aviso en `bottle_column`
  y en `run_options_dialog`; línea "Sirve para…" en `backend_card`. Widget tests.

## Hito B · Instalar D3DMetal
- [x] T6 **U (usuario)**: bajar `Game_Porting_Toolkit_3.0.dmg` de Apple. Yo miro el dmg real
  (nombres, dmg de dentro, licencia, `redist/lib`, `Info.plist`) antes de escribir T8.
  Si algo no cuadra con el spec, paro y corrijo el spec. T8 se hizo antes con la
  estructura documentada. Con el dmg real (`Game_Porting_Toolkit_4.0_beta_3.dmg`): el de
  fuera no tiene licencia y trae `Evaluation environment for Windows games 4.0 beta 3.dmg`
  (con licencia) junto a samples y `.pkg`. Lo de dentro (`redist/lib`) lo confirma U2 al
  aceptar la licencia. Recién bajado, `hdiutil` da "Resource busy" unos segundos: se reintenta.
- [x] T7 Motor: `gptkReleases`, `findGptkDmg(version, dir)`, `d3dmetalVersion(home)`. Tests.
- [x] T8 Motor: `installD3DMetalDmg(home, dmg)` (montar, `open` del de dentro, esperar
  volumen, importar, desmontar siempre). Test Mac con un dmg hecho con `hdiutil create`.
- [x] T9 App: tarjeta de D3DMetal con versión instalada + lista + Instalar / Esperando /
  elegir dmg / Cancelar; Comprobar al acabar. Borrar `d3dmetal_instructions.dart`.
  `NSDownloadsFolderUsageDescription`. bloc_test + widget test.

## Extra (pedido en apply)
- [-] E1 Detectar con Spotlight los tarballs del motor y de dxmt/dxvk. **Descartado**: la
  app de la release ya trae el motor dentro (`Resources/bundle`), y abierta desde Finder
  macOS no le deja ver Documentos. La pantalla de motor solo sale en builds de debug.
- [x] E2 Icono de la app: `assets/images/logo.png` en los 7 tamaños de `AppIcon.appiconset`
  (Mac). Los paquetes de Linux (deb, AppImage, Arch) ya toman `app_icon_512.png` de ahí.

## Cierre
- [x] T10 `dart analyze && dart test` (motor), `flutter analyze && flutter test &&
  tool/check_layers.sh` (app), build macOS.
- [ ] U1 Blur: etiqueta `DX9 · 32 bits`; botella en d3dmetal → aviso; Automático → sin aviso.
- [x] U2 Instalar desde la tarjeta con el dmg real → licencia → importado. Hecho con 4.0 beta 3
  (queda 4.0b3). Falta Comprobar con una botella (Blur estaba abierto en verify).
