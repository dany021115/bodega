# Spec · Gráficos del exe y avisos de backend

## G1 · Leer el exe
- `exeGraphics(path)` devuelve `bits` (32/64) y `directx` (`DX12`, `DX11`, `DX10`, `DX9`
  o vacío si no encuentra ninguno), o nada si no es un PE x86.
- Reparto (igual que Automático hoy): `d3d12.dll` → DX12; si no, `d3d11.dll` → DX11; si no,
  `d3d9.dll` → DX9 (aunque nombre `d3d10`/`dxgi`, como Blur); si no, `d3d10`/`dxgi.dll` → DX10.
- Se lee fuera del hilo de la interfaz (otro isolate). La app guarda lo leído y no relee
  un exe que ya leyó en esta sesión.
- `autoBackend` en Mac usa esta función y sigue eligiendo lo mismo que hoy.

## G2 · Etiqueta
- Texto: `DX9 · 32 bits`; sin DirectX conocido, solo `32 bits`.
- Sale en `AppCard` y `AppRow` (biblioteca y botella). `steam.exe` no lleva etiqueta.

## G3 · Qué le sirve a cada backend (Mac)
| Backend | Le sirve a |
|---|---|
| wine | todo |
| dxmt | DX10 y DX11, 32 y 64 bits |
| dxvk | DX10 y DX11, 32 y 64 bits |
| d3dmetal | DX11 y DX12, solo 64 bits |
- En Linux (wine y dxvk con vkd3d-proton) todo encaja: nunca hay aviso.
- Sin DirectX conocido no hay aviso.
- Cada tarjeta de backend muestra su línea "Sirve para…".

## G4 · Aviso
- Botella: si "Gráficos" no es Automático, debajo sale qué apps de la botella no encajan:
  "D3DMetal no le sirve a: Blur (DX9 · 32 bits). Usa Automático."
- "Ejecutar con opciones": si hay programa y un backend elegido que no encaja:
  "Blur es de 32 bits con DirectX 9: D3DMetal no le sirve. Usa Automático."
- `steam.exe` nunca genera aviso. El aviso no bloquea: el usuario puede seguir.

## Escenarios
- **Dado** un exe de 32 bits que nombra `d3d9.dll` y `d3d10`, **cuando** se lee,
  **entonces** da `DX9 · 32 bits` y Automático elige `wine`. (test)
- **Dado** un exe de 64 bits con `d3d12.dll`, **entonces** `DX12 · 64 bits` y d3dmetal no
  avisa; dxmt sí. (test)
- **Dado** la botella "juegos" en d3dmetal con Blur, **cuando** se abre, **entonces** sale
  el aviso con Blur. En Automático no sale. (widget test + U)
- **Dado** Steam en la botella, **entonces** no lleva etiqueta ni aviso. (widget test)
- **Dado** Linux simulado, **cuando** se pide el aviso de dxvk para un DX9, **entonces** no
  hay aviso. (test)
