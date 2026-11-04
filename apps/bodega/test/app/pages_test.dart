import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/presentation/add_app/add_app_dialog.dart';
import 'package:bodega/app/presentation/backends/backends_page.dart';
import 'package:bodega/app/presentation/bottles/bottle_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_page.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/install_panel.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

class _MockBackends extends MockBloc<BackendsEvent, BackendsState>
    implements BackendsBloc {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockBottle extends MockBloc<BottleDetailEvent, BottleDetailState>
    implements BottleDetailBloc {}

class _MockAddApp extends MockBloc<AddAppEvent, AddAppState>
    implements AddAppBloc {}

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockPreferences extends Mock implements Preferences {}

// The longest texts and every chip at once: what would overflow first.
final _long = 'Una nota larga que ocupa varias líneas en la pantalla. ' * 6;
final _longName = 'una-botella-con-un-nombre-muy-largo-${'x' * 28}';
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

List<LibraryApp> _apps(String bottle) => [
  for (var i = 0; i < 30; i++)
    LibraryApp(
      bottle: bottle,
      key: 'p/$i.exe',
      id: i.isEven ? 'steam' : 'custom',
      title: 'Una aplicación con un título bastante largo $i',
    ),
];

BottleDetailState _bottle({bool ready = true, List<LibraryApp>? apps}) =>
    BottleDetailState(
      isLoading: false,
      detail: BottleDetail(
        name: _longName,
        ready: ready,
        backend: 'dxmt',
        sync: 'msync',
        apps: apps ?? _apps(_longName),
        exceptions: [
          ProgramBackend(exe: '$_longName.exe', backend: 'd3dmetal'),
        ],
        logs: [
          BottleLogEntry(
            path: '/l/a.log',
            name: '$_longName.log',
            modified: DateTime(2026, 11, 4),
            exitCode: 42,
          ),
        ],
        installedBackends: const ['wine', 'dxmt', 'dxvk', 'd3dmetal'],
      ),
    );

final _backends = BackendsState(
  isLoading: false,
  backends: const [
    BackendInfo(name: 'wine', installed: true, downloadable: false),
    BackendInfo(name: 'dxmt', installed: false, downloadable: true),
    BackendInfo(name: 'dxvk', installed: true, downloadable: true),
    BackendInfo(name: 'd3dmetal', installed: false, downloadable: false),
  ],
  bottles: const ['prueba'],
  busy: 'dxmt',
  isDownloading: true,
  received: 50,
  total: 100,
  checking: 'dxvk',
  results: {
    'dxvk': [
      ProbeResult(bits: 64, d3d: '11', ok: true, log: '/l/$_longName.log'),
      ProbeResult(bits: 32, d3d: '11', ok: false, log: '/l/$_longName.log'),
    ],
  },
  error: AppError.engine(_long),
);

void main() {
  late _MockCatalog catalog;
  late _MockInstall install;
  late _MockLibrary library;
  late _MockBackends backends;
  late _MockBottles bottles;
  late _MockBottle bottle;
  late _MockAddApp addApp;
  late _MockSections sections;

  void showBottle(BottleDetailState state) => whenListen(
    bottle,
    const Stream<BottleDetailState>.empty(),
    initialState: state,
  );

  void showLibrary(LibraryState state) => whenListen(
    library,
    const Stream<LibraryState>.empty(),
    initialState: state,
  );

  setUp(() {
    backends = _MockBackends();
    bottles = _MockBottles();
    bottle = _MockBottle();
    addApp = _MockAddApp();
    catalog = _MockCatalog();
    install = _MockInstall();
    library = _MockLibrary();
    sections = _MockSections();
    whenListen(
      backends,
      const Stream<BackendsState>.empty(),
      initialState: _backends,
    );
    whenListen(
      bottles,
      const Stream<BottlesState>.empty(),
      initialState: BottlesState(
        isLoading: false,
        bottles: [Bottle(name: _longName, ready: true)],
      ),
    );
    whenListen(
      sections,
      const Stream<SectionsState>.empty(),
      initialState: const SectionsState(),
    );
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
    showBottle(_bottle());
    showLibrary(
      LibraryState(
        isLoading: false,
        apps: [
          LibraryApp(bottle: 'steam', key: 's', id: 'steam', title: _app.title),
          const LibraryApp(
            bottle: 'steam',
            key: 'steam:1',
            id: 'steam-game',
            title: 'Muck',
          ),
          const LibraryApp(
            bottle: 'blur',
            key: 'b',
            id: 'custom',
            title: 'Blur',
          ),
        ],
        open: {'steam', _longName},
        hints: {
          'steam': [_long],
          _longName: [_long],
        },
      ),
    );
  });

  List<BlocProvider> providers() => [
    BlocProvider<CatalogBloc>.value(value: catalog),
    BlocProvider<InstallBloc>.value(value: install),
    BlocProvider<LibraryBloc>.value(value: library),
    BlocProvider<BackendsBloc>.value(value: backends),
    BlocProvider<BottlesBloc>.value(value: bottles),
    BlocProvider<BottleDetailBloc>.value(value: bottle),
    BlocProvider<AddAppBloc>.value(value: addApp),
    BlocProvider<SectionsBloc>.value(value: sections),
  ];

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
        providers: providers(),
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

  Widget bottleView() => BottleDetailView(name: _longName);

  // The minimum window, the narrowest with two catalog columns, the default
  // one, and a big one.
  for (final width in [720.0, 801.0, 1150.0, 1921.0]) {
    testWidgets('nothing overflows at $width px', (tester) async {
      await pump(tester, width, const CatalogPage());
      await pump(tester, width, const CatalogDetailPage(id: 'steam'));
      await pump(tester, width, const LibraryPage());
      await pump(tester, width, bottleView());
      await pump(tester, width, const BackendsPage());
    });

    testWidgets('an empty or incomplete bottle fits at $width px', (
      tester,
    ) async {
      showBottle(_bottle(ready: false, apps: const []));
      await pump(tester, width, bottleView());
    });

    testWidgets('a bottle with its sections folded fits at $width px', (
      tester,
    ) async {
      whenListen(
        sections,
        const Stream<SectionsState>.empty(),
        initialState: const SectionsState(
          collapsed: {'actions', 'settings', 'details'},
        ),
      );
      await pump(tester, width, bottleView());
    });

    for (final step in [
      AddAppStep.form,
      AddAppStep.creating,
      AddAppStep.installing,
      AddAppStep.pickInstalled,
    ]) {
      testWidgets('adding an app at ${step.name} fits at $width px', (
        tester,
      ) async {
        whenListen(
          addApp,
          const Stream<AddAppState>.empty(),
          initialState: AddAppState(
            step: step,
            bottles: const ['prueba'],
            bottle: 'prueba',
            exe: '/g/$_longName$_longName.exe',
            title: 'Blur',
            error: AppError.engine(_long),
          ),
        );
        await pump(tester, width, const AddAppDialog());
      });
    }

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

  group('the bottle screen', () {
    testWidgets('the column goes beside when there is room', (tester) async {
      await pump(tester, 1150, bottleView());
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('and below when there is not', (tester) async {
      await pump(tester, 801, bottleView());
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('says the state of the bottle', (tester) async {
      await pump(tester, 1150, bottleView());
      expect(find.text('Abierta'), findsOneWidget);

      showBottle(_bottle(ready: false));
      await tester.pumpWidget(const SizedBox());
      await pump(tester, 1150, bottleView());
      expect(find.text('Incompleta'), findsOneWidget);
    });

    testWidgets('it stays closed when it is', (tester) async {
      showLibrary(const LibraryState());
      await pump(tester, 1150, bottleView());
      expect(find.text('Cerrada'), findsOneWidget);
      expect(find.text('Parar'), findsNothing);
    });

    testWidgets('an empty one invites to install', (tester) async {
      showBottle(_bottle(apps: const []));
      await pump(tester, 1150, bottleView(), height: 900);
      expect(find.text('Esta botella no tiene aplicaciones'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Instalar'), findsOneWidget);
    });

    testWidgets('a bottle that does not exist offers a way back', (
      tester,
    ) async {
      showBottle(
        const BottleDetailState(
          isLoading: false,
          error: AppError.engine('no existe la botella nope'),
        ),
      );
      await pump(tester, 1150, const BottleDetailView(name: 'nope'));
      expect(find.text('no existe la botella nope'), findsOneWidget);
      expect(find.text('Volver a Biblioteca'), findsOneWidget);
    });

    testWidgets('a folded section hides its content', (tester) async {
      whenListen(
        sections,
        const Stream<SectionsState>.empty(),
        initialState: const SectionsState(collapsed: {'settings'}),
      );
      await pump(tester, 1150, bottleView(), height: 1200);
      expect(find.text('Configuración avanzada'), findsOneWidget);
      expect(find.text('msync'), findsNothing);
      expect(find.text('Borrar botella'), findsOneWidget);
    });

    testWidgets('its applications open by their key', (tester) async {
      showBottle(
        _bottle(
          apps: [
            LibraryApp(
              bottle: _longName,
              key: 'steam:9',
              id: 'steam-game',
              title: 'Muck',
            ),
          ],
        ),
      );
      await pump(tester, 1150, bottleView(), height: 1200);
      await tester.tap(find.text('Muck'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Muck'));
      await tester.pump(const Duration(seconds: 1));
      verify(() => library.add(LibraryEvent.open(_longName, 'steam:9')))
          .called(1);
    });

    testWidgets('hiding one asks the bottle', (tester) async {
      showBottle(
        _bottle(
          apps: [
            LibraryApp(
              bottle: _longName,
              key: 'steam:9',
              id: 'steam-game',
              title: 'Muck',
            ),
          ],
        ),
      );
      await pump(tester, 1150, bottleView(), height: 1200);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocultar'));
      await tester.pumpAndSettle();
      verify(() => bottle.add(const BottleDetailEvent.hideApp('steam:9')))
          .called(1);
    });
  });

  group('the library', () {
    testWidgets('names the bottle, and says it is the bottle that is open', (
      tester,
    ) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      expect(find.text('Botella steam'), findsNWidgets(2));
      expect(find.text('Botella abierta'), findsNWidgets(2));
      expect(find.text('Parar botella'), findsNWidgets(2));
      expect(find.text('Abrir'), findsNWidgets(3));
    });

    testWidgets('shows a hint once per bottle', (tester) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      expect(find.text(_long), findsOneWidget);
    });

    testWidgets('opens the application asked', (tester) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      await tester.tap(find.text('Abrir').at(1));
      await tester.pump();
      verify(() => library.add(const LibraryEvent.open('steam', 'steam:1')))
          .called(1);
    });
  });

  testWidgets('D3DMetal is imported, never downloaded', (tester) async {
    await pump(tester, 1150, const BackendsPage(), height: 3000);
    final d3dmetal = find.ancestor(
      of: find.text('d3dmetal'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: d3dmetal, matching: find.text('Elegir carpeta…')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: d3dmetal, matching: find.text('Instalar')),
      findsNothing,
    );
    expect(find.textContaining('licencia de Apple'), findsOneWidget);
    expect(find.textContaining('CrossOver no se acepta'), findsOneWidget);
  });

  testWidgets('the detail offers each case', (tester) async {
    Future<void> showing(CatalogApp app) async {
      whenListen(
        catalog,
        const Stream<CatalogState>.empty(),
        initialState: CatalogState(isLoading: false, apps: [app]),
      );
      // A fresh tree, and tall enough for the list to build the button.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, 1150, CatalogDetailPage(id: app.id), height: 3000);
    }

    final free = _app.copyWith(bottle: null);
    await showing(free);
    expect(find.widgetWithText(FilledButton, 'Instalar'), findsOneWidget);

    await showing(_app.copyWith(appKey: 'program/x.exe'));
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

  testWidgets('the detail opens the application by its key', (tester) async {
    whenListen(
      catalog,
      const Stream<CatalogState>.empty(),
      initialState: CatalogState(
        isLoading: false,
        apps: [_app.copyWith(appKey: 'program/x.exe')],
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1150, 3000);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CatalogDetailPage(id: _app.id),
        ),
        GoRoute(path: '/library', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: providers(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir'));
    await tester.pumpAndSettle();
    verify(
      () => library.add(const LibraryEvent.open('ea-app', 'program/x.exe')),
    ).called(1);
    expect(router.state.matchedLocation, '/library');
  });

  group('the routes', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1150, 800);
      addTearDown(tester.view.reset);
      final setup = _MockSetup();
      whenListen(
        setup,
        const Stream<SetupState>.empty(),
        initialState: const SetupState(
          isChecking: false,
          rosetta: true,
          runtime: true,
        ),
      );
      final preferences = _MockPreferences();
      when(() => preferences.getDarkTheme()).thenReturn(null);
      final router = createRouter(setup);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            ...providers(),
            BlocProvider<ThemeBloc>(create: (_) => ThemeBloc(preferences)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => ResponsiveBreakpoints.builder(
              child: child!,
              breakpoints: appBreakpoints,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('the app starts at the library', (tester) async {
      final router = await pumpRouter(tester);
      expect(router.state.matchedLocation, '/library');
      expect(find.byType(LibraryPage), findsOneWidget);
    });

    testWidgets('/bottles leads to the library', (tester) async {
      final router = await pumpRouter(tester);
      router.go('/catalog');
      await tester.pumpAndSettle();
      router.go('/bottles');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/library');
    });
  });
}
