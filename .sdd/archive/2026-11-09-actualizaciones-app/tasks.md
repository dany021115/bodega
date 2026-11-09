# Tareas · actualizaciones-app

## Publicar
- [x] T1 Paso "Publish to bodega-releases" en `release-macos.yml` y `release-linux.yml`
  (crear release con notas copiadas, subir archivos y `wine-src.tar.gz`; sin
  `RELEASES_TOKEN`, aviso). Comprobación: `actionlint` si está, y lectura del YAML.
- [ ] T2 **U (usuario)**: ~~crear `dany021115/bodega-releases` público~~ (hecho con `gh`, aprobado);
  falta crear el token fine-grained y guardarlo como `RELEASES_TOKEN`.

## App
- [x] T3 Motor: `sha256Of(path)` público (lo que era `_sha256`). Test. Test de A5: arrancar
  con un bundle nuevo conserva botellas, `backends/d3dmetal` y `runtimes/current`.
- [x] T4 Dominio + datos: `AppUpdate`, `UpdateRepository`, `UpdateRepositoryImpl.check`
  (API, SemVer, 24 h, versión saltada, plataforma). Tests con `dio` falso: mayor, igual,
  menor, 404, sin red, saltada, 24 h, Linux sin AppImage.
- [x] T5 Datos: `download` (Downloader + SHA256SUMS + comprobación) e `install` (macOS: dmg
  → `.Bodega-update.app` + script; AppImage: rename). Tests: SHA que no cuadra; dmg de
  prueba con `hdiutil create` (Mac) deja la app nueva y el script, nada montado, y la
  carpeta de datos intacta (A5).
- [x] T6 `UpdateBloc` (check al arrancar, skip, download con progreso, cancel, install) +
  bloc_test.
- [x] T7 `UpdateDialog` + listener en `ShellBody`; check al arrancar en `main.dart` solo con
  `kReleaseMode`. Widget test del modal (instalable, solo aviso, progreso, error).
- [x] T8 `dart analyze && dart test`, `flutter analyze && flutter test &&
  tool/check_layers.sh`, build macOS. Marcar T11/T16 de `.sdd/mejoras-releases` como
  sustituidas.
- [ ] U1 (usuario) Con la primera release pública: una app más vieja instalada avisa, se
  actualiza y abre la nueva.
