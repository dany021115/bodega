# Propuesta · actualizaciones-app

## Por qué
La app no sabe cuándo hay una versión nueva, y aunque lo supiera no podría bajarla: las
releases están en un repo privado. El usuario quiere un modal de "hay actualización" y que la
app se actualice sola.

## Qué
**A. Releases públicas**
- Repo público nuevo `dany021115/bodega-releases`, sin código: solo releases.
- `release-macos` y `release-linux` publican también ahí, con las mismas notas, los
  instaladores, los `SHA256SUMS-*` y `wine-src.tar.gz` (la carpeta `wine/`, por la LGPL).
  Usan un token en el secreto `RELEASES_TOKEN`; sin él, avisan y lo saltan.

**B. Aviso en la app**
- Al abrir, como mucho una vez cada 24 h, la app pregunta a GitHub por la última release
  del repo público. Si es más nueva que la instalada, sale un modal con la versión y sus
  notas. "Ahora no" no vuelve a avisar de esa versión.
- Sin internet o con error: no sale nada.

**C. Actualizar**
- **macOS y AppImage:** "Actualizar" baja el instalador con progreso (se puede cancelar),
  lo comprueba con su SHA256, reemplaza la app y la vuelve a abrir.
- **`.deb`, Arch y `.tar.gz`:** el modal dice cómo actualizar (comando) y enlaza la release.
- Solo en la app de release: una build de desarrollo no se actualiza (se reemplazaría a sí
  misma).

## Impacto
- `.github/workflows/release-macos.yml`, `release-linux.yml`.
- Motor: `_sha256` pasa a público (`sha256Of`) para reutilizarlo.
- App: entidad y repositorio de actualizaciones (dominio/datos), `UpdateBloc`, modal en
  `ShellBody`, dos claves nuevas en `Preferences`.
- Pasos del usuario: crear el repo público y el token (o aprobar que lo cree yo con `gh`),
  y lanzar una release para estrenarlo.
- Sustituye M8 (T11 y T16) de `.sdd/mejoras-releases`.
