/// The Wine a bottle runs on (MR1): the engine's `RuntimeKind`, which `data/`
/// maps here. A bottle's kind is fixed when it is made (D1).
enum RuntimeKind {
  /// Bodega's own x86_64 Wine, under Rosetta 2.
  bodega,

  /// Mach9's arm64 Wine, the native engine.
  mach9,
}
