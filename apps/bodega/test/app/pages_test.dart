import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/catalog/catalog_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_page.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/shared/widgets/install_panel.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

// The longest texts and every chip at once: what would overflow first.
final _long = 'Una nota larga que ocupa varias líneas en la pantalla. ' * 6;
final _app = CatalogApp(
  id: 'ea-app',
  title: 'Rockstar Games Launcher con un nombre que no cabe en la tarjeta',
  status: CatalogStatus.reported,
  statusNote: _long,
  flaky: _long,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: false,
  notes: [_long, _long],
  knownIssues: [KnownIssue(symptom: _long, fix: _long)],
  source: const {'repo': 'a/b', 'license': 'CC0-1.0'},
  bottle: 'ea-app',
);

final _catalog = CatalogState(
  isLoading: false,
  apps: [
    for (final id in ['steam', 'gog-galaxy', 'custom']) _app.copyWith(id: id),
  ],
  query: 'ro',
  antiCheat: [
    AntiCheatGame(
      title: 'Rogue con un título también larguísimo $_long',
      anticheats: const ['Easy Anti-Cheat', 'BattlEye', 'nProtect GameGuard'],
      verdict: AntiCheatVerdict.blocked,
    ),
  ],
  antiCheatError: const AppError.network('sin red'),
  error: AppError.engine(_long),
);

void main() {
  late _MockCatalog catalog;
  late _MockInstall install;
  late _MockLibrary library;

  setUp(() {
    catalog = _MockCatalog();
    install = _MockInstall();
    library = _MockLibrary();
    whenListen(
      catalog,
      const Stream<CatalogState>.empty(),
      initialState: _catalog,
    );
    whenListen(
      install,
      const Stream<InstallState>.empty(),
      initialState: const InstallState(),
    );
    whenListen(
      library,
      const Stream<LibraryState>.empty(),
      initialState: LibraryState(
        isLoading: false,
        apps: [
          LibraryApp(bottle: 'steam', id: 'steam', title: _app.title),
          const LibraryApp(bottle: 'blur', id: 'custom', title: 'Blur'),
        ],
        open: const {'steam'},
        hints: {
          'steam': [_long],
        },
      ),
    );
  });

  // [width] is the window's: the sidebar takes its part, as in the app.
  Future<void> pump(
    WidgetTester tester,
    double width,
    Widget page, {
    double height = 480,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CatalogBloc>.value(value: catalog),
          BlocProvider<InstallBloc>.value(value: install),
          BlocProvider<LibraryBloc>.value(value: library),
        ],
        child: MaterialApp(
          theme: AppTheme.getDarkTheme(),
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: appBreakpoints,
          ),
          home: Row(
            children: [
              SizedBox(width: width > 800 ? 220 : 68),
              Expanded(child: page),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  // The minimum window, the narrowest with two catalog columns, the default
  // one, and a big one.
  for (final width in [720.0, 801.0, 1100.0, 1921.0]) {
    testWidgets('nothing overflows at $width px', (tester) async {
      await pump(tester, width, const CatalogPage());
      await pump(tester, width, const CatalogDetailPage(id: 'steam'));
      await pump(tester, width, const LibraryPage());
    });

    for (final phase in [
      InstallPhase.downloading,
      InstallPhase.installing,
      InstallPhase.done,
      InstallPhase.failed,
    ]) {
      testWidgets('the ${phase.name} panel fits at $width px', (tester) async {
        whenListen(
          install,
          const Stream<InstallState>.empty(),
          initialState: InstallState(
            phase: phase,
            app: _app,
            received: 150 << 20,
            total: 300 << 20,
            step: _long,
            error: AppError.engine(_long),
            bottleLeft: phase == InstallPhase.failed,
          ),
        );
        await pump(
          tester,
          width,
          const Scaffold(
            body: Column(
              children: [
                Expanded(child: SizedBox.expand()),
                InstallPanel(),
              ],
            ),
          ),
        );
      });
    }
  }

  testWidgets('the detail offers each case', (tester) async {
    Future<void> showing(CatalogApp app) async {
      whenListen(
        catalog,
        const Stream<CatalogState>.empty(),
        initialState: CatalogState(isLoading: false, apps: [app]),
      );
      // A fresh tree, and tall enough for the list to build the button.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, 1100, CatalogDetailPage(id: app.id), height: 3000);
    }

    final free = _app.copyWith(bottle: null);
    await showing(free);
    expect(find.widgetWithText(FilledButton, 'Instalar'), findsOneWidget);

    await showing(_app);
    expect(find.widgetWithText(FilledButton, 'Abrir'), findsOneWidget);

    await showing(free.copyWith(status: CatalogStatus.blocked));
    final blocked = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Instalar'),
    );
    expect(blocked.onPressed, isNull);
    expect(find.textContaining('No se puede instalar'), findsOneWidget);

    await showing(free.copyWith(backendInstalled: false));
    expect(find.widgetWithText(FilledButton, 'Instalar dxmt'), findsOneWidget);
  });
}
