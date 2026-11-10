import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/api/rest_client.dart';
import 'package:bodega/data/repository/anti_cheat_repository_impl.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockClient extends Mock implements RestClient {}

void main() {
  late Directory home;
  late _MockClient client;
  late AntiCheatRepositoryImpl repository;
  final body = jsonEncode({
    'license': 'MIT',
    'games': {
      'fortnite': {
        'title': 'Fortnite',
        'anticheats': ['Easy Anti-Cheat'],
        'steam_appid': null,
        'macVerdict': 'blocked',
      },
      'halo': {'title': 'Halo', 'macVerdict': 'warning'},
    },
  });

  setUp(() {
    home = Directory.systemTemp.createTempSync('bodega-anticheat');
    addTearDown(() => home.deleteSync(recursive: true));
    client = _MockClient();
    repository = AntiCheatRepositoryImpl(client, TestHome(home.path));
  });

  void noNetwork() => when(() => client.antiCheat()).thenThrow(
    DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionError,
      message: 'offline',
    ),
  );

  test('downloads and saves', () async {
    when(() => client.antiCheat()).thenAnswer((_) async => body);

    final games = (await repository.games()).getOrElse((_) => fail('left'));

    expect(games.first.title, 'Fortnite');
    expect(games.first.anticheats, ['Easy Anti-Cheat']);
    expect(games.first.verdict, AntiCheatVerdict.blocked);
    expect(games.last.verdict, AntiCheatVerdict.warning);
    expect(File('${home.path}/cache/anticheat.json').readAsStringSync(), body);
  });

  test('without network it uses the cache', () async {
    File('${home.path}/cache/anticheat.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(body);
    noNetwork();

    final games = (await repository.games()).getOrElse((_) => fail('left'));

    expect(games, hasLength(2));
    verifyNever(() => client.antiCheat());
  });

  test('without network or cache it is a NetworkError', () async {
    noNetwork();

    final error = (await repository.games()).getLeft().toNullable();

    expect(error, isA<NetworkError>());
    expect((error! as NetworkError).detail, contains('offline'));
    expect(File('${home.path}/cache/anticheat.json').existsSync(), isFalse);
  });
}
