# Spec · Exe graphics and backend notices

## G1 · Reading the exe
- `exeGraphics(path)` returns `bits` (32/64) and `directx` (`DX12`, `DX11`, `DX10`, `DX9`
  or empty if it finds none), or nothing if it is not an x86 PE.
- Assignment (same as Automatic today): `d3d12.dll` → DX12; otherwise, `d3d11.dll` → DX11; otherwise,
  `d3d9.dll` → DX9 (even if it names `d3d10`/`dxgi`, like Blur); otherwise, `d3d10`/`dxgi.dll` → DX10.
- It is read off the UI thread (in another isolate). The app keeps what it read and does not re-read
  an exe it already read in this session.
- `autoBackend` on Mac uses this function and keeps choosing the same as today.

## G2 · Label
- Text: `DX9 · 32 bits`; with no known DirectX, just `32 bits`.
- It shows in `AppCard` and `AppRow` (library and bottle). `steam.exe` gets no label.

## G3 · What each backend works for (Mac)
| Backend | Works for |
|---|---|
| wine | everything |
| dxmt | DX10 and DX11, 32 and 64 bits |
| dxvk | DX10 and DX11, 32 and 64 bits |
| d3dmetal | DX11 and DX12, 64 bits only |
- On Linux (wine, and dxvk with vkd3d-proton) everything fits: there is never a notice.
- With no known DirectX, there is no notice.
- Each backend card shows its "Sirve para…" ("Works for…") line.

## G4 · Notice
- Bottle: if "Gráficos" ("Graphics") is not Automatic, below it shows which apps in the bottle do not fit:
  "D3DMetal no le sirve a: Blur (DX9 · 32 bits). Usa Automático." ("D3DMetal does not work for: Blur (DX9 · 32 bits). Use Automatic.")
- "Ejecutar con opciones" ("Run with options"): if there is a program and a chosen backend that does not fit:
  "Blur es de 32 bits con DirectX 9: D3DMetal no le sirve. Usa Automático." ("Blur is 32-bit with DirectX 9: D3DMetal does not work for it. Use Automatic.")
- `steam.exe` never produces a notice. The notice does not block: the user can go ahead.

## Scenarios
- **Given** a 32-bit exe that names `d3d9.dll` and `d3d10`, **when** it is read,
  **then** it gives `DX9 · 32 bits` and Automatic picks `wine`. (test)
- **Given** a 64-bit exe with `d3d12.dll`, **then** `DX12 · 64 bits`, and d3dmetal gives no
  notice; dxmt does. (test)
- **Given** the bottle "juegos" on d3dmetal with Blur, **when** it is opened, **then** the
  notice with Blur shows. On Automatic it does not. (widget test + U)
- **Given** Steam in the bottle, **then** it gets no label or notice. (widget test)
- **Given** a simulated Linux, **when** the dxvk notice is requested for a DX9 exe, **then** there is no
  notice. (test)
