# Versionado automático y workflows de instalables

Versión actual: 1.0.0 (`apps/bodega/pubspec.yaml`, línea `version: 1.0.0+1`). Con este trabajo no cambia.

Regla de entrega: no se prueba nada de macOS (no hay Mac). Lo de macOS se escribe por lectura.

## Flujo

```
push a main ──► tag-version ──► crea vX.Y.Z (solo si no existe)
                                      │
  release-linux (a mano, tag=vX.Y.Z)        release-macos (a mano, tag=vX.Y.Z)
   build   -> .deb, .tar.gz, AppImage         resolve -> engine-* y hostlibs-* de este repo
   release -> sube a la release vX.Y.Z         (opcional: construirlos antes)
                                               package -> Bodega-X.Y.Z-macos-arm64.dmg
                                               release -> sube a la release vX.Y.Z
```

## Requisitos (EARS)

| ID | Requisito |
|---|---|
| R1 | Cuando llegue un push a `main` y la versión de `apps/bodega/pubspec.yaml` no tenga etiqueta `vX.Y.Z`, `tag-version` creará esa etiqueta anotada sobre ese commit. Si ya existe, no hará nada. Solo se dispara con push a `main`. |
| R2 | `release-linux` y `release-macos` se lanzarán solo a mano con un input `tag`. Harán checkout de esa etiqueta y rechazarán una que no sea `vX.Y.Z` o que no esté en el historial de `main`. |
| R3 | `release-macos` generará `Bodega-X.Y.Z-macos-arm64.dmg` con `Bodega.app` (arm64, firma ad hoc) que lleva dentro Wine, hostlibs, DXMT, DXVK, SDL2 y la CLI. |
| R4 | En el primer arranque en macOS la app registrará el runtime y las capas incluidos copiándolos a `~/Library/Application Support/Bodega` y quitando la cuarentena, de modo que no aparezca la pantalla de Setup (Rosetta se sigue comprobando). |
| R5 | `release-macos` tomará motor y hostlibs de releases de este repo (`engine-*` y `hostlibs-*`, por tag explícito o el más reciente) y podrá construirlos antes con `build_engine` y `build_hostlibs` (apagados por defecto). |
| R6 | `release-linux` generará `Bodega-X.Y.Z-linux-amd64.deb`, `Bodega-X.Y.Z-linux-x86_64.tar.gz` y `Bodega-X.Y.Z-linux-x86_64.AppImage`. |
| R7 | El job `release` de cada workflow creará la release `vX.Y.Z` si falta (notas generadas) y subirá sus archivos, sustituyendo los del mismo nombre. |
| R8 | `tool/package_macos.sh` construirá el DMG en local con las mismas piezas (archivos locales o descargados de las releases). El workflow lo llama. |
| R9 | `tool/version.sh` tendrá `get`, `bump patch\|minor\|major` y `check`. |
| R10 | La skill `bump-version` y `AGENTS.md` exigirán subir la versión con cada fix (patch), update o feature (minor) y cambio incompatible (major), y correr `tool/version.sh check` antes de cada commit. Queda prohibido crear etiquetas a mano. |
| R11 | La versión sigue en 1.0.0 con este trabajo. |
| R12 | El error del motor que apunta a `dany021115/bodega-engine` apuntará a las releases de este repo. |

## Criterios de aceptación

Estáticos (se comprueban sin Flutter ni Mac):

- S1: `bash -n` de todos los scripts y `apps/bodega/tool/check_layers.sh`.
- S2: los workflows son YAML válido. `tag-version` solo tiene `push` con `branches: [main]`. Los `release-*` solo `workflow_dispatch`. `build.yml` y `build-hostlibs.yml` conservan `workflow_dispatch` y suman `workflow_call`.
- S3: `tool/version.sh get` imprime `1.0.0`; `check` sale con 0 sin etiquetas; `bump` sobre una copia temporal reinicia los números menores.
- S4: `git tag` solo aparece en `tag-version.yml`, `AGENTS.md` y la skill.
- S5: los nombres de los instalables llevan versión y sistema.

Manuales (los corre el usuario): ejecutar los workflows; abrir el `.dmg` en un Mac y comprobar que no sale Setup.

## tool/version.sh

Archivo de versión: `apps/bodega/pubspec.yaml`, línea `version: X.Y.Z+N`.

- `get`: imprime `X.Y.Z`.
- `bump patch|minor|major`: base = versión de la última etiqueta `vX.Y.Z` (`git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*'`). Objetivo = base subida en ese nivel (patch: `x.y.z+1`; minor: `x.y+1.0`; major: `x+1.0.0`). Si la versión actual ya es mayor o igual que el objetivo, no cambia nada y lo dice. Si no, escribe el objetivo y sube `N` en uno. Sin etiquetas, la versión actual aún no se ha publicado: no cambia nada y lo dice. Así se sube una sola vez por entrega, con el nivel más alto necesario.
- `check`: sin etiquetas, sale con 0. Con etiqueta: si la versión es menor que la de la etiqueta, falla; si es igual y hay cambios de producto desde la etiqueta (archivos modificados respecto a la etiqueta o sin seguimiento, que no sean `.sdd/`, `.claude/`, `AGENTS.md` ni `*.md`), falla con el mensaje de qué hacer (`tool/version.sh bump <nivel>`); si es mayor, sale con 0.

