import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

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
          'A game with a very long title, number $i, to check that nothing '
          'overflows the card or the row',
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
        child: wrapApp(
          Row(
            children: [
              SizedBox(width: width > 800 ? 220 : 68),
              const Expanded(child: LibraryPage()),
            ],
          ),
          theme: AppTheme.getDarkTheme(),
          breakpoints: true,
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

  testWidgets('the count agrees with each number (L10)', (tester) async {
    givenLibrary(LibraryState(isLoading: false, apps: _apps));
    givenView(isGrid: true);

    await pump(tester, 1100);
    // Numbers 1, 10 and 11: two in bottle-1, one in bottle-2.
    await tester.enterText(find.byType(TextField), 'number 1');
    await tester.pump();

    expect(find.byType(AppCard), findsNWidgets(3));
    expect(find.text('3 apps in 2 bottles'), findsOneWidget);
    // The header counts the bottles of the apps it shows, so it never shows
    // more bottles than apps: the message says that case too.
    final en = lookupAppL10n(const Locale('en'));
    expect(en.libraryCount(2, 3), '2 apps in 3 bottles');
  });

  testWidgets('only the running app of a bottle shows Stop', (tester) async {
    final apps = [
      const LibraryApp(bottle: 'b', key: 'k1', id: 'k1', title: 'Alpha'),
      const LibraryApp(bottle: 'b', key: 'k2', id: 'k2', title: 'Beta'),
    ];
    givenLibrary(
      LibraryState(
        isLoading: false,
        apps: apps,
        open: const {'b'},
        running: const {
          'b': {'k1'},
        },
      ),
    );
    givenView(isGrid: true);

    await pump(tester, 1100);
    expect(find.text('Running'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    verify(() => library.add(const LibraryEvent.stop('b', 'k1'))).called(1);
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
