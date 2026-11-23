/// What making a bottle is doing (MB5): the engine's `BottleStep`, which
/// `data/` maps here.
enum BottleStep {
  /// Creates the prefix.
  prefix,

  /// Installs Wine Mono into a native bottle.
  mono,
}
