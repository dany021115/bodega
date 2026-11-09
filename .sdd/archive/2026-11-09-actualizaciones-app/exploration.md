# Exploración · actualizaciones-app

## Problema
Cuando sale una versión nueva de Bodega, la app no se entera. El usuario quiere que, al
detectar una release nueva, salga un modal y la app se actualice sola.

Hoy no puede: `dany021115/bodega` es **privado** y sin cuenta la API de GitHub responde
`404` a `releases/latest` (comprobado con `curl`). Decisión del usuario: un **repo público
solo de releases** (p. ej. `dany021115/bodega-releases`), con el código privado.
Una GitHub Page no hace falta: la app pregunta a la API de releases. Además Pages no admite
archivos de más de 100 MB, y el `.dmg` pesa 447 MB.

## Releases hoy
- `tag-version.yml:24-35`: crea `vX.Y.Z` al hacer push a `main` si la versión del pubspec
  no tiene tag.
- `release-macos.yml` y `release-linux.yml` (a mano, desde el tag):
  - `release-macos.yml:155-157` y `release-linux.yml:167-169`: `SHA256SUMS-macos` /
    `SHA256SUMS-linux` con `sha256sum`.
  - `release-macos.yml:167-168` y `release-linux.yml:179-180`: `gh release create "$TAG"
    --generate-notes` y `gh release upload "$TAG" dist/* --clobber`, con `github.token`
    (solo sirve para este repo).
- Tamaños de v1.1.0: `.dmg` 447 MB, AppImage 210 MB, `.deb` 130 MB, Arch 187 MB,
  `.tar.gz` 235 MB. El `.dmg` lleva el motor dentro (`Resources/bundle`).
- Firma de macOS: ad hoc (`tool/package_macos.sh:153-156`), sin Developer ID.
- Plan previo de los compañeros: `.sdd/mejoras-releases` M8 (`design.md:79-86`): aviso de
  versión con `dio` + `package_info_plus` una vez por sesión; fase 2 Sparkle en macOS.
  Este SDD lo sustituye (T11 y T16 de allí).

## App (`apps/bodega/lib`)
- Versión instalada: `app/shared/widgets/app_version.dart:7` (`PackageInfo.fromPlatform`).
- Descargas: `data/service/downloader.dart:12` `Downloader.fetch(url, dest, cancel,
  onProgress)` con `dio`, a un `.part`, cancelable. Sirve para bajar el instalador.
- Avisos globales: `app/shared/widgets/shell_body.dart:11` (`MultiBlocListener` con
  toasts): sitio para escuchar un bloc de actualizaciones y abrir el modal.
- Rutas: `app/router.dart:71` `ShellRoute` → `MainShell` → `ShellBody`.
- Dependencias que ya están: `dio`, `package_info_plus`, `url_launcher`, `toastification`.

## Cómo se reemplaza la app
- **macOS:** la app no está en sandbox y no marca las descargas como "en cuarentena": un
  `.dmg` bajado por la propia app no dispara Gatekeeper. Se monta (`hdiutil`, como ya hace
  el motor en `engine.dart:483`), se copia el `.app` nuevo, y un script aparte espera a
  que Bodega se cierre, cambia `Bodega.app` y la vuelve a abrir. Dónde está instalada:
  `Platform.resolvedExecutable` (`platform_mac.dart:47` ya lo usa).
- **Linux AppImage:** la variable `APPIMAGE` dice su ruta. Se reemplaza el archivo y se
  relanza.
- **Linux `.deb`, Arch y `.tar.gz`:** van en `/opt/bodega` (`packaging/linux/build_deb.sh:3`)
  y son del gestor de paquetes: solo aviso con el comando (o el enlace).

## Restricciones
- Licencia: el motor es Wine (LGPL). Si los binarios son públicos, el código de Wine que
  usamos también: el árbol LGPL de CrossOver (público en codeweavers.com) + `wine/` del
  repo (receta y parches, 1,6 MB). Se puede adjuntar `wine/` a cada release pública.
- D3DMetal nunca se publica (no va en el `.dmg`: lo importa el usuario).
- Crear el repo público y su token es algo que se ve desde fuera: lo confirma el usuario.
  Hace falta un token con permiso de escritura en ese repo, guardado como secreto en
  `dany021115/bodega`.
- La API sin login permite 60 consultas por hora por IP: una por sesión basta.
- Desde Cuba la descarga de 447 MB por Starlink es larga: hay que mostrar progreso y poder
  cancelar.
- Capas: la red y los procesos van en `data/`; la UI en `app/`; `tool/check_layers.sh`.

## Dudas abiertas
1. **Nombre del repo público:** `dany021115/bodega-releases`.
2. **Qué se sube allí:** los instaladores, `SHA256SUMS-*`, las notas de la versión y
   `wine-src.tar.gz` (la carpeta `wine/`). ¿Se dejan también en el repo privado? Propongo
   que sí (no cuesta nada).
3. **Cuándo se pregunta:** al abrir la app y como mucho una vez cada 24 h. "Ahora no"
   oculta esa versión hasta la siguiente.
4. **Comprobación del archivo:** contra `SHA256SUMS-macos`/`-linux` de la misma release.
   Si no cuadra, no se instala.
5. **Notas en el modal:** el cuerpo de la release (Markdown) como texto simple.
6. **Probarlo de verdad** requiere dos releases públicas (una vieja instalada y una nueva).
   Propongo una prueba con una release falsa local (servidor de prueba) en tests, y la real
   cuando salga la próxima versión.
