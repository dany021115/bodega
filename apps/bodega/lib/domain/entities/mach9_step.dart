/// What the native engine's install is doing (MR4): the engine's `Mach9Step`,
/// which `data/` maps here. The state keeps it as a code and the engine card
/// words it.
enum Mach9Step {
  /// Downloads Wine Mono's installer.
  downloadingMono,

  /// Downloads Mach9's dmg.
  downloading,

  /// Opens the dmg.
  mounting,

  /// Checks Mach9's signature before copying it.
  checkingSignature,

  /// Copies Mach9's Wine into Bodega.
  copying,

  /// Checks the copy.
  checking,

  /// Makes the copy the one bottles use.
  switching,

  /// Checks the new version's graphics in a temporary bottle (MU4).
  probing,
}
