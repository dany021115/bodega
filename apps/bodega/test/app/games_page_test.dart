import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/game_detail/game_detail_bloc.dart';
import 'package:bodega/app/bloc/games/games_bloc.dart';
import 'package:bodega/app/presentation/games/game_detail_page.dart';
import 'package:bodega/app/presentation/games/games_page.dart';
import 'package:bodega/app/presentation/games/widgets/game_card.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockGames extends MockBloc<GamesEvent, GamesState>
    implements GamesBloc {}

class _MockDetail extends MockBloc<GameDetailEvent, GameDetailState>
    implements GameDetailBloc {}

const _alpha = GameConfig(
  id: 'alpha',
  title: 'Alpha',
  status: GameStatus.community,
  rating: GameRating.playable,
  backend: 'dxmt',
  antiCheat: ['Easy Anti-Cheat'],
  antiCheatVerdict: AntiCheatVerdict.blocked,
  reports: 3,
  lastReport: '2026-11-11',
  nativeMac: true,
  steps: [
    GameStep(kind: GameStepKind.variable, name: 'DXVK_CONFIG', value: 'a=b'),
    GameStep(
      kind: GameStepKind.registry,
      name: 'EmulateModeset',
      value: 'y',
      where: r'HKCU\Software\Wine',
    ),
  ],
  requires: ['vcrun2022'],
  notes: ['Upstream note.'],
  knownIssues: [GameIssue(symptom: 'It stutters.', cause: '', fix: 'Wait.')],
  sourceUrl: 'https://github.com/gauthierpiarrette/highball-db/blob/x/a.json',
);

const _ours = GameConfig(
  id: 'blur',
  title: 'Blur',
  status: GameStatus.verified,
  antiCheat: ['VAC'],
  antiCheatVerdict: AntiCheatVerdict.warning,
  notes: ['Our note.'],
);

void main() {
  final en = lookupAppL10n(const Locale('en'));

  setUpAll(() => registerFallbackValue(const GamesEvent.load()));

  group('the Games page (A2)', () {
    late _MockGames bloc;

    setUp(() {
      bloc = _MockGames();
      whenListen(
        bloc,
        const Stream<GamesState>.empty(),
        initialState: const GamesState(
          isLoading: false,
          games: [_alpha, _ours],
        ),
      );
    });

    testWidgets('a card per game, with its chips, and the filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapApp(
          BlocProvider<GamesBloc>.value(value: bloc, child: const GamesView()),
        ),
      );
      expect(find.byType(GameCard), findsNWidgets(2));
      expect(find.text(en.gamesStatusCommunity), findsOneWidget);
      expect(find.text(en.gamesStatusVerified), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, en.gamesRatingBroken));
      verify(() => bloc.add(const GamesEvent.rating(RatingFilter.broken)));
      await tester.tap(find.widgetWithText(FilterChip, 'dxmt'));
      verify(() => bloc.add(const GamesEvent.backend('dxmt')));
      await tester.enterText(find.byType(TextFormField), 'alp');
      verify(() => bloc.add(const GamesEvent.search('alp')));
    });

    testWidgets('a card opens its game, at /games/<id>', (tester) async {
      String? at;
      final router = GoRouter(
        initialLocation: RouterManager.path(AppRoute.games),
        routes: [
          GoRoute(
            path: '/games',
            builder: (_, _) => BlocProvider<GamesBloc>.value(
              value: bloc,
              child: const GamesView(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) {
                  at = state.matchedLocation;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(wrapRouter(router));
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(at, '/games/alpha');
      expect(
        RouterManager.path(AppRoute.gameDetail, params: {'id': 'x'}),
        '/games/x',
      );
    });
  });

  group("a game's page (A3)", () {
    Future<void> pump(WidgetTester tester, GameConfig game) async {
      // Tall enough that the list builds every section.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      final bloc = _MockDetail();
      whenListen(
        bloc,
        const Stream<GameDetailState>.empty(),
        initialState: GameDetailState(isLoading: false, game: game),
      );
      await tester.pumpWidget(
        wrapApp(
          BlocProvider<GameDetailBloc>.value(
            value: bloc,
            child: GameDetailView(id: game.id),
          ),
        ),
      );
    }

    testWidgets("highball-db's game: banner, reports, changes, notes, source", (
      tester,
    ) async {
      await pump(tester, _alpha);
      expect(
        find.text(en.gamesAntiCheatBlocked('Easy Anti-Cheat')),
        findsOneWidget,
      );
      expect(
        find.text(en.gamesReports(3, en.gamesRatingPlayable, '2026-11-11')),
        findsOneWidget,
      );
      expect(find.text(en.gamesReportsSource), findsOneWidget);
      expect(find.text(en.gamesNativeMac), findsOneWidget);
      for (final line in [
        en.gamesStepBackend('dxmt'),
        en.gamesStepVariable('DXVK_CONFIG', 'a=b'),
        en.gamesStepRegistry('EmulateModeset', 'y'),
        en.gamesStepRuntime('vcrun2022'),
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text(en.gamesNotesHighball), findsOneWidget);
      expect(find.text('Upstream note.'), findsOneWidget);
      expect(find.text('It stutters.'), findsOneWidget);
      expect(find.text(en.gamesSourceHighball), findsOneWidget);
      expect(find.text(en.gamesSourceOpen), findsOneWidget);
    });

    testWidgets("Bodega's own: a warning, nothing to change, no link", (
      tester,
    ) async {
      await pump(tester, _ours);
      expect(find.text(en.gamesAntiCheatWarning('VAC')), findsOneWidget);
      expect(find.text(en.gamesNoReports), findsOneWidget);
      expect(find.text(en.gamesChangesNone), findsOneWidget);
      expect(find.text(en.gamesNotesBodega), findsOneWidget);
      expect(find.text(en.gamesSourceBodega), findsOneWidget);
      expect(find.text(en.gamesSourceOpen), findsNothing);
      expect(en.gameStatusOf(GameStatus.verified), en.gamesStatusVerified);
    });
  });
}
