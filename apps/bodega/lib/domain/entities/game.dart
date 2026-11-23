import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

// The catalog's anti-cheat list and a game's configuration share highball-db's
// verdict for the Mac.
export 'package:bodega/domain/entities/anti_cheat_game.dart'
    show AntiCheatVerdict;

part 'game.freezed.dart';

/// Where a game's configuration stands (G1): tested on Bodega, from
/// highball-db's players, or kept from working by anti-cheat or its publisher.
enum GameStatus { verified, community, blocked }

/// How a game runs: from its reports' median, `blocked` first.
enum GameRating { works, playable, broken, blocked }

/// How an app was matched to its game (G3).
enum GameMatchKind { steam, exe, title }

/// What the user said of a game (G6).
enum GameVerdict { works, playable, broken }

/// One thing a configuration changes.
enum GameStepKind { variable, override, registry, settingsFile }

/// Where a launch's backend comes from (S2, G5).
enum BackendOrigin { option, exe, bottle, config, auto }

@freezed
abstract class GameStep with _$GameStep {
  /// [name] is the variable, the registry value or the setting; [where] is
  /// the registry key or the settings file; [value] is what it is set to.
  const factory GameStep({
    required GameStepKind kind,
    @Default('') String name,
    @Default('') String value,
    @Default('') String where,
  }) = _GameStep;
}

@freezed
abstract class GameIssue with _$GameIssue {
  const factory GameIssue({
    required String symptom,
    required String cause,
    required String fix,
  }) = _GameIssue;
}

/// A game's configuration (G1). Its notes and known issues are upstream's
/// prose, in English: the page shows them under a label that says so (§9).
@freezed
abstract class GameConfig with _$GameConfig {
  const factory GameConfig({
    required String id,
    required String title,
    int? steam,
    required GameStatus status,
    GameRating? rating,

    /// The backend this host gets, or null.
    String? backend,
    @Default([]) List<String> antiCheat,
    AntiCheatVerdict? antiCheatVerdict,
    @Default(0) int reports,
    String? lastReport,
    @Default(false) bool nativeMac,
    @Default([]) List<GameStep> steps,
    @Default([]) List<String> requires,
    @Default([]) List<String> notes,
    @Default([]) List<GameIssue> knownIssues,

    /// The entry's file at the pinned commit, or null for Bodega's own.
    String? sourceUrl,
  }) = _GameConfig;
}

/// What a launch of one app of a bottle gets (G7).
@freezed
abstract class AppGame with _$AppGame {
  const factory AppGame({
    required String key,
    required String title,
    GameConfig? config,
    GameMatchKind? by,

    /// False when the user turned the configuration off.
    @Default(true) bool on,
    required String backend,
    required BackendOrigin origin,

    /// What auto read in the exe, when auto chose.
    ExeGraphics? graphics,
    @Default([]) List<GameStep> steps,
    @Default([]) List<String> requires,
    GameVerdict? verdict,

    /// The engine of the app's bottle, for a report (PA5).
    @Default(RuntimeKind.bodega) RuntimeKind runtime,
  }) = _AppGame;
}
