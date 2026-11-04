import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/shared/widgets/main_shell.dart';
import 'package:bodega/app/shared/widgets/side_bar.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _MockPreferences extends Mock implements Preferences {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

void main() {
  late _MockBottles bottles;
  late _MockLibrary library;

  setUp(() {
    bottles = _MockBottles();
    library = _MockLibrary();
    whenListen(
      bottles,
      const Stream<BottlesState>.empty(),
      initialState: BottlesState(
        isLoading: false,
        bottles: [
          const Bottle(name: 'games', ready: true),
          const Bottle(name: 'rota', ready: false),
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
    final preferences = _MockPreferences();
    when(() => preferences.getDarkTheme()).thenReturn(null);
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc(preferences)),
        BlocProvider<BottlesBloc>.value(value: bottles),
        BlocProvider<LibraryBloc>.value(value: library),
      ],
      child: child,
    );
  }

  Future<void> pumpShell(WidgetTester tester, double width) async {
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
      providers(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: appBreakpoints,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('at 1000 px the sidebar shows text', (tester) async {
    await pumpShell(tester, 1000);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Instalar'), findsOneWidget);
    expect(find.text('Backends'), findsOneWidget);
    expect(find.text('steam'), findsOneWidget);
  });

  testWidgets('at 600 px it shows icons and initials', (tester) async {
    await pumpShell(tester, 600);
    expect(find.text('Biblioteca'), findsNothing);
    expect(find.text('steam'), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
  });

  group('SideBar', () {
    Future<void> pumpBar(WidgetTester tester, String location) async {
      await tester.pumpWidget(
        providers(
          MaterialApp(
            home: Scaffold(
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
      expect(rowFor(tester, 'Botella steam').properties.selected, isTrue);
      expect(rowFor(tester, 'Botella games').properties.selected, isFalse);
    });

    testWidgets('marks a section only by its own path', (tester) async {
      await pumpBar(tester, '/catalog/steam');
      expect(rowFor(tester, 'Instalar').properties.selected, isTrue);
      expect(rowFor(tester, 'Biblioteca').properties.selected, isFalse);
      expect(rowFor(tester, 'Botella steam').properties.selected, isFalse);
    });

    testWidgets('says which is open and which is incomplete', (tester) async {
      await pumpBar(tester, '/library');
      expect(
        rowFor(tester, 'Botella steam').properties.label,
        'Botella steam, abierta',
      );
      expect(
        rowFor(tester, 'Botella games').properties.label,
        'Botella games, cerrada',
      );
      expect(
        rowFor(tester, 'Botella rota').properties.label,
        'Botella rota, incompleta',
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
    });

    testWidgets('asks for the bottles when it appears', (tester) async {
      await pumpBar(tester, '/library');
      verify(() => bottles.add(const BottlesEvent.load())).called(1);
      verify(() => library.add(const LibraryEvent.load())).called(1);
    });
  });
}
