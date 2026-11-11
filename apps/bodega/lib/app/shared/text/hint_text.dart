import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/l10n/l10n.dart';

/// A [RunHint] in the user's language: on the bottle's card and page, and in
/// its toast (design §6). Where the engine's text gives a command, this says
/// what to do in Bodega instead (L8).
///
/// One case per hint and no default, so a hint added to the domain fails the
/// build here until it has its words (E12).
extension RunHintText on RunHint {
  String localized(AppL10n l10n) => switch (this) {
    LogRunHint(:final hint) => logHintText(l10n, hint),
    AntiCheatRunHint(:final game?) => l10n.hintAntiCheat(game),
    AntiCheatRunHint(game: null) => l10n.hintAntiCheatUnnamed,
  };
}

/// What a run's log showed, and what to do about it.
String logHintText(AppL10n l10n, LogHint hint) => switch (hint) {
  LogHint.freeType => l10n.hintFreeType,
  LogHint.gnuTls => l10n.hintGnuTls,
  LogHint.otherServer => l10n.hintOtherServer,
  LogHint.cannotOpen => l10n.hintCannotOpen,
  LogHint.fixNotApplied => l10n.hintFixNotApplied,
};
