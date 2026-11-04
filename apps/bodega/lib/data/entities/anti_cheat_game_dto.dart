import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'anti_cheat_game_dto.freezed.dart';
part 'anti_cheat_game_dto.g.dart';

@freezed
abstract class AntiCheatGameDto with _$AntiCheatGameDto {
  const AntiCheatGameDto._();

  const factory AntiCheatGameDto({
    required String title,
    @Default([]) List<String> anticheats,
    String? macVerdict,
  }) = _AntiCheatGameDto;

  factory AntiCheatGameDto.fromJson(Map<String, dynamic> json) =>
      _$AntiCheatGameDtoFromJson(json);

  AntiCheatGame toDomain() => AntiCheatGame(
    title: title,
    anticheats: anticheats,
    verdict: macVerdict == 'blocked'
        ? AntiCheatVerdict.blocked
        : AntiCheatVerdict.warning,
  );
}
