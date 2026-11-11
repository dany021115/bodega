/// What a run's log showed that the user can act on (R16): the engine's
/// `LogHint`, which `data/` maps here.
enum LogHint {
  /// Wine cannot find FreeType: the engine lacks its libraries.
  freeType,

  /// Wine cannot load GnuTLS: the engine lacks its libraries.
  gnuTls,

  /// A Wine server of another engine holds the bottle.
  otherServer,

  /// Wine could not open the program, as when Windows refuses a name in its
  /// path (trap 11).
  cannotOpen,

  /// Steam was already open, so the fix of the game did not reach it.
  fixNotApplied,
}
