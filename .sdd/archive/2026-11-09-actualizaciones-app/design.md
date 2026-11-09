# Diseño · actualizaciones-app

## 1. Sin GitHub Pages, sin Sparkle
La app pregunta a la API de releases del repo público. Sparkle pide appcast y firma EdDSA, y
con la firma ad hoc su comprobación de identidad entre versiones puede fallar; además el
modal propio ya hace falta en Linux. Una sola vía para las dos plataformas.

## 2. Capas
- `domain/`: `AppUpdate` (versión, actual, notas, página, y si se puede instalar) y
  `UpdateRepository` (`check`, `download`, `install`, `skip`).
- `data/`: `UpdateRepositoryImpl` con `dio` (API), `Downloader` (descarga), `Preferences`
  (última comprobación y versión saltada), `engine.sha256Of` y `Process` (`hdiutil`,
  `ditto`, script de cambio). Solo `data/` toca procesos y red.
- `app/`: `UpdateBloc` (singleton) y `UpdateDialog`, escuchado en `ShellBody`.

## 3. Cambiar la app que está corriendo (macOS)
No se puede reemplazar `Bodega.app` con seguridad mientras corre. La app deja
`.Bodega-update.app` junto a la instalada y lanza, separado de ella
(`ProcessStartMode.detached`), un `sh` que espera a que el PID de Bodega termine, borra la
vieja, renombra la nueva y hace `open`. Después la app se cierra. Un `.dmg` bajado por la app
no lleva cuarentena (la app no está en sandbox ni la activa), así que no salta Gatekeeper.

## 4. AppImage
En Linux se puede renombrar encima de un ejecutable en uso: `rename` del nuevo sobre
`$APPIMAGE`, y se lanza separado antes de cerrar.

## 5. Solo en release
`kReleaseMode`: una build de desarrollo está en `build/` y se reemplazaría a sí misma.

## 6. Publicar con token aparte
`github.token` solo vale para el repo donde corre el workflow. Para el público hace falta un
token *fine-grained* con "Contents: write" solo en `bodega-releases`, guardado como
`RELEASES_TOKEN`. Las notas se copian de la release privada (`gh release view --json body`).
