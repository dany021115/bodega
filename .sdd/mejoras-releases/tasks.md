# Tareas: mejoras de releases y experiencia

Estado: **plan sin aprobar**. El orden de abajo es una propuesta; cambia al decidir (decisión 1 de `proposal.md`).

Convenciones: cada PR sube la versión (`tool/version.sh bump patch|minor`) y no pasa de ~400 líneas; si una tarea pasa, se parte. Las pruebas de workflows se hacen en un tag real o en un fork. El agente no hace commit ni push sin que lo apruebes.

## Olas

| Ola | PR | Mejoras | Depende de | Tamaño | Versión |
|---|---|---|---|---|---|
| 1 | P1 | M1 guarda de portabilidad | — | pequeño | patch |
| 1 | P2 | M2 `SHA256SUMS` y attestations | — | pequeño | patch |
| 2 | P3 | M3 prueba de humo (Linux) | P1 | medio | patch |
| 2 | P4 | M3 prueba de humo (macOS) | — | pequeño | patch |
| 3 | P5 | M4 release encadenado + `AGENTS.md` | P3 | pequeño | patch |
| 3 | P6 | M5 revisión automática de versiones | — | medio | patch |
| 4 | P7 | M6 arreglos por juego: datos y motor | — | medio | minor |
| 4 | P8 | M6 arreglos por juego: CLI `fix show` y app | P7 | medio | minor |
| 5 | P9 | M7 dependencias de Windows (motor y CLI) | P7 | medio | minor |
| 5 | P10 | M7 dependencias de Windows (app) | P9 | medio | minor |
| 6 | P11 | M8 fase 1: aviso de versión nueva | — | medio | minor |
| 6 | P12 | M9 `PKGBUILD` del AUR | P2 | pequeño | patch |
| 7 | P13 | M10 Developer ID y notarización | cuenta Apple | medio | minor |
| 7 | P14 | M8 fase 2: Sparkle en macOS | P13 | medio | minor |

P1 y P2 son independientes y se pueden hacer a la vez. P7 a P11 no dependen de los releases y se pueden mover antes si se prefiere avanzar en producto.

## P1. Guarda de portabilidad

- [x] **T1** `tool/check_isa.sh`, llamada desde `tool/package_linux.sh` tras copiar el bundle al stage: revisa `readelf -n` de `bodega`, `bodega-cli` y las `.so`, y falla con mensaje claro si piden v3 o v4. `BODEGA_ALLOW_NATIVE=1` la salta.
  **Comprobación (hecha):** en CachyOS el bundle real falla con el mensaje y con `BODEGA_ALLOW_NATIVE=1` pasa; con un `readelf` simulado, `baseline, v2` pasa y `baseline…v3` falla. Dato nuevo: en CachyOS hasta un `gcc -march=x86-64` sale con v4, así que la causa son los objetos del sistema, no las banderas. En un contenedor `ubuntu:24.04` un binario sale con `x86 ISA needed: x86-64-baseline` y la guarda pasa. Documentado en `packaging/linux/README.md`.

## P2. SHA256SUMS y procedencia

- [ ] **T2** En el job `release` de `release-linux.yml` y de `release-macos.yml`: generar `SHA256SUMS` en `dist/`, subirlo, y añadir `actions/attest-build-provenance` con los permisos `id-token` y `attestations`.
  **Comprobación:** en un release real, `sha256sum -c SHA256SUMS` pasa y `gh attestation verify` valida un archivo.

## P3 y P4. Prueba de humo

- [ ] **T3 (P3)** Job `smoke` en `release-linux.yml` para `.deb` (Ubuntu limpio), `.pkg.tar.zst` (`archlinux`) y AppImage, antes de `release`.
  **Comprobación:** con un paquete roto a propósito, el job falla y no se publica; con uno bueno, pasa.
- [ ] **T4 (P4)** Job `smoke` en `release-macos.yml`: montar el DMG y ejecutar `bodega-cli --help` y `bodega create prueba`.
  **Comprobación:** igual que T3.