Niveles: patch = corrección de un fallo; minor = función nueva o mejora; major = cambio incompatible (formato de datos o de botellas, función eliminada).

## Workflows

Todos los `release-*` y `tag-version` van en `.github/workflows/`.

`tag-version.yml`: `on: push: branches: [main]`, `permissions: contents: write`, `concurrency: tag-version`. Un job en `ubuntu-24.04`: checkout con `fetch-depth: 0`, `ver=$(tool/version.sh get)`, `tag=v$ver`; si existe `refs/tags/$tag`, termina; si no, `git tag -a "$tag" -m "Bodega $ver" "$GITHUB_SHA"` y `git push origin "refs/tags/$tag"` con identidad `github-actions[bot]`. Con `if: github.ref == 'refs/heads/main'`.

`release-linux.yml` (sustituye a `package-linux.yml`): `on: workflow_dispatch` con input `tag` (obligatorio). Jobs: `build` (ubuntu-24.04) comprueba la etiqueta, hace checkout de ella, instala dependencias, corre `tool/package_linux.sh` y sube `dist/*` como artefacto; `release` (needs build) descarga el artefacto y hace `gh release view "$TAG" || gh release create "$TAG" --title "Bodega ${TAG#v}" --generate-notes` y `gh release upload "$TAG" dist/* --clobber`.

`release-macos.yml`: `on: workflow_dispatch` con inputs `tag` (obligatorio), `engine_tag` y `hostlibs_tag` (vacío = la release más reciente cuyo tag empieza por `engine-` o `hostlibs-` en este repo), `build_engine` y `build_hostlibs` (booleanos, por defecto false). Jobs: `engine` (si `build_engine`) y `hostlibs` (si `build_hostlibs`) llaman a `build.yml` y `build-hostlibs.yml` con `workflow_call` y `publish_release: true`; `package` (runner `macos-15`, arm64; necesita a los anteriores con `if: always() && !failure() && !cancelled()`) comprueba la etiqueta, hace checkout, instala Rosetta (`softwareupdate --install-rosetta --agree-to-license`) y Flutter 3.47.x, resuelve los tags, y corre `tool/package_macos.sh`; `release` igual que en Linux. Si no hay release `engine-*` o `hostlibs-*` y los inputs de construcción están apagados, `package` falla con un mensaje que dice qué lanzar.

Validación de la etiqueta en ambos (job inicial): coincide con `^v[0-9]+\.[0-9]+\.[0-9]+$`, existe, y `git merge-base --is-ancestor "$tag" origin/main`.

`build.yml` y `build-hostlibs.yml`: añaden `workflow_call` con los mismos inputs (`publish_release`, `ref_note`) y sustituyen `github.event.inputs.X` por `inputs.X`.

## macOS: contenido del DMG y arranque

DMG (`hdiutil create -format UDZO`): `Bodega.app` y un enlace a `/Applications`. Nombre: `Bodega-X.Y.Z-macos-arm64.dmg`.

Dentro de la app: `Contents/MacOS/bodega-cli` (la CLI), y `Contents/Resources/bundle/` con la misma estructura que el paquete de Linux: `runtime/<id>/{engine,renderers?,frameworks?,...}` (lo que produce `bodega install`) y `backends/<name>/wine` (dxmt y dxvk).

`tool/package_macos.sh`: compila la app (`flutter build macos --release`, tras `pub get` y `build_runner`) y la CLI (`dart compile exe`); crea un `BODEGA_HOME` temporal y lo siembra con la propia CLI: `bodega install <engine> <hostlibs>`, `bodega sdl install`, `bodega backend install dxmt`, `bodega backend install dxvk`; copia `runtimes/*` a `bundle/runtime/` y `backends/*` a `bundle/backends/`; firma ad hoc (`codesign --force --deep --sign -`); crea el DMG en `dist/`. Los tarballs vienen de `--engine`/`--hostlibs` (archivos locales con su `.sha256` al lado) o, si no se pasan, de `gh release download` con `--engine-tag`/`--hostlibs-tag` (o la más reciente `engine-*`/`hostlibs-*`).

Primer arranque (`MacPlatform.prepareHome`): raíz = `$BODEGA_BUNDLE` o `Contents/Resources/bundle` (dos niveles sobre el ejecutable: `File(Platform.resolvedExecutable).parent.parent.path + '/Resources/bundle'`). Se reutiliza el registro de lo incluido de Linux con `copy: true` siempre, y tras copiar cada carpeta se quita la cuarentena con `xattr -dr com.apple.quarantine` (si `xattr` no existe, se ignora). La copia es síncrona, una sola vez, y tarda unos segundos.

Constructor de prueba: `LinuxPlatform({mangoHud, bundle})` y `MacPlatform({bundle})`; `bundle` sustituye a la detección por entorno y ejecutable.

## Nombres de archivo (Linux)

`tool/package_linux.sh` produce `Bodega-X.Y.Z-linux-amd64.deb`, `Bodega-X.Y.Z-linux-x86_64.tar.gz` y `Bodega-X.Y.Z-linux-x86_64.AppImage` (antes `bodega_X.Y.Z_amd64.deb`, `bodega-X.Y.Z-linux-x86_64.tar.gz`, `Bodega-X.Y.Z-x86_64.AppImage`). El README de Linux se actualiza con los nombres nuevos.
