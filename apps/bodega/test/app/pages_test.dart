import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/bloc/run_options/run_options_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/add_app/add_app_dialog.dart';
import 'package:bodega/app/presentation/backends/backends_page.dart';
import 'package:bodega/app/presentation/bottles/bottle_detail_page.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_empty_apps.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/presentation/catalog/catalog_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_page.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/presentation/library/widgets/bottle_tag.dart';
import 'package:bodega/app/presentation/settings/settings_dialog.dart';
import 'package:bodega/app/presentation/setup/setup_page.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/hint_text.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/app/shared/widgets/install_panel.dart';
import 'package:bodega/app/shared/widgets/side_bar.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/backend_role.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/entities/install_step.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

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

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

class _MockRunOptions extends MockBloc<RunOptionsEvent, RunOptionsState>
    implements RunOptionsBloc {}

class _MockNewBottle extends MockBloc<NewBottleEvent, NewBottleState>
    implements NewBottleBloc {}

class _MockGamepads extends MockBloc<GamepadsEvent, GamepadsState>
    implements GamepadsBloc {}

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockLocale extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

// The longest texts and every chip at once: what would overflow first.
final _long = 'A long note that takes up several lines on the screen. ' * 6;

/// An error whose text holds [_long], with a detail: its panel also shows
/// Copy details (L9).
final _error = AppError.corruptData(_long, detail: 'stderr: boom');
final _longName = 'a-bottle-with-a-very-very-long-name-${'x' * 28}';

/// Every hint a bottle can get at once, the anti-cheat one for a game with a
/// long title: the most a bottle's card and page show.
final _hints = [
  for (final hint in LogHint.values) RunHint.log(hint),
  RunHint.antiCheat(game: _long),
];

/// Every chip at once. Its prose comes from the ARBs by id (L16): a copy as
/// Steam, the catalog's longest, and one as `custom`, which has none.
const _app = CatalogApp(
  id: 'ea-app',
  title: 'Rockstar Games Launcher with a name that would not fit the card',
  status: CatalogStatus.reported,
  flaky: true,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: false,
  source: {'repo': 'a/b', 'license': 'CC0-1.0', 'verified': null},
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
      title: 'Rogue with a really long title as well $_long',
      anticheats: const ['Easy Anti-Cheat', 'BattlEye', 'nProtect GameGuard'],
      verdict: AntiCheatVerdict.blocked,
    ),
  ],
  antiCheatError: const AppError.network(detail: 'no network'),
  error: _error,
);

List<LibraryApp> _apps(String bottle) => [
  for (var i = 0; i < 30; i++)
    LibraryApp(
      bottle: bottle,
      key: 'p/$i.exe',
      id: i.isEven ? 'steam' : 'custom',
      title: 'An application with a fairly long title too $i',
    ),
];

/// The messages of app_en.arb that a Spanish screen must not show: their
/// Spanish differs, so one on screen is an English literal left in the code
/// (L1). Messages with placeholders or ICU syntax cannot be matched as
/// literals, and a text that is also a Spanish message is not one.
final Set<String> _englishOnly = () {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  final spanish = arb('es').values.toSet();
  return {
    for (final MapEntry(:key, :value) in arb('en').entries)
      if (!key.startsWith('@') &&
          value is String &&
          !value.contains('{') &&
          !spanish.contains(value))
        value,
  };
}();

/// Fails when a text, a text field or a tooltip on screen shows one of
/// [_englishOnly] (L1). Every `Text` builds a `RichText`, and a
/// `SelectableText` an `EditableText`.
void _expectNoEnglishLiterals(WidgetTester tester) {
  final shown = <String>{};
  void add(String? text) {
    if (text != null) shown.add(text.trim());
  }

  void addSpans(InlineSpan? span) => span?.visitChildren((child) {
    if (child is TextSpan) add(child.text);
    return true;
  });

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    add(rich.text.toPlainText());
    addSpans(rich.text);
  }
  for (final field in tester.widgetList<EditableText>(
    find.byType(EditableText),
  )) {
    add(field.controller.text);
  }
  for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    add(tip.message);
    add(tip.richMessage?.toPlainText());
    addSpans(tip.richMessage);
  }
  expect(
    shown.intersection(_englishOnly),
    isEmpty,
    reason: 'English messages of app_en.arb on a Spanish screen (L1)',
  );
}

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

/// A pad Bodega cannot open, by a long name, and no SDL2: the two issue cards
/// of a bottle's controllers section.
final _padIssues = GamepadsState(
  isLoading: false,
  report: GamepadReport(
    pads: [Gamepad(name: _longName, vid: '045e', pid: '028e', readable: false)],
    sdl: false,
    issues: [
      HostIssue(
        kind: HostIssueKind.padNoAccess,
        subject: _longName,
        command: 'sudo apt install steam-devices',
      ),
      const HostIssue(
        kind: HostIssueKind.noSdl,
        command: 'sudo apt install libsdl2-2.0-0',
      ),
    ],
  ),
);

