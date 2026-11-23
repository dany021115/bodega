import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/app_games/app_games_bloc.dart';
import 'package:bodega/app/bloc/game_detail/game_detail_bloc.dart';
import 'package:bodega/app/bloc/games/games_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/repository/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockGames extends Mock implements GameRepository {}

GameConfig _game(String id, GameRating? rating, {String? backend}) =>
    GameConfig(
      id: id,
      title: id[0].toUpperCase() + id.substring(1),
      status: rating == GameRating.blocked
          ? GameStatus.blocked
          : GameStatus.community,
      rating: rating,
      backend: backend,
    );

void main() {
  late _MockGames games;
  final all = [
    _game('alpha', GameRating.works, backend: 'dxmt'),
    _game('beta', GameRating.broken, backend: 'd3dmetal'),
    _game('gamma', null),
    _game('delta', GameRating.blocked),
  ];
  const app = AppGame(
    key: 'steam:9',
    title: 'Alpha',
    backend: 'dxmt',
    origin: BackendOrigin.config,
  );
  final url = Uri.parse('https://github.com/dany021115/bodega/issues/new');

  setUpAll(() => registerFallbackValue(GameVerdict.works));

  setUp(() {
    games = _MockGames();
    when(() => games.games()).thenAnswer((_) async => right(all));
    when(() => games.game('alpha')).thenAnswer((_) async => right(all.first));
    when(() => games.game('nope'))
        .thenAnswer((_) async => left(const AppError.unknown(detail: 'nope')));
    when(() => games.appGames('b')).thenAnswer((_) async => right([app]));
    when(() => games.setOn('b', any(), any()))
        .thenAnswer((_) async => right(unit));
    when(() => games.setVerdict('b', any(), any()))
        .thenAnswer((_) async => right(unit));
    when(() => games.reportUrl(any(), any(), any()))
        .thenAnswer((_) async => right(url));
  });

  setUpAll(() {
    registerFallbackValue(app);
  });

  group('GamesBloc (A2)', () {
    blocTest<GamesBloc, GamesState>(
      'loads every game',
      build: () => GamesBloc(games),
      act: (bloc) => bloc.add(const GamesEvent.load()),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.visibleGames, all);
      },
    );

    blocTest<GamesBloc, GamesState>(
      'searches the title, ignoring case',
      build: () => GamesBloc(games),
      seed: () => GamesState(isLoading: false, games: all),
      act: (bloc) => bloc.add(const GamesEvent.search('ALP')),
      verify: (bloc) =>
          expect(bloc.state.visibleGames.map((game) => game.id), ['alpha']),
    );

    blocTest<GamesBloc, GamesState>(
      'filters by rating and by backend; the same chip again clears it',
      build: () => GamesBloc(games),
      seed: () => GamesState(isLoading: false, games: all),
      act: (bloc) => bloc
        ..add(const GamesEvent.rating(RatingFilter.broken))
        ..add(const GamesEvent.rating(RatingFilter.broken))
        ..add(const GamesEvent.rating(RatingFilter.none))
        ..add(const GamesEvent.backend('dxmt')),
      expect: () => [
        isA<GamesState>().having(
          (s) => s.visibleGames.map((game) => game.id),
          'broken',
          ['beta'],
        ),
        isA<GamesState>().having((s) => s.rating, 'cleared', isNull),
        isA<GamesState>().having(
          (s) => s.visibleGames.map((game) => game.id),
          'no reports',
          ['gamma'],
        ),
        isA<GamesState>().having(
          (s) => s.visibleGames,
          'none and dxmt',
          isEmpty,
        ),
      ],
    );
  });

  group('GameDetailBloc (A3)', () {
    blocTest<GameDetailBloc, GameDetailState>(
      'loads a game, or its error',
      build: () => GameDetailBloc(games),
      act: (bloc) => bloc
        ..add(const GameDetailEvent.load('alpha'))
        ..add(const GameDetailEvent.load('nope')),
      expect: () => [
        GameDetailState(isLoading: false, game: all.first),
        const GameDetailState(
          isLoading: false,
          error: AppError.unknown(detail: 'nope'),
        ),
      ],
    );
  });

  group('AppGamesBloc (A4, A5)', () {
    blocTest<AppGamesBloc, AppGamesState>(
      "loads the bottle's apps",
      build: () => AppGamesBloc(games),
      act: (bloc) => bloc.add(const AppGamesEvent.load('b')),
      verify: (bloc) {
        expect(bloc.state.bottle, 'b');
        expect(bloc.state.apps, [app]);
      },
    );

    blocTest<AppGamesBloc, AppGamesState>(
      'the switch saves, then reads the bottle again',
      build: () => AppGamesBloc(games),
      seed: () => const AppGamesState(bottle: 'b', isLoading: false),
      act: (bloc) => bloc.add(const AppGamesEvent.setOn('steam:9', false)),
      verify: (_) {
        verify(() => games.setOn('b', 'steam:9', false)).called(1);
        verify(() => games.appGames('b')).called(1);
      },
    );

    blocTest<AppGamesBloc, AppGamesState>(
      'a report saves the verdict and gives the form to open',
      build: () => AppGamesBloc(games),
      seed: () => const AppGamesState(bottle: 'b', isLoading: false),
      act: (bloc) => bloc.add(
        const AppGamesEvent.report(app, GameVerdict.playable, 'menu only'),
      ),
      verify: (bloc) {
        verify(() => games.setVerdict('b', 'steam:9', GameVerdict.playable))
            .called(1);
        verify(() => games.reportUrl(app, GameVerdict.playable, 'menu only'))
            .called(1);
        expect(bloc.state.report, url);
        expect(bloc.state.reportId, 1);
      },
    );

    blocTest<AppGamesBloc, AppGamesState>(
      'a verdict that is not saved opens no form',
      build: () => AppGamesBloc(games),
      setUp: () => when(() => games.setVerdict('b', any(), any()))
          .thenAnswer((_) async => left(const AppError.unknown(detail: 'x'))),
      seed: () => const AppGamesState(bottle: 'b', isLoading: false),
      act: (bloc) =>
          bloc.add(const AppGamesEvent.report(app, GameVerdict.works, '')),
      verify: (bloc) {
        verifyNever(() => games.reportUrl(any(), any(), any()));
        expect(bloc.state.error, isNotNull);
        expect(bloc.state.reportId, 0);
      },
    );
  });
}
