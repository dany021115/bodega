import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/api/rest_client.dart';
import 'package:bodega/data/entities/anti_cheat_game_dto.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/anti_cheat_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AntiCheatRepository)
class AntiCheatRepositoryImpl implements AntiCheatRepository {
  final RestClient _client;
  final EngineHome _home;

  AntiCheatRepositoryImpl(this._client, this._home);

  /// The list is pinned to a commit, so it never changes: with a copy saved,
  /// there is nothing to ask the network.
  @override
  Future<Either<AppError, List<AntiCheatGame>>> games() =>
      repositoryCall(() async {
        final cache = File('${_home.path}/cache/anticheat.json');
        if (cache.existsSync()) return _parse(cache.readAsStringSync());

        final body = await _client.antiCheat();
        final games = _parse(body);
        cache.parent.createSync(recursive: true);
        final temp = File('${cache.path}.tmp')..writeAsStringSync(body);
        temp.renameSync(cache.path);
        return games;
      });

  List<AntiCheatGame> _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final game in (json['games'] as Map<String, dynamic>).values)
        AntiCheatGameDto.fromJson(game as Map<String, dynamic>).toDomain(),
    ];
  }
}
