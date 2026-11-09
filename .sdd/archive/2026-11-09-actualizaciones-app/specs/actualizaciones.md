# Spec · Actualizaciones de la app

## P1 · Publicar
- `release-macos` y `release-linux`, tras subir a la release privada, crean (si falta) la
  release `vX.Y.Z` en `dany021115/bodega-releases` con el título y las notas de la privada,
  y suben sus archivos (`--clobber`) y `wine-src.tar.gz`.
- Sin el secreto `RELEASES_TOKEN`: un aviso (`::warning::`) y el paso no falla.

## A1 · Comprobar
- Al arrancar la app de release, si pasaron 24 h desde la última comprobación, pide
  `https://api.github.com/repos/dany021115/bodega-releases/releases/latest`.
- Compara `tag_name` (`vX.Y.Z`) con la versión instalada (SemVer, número a número).
- Hay aviso si es mayor y no es la versión que el usuario dejó para "Ahora no".
- Error de red, respuesta rara o tag no SemVer: sin aviso, sin error en pantalla.
- En builds de desarrollo no se comprueba nada.

## A2 · Qué se puede hacer
- **macOS** → `Bodega-X.Y.Z-macos-arm64.dmg`. **AppImage** (variable `APPIMAGE`) →
  `Bodega-X.Y.Z-linux-x86_64.AppImage`. Se instala desde la app.
- **Linux sin AppImage** → solo aviso: el comando del gestor de paquetes y el enlace.
- Si la release no tiene el archivo de esta plataforma o su `SHA256SUMS-*`: solo enlace.

## A3 · Modal
- Título "Hay una versión nueva", "Bodega X.Y.Z (tienes A.B.C)", las notas con scroll.
- Botones: **Actualizar** (o **Ver la versión** si es solo aviso) y **Ahora no**.
- Mientras baja: barra de progreso con MB y **Cancelar**. Cancelar deja todo como estaba.
- Si algo falla: el motivo en el modal y la app sigue como estaba.

## A4 · Instalar
- Baja a una carpeta temporal de la app, retomando un `.part` si lo hay.
- Comprueba el SHA256 contra la línea de ese archivo en `SHA256SUMS-macos`/`-linux`. Si no
  cuadra: borra la descarga y no instala.
- **macOS:** monta el dmg sin mostrarlo, copia `Bodega.app` junto a la instalada y desmonta.
  Un script aparte espera a que Bodega se cierre, cambia la vieja por la nueva y la abre.
  Si no se puede escribir donde está instalada: lo dice y no toca nada.
- **AppImage:** escribe el nuevo junto al viejo, le da permiso de ejecución, lo pone en su
  lugar y lo abre.
- Luego la app se cierra.

## A5 · Se conserva todo
- Actualizar solo cambia el programa: `Bodega.app` (macOS) o el AppImage. Nunca toca la
  carpeta de datos (`~/Library/Application Support/Bodega` en macOS: botellas con sus juegos
  y ajustes, backends con D3DMetal, motores instalados, iconos, logs) ni las preferencias.
- La descarga va a una carpeta temporal, fuera de la de datos.
- Al arrancar, la versión nueva registra el motor y los backends que trae solo si no
  existen (`_register` no sobrescribe) y no cambia el motor en uso (`runtimes/current`).

## Escenarios
- **Dado** una carpeta de datos con una botella, `backends/d3dmetal` y `runtimes/current`,
  **cuando** arranca una versión que trae otro motor y otros backends, **entonces** la
  botella, D3DMetal y `current` siguen igual y el motor nuevo queda instalado al lado.
  (test del motor)
- **Dado** una instalación preparada (dmg de prueba), **entonces** la carpeta de datos no
  cambió. (test)
- **Dado** la release `v1.4.0` y la app `1.3.0`, **cuando** arranca, **entonces** sale el
  modal con `1.4.0`. Con `v1.3.0` o `v1.2.9`: nada. (bloc + datos con servidor falso)
- **Dado** "Ahora no" en `1.4.0`, **entonces** no vuelve a salir para `1.4.0`, sí para
  `1.4.1`. (test)
- **Dado** menos de 24 h desde la última comprobación, **entonces** no pide nada. (test)
- **Dado** sin red o un 404, **entonces** nada en pantalla. (test)
- **Dado** un SHA256 que no cuadra, **entonces** no instala y lo dice. (test)
- **Dado** un `.dmg` hecho con `hdiutil create` que trae un `Bodega.app`, **cuando** se
  prepara la instalación, **entonces** queda `Bodega.app` nuevo listo junto al instalado y
  el script de cambio, y no queda nada montado. (test, Mac)
- **Dado** Linux sin `APPIMAGE`, **entonces** el modal da el comando y el enlace. (test)
- **Dado** la primera release pública y una app instalada más vieja, **cuando** se abre,
  **entonces** se actualiza y abre la nueva. (U, el usuario)
