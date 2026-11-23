/// Why this host cannot run a runtime (MR2): the engine's `RuntimeBlock`,
/// which `data/` maps here.
enum RuntimeBlock {
  /// Not a Mac.
  notThisHost,

  /// A Mac with an Intel processor.
  appleSiliconOnly,

  /// A Mac older than the runtime's minimum macOS.
  macosTooOld,
}
