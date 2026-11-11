/// The Wine programs whose exit code the engine checks: the engine's
/// `WineTool`, which `data/` maps here.
enum WineTool {
  /// Creates a bottle's prefix.
  wineboot,

  /// `reg add`: the catalog's values, the Windows user, high resolution and
  /// the fixes.
  reg,

  /// A catalog app's installer, or msiexec for an MSI.
  installer,

  /// Sets a bottle's Windows version.
  winecfg,
}
