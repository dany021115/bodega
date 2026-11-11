import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/presentation/settings/settings_dialog.dart';
import 'package:bodega/app/shared/widgets/app_version.dart';
import 'package:bodega/app/shared/widgets/main_shell.dart';
import 'package:bodega/app/shared/widgets/side_bar.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockLocale extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockBottles bottles;
  late _MockLibrary library;
  late _MockLocale language;

  setUp(() {
    bottles = _MockBottles();
    library = _MockLibrary();
    language = _MockLocale();
    whenListen(
      language,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(),
    );
    whenListen(
      bottles,
      const Stream<BottlesState>.empty(),
      initialState: BottlesState(
        isLoading: false,
        bottles: [
          const Bottle(name: 'games', ready: true),
          const Bottle(name: 'broken', ready: false),
          const Bottle(name: 'steam', ready: true),
          for (var i = 0; i < 50; i++) Bottle(name: 'b$i', ready: true),
        ],
      ),
    );
    whenListen(
      library,
      const Stream<LibraryState>.empty(),
      initialState: const LibraryState(open: {'steam'}),
    );
  });

  Widget providers(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<BottlesBloc>.value(value: bottles),
        BlocProvider<LibraryBloc>.value(value: library),
        BlocProvider<LocaleBloc>.value(value: language),
      ],
      child: child,
    );
  }

  Future<void> pumpShell(
    WidgetTester tester,
    double width, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 700);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox.expand()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      providers(wrapRouter(router, locale: locale, breakpoints: true)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('at 1000 px the sidebar shows text', (tester) async {
    await pumpShell(tester, 1000);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('BOTTLES'), findsOneWidget);
    expect(find.text('Backends'), findsOneWidget);
    expect(find.text('steam'), findsOneWidget);
    // The catalog has no sidebar item since the redesign.
    expect(find.text(en.catalogTitle), findsNothing);
  });

  testWidgets('at 600 px it shows only icons, with tooltips', (tester) async {
    await pumpShell(tester, 600);
    expect(find.text(en.navLibrary), findsNothing);
    expect(find.text(en.navBottles), findsNothing);
    expect(find.text('steam'), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
    expect(find.byTooltip('Library'), findsOneWidget);
    expect(find.byTooltip('Backends'), findsOneWidget);
    expect(find.byTooltip('New bottle'), findsOneWidget);
    expect(find.text('S'), findsNothing);
    expect(find.text('G'), findsNothing);
  });

  // L4: the language is set in a dialog, opened from a gear item at the foot
  // of the sidebar.
  group('Settings', () {
    testWidgets('at 1000 px it sits between Backends and the version', (
      tester,
    ) async {
      await pumpShell(tester, 1000);
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final settings = find.text('Settings');
      expect(settings, findsOneWidget);
      expect(top(settings), greaterThan(top(find.text('Backends'))));
      expect(top(settings), lessThan(top(find.byType(AppVersion))));
    });

    testWidgets('at 600 px only its gear shows, a button with a tooltip', (
      tester,
    ) async {
      await pumpShell(tester, 600);
      final gear = find.byIcon(Icons.settings_rounded);
      expect(gear, findsOneWidget);
      expect(find.text(en.navSettings), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(
        tester.getSemantics(gear),
        isSemantics(label: 'Settings', isButton: true),
      );
    });

    for (final width in [1000.0, 600.0]) {
      testWidgets('a click opens the dialog at $width px', (tester) async {
        await pumpShell(tester, width);
        expect(find.byType(SettingsDialog), findsNothing);
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsOneWidget);
      });
    }
  });

  testWidgets('in Spanish, its words are Spanish (L1)', (tester) async {
    final es = lookupAppL10n(const Locale('es'));
    await pumpShell(tester, 1000, locale: const Locale('es'));
    for (final text in <String Function(AppL10n)>[
      (l10n) => l10n.navLibrary,
      (l10n) => l10n.navBottles,
      (l10n) => l10n.navNewBottle,
      (l10n) => l10n.navSettings,
    ]) {
      expect(find.text(text(es)), findsOneWidget);
      expect(find.text(text(en)), findsNothing);
    }
  });

  group('SideBar', () {
    Future<void> pumpBar(WidgetTester tester, String location) async {
      await tester.pumpWidget(
        providers(
          wrapApp(
            Scaffold(
              body: Row(
                children: [
                  SideBar(location: location, expanded: true),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Semantics rowFor(WidgetTester tester, String label) => tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith(label) == true,
      ),
    );

    testWidgets('marks the bottle of the current path', (tester) async {
      await pumpBar(tester, '/bottles/steam');
      expect(rowFor(tester, 'Bottle steam').properties.selected, isTrue);
      expect(rowFor(tester, 'Bottle games').properties.selected, isFalse);
    });

    testWidgets('marks a section only by its own path', (tester) async {
      await pumpBar(tester, '/backends');
      expect(rowFor(tester, 'Backends').properties.selected, isTrue);
      expect(rowFor(tester, 'Library').properties.selected, isFalse);
      expect(rowFor(tester, 'Bottle steam').properties.selected, isFalse);
    });

    testWidgets('says which is open and which is incomplete', (tester) async {
      await pumpBar(tester, '/library');
      expect(
        rowFor(tester, 'Bottle steam').properties.label,
        'Bottle steam, open',
      );
      expect(
        rowFor(tester, 'Bottle games').properties.label,
        'Bottle games, closed',
      );
      expect(
        rowFor(tester, 'Bottle broken').properties.label,
        'Bottle broken, incomplete',
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('50 bottles scroll without overflowing', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(801, 480);
      addTearDown(tester.view.reset);
      await pumpBar(tester, '/library');
      expect(tester.takeException(), isNull);
      expect(find.text('Backends'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('asks for the bottles when it appears', (tester) async {
      await pumpBar(tester, '/library');
      verify(() => bottles.add(const BottlesEvent.load())).called(1);
      verify(() => library.add(const LibraryEvent.load())).called(1);
    });
  });
}
