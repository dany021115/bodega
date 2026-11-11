/// What a backend is for, on its card (G3): the engine's `BackendRole`, which
/// `data/` maps here.
enum BackendRole {
  /// D3DMetal: DirectX 11 and 12, 64 bits only.
  dx11to12x64,

  /// DXMT and DXVK on the Mac: DirectX 10 and 11, 32 and 64 bits.
  dx10to11,

  /// Wine on the Mac: DirectX 9 and older, and what the others cannot run.
  everythingElse,

  /// The dxvk layer on Linux, with DXVK and vkd3d-proton: DirectX 8 to 12.
  dx8to12,

  /// Wine on Linux: everything, slower than dxvk.
  everythingSlower,
}