## P5. Release encadenado

- [ ] **T5** En `tag-version.yml`, tras crear el tag, `gh workflow run release-linux.yml --ref "$tag"` (el release se construye con el tag desde el que corre, ya no hay input `tag`), con `permissions: actions: write`. Actualizar `AGENTS.md`.
  **Comprobación:** un merge a `main` con versión nueva crea el tag y lanza `release-linux` sin tocar nada; un merge sin versión nueva no lanza nada.

## P6. Revisión automática de versiones

- [ ] **T6** `tool/check_assets.sh` y `.github/workflows/check-versions.yml` (semanal y manual), que abren una PR con el `assets.json` actualizado.
  **Comprobación:** con un `assets.json` de versión vieja inventada, abre la PR con el sha256 correcto; con todo al día, no abre nada.

## P7 y P8. Arreglos por juego

- [ ] **T7 (P7)** `packages/engine/data/fixes.json`, su generador y `fixes_data.dart`; la mezcla en `createBottle` y `_launchIn` con la precedencia del diseño.
  **Comprobación:** tests de precedencia (el ajuste del usuario gana) y de plataforma (una entrada de otra plataforma no se aplica).
- [ ] **T8 (P8)** `bodega fix show` y, en la app, una nota "Arreglos aplicados" en la pantalla de la botella.
  **Comprobación:** tests del repositorio y de widget; `pages_test.dart` a los 4 anchos.

## P9 y P10. Dependencias de Windows

- [ ] **T9 (P9)** `winetricks` en el paquete (con sha256 en `assets.json`), la lista permitida de verbos y `bodega deps install`. Solo en procesos sin ventana.
  **Comprobación:** en una botella temporal real y sin ventana, `deps install <b> corefonts` deja la marca en `settings.json` y un log. Un verbo fuera de la lista se rechaza.
- [ ] **T10 (P10)** Pantalla de dependencias en la botella, con confirmación y origen de la descarga.
  **Comprobación:** tests de bloc y de widget.

## P11. Aviso de versión nueva

- [ ] **T11** Servicio en `data/`, estado en `domain/`, aviso en `app/`. Una consulta por sesión; sin red no muestra nada.
  **Comprobación:** tests con cliente falso (mayor, igual, error); `flutter analyze` y `check_layers.sh` pasan.

## P12. AUR

- [ ] **T12** `packaging/aur/PKGBUILD` y su guía de publicación.
  **Comprobación:** `makepkg` en CachyOS contra el release publicado instala y el binario arranca.
- [ ] **T13 (USUARIO)** Crear la cuenta del AUR, subir la clave SSH y publicar.

## P13 y P14. macOS firmado y Sparkle

- [ ] **T14 (USUARIO)** Decidir si hay cuenta de Apple Developer. Sin ella, se cierran P13 y P14 y solo se mejora `LEEME.txt`.
- [ ] **T15 (P13)** Firma con Developer ID, hardened runtime, entitlements y notarización en `tool/package_macos.sh` y `release-macos.yml`.
  **Comprobación:** en un Mac limpio, el DMG abre sin el aviso de Gatekeeper y Wine arranca una botella.
- [ ] **T16 (P14)** Sparkle con appcast y firma EdDSA.
  **Comprobación:** una versión instalada detecta una más nueva y la actualiza.

## Aceptación del usuario

- [ ] **U1** Un release de Linux sale solo tras un merge, con `SHA256SUMS` y sin pasos manuales.
- [ ] **U2** El caso Manjaro: el paquete del release arranca en un equipo sin AVX-512.
- [ ] **U3** Un juego con arreglo en `fixes.json` se lanza con sus variables, y `bodega fix show` lo explica.
- [ ] **U4** Una botella nueva instala `vcrun2022` desde la app.
- [ ] **U5** Con una versión más nueva publicada, la app avisa y el enlace abre el release.
