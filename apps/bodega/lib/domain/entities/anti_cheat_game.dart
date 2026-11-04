import 'package:freezed_annotation/freezed_annotation.dart';

part 'anti_cheat_game.freezed.dart';

enum AntiCheatVerdict { warning, blocked }

@freezed
abstract class AntiCheatGame with _$AntiCheatGame {
  const factory AntiCheatGame({
    required String title,
    required List<String> anticheats,
    required AntiCheatVerdict verdict,
  }) = _AntiCheatGame;
}
