# Propuesta · d3dmetal-y-backends

## Por qué
- Blur se cerraba por tener la botella forzada a D3DMetal, que no sirve para un juego de
  32 bits con DirectX 9. La app no avisa: el usuario elige a ciegas.
- Instalar D3DMetal hoy es leer una guía y buscar una carpeta a mano. El usuario quiere
  elegir una versión y darle a Instalar.

## Qué
**A. Saber qué backend le sirve a cada juego**
- El motor lee el exe una vez y dice sus bits y su DirectX (`DX9 · 32 bits`). Es la misma
  lectura que ya hace Automático, sacada a una función para no repetirla.
- Cada app (tarjeta y fila) muestra esa etiqueta. Steam no lleva etiqueta.
- Al elegir a mano un backend que no encaja (botella o "Ejecutar con opciones"), sale un
  aviso debajo: "Blur es de 32 bits con DirectX 9: D3DMetal no le sirve. Usa Automático."
- Cada backend en la página de Backends dice para qué sirve ("DirectX 11 y 12, solo 64 bits").
  En vez de una tabla aparte, una línea en cada tarjeta: dice lo mismo y sale bien en Linux.

**B. Instalar D3DMetal eligiendo versión**
- La tarjeta de D3DMetal lista las versiones del Game Porting Toolkit: 3.0 (probada) y
  4.0 (beta, sin probar), y la versión que ya tienes.
- "Instalar" → si el dmg ya está en Descargas lo usa; si no, abre la descarga oficial de
  Apple en el navegador (inicias sesión y se baja) y espera a que aparezca en Descargas.
  También vale "Ya lo tengo: elegir dmg…".
- Bodega monta el dmg y abre el de dentro. La ventana de Apple pide aceptar la licencia y
  la aceptas tú. Después Bodega importa D3DMetal, desmonta todo y lanza Comprobar.
- La guía de texto se va.

## Impacto
- Motor: `backends.dart`, `platform.dart`, `platform_mac.dart`, `platform_linux.dart`
  (nuevas funciones; `autoBackend` reusa la lectura). Sin cambios en ajustes guardados.
- App: un bloc nuevo (`GraphicsBloc`), `BackendRepository`, `AppCard`, `AppRow`,
  `bottle_column.dart`, `run_options_dialog.dart`, `backend_card.dart`, `Info.plist`
  (`NSDownloadsFolderUsageDescription`). Se borra `d3dmetal_instructions.dart`.
- Linux: sin D3DMetal; su DXVK trae vkd3d-proton y le sirve a todo, así que allí no hay
  avisos. Solo sale la etiqueta.
- Sigue en pie la regla B2: Bodega no descarga ni aloja D3DMetal; baja el navegador del
  usuario con su cuenta y la licencia la acepta él.
