import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';

/// The words of the game configurations (A6): exhaustive switches over the
/// domain's codes, so a new code fails analysis until it is worded. Names,
/// values and upstream's notes are shown as they are.
extension GameText on AppL10n {
  String gameStatusOf(GameStatus status) => switch (status) {
    GameStatus.verified => gamesStatusVerified,
    GameStatus.community => gamesStatusCommunity,
    GameStatus.blocked => gamesStatusBlocked,
  };

  /// A rating, or [gamesRatingNone] for a game no one reported.
  String ratingOf(GameRating? rating) => switch (rating) {
    GameRating.works => gamesRatingWorks,
    GameRating.playable => gamesRatingPlayable,
    GameRating.broken => gamesRatingBroken,
    GameRating.blocked => gamesRatingBlocked,
    null => gamesRatingNone,
  };

  String verdictOf(GameVerdict verdict) => switch (verdict) {
    GameVerdict.works => gamesRatingWorks,
    GameVerdict.playable => gamesRatingPlayable,
    GameVerdict.broken => gamesRatingBroken,
  };

  String matchOf(GameMatchKind kind, String game) => switch (kind) {
    GameMatchKind.steam => gamesMatchSteam(game),
    GameMatchKind.exe => gamesMatchExe(game),
    GameMatchKind.title => gamesMatchTitle(game),
  };

  String originOf(BackendOrigin origin) => switch (origin) {
    BackendOrigin.option => gamesOriginOption,
    BackendOrigin.exe => gamesOriginExe,
    BackendOrigin.bottle => gamesOriginBottle,
    BackendOrigin.config => gamesOriginConfig,
    BackendOrigin.auto => gamesOriginAuto,
  };

  String antiCheatOf(AntiCheatVerdict verdict, List<String> names) =>
      switch (verdict) {
        AntiCheatVerdict.blocked => gamesAntiCheatBlocked(names.join(', ')),
        AntiCheatVerdict.warning => gamesAntiCheatWarning(names.join(', ')),
      };

  String stepOf(GameStep step) => switch (step.kind) {
    GameStepKind.variable => gamesStepVariable(step.name, step.value),
    GameStepKind.override => gamesStepOverride(step.value),
    GameStepKind.registry => gamesStepRegistry(step.name, step.value),
    GameStepKind.settingsFile => gamesStepSettingsFile(step.name, step.value),
  };
}
