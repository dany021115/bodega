import 'package:bodega/domain/entities/log_hint.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_hint.freezed.dart';

/// Advice about a bottle's run, as a code the app words (design §5): what its
/// log showed, or Easy Anti-Cheat failing. Equal hints are the same advice,
/// which the library shows once (E14).
@freezed
sealed class RunHint with _$RunHint {
  /// The run's log holds the marker of [hint].
  const factory RunHint.log(LogHint hint) = LogRunHint;

  /// Easy Anti-Cheat could not load under Wine (error 206) for [game], the
  /// title its log names, or for a game it does not name (I11).
  const factory RunHint.antiCheat({String? game}) = AntiCheatRunHint;
}
