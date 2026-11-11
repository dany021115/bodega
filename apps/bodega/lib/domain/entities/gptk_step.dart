/// What the D3DMetal install from a Game Porting Toolkit dmg is doing (I3):
/// the engine's `GptkStep`, which `data/` maps here. The state keeps it as a
/// code and D3DMetal's card words it, so a language switch rewords it (L6).
enum GptkStep {
  /// Opens the dmg.
  opening,

  /// Waits for the user to accept Apple's license in the window macOS opened.
  acceptLicense,

  /// Copies D3DMetal into Bodega.
  importing,
}