final _backends = BackendsState(
  isLoading: false,
  backends: const [
    // Wine's is the longest role.
    BackendInfo(
      name: 'wine',
      installed: true,
      downloadable: false,
      role: BackendRole.everythingElse,
    ),
    BackendInfo(
      name: 'dxmt',
      installed: false,
      downloadable: true,
      role: BackendRole.dx10to11,
    ),
    BackendInfo(name: 'dxvk', installed: true, downloadable: true),
    BackendInfo(name: 'd3dmetal', installed: false, downloadable: false),
  ],
  bottles: const ['test'],
  releases: const [
    GptkRelease(version: '3.0', tested: true, url: 'https://x'),
    GptkRelease(version: '4.0', tested: false, url: 'https://y'),
  ],
  busy: 'dxmt',
  isDownloading: true,
  received: 1234000000,
  total: 2468000000,
  checking: 'dxvk',
  results: {
    'dxvk': [
      ProbeResult(bits: 64, d3d: '11', ok: true, log: '/l/$_longName.log'),
      ProbeResult(bits: 32, d3d: '11', ok: false, log: '/l/$_longName.log'),
    ],
  },
  error: _error,
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockCatalog catalog;
  late _MockInstall install;
  late _MockUpdate updates;
  late _MockLibrary library;
  late _MockBackends backends;
  late _MockBottles bottles;
  late _MockBottle bottle;
  late _MockAddApp addApp;
  late _MockSections sections;
  late _MockGamepads gamepads;
  late _MockViewMode viewMode;
  late _MockSetup setup;

  void showBottle(BottleDetailState state) => whenListen(
    bottle,
    const Stream<BottleDetailState>.empty(),
    initialState: state,
  );

  void showSetup(SetupState state) =>
      whenListen(setup, const Stream<SetupState>.empty(), initialState: state);

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
    updates = _MockUpdate();
    when(() => updates.state).thenReturn(const UpdateState());
    library = _MockLibrary();
    sections = _MockSections();
    setup = _MockSetup();
    gamepads = _MockGamepads();
    when(() => gamepads.state)
        .thenReturn(const GamepadsState(isLoading: false));
    showSetup(const SetupState(isChecking: false, runtime: true));
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
    viewMode = _MockViewMode();
    whenListen(
      viewMode,
      const Stream<ViewModeState>.empty(),
      initialState: const ViewModeState(),
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
        hints: {'steam': _hints, _longName: _hints},
      ),
    );
  });

  List<BlocProvider> providers() => [
    BlocProvider<CatalogBloc>.value(value: catalog),
    BlocProvider<InstallBloc>.value(value: install),
    BlocProvider<UpdateBloc>.value(value: updates),
    BlocProvider<LibraryBloc>.value(value: library),
    BlocProvider<BackendsBloc>.value(value: backends),
    BlocProvider<BottlesBloc>.value(value: bottles),
    BlocProvider<BottleDetailBloc>.value(value: bottle),
    BlocProvider<AddAppBloc>.value(value: addApp),
    BlocProvider<SectionsBloc>.value(value: sections),
    BlocProvider<GamepadsBloc>.value(value: gamepads),
    BlocProvider<ViewModeBloc>.value(value: viewMode),
    BlocProvider<SetupBloc>.value(value: setup),
  ];

  // [width] is the window's: the sidebar takes its part, as in the app. In
  // Spanish, the page must also show no English message of the ARBs (L1).
  Future<void> pump(
    WidgetTester tester,
    double width,
    Widget page, {
    double height = 480,
    bool light = false,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: providers(),
        child: wrapApp(
          Row(
            children: [
              SizedBox(width: width > 800 ? 220 : 68),
              Expanded(child: page),
            ],
          ),
          locale: locale,
          theme: light ? AppTheme.getLightTheme() : AppTheme.getDarkTheme(),
          breakpoints: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (locale.languageCode == 'es') _expectNoEnglishLiterals(tester);
  }

  Widget bottleView() => BottleDetailView(name: _longName);

  // There is no switch yet, but the light theme must be ready for one.
  testWidgets('every screen renders with the light theme', (tester) async {
    for (final width in [720.0, 1150.0]) {
      await pump(tester, width, const CatalogPage(), light: true);
      await pump(tester, width, const LibraryPage(), light: true);
      await pump(tester, width, bottleView(), light: true);
      await pump(tester, width, const BackendsPage(), light: true);
    }
    final context = tester.element(find.byType(BackendsPage));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  // The minimum window, the narrowest with two catalog columns, the default
  // one, and a big one, each in English and in Spanish (N11, L18).
  for (final locale in const [Locale('en'), Locale('es')]) {
    final lang = '(${locale.languageCode})';
    for (final width in [720.0, 801.0, 1150.0, 1921.0]) {
      // Every case below pumps through this: its width, in its language.
      Future<void> pumpAt(WidgetTester tester, Widget page) =>
          pump(tester, width, page, locale: locale);

      testWidgets('nothing overflows at $width px $lang', (tester) async {
        await pumpAt(tester, const CatalogPage());
        await pumpAt(tester, const CatalogDetailPage(id: 'steam'));
        await pumpAt(tester, const LibraryPage());
        await pumpAt(tester, bottleView());
        await pumpAt(tester, const BackendsPage());
      });

      testWidgets('an empty or incomplete bottle fits at $width px $lang', (
        tester,
      ) async {
        showBottle(_bottle(ready: false, apps: const []));
        await pumpAt(tester, bottleView());
      });

      testWidgets('an empty library fits at $width px $lang', (tester) async {
        whenListen(
          library,
          const Stream<LibraryState>.empty(),
          initialState: const LibraryState(),
        );
        await pumpAt(tester, const LibraryPage());
      });

      testWidgets('a bottle with its sections folded fits at $width px $lang', (
        tester,
      ) async {
        whenListen(
          sections,
          const Stream<SectionsState>.empty(),
          initialState: const SectionsState(
            collapsed: {'actions', 'settings', 'details'},
          ),
        );
        await pumpAt(tester, bottleView());
      });

      testWidgets("a bottle's controller issues fit at $width px $lang", (
        tester,
      ) async {
        showBottle(_bottle(apps: const []));
        when(() => gamepads.state).thenReturn(_padIssues);
        await pumpAt(tester, bottleView());
        // Narrow, the panel goes under the apps, in a list that builds it
        // only once it scrolls near.
        final title = find.text(
          lookupAppL10n(locale).issuePadNoAccessTitle(_longName),
        );
        await tester.scrollUntilVisible(
          title,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // The pad is named, in the active language (E15), and its cards show
        // no English message (L1).
        expect(title, findsOneWidget);
        if (locale.languageCode == 'es') _expectNoEnglishLiterals(tester);
      });

      testWidgets('running with options fits at $width px $lang', (
        tester,
      ) async {
        final options = _MockRunOptions();
        whenListen(
          options,
          const Stream<RunOptionsState>.empty(),
          initialState: RunOptionsState(
            bottle: 'steam',
            program: '/g/$_longName$_longName.exe',
            env: 'A=1',
            save: true,
            error: _error,
          ),
        );
        await pumpAt(
          tester,
          BlocProvider<RunOptionsBloc>.value(
            value: options,
            child: const RunOptionsDialog(backends: ['dxmt', 'dxvk']),
          ),
        );
      });

      for (final step in [
        AddAppStep.form,
        AddAppStep.installing,
        AddAppStep.pickInstalled,
      ]) {
        testWidgets('adding an app at ${step.name} fits at $width px $lang', (
          tester,
        ) async {
          whenListen(
            addApp,
            const Stream<AddAppState>.empty(),
            initialState: AddAppState(
              step: step,
              bottle: 'games',
              exe: '/g/$_longName$_longName.exe',
              title: 'Blur',
              error: _error,
            ),
          );
          await pumpAt(tester, const AddAppDialog());
        });
      }

      for (final phase in [
        InstallPhase.downloading,
        InstallPhase.installing,
        InstallPhase.done,
        InstallPhase.failed,
      ]) {
        testWidgets('the ${phase.name} panel fits at $width px $lang', (
          tester,
        ) async {
          whenListen(
            install,
            const Stream<InstallState>.empty(),
            initialState: InstallState(
              phase: phase,
              app: _app,
              received: 150 << 20,
              total: 300 << 20,
              // The longest step: it names the app and two syncs.
              step: InstallStep.syncMismatch(_long),
              error: _error,
              bottleLeft: phase == InstallPhase.failed,
            ),
          );
          await pumpAt(
            tester,
            const Scaffold(
              body: Column(
                children: [
                  Expanded(child: SizedBox.expand()),
                  InstallPanel(),
                ],
              ),
            ),
          );
          // MB of 10^6 bytes (L13): 150 × 2^20 bytes are 157 MB.
          if (phase == InstallPhase.downloading) {
            expect(find.textContaining('157 MB'), findsOneWidget);
            expect(find.textContaining('150 MB'), findsNothing);
          }
          // The app is installed: the catalog chip's word, for the same app
          // (L15).
          if (phase == InstallPhase.done) {
            expect(
              find.text(lookupAppL10n(locale).catalogAppInstalled),
              findsOneWidget,
            );
          }
        });
      }

      testWidgets('a D3DMetal import fits at $width px $lang', (tester) async {
        whenListen(
          backends,
          const Stream<BackendsState>.empty(),
          initialState: _backends.copyWith(
            busy: 'd3dmetal',
            isDownloading: false,
            // The longest step.
            gptkStep: GptkStep.acceptLicense,
          ),
        );
        // Tall enough for the list to build D3DMetal's card, the last one.
        await pump(
          tester,
          width,
          const BackendsPage(),
          height: 3000,
          locale: locale,
        );
        expect(
          find.text(lookupAppL10n(locale).stepGptkAcceptLicense),
          findsOneWidget,
        );
      });

      testWidgets('the Settings dialog fits at $width px $lang', (
        tester,
      ) async {
        final language = _MockLocale();
        whenListen(
          language,
          const Stream<LocaleState>.empty(),
          initialState: const LocaleState(),
        );
        await pumpAt(
          tester,
          BlocProvider<LocaleBloc>.value(
            value: language,
            child: const SettingsDialog(),
          ),
        );
        // Its three choices, and Close on screen.
        expect(find.byType(RadioListTile<String?>), findsNWidgets(3));
        expect(
          find.text(lookupAppL10n(locale).commonClose).hitTestable(),
          findsOneWidget,
        );
      });
    }
  }

  // An error's detail is copied, never shown (L9): each error panel of design
  // §6 shows one failure, with a tool's stderr as its detail and without.
  group('copy details (L9)', () {
    const detail = 'stderr: boom';
    const failed = AppError.processFailed('/usr/bin/hdiutil', 1);
    const withDetail = AppError.processFailed(
      '/usr/bin/hdiutil',
      1,
      detail: detail,
    );

    /// Pumps [page] in the narrowest window, tall enough for each panel.
    Future<void> pumpPanel(WidgetTester tester, Widget page, Locale locale) =>
        pump(tester, 720, page, height: 1200, locale: locale);

    /// Each error panel, showing an error where the user sees it.
    final panels =
        <String, Future<void> Function(WidgetTester, AppError, Locale)>{
          'the install panel': (tester, error, locale) {
            whenListen(
              install,
              const Stream<InstallState>.empty(),
              initialState: InstallState(
                phase: InstallPhase.failed,
                app: _app,
                error: error,
              ),
            );
            return pumpPanel(
              tester,
              const Scaffold(
                body: Column(
                  children: [
                    Expanded(child: SizedBox.expand()),
                    InstallPanel(),
                  ],
                ),
              ),
              locale,
            );
          },
          'the Backends page': (tester, error, locale) {
            whenListen(
              backends,
              const Stream<BackendsState>.empty(),
              initialState: BackendsState(isLoading: false, error: error),
            );
            return pumpPanel(tester, const BackendsPage(), locale);
          },
          'the catalog': (tester, error, locale) {
            whenListen(
              catalog,
              const Stream<CatalogState>.empty(),
              initialState: CatalogState(isLoading: false, error: error),
            );
            return pumpPanel(tester, const CatalogPage(), locale);
          },
          'the setup page': (tester, error, locale) {
            showSetup(
              SetupState(isChecking: false, runtime: true, error: error),
            );
            return pumpPanel(tester, const SetupPage(), locale);
          },
          'the new-bottle dialog': (tester, error, locale) {
            final newBottle = _MockNewBottle();
            whenListen(
              newBottle,
              const Stream<NewBottleState>.empty(),
              initialState: NewBottleState(name: 'games', error: error),
            );
            return pumpPanel(
              tester,
              BlocProvider<NewBottleBloc>.value(
                value: newBottle,
                child: const NewBottleDialog(),
              ),
              locale,
            );
          },
          'running with options': (tester, error, locale) {
            final options = _MockRunOptions();
            whenListen(
              options,
              const Stream<RunOptionsState>.empty(),
              initialState: RunOptionsState(
                bottle: 'steam',
                program: '/g/Blur.exe',
                error: error,
              ),
            );
            return pumpPanel(
              tester,
              BlocProvider<RunOptionsBloc>.value(
                value: options,
                child: const RunOptionsDialog(backends: ['dxvk']),
              ),
              locale,
            );
          },
          'the add-app dialog': (tester, error, locale) {
            whenListen(
              addApp,
              const Stream<AddAppState>.empty(),
              initialState: AddAppState(bottle: 'games', error: error),
            );
            return pumpPanel(tester, const AddAppDialog(), locale);
          },
          // The catalog's own error, on the tab that lists it when it could
          // not load.
          "the add-app dialog's catalog tab": (tester, error, locale) async {
            whenListen(
              catalog,
              const Stream<CatalogState>.empty(),
              initialState: CatalogState(isLoading: false, error: error),
            );
            whenListen(
              addApp,
              const Stream<AddAppState>.empty(),
              initialState: const AddAppState(bottle: 'games'),
            );
            await pumpPanel(tester, const AddAppDialog(), locale);
            await tester.tap(find.text(lookupAppL10n(locale).addAppTabOthers));
            await tester.pump();
          },
        };

    /// What the app puts on the clipboard while the test runs.
    List<Object?> clipboard(WidgetTester tester) {
      final copied = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text']);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return copied;
    }

    for (final locale in const [Locale('en'), Locale('es')]) {
      final l10n = lookupAppL10n(locale);
      final lang = '(${locale.languageCode})';
      final message = l10n.errProcessFailed('/usr/bin/hdiutil', 1);

      for (final MapEntry(key: panel, value: show) in panels.entries) {
        testWidgets('$panel copies the detail, and never shows it $lang', (
          tester,
        ) async {
          final copied = clipboard(tester);
          await show(tester, withDetail, locale);
          expect(find.text(message), findsOneWidget);
          expect(find.textContaining('boom', findRichText: true), findsNothing);

          final button = find.text(l10n.commonCopyDetails);
          await tester.ensureVisible(button);
          await tester.tap(button);
          // The copy, then the toast, which slides in.
          await tester.pumpAndSettle();
          expect(copied, [detail]);
          expect(find.text(l10n.commonCopied), findsOneWidget);
          // The toast says only that: the detail stays off the screen.
          expect(find.textContaining('boom', findRichText: true), findsNothing);
          // It closes by itself.
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        });

        testWidgets('$panel has nothing to copy without a detail $lang', (
          tester,
        ) async {
          await show(tester, failed, locale);
          expect(find.text(message), findsOneWidget);
          expect(find.text(l10n.commonCopyDetails), findsNothing);
        });
      }
    }
  });

  group('the bottle screen', () {
    // The panel is the box of its width: it is only there when it is beside.
    final panel = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == BottleDetailView.panelWidth,
    );

    testWidgets('the column goes beside when there is room', (tester) async {
      await pump(tester, 1150, bottleView());
      expect(panel, findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(BottleColumn)).dx,
        greaterThanOrEqualTo(tester.getTopLeft(panel).dx),
      );
    });

    testWidgets('and below when there is not', (tester) async {
      showBottle(_bottle(apps: const []));
      await pump(tester, 801, bottleView(), height: 1200);
      expect(panel, findsNothing);
      expect(
        tester.getTopLeft(find.byType(BottleColumn)).dy,
        greaterThan(tester.getTopLeft(find.text('Installed apps')).dy),
      );
    });

    testWidgets('says the state of the bottle', (tester) async {
      await pump(tester, 1150, bottleView());
      expect(find.text('Open'), findsOneWidget);

      showBottle(_bottle(ready: false));
      await tester.pumpWidget(const SizedBox());
      await pump(tester, 1150, bottleView());
      expect(find.text('Incomplete'), findsOneWidget);
    });

    testWidgets('it stays closed when it is', (tester) async {
      showLibrary(const LibraryState());
      await pump(tester, 1150, bottleView());
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text(en.commonStop), findsNothing);
    });

    testWidgets('an empty one invites to install', (tester) async {
      showBottle(_bottle(apps: const []));
      await pump(tester, 1150, bottleView(), height: 900);
      expect(find.text('This bottle is empty'), findsOneWidget);
      final invite = find.descendant(
        of: find.byType(BottleEmptyApps),
        matching: find.byType(GradientButton),
      );
      expect(tester.widget<GradientButton>(invite).onPressed, isNotNull);
    });

    testWidgets('a bottle that does not exist offers a way back', (
      tester,
    ) async {
      showBottle(
        const BottleDetailState(
          isLoading: false,
          error: AppError.bottleNotFound('nope'),
        ),
      );
      await pump(tester, 1150, const BottleDetailView(name: 'nope'));
      expect(find.text(en.errBottleNotFound('nope')), findsOneWidget);
      expect(find.text('Back to Library'), findsOneWidget);
    });

    testWidgets('each control panel runs its program', (tester) async {
      await pump(tester, 1150, bottleView(), height: 2400);
      await tester.tap(find.text('Game controllers'));
      await tester.tap(find.text('Wine configuration'));
      await tester.tap(find.text('Terminal'));
      await tester.pump();
      verify(
        () => library.add(LibraryEvent.run(_longName, 'control', ['joy.cpl'])),
      ).called(1);
      verify(() => library.add(LibraryEvent.run(_longName, 'winecfg', [])))
          .called(1);
      verify(
        () => library.add(LibraryEvent.run(_longName, 'wineconsole', ['cmd'])),
      ).called(1);
    });

    testWidgets('the settings show what the bottle has', (tester) async {
      await pump(tester, 1150, bottleView(), height: 2400);
      // The fact card and the selected version of the dropdown both say it.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('windows win10')),
          matching: find.text('Windows 10'),
        ),
        findsOneWidget,
      );
      expect(find.text('High-density display'), findsOneWidget);
      expect(find.text('DLSS'), findsOneWidget);
      expect(find.text('Advertise AVX'), findsOneWidget);
    });

    testWidgets('a host without AVX or DLSS does not offer them', (
      tester,
    ) async {
      showSetup(
        const SetupState(
          isChecking: false,
          runtime: true,
          capabilities: HostCapabilities(avx: false, dlss: false),
        ),
      );
      await pump(tester, 1150, bottleView(), height: 2400);
      expect(find.text(en.bottleAvx), findsNothing);
      expect(find.text('DLSS'), findsNothing);
    });

    testWidgets('a host with one sync mode does not offer msync', (
      tester,
    ) async {
      await pump(tester, 1150, bottleView(), height: 2400);
      expect(find.text('Changing it closes what is open.'), findsOneWidget);

      showSetup(
        const SetupState(
          isChecking: false,
          runtime: true,
          capabilities: HostCapabilities(syncModes: ['none']),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await pump(tester, 1150, bottleView(), height: 2400);
      expect(find.text(en.bottleChangeCloses), findsNothing);
    });

    testWidgets('an incomplete bottle offers only to delete it', (
      tester,
    ) async {
      showBottle(_bottle(ready: false));
      await pump(tester, 1150, bottleView(), height: 2400);
      // The quick actions and the delete button are outlined buttons.
      Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final run = tester.widget<ButtonStyleButton>(button('Run with options…'));
      expect(run.onPressed, isNull);
      final delete = tester.widget<ButtonStyleButton>(button('Delete bottle'));
      expect(delete.onPressed, isNotNull);
    });

    testWidgets('a folded section hides its content', (tester) async {
      whenListen(
        sections,
        const Stream<SectionsState>.empty(),
        initialState: const SectionsState(collapsed: {'settings'}),
      );
      await pump(tester, 1150, bottleView(), height: 1200);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('msync'), findsNothing);
      expect(find.text('Delete bottle'), findsOneWidget);
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
      // Not running: a running application does not take a double click.
      showLibrary(const LibraryState());
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
      await tester.tap(find.text('Remove from bottle'));
      await tester.pumpAndSettle();
      verify(() => bottle.add(const BottleDetailEvent.hideApp('steam:9')))
          .called(1);
    });
  });

  group('the library', () {
    testWidgets('names the bottle, and says which of its apps run', (
      tester,
    ) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      expect(find.text('steam'), findsNWidgets(2));
      expect(find.text('Running'), findsNWidgets(2));
      expect(find.byTooltip('Stop'), findsNWidgets(2));
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('shows a hint once per bottle', (tester) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      // The hints are the warning's tooltip: one per bottle, on its first app.
      final words = [for (final hint in _hints) hint.localized(en)];
      expect(find.byTooltip(words.join('\n')), findsOneWidget);
    });

    testWidgets('opens the application asked', (tester) async {
      await pump(tester, 1150, const LibraryPage(), height: 1200);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      verify(() => library.add(const LibraryEvent.open('blur', 'b'))).called(1);
    });
  });

  testWidgets('D3DMetal lists the Game Porting Toolkit versions (I1)', (
    tester,
  ) async {
    await pump(tester, 1150, const BackendsPage(), height: 3000);
    final d3dmetal = find.ancestor(
      of: find.text('d3dmetal'),
      matching: find.byType(Card),
    );
    Finder inCard(String text) =>
        find.descendant(of: d3dmetal, matching: find.text(text));
    expect(inCard('Game Porting Toolkit 3.0'), findsOneWidget);
    expect(inCard('Tested'), findsOneWidget);
    expect(inCard('Beta, untested'), findsOneWidget);
    expect(inCard('Install'), findsNWidgets(2));
    expect(inCard('I already have it: choose the dmg…'), findsOneWidget);
    expect(find.textContaining('you accept its license'), findsOneWidget);
  });

  // The states keep codes, so a language switch rewords what is already on
  // screen: the same state, pumped in English and then in Spanish (L6).
  testWidgets('a language switch rewords a step, an error and a hint (L6)', (
    tester,
  ) async {
    final es = lookupAppL10n(const Locale('es'));

    /// Pumps [page] in English, then in Spanish over the same tree. Each of
    /// [words] is an (English, Spanish) pair of finders: each finds one
    /// widget in its own language, and the English one none in Spanish.
    Future<void> switches(Widget page, List<(Finder, Finder)> words) async {
      await pump(tester, 1150, page, height: 3000);
      for (final (english, _) in words) {
        expect(english, findsOneWidget);
      }
      await pump(tester, 1150, page, height: 3000, locale: const Locale('es'));
      for (final (english, spanish) in words) {
        expect(spanish, findsOneWidget);
        expect(english, findsNothing);
      }
    }

    /// A text on screen, in English and in Spanish.
    (Finder, Finder) texts(String english, String spanish) =>
        (find.text(english), find.text(spanish));

    /// The tooltip of a bottle tag's warning, holding [text] among its lines.
    Finder tagTooltip(String text) => find.descendant(
      of: find.byType(BottleTag),
      matching: find.byWidgetPredicate(
        (widget) => widget is Tooltip && (widget.message ?? '').contains(text),
        description: 'tooltip holding "$text"',
      ),
    );

    // An install panel with its step.
    whenListen(
      install,
      const Stream<InstallState>.empty(),
      initialState: const InstallState(
        phase: InstallPhase.installing,
        app: _app,
        step: InstallStep.creatingBottle('ea-app'),
      ),
    );
    await switches(
      const Scaffold(
        body: Column(
          children: [
            Expanded(child: SizedBox.expand()),
            InstallPanel(),
          ],
        ),
      ),
      [texts(en.stepCreatingBottle('ea-app'), es.stepCreatingBottle('ea-app'))],
    );

    // The library: the tag of a bottle with hints has a warning whose
    // tooltip holds them, one per line.
    await tester.pumpWidget(const SizedBox());
    await switches(const LibraryPage(), [
      for (final hint in _hints)
        (tagTooltip(hint.localized(en)), tagTooltip(hint.localized(es))),
    ]);

    // The Backends page with its error, and D3DMetal's card with its step.
    whenListen(
      backends,
      const Stream<BackendsState>.empty(),
      initialState: _backends.copyWith(
        busy: 'd3dmetal',
        isDownloading: false,
        gptkStep: GptkStep.importing,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await switches(const BackendsPage(), [
      texts(en.stepGptkImporting, es.stepGptkImporting),
      texts(_error.localized(en), _error.localized(es)),
    ]);

    // A bottle's page with the hints of its last run.
    await tester.pumpWidget(const SizedBox());
    await switches(bottleView(), [
      for (final hint in _hints) texts(hint.localized(en), hint.localized(es)),
    ]);
  });

  testWidgets('a backend download shows the shared progress text (L15)', (
    tester,
  ) async {
    await pump(tester, 1150, const BackendsPage(), height: 3000);
    expect(
      find.text('Downloading · 50% · 1,234 MB of 2,468 MB'),
      findsOneWidget,
    );

    // Without a total, only what arrived.
    whenListen(
      backends,
      const Stream<BackendsState>.empty(),
      initialState: _backends.copyWith(total: null),
    );
    await tester.pumpWidget(const SizedBox());
    await pump(tester, 1150, const BackendsPage(), height: 3000);
    expect(find.text('Downloading · 1,234 MB'), findsOneWidget);
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
    expect(find.widgetWithText(FilledButton, 'Install'), findsOneWidget);

    await showing(_app.copyWith(appKey: 'program/x.exe'));
    expect(find.widgetWithText(FilledButton, 'Open'), findsOneWidget);

    await showing(free.copyWith(status: CatalogStatus.blocked));
    final blocked = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Install'),
    );
    expect(blocked.onPressed, isNull);
    expect(find.textContaining("can't be installed"), findsOneWidget);

    await showing(free.copyWith(backendInstalled: false));
    expect(find.widgetWithText(FilledButton, 'Install dxmt'), findsOneWidget);
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
      MultiBlocProvider(providers: providers(), child: wrapRouter(router)),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await tester.pumpAndSettle();
    verify(
      () => library.add(const LibraryEvent.open('ea-app', 'program/x.exe')),
    ).called(1);
    expect(router.state.matchedLocation, '/library');
  });

  // A catalog page words its prose by app id, in the active language (L16).
  for (final locale in const [Locale('en'), Locale('es')]) {
    final lang = '(${locale.languageCode})';

    testWidgets('the Steam page shows its prose $lang', (tester) async {
      final l10n = lookupAppL10n(locale);
      List<String> texts(CatalogProse prose) => [
        prose.statusNote,
        ...prose.notes,
        for (final (symptom, fix) in prose.issues) ...[symptom, fix],
      ];

      await pump(
        tester,
        1150,
        const CatalogDetailPage(id: 'steam'),
        height: 3000,
        locale: locale,
      );
      for (final text in texts(catalogProse('steam', l10n)!)) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      if (locale.languageCode != 'en') {
        for (final text in texts(catalogProse('steam', en)!)) {
          expect(find.text(text), findsNothing, reason: text);
        }
      }
      // A source field with no data says so, in words of the ARBs.
      expect(
        find.text(
          l10n.catalogSourceLine(
            l10n.catalogSourceVerified,
            l10n.catalogSourceNoData,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unstable app says why on its page $lang', (tester) async {
      final l10n = lookupAppL10n(locale);
      whenListen(
        catalog,
        const Stream<CatalogState>.empty(),
        initialState: const CatalogState(isLoading: false, apps: [_app]),
      );
      await pump(
        tester,
        1150,
        CatalogDetailPage(id: _app.id),
        height: 3000,
        locale: locale,
      );
      expect(find.text(l10n.catalogFlaky), findsOneWidget);
      expect(find.text(catalogProse(_app.id, l10n)!.flaky!), findsOneWidget);
    });
  }

  testWidgets('an app with no prose shows its page without it', (tester) async {
    await pump(
      tester,
      1150,
      const CatalogDetailPage(id: 'custom'),
      height: 3000,
    );
    expect(find.text(en.catalogConfigSection), findsOneWidget);
    expect(find.text(en.catalogNotesSection), findsNothing);
    expect(find.text(en.catalogKnownIssuesSection), findsNothing);
  });

  testWidgets('a blocked app reads alike in the catalog and in the add-app '
      'dialog (L15)', (tester) async {
    whenListen(
      catalog,
      const Stream<CatalogState>.empty(),
      initialState: CatalogState(
        isLoading: false,
        apps: [_app.copyWith(status: CatalogStatus.blocked, bottle: null)],
      ),
    );
    whenListen(
      addApp,
      const Stream<AddAppState>.empty(),
      initialState: const AddAppState(bottle: 'games'),
    );
    final es = lookupAppL10n(const Locale('es'));
    for (final (locale, others, label) in [
      (const Locale('en'), 'Others', 'Not supported'),
      (const Locale('es'), es.addAppTabOthers, es.catalogStatusBlocked),
    ]) {
      // The catalog's chips, in the narrowest window.
      await pump(tester, 720, const CatalogPage(), locale: locale);
      expect(find.text(label), findsOneWidget, reason: '$locale catalog');

      // The add-app dialog's card, on its tab.
      await pump(tester, 720, const AddAppDialog(), locale: locale);
      await tester.tap(find.text(others));
      await tester.pump();
      expect(find.text(label), findsOneWidget, reason: '$locale add-app');
      if (locale.languageCode == 'es') _expectNoEnglishLiterals(tester);
    }
  });

  group('the routes', () {
    Future<GoRouter> pumpRouter(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1150, 800);
      addTearDown(tester.view.reset);
      final router = createRouter(setup);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [...providers()],
          child: wrapRouter(router, locale: locale, breakpoints: true),
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

    testWidgets('a bottle of the sidebar opens it, and marks it', (
      tester,
    ) async {
      getIt.registerFactory<BottleDetailBloc>(() => bottle);
      addTearDown(() => getIt.unregister<BottleDetailBloc>());
      getIt.registerFactory<GamepadsBloc>(() => gamepads);
      addTearDown(() => getIt.unregister<GamepadsBloc>());
      final router = await pumpRouter(tester);
      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/bottles/$_longName');
      expect(find.byType(BottleDetailView), findsOneWidget);
      expect(
        tester.widget<SideBar>(find.byType(SideBar)).location,
        '/bottles/$_longName',
      );
    });

    testWidgets('/bottles leads to the library', (tester) async {
      final router = await pumpRouter(tester);
      router.go('/catalog');
      await tester.pumpAndSettle();
      router.go('/bottles');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/library');
    });

    // go_router's own page would say "Page Not Found", in English (L7).
    for (final locale in const [Locale('en'), Locale('es')]) {
      testWidgets('an unknown path says so, with a way back '
          '(${locale.languageCode})', (tester) async {
        final l10n = lookupAppL10n(locale);
        final router = await pumpRouter(tester, locale: locale);
        router.go('/nope');
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text(l10n.routeNotFoundTitle), findsOneWidget);
        expect(find.text(l10n.routeNotFoundMessage('/nope')), findsOneWidget);
        expect(find.text('Page Not Found'), findsNothing);
        if (locale.languageCode == 'es') _expectNoEnglishLiterals(tester);

        await tester.tap(find.text(l10n.navBackToLibrary));
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, '/library');
      });
    }
  });
}
