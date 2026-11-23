import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/app_games/app_games_bloc.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/games_section.dart';
import 'package:bodega/app/presentation/bottles/widgets/report_dialog.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/pump.dart';

class _MockAppGames extends MockBloc<AppGamesEvent, AppGamesState>
    implements AppGamesBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockBottleDetail extends MockBloc<BottleDetailEvent, BottleDetailState>
    implements BottleDetailBloc {}

/// url_launcher's platform: it records each page it is asked to open.
class _FakeBrowser extends UrlLauncherPlatform {
  final opened = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

const _matched = AppGame(
  key: 'steam:9',
  title: 'Steam game',
  config: GameConfig(
    id: 'alpha',
    title: 'Alpha',
    status: GameStatus.blocked,
    rating: GameRating.blocked,
    antiCheat: ['Easy Anti-Cheat'],
    antiCheatVerdict: AntiCheatVerdict.blocked,
  ),
  by: GameMatchKind.steam,
  backend: 'dxmt',
  origin: BackendOrigin.config,
  steps: [GameStep(kind: GameStepKind.variable, name: 'A', value: '1')],
  requires: ['vcrun2022'],
  verdict: GameVerdict.playable,
);

const _other = AppGame(
  key: 'other.exe',
  title: 'Other',
  backend: 'wine',
  origin: BackendOrigin.auto,
  graphics: ExeGraphics(bits: 32, directx: 'DX9'),
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockAppGames bloc;

  setUpAll(() => registerFallbackValue(const AppGamesEvent.load('')));

  Future<void> pump(WidgetTester tester, List<AppGame> apps) async {
    bloc = _MockAppGames();
    final sections = _MockSections();
    final detail = _MockBottleDetail();
    when(() => sections.state).thenReturn(const SectionsState());
    when(() => detail.state).thenReturn(const BottleDetailState());
    whenListen(
      bloc,
      const Stream<AppGamesState>.empty(),
      initialState: AppGamesState(bottle: 'b', isLoading: false, apps: apps),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppGamesBloc>.value(value: bloc),
            BlocProvider<SectionsBloc>.value(value: sections),
            BlocProvider<BottleDetailBloc>.value(value: detail),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(child: GamesSection(bottle: 'b')),
          ),
        ),
      ),
    );
  }

  testWidgets('a matched app: its game, banner, steps, switch, verdict', (
    tester,
  ) async {
    await pump(tester, [_matched]);
    verify(() => bloc.add(const AppGamesEvent.load('b'))).called(1);
    expect(find.text(en.gamesMatchSteam('Alpha')), findsOneWidget);
    expect(
      find.text(en.gamesAntiCheatBlocked('Easy Anti-Cheat')),
      findsOneWidget,
    );
    expect(
      find.text(en.gamesBackendFrom('dxmt', en.gamesOriginConfig)),
      findsOneWidget,
    );
    expect(find.text(en.gamesStepVariable('A', '1')), findsOneWidget);
    expect(find.text(en.gamesStepRuntime('vcrun2022')), findsOneWidget);
    expect(find.text(en.gamesYouSaid(en.gamesRatingPlayable)), findsOneWidget);
    expect(find.text(en.gamesOpenPage), findsOneWidget);
    await tester.tap(find.byType(Switch));
    verify(() => bloc.add(const AppGamesEvent.setOn('steam:9', false)));
  });

  testWidgets('an unmatched app: automatic, with what the exe draws', (
    tester,
  ) async {
    await pump(tester, [_other]);
    expect(find.text(en.gamesAutomatic), findsOneWidget);
    expect(
      find.text(
        '${en.gamesBackendFrom('wine', en.gamesOriginAuto)} · '
        '${en.graphicsLabel('DX9', 32)}',
      ),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.text(en.gamesOpenPage), findsNothing);
    expect(find.text(en.gamesReport), findsOneWidget);
  });

  testWidgets('a bottle with no apps says so', (tester) async {
    await pump(tester, []);
    expect(find.text(en.gamesNoApps), findsOneWidget);
  });

  testWidgets('the report: a choice first, then the verdict and the note', (
    tester,
  ) async {
    await pump(tester, [_matched]);
    await tester.tap(find.text(en.gamesReport));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDialog), findsOneWidget);
    final send = find.widgetWithText(FilledButton, en.gamesReportSend);
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, en.gamesRatingPlayable));
    await tester.enterText(find.byType(TextField), 'menu only');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(
        const AppGamesEvent.report(_matched, GameVerdict.playable, 'menu only'),
      ),
    ).called(1);
  });

  testWidgets("a report's form opens in the browser, once per report", (
    tester,
  ) async {
    final real = UrlLauncherPlatform.instance;
    final browser = _FakeBrowser();
    UrlLauncherPlatform.instance = browser;
    addTearDown(() => UrlLauncherPlatform.instance = real);
    final url = Uri.parse('https://github.com/dany021115/bodega/issues/new');
    final sections = _MockSections();
    final detail = _MockBottleDetail();
    bloc = _MockAppGames();
    when(() => sections.state).thenReturn(const SectionsState());
    when(() => detail.state).thenReturn(const BottleDetailState());
    const before = AppGamesState(bottle: 'b', isLoading: false);
    whenListen(
      bloc,
      Stream.fromIterable([before.copyWith(report: url, reportId: 1)]),
      initialState: before,
    );
    await tester.pumpWidget(
      wrapApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppGamesBloc>.value(value: bloc),
            BlocProvider<SectionsBloc>.value(value: sections),
            BlocProvider<BottleDetailBloc>.value(value: detail),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(child: GamesSection(bottle: 'b')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(browser.opened, ['$url']);
  });
}
