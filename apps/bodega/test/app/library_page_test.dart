import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

/// Twelve applications over three bottles, with titles too long for a card.
final _apps = [
  for (var i = 0; i < 12; i++)
    LibraryApp(
      bottle: 'bottle-${i % 3}',
      key: 'app$i.exe',
      id: 'app$i',
      title:
          'Game with a very long title number $i to check that nothing '
          'overflows on the card or on the row',
    ),
];

void main() {
  late _MockLibrary library;
  late _MockViewMode viewMode;

  setUp(() {
    library = _MockLibrary();
    viewMode = _MockViewMode();
  });

  void givenLibrary(LibraryState state) {
    when(() => library.state).thenReturn(state);
    whenListen(library, Stream.value(state), initialState: state);
  }

  void givenView({required bool isGrid}) {
    final state = ViewModeState(isGrid: isGrid);
    when(() => viewMode.state).thenReturn(state);
    whenListen(viewMode, Stream.value(state), initialState: state);
  }

  // [width] is the window's: the sidebar takes its part, as in the app.
  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 480);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LibraryBloc>.value(value: library),
          BlocProvider<ViewModeBloc>.value(value: viewMode),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.getDarkTheme(),
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: appBreakpoints,
          ),
          home: Row(
            children: [
              SizedBox(width: width > 800 ? 220 : 68),
              const Expanded(child: LibraryPage()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final width in [720.0, 1100.0]) {
    testWidgets('the grid of 12 long titles fits at $width px', (tester) async {
      givenLibrary(LibraryState(isLoading: false, apps: _apps));
      givenView(isGrid: true);

      await pump(tester, width);

      expect(tester.takeException(), isNull);
      expect(find.byType(AppCard), findsWidgets);
    });

    testWidgets('the list of 12 long titles fits at $width px', (tester) async {
      givenLibrary(LibraryState(isLoading: false, apps: _apps));
      givenView(isGrid: false);

      await pump(tester, width);

      expect(tester.takeException(), isNull);
      expect(find.byType(AppRow), findsWidgets);
    });
  }

  testWidgets('shows the count of apps and bottles', (tester) async {
    givenLibrary(LibraryState(isLoading: false, apps: _apps));
    givenView(isGrid: true);

    await pump(tester, 1100);

    expect(find.text('12 apps in 3 bottles'), findsOneWidget);
  });

  testWidgets('an empty library offers a new bottle', (tester) async {
    givenLibrary(const LibraryState(isLoading: false));
    givenView(isGrid: true);

    await pump(tester, 720);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('New bottle'), findsOneWidget);
    expect(find.byType(AppCard), findsNothing);
  });

  testWidgets('the search filters by title', (tester) async {
    givenLibrary(LibraryState(isLoading: false, apps: _apps));
    givenView(isGrid: true);

    await pump(tester, 1100);
    await tester.enterText(find.byType(TextField), 'number 7 ');
    await tester.pump();

    expect(find.byType(AppCard), findsOneWidget);
    expect(find.text('1 app in 1 bottle'), findsOneWidget);
  });

  testWidgets('a search without results says so', (tester) async {
    givenLibrary(LibraryState(isLoading: false, apps: _apps));
    givenView(isGrid: false);

    await pump(tester, 720);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
