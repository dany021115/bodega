// The Switch page (switch-support SA13 to SA16): its status panel, its games
// and Add games, over a mocked SwitchBloc, a fake picker that records and
// answers the calls of file_selector, and a fake browser that records the
// pages url_launcher opens.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/presentation/switch/switch_page.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_game_menu.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_status_panel.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/pump.dart';

class _MockSwitch extends MockBloc<SwitchEvent, SwitchState>
    implements SwitchBloc {}

/// A call to a picker: which one, its type groups and where it opened.
typedef _PickerCall = ({
  String picker,
  List<XTypeGroup> groups,
  String? initialDirectory,
});

/// file_selector's pickers: each call is recorded, and answered with
/// [answer], or cancelled while it is null.
class _FakePicker extends FileSelectorPlatform {
  final calls = <_PickerCall>[];
  List<String>? answer;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls.add((
      picker: 'openFile',
      groups: acceptedTypeGroups ?? const [],
      initialDirectory: initialDirectory,
    ));
    final paths = answer;
    return paths == null ? null : XFile(paths.single);
  }

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls.add((
      picker: 'openFiles',
      groups: acceptedTypeGroups ?? const [],
      initialDirectory: initialDirectory,
    ));
    return [for (final path in answer ?? const <String>[]) XFile(path)];
  }

  @override
  Future<String?> getDirectoryPathWithOptions(FileDialogOptions options) async {
    calls.add((
      picker: 'getDirectoryPath',
      groups: const [],
      initialDirectory: options.initialDirectory,
    ));
    return answer?.single;
  }
}

/// url_launcher's platform: it records each page it is asked to open, and
/// opens none.
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

const _extensions = ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'];

/// Ryubing's official download page, as the engine's table gives it.
const _page = 'https://ryujinx.app/download';

/// Ryubing in /Applications, with its keys and its firmware.
const _found = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  install: EmulatorInstall(app: '/Applications/Ryujinx.app', version: '1.3.3'),
  keys: true,
  firmware: true,
  extensions: _extensions,
);

/// No Ryubing in the Applications folders and none picked, and no keys or
/// firmware.
const _missing = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  keys: false,
  firmware: false,
  extensions: _extensions,
);

/// A copy picked elsewhere, never opened, that gives no version.
const _pickedApp = '/Users/me/Emulators/Ryujinx.app';
const _picked = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  install: EmulatorInstall(app: _pickedApp, picked: true, quarantined: true),
  keys: false,
  firmware: false,
  extensions: _extensions,
);

String _note(String name) =>
    "If $name doesn't start, open it once from the Finder. If macOS blocks "
    'it, allow it in System Settings > Privacy & Security.';

/// What the panel says to do once Ryubing is downloaded.
const _afterDownload =
    'After you download Ryubing, put Ryujinx.app in Applications, then click '
    'Check again.';

/// A game file, with its title and id from its name.
const _gamePath = '/g/Bodega Test [0100F00DBA5E0000][v0] (EU).nsp';
const _game = SwitchGame(
  path: _gamePath,
  title: 'Bodega Test',
  titleId: '0100F00DBA5E0000',
);

/// A game file with no id.
const _homebrew = SwitchGame(
  path: '/g/Homebrew Demo.nro',
  title: 'Homebrew Demo',
);

/// A native game: a Mac app made of a game, which needs no emulator.
const _nativePath = '/g/Bodega Test.app';
const _native = SwitchGame(
  path: _nativePath,
  title: 'Bodega Test',
  native: true,
);

/// The page once its first load ended, with [_found].
const _loaded = SwitchState(
  isLoading: false,
  status: _found,
  games: [_game, _homebrew],
);

void main() {
  late _MockSwitch bloc;
  late _FakePicker picker;
  late FileSelectorPlatform realPicker;
  late _FakeBrowser browser;
  late UrlLauncherPlatform realBrowser;

  setUpAll(() => registerFallbackValue(const SwitchEvent.load()));

  setUp(() {
    bloc = _MockSwitch();
    whenListen(
      bloc,
      const Stream<SwitchState>.empty(),
      initialState: const SwitchState(isLoading: false),
    );
    realPicker = FileSelectorPlatform.instance;
    picker = _FakePicker();
    FileSelectorPlatform.instance = picker;
    realBrowser = UrlLauncherPlatform.instance;
    browser = _FakeBrowser();
    UrlLauncherPlatform.instance = browser;
  });

  tearDown(() {
    FileSelectorPlatform.instance = realPicker;
    UrlLauncherPlatform.instance = realBrowser;
  });

  /// The chip that shows [text], and its color.
  Color chipColor(WidgetTester tester, String text) =>
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, text)).color;

  /// The page showing [state], then what [stream] emits. [width] is the
  /// window's: a box as wide as the side bar takes its part, as
  /// pages_test.dart places pages.
  Future<void> pumpPage(
    WidgetTester tester,
    SwitchState state, {
    Stream<SwitchState> stream = const Stream.empty(),
    double width = 1150,
    double height = 900,
  }) async {
    whenListen(bloc, stream, initialState: state);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<SwitchBloc>.value(
        value: bloc,
        child: wrapApp(
          Row(
            children: [
              SizedBox(width: width > 800 ? 220 : 68),
              const Expanded(child: SwitchPage()),
            ],
          ),
          theme: AppTheme.getDarkTheme(),
          breakpoints: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Opens the Add games menu of the button [at], and picks [choice] in it.
  Future<void> addGames(
    WidgetTester tester,
    String choice, {
    Finder? at,
  }) async {
    await tester.tap(at ?? find.text('Add games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
  }

  group('the status panel (SA14)', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      SwitchStatus? status, {
      List<String> quarantined = const [],
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(380, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        BlocProvider<SwitchBloc>.value(
          value: bloc,
          child: wrapApp(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SwitchStatusPanel(
                  status: status,
                  quarantined: quarantined,
                ),
              ),
            ),
            theme: AppTheme.getDarkTheme(),
          ),
        ),
      );
    }

    testWidgets('an emulator, keys and firmware found: three green rows', (
      tester,
    ) async {
      await pumpPanel(tester, _found);

      for (final text in [
        'Ryubing 1.3.3 at /Applications/Ryujinx.app',
        'Ryubing has keys (prod.keys)',
        'Ryubing has firmware',
      ]) {
        expect(chipColor(tester, text), AppColor.statusTested, reason: text);
      }
      expect(find.byType(StatusChip), findsNWidgets(3));
      // In Applications and not picked: nothing to choose, nothing to note,
      // nothing to download.
      expect(find.text('Choose Ryubing…'), findsNothing);
      expect(find.text(_note('Ryubing')), findsNothing);
      expect(find.text('Download Ryubing'), findsNothing);
      expect(find.text(_afterDownload), findsNothing);
      expect(find.text('Check again'), findsOneWidget);
      expect(find.text('Full screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing found: three amber rows, Download Ryubing, what to '
        'do after, and Choose Ryubing…', (tester) async {
      await pumpPanel(tester, _missing);

      for (final text in [
        'Ryubing is missing: Bodega needs it to play Switch game files',
        'Ryubing has no keys (prod.keys)',
        'Ryubing has no firmware',
      ]) {
        expect(chipColor(tester, text), AppColor.statusFlaky, reason: text);
      }
      expect(find.text('Download Ryubing'), findsOneWidget);
      expect(find.text(_afterDownload), findsOneWidget);
      expect(find.text('Choose Ryubing…'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
      expect(find.text(_note('Ryubing')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Download Ryubing opens its page in the browser, and nothing '
        'else', (tester) async {
      await pumpPanel(tester, _missing);
      await tester.tap(find.text('Download Ryubing'));
      await tester.pump();

      expect(browser.opened, [_page]);
      expect(picker.calls, isEmpty);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('a picked copy in quarantine: its path, Choose Ryubing… and '
        'the note', (tester) async {
      await pumpPanel(tester, _picked);

      // It gives no version.
      expect(
        chipColor(tester, 'Ryubing at $_pickedApp'),
        AppColor.statusTested,
      );
      expect(find.text('Choose Ryubing…'), findsOneWidget);
      expect(find.text(_note('Ryubing')), findsOneWidget);
      expect(find.text(_note('Bodega Test')), findsNothing);
      // Found, if picked: nothing to download.
      expect(find.text('Download Ryubing'), findsNothing);
      expect(find.text(_afterDownload), findsNothing);
    });

    testWidgets('a native game in quarantine gets the note too', (
      tester,
    ) async {
      await pumpPanel(tester, _picked, quarantined: ['Bodega Test']);

      expect(find.text(_note('Ryubing')), findsOneWidget);
      expect(find.text(_note('Bodega Test')), findsOneWidget);
    });

    testWidgets('no status: Check again and the native notes alone', (
      tester,
    ) async {
      await pumpPanel(tester, null, quarantined: ['Bodega Test']);

      expect(find.text('Check again'), findsOneWidget);
      expect(find.text(_note('Bodega Test')), findsOneWidget);
      expect(find.byType(StatusChip), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      // Nothing names Ryubing: no row, and no Choose or Download button.
      expect(find.textContaining('Ryubing'), findsNothing);
    });

    testWidgets('Check again reads it all again', (tester) async {
      await pumpPanel(tester, _found);
      await tester.tap(find.text('Check again'));
      await tester.pump();

      verify(() => bloc.add(const SwitchEvent.load())).called(1);
    });

    testWidgets('the switch turns full screen off, and back on', (
      tester,
    ) async {
      await pumpPanel(tester, _found);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      verify(() => bloc.add(const SwitchEvent.setFullscreen(false))).called(1);

      await pumpPanel(tester, _found.copyWith(fullscreen: false));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      verify(() => bloc.add(const SwitchEvent.setFullscreen(true))).called(1);
    });

    testWidgets('Choose Ryubing… picks an app bundle in /Applications', (
      tester,
    ) async {
      picker.answer = [_pickedApp];
      await pumpPanel(tester, _missing);
      await tester.tap(find.text('Choose Ryubing…'));
      await tester.pump();

      final call = picker.calls.single;
      expect(call.picker, 'openFile');
      expect(call.initialDirectory, '/Applications');
      final group = call.groups.single;
      expect(group.uniformTypeIdentifiers, ['com.apple.application-bundle']);
      expect(group.extensions, isNull);
      expect(group.label, isNull);
      verify(() => bloc.add(const SwitchEvent.chooseEmulator(_pickedApp)))
          .called(1);
    });

    testWidgets('a cancelled picker chooses nothing', (tester) async {
      await pumpPanel(tester, _missing);
      await tester.tap(find.text('Choose Ryubing…'));
      await tester.pump();

      expect(picker.calls, hasLength(1));
      verifyNever(() => bloc.add(any()));
    });
  });

  group('the page (SA13)', () {
    testWidgets('loads once, and shows the loading until it ends', (
      tester,
    ) async {
      await pumpPage(tester, const SwitchState());

      verify(() => bloc.add(const SwitchEvent.load())).called(1);
      expect(find.byType(CustomLoading), findsOneWidget);
      expect(find.byType(SwitchStatusPanel), findsNothing);
    });

    testWidgets('at 1150 px the panel is 380 px wide at the right of the '
        'games', (tester) async {
      await pumpPage(tester, _loaded);

      final panel = tester.getRect(find.byKey(SwitchPage.panelKey));
      final games = tester.getRect(find.byType(GridView));
      expect(panel.width, SwitchPage.panelWidth);
      expect(panel.right, 1150);
      expect(games.right, lessThanOrEqualTo(panel.left));
      expect(games.top, lessThan(panel.bottom));
      expect(find.text('Switch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 801 px the panel sits under the games, as wide as the '
        'page', (tester) async {
      await pumpPage(tester, _loaded, width: 801);

      final panel = tester.getRect(find.byKey(SwitchPage.panelKey));
      final games = tester.getRect(find.byType(GridView));
      expect(panel.top, greaterThan(games.bottom));
      expect(panel.left, games.left);
      expect(panel.right, games.right);
      expect(panel.width, greaterThan(SwitchPage.panelWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no games, the empty state and the panel; its action '
        'offers files and a folder', (tester) async {
      await pumpPage(tester, _loaded.copyWith(games: const []));

      expect(find.text('No Switch games yet'), findsOneWidget);
      expect(
        find.text(
          'Add Nintendo Switch game files or nxnative apps, or a folder that '
          'holds them. Bodega remembers where they are and never copies them.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SwitchStatusPanel), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.text('Add games'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Files…'), findsOneWidget);
      expect(find.text('A folder…'), findsOneWidget);
    });

    testWidgets('the panel notes a native game in quarantine', (tester) async {
      final quarantined = _native.copyWith(quarantined: true);
      await pumpPage(tester, _loaded.copyWith(games: [_game, quarantined]));

      expect(find.text(_note('Bodega Test')), findsOneWidget);
    });

    testWidgets('the panel notes no native game out of quarantine', (
      tester,
    ) async {
      await pumpPage(tester, _loaded.copyWith(games: [_game, _native]));

      expect(find.text(_note('Bodega Test')), findsNothing);
    });
  });

  group('Add games (SA16)', () {
    testWidgets('Files… takes game files and app bundles, and adds the '
        'picked ones', (tester) async {
      await pumpPage(tester, _loaded);
      picker.answer = ['/g/a.nsp', '/g/b.xci'];
      await addGames(tester, 'Files…');

      final call = picker.calls.single;
      expect(call.picker, 'openFiles');
      final group = call.groups.single;
      expect(group.extensions, ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso']);
      expect(group.uniformTypeIdentifiers, ['com.apple.application-bundle']);
      expect(group.label, isNull);
      verify(
        () => bloc.add(const SwitchEvent.addFiles(['/g/a.nsp', '/g/b.xci'])),
      ).called(1);

      // A native game is an app bundle.
      picker.answer = [_nativePath];
      await addGames(tester, 'Files…');
      verify(() => bloc.add(const SwitchEvent.addFiles([_nativePath])))
          .called(1);
    });

    testWidgets('A folder… adds the picked folder', (tester) async {
      await pumpPage(tester, _loaded);
      picker.answer = ['/g'];
      await addGames(tester, 'A folder…');

      expect(picker.calls.single.picker, 'getDirectoryPath');
      verify(() => bloc.add(const SwitchEvent.addFolder('/g'))).called(1);
    });

    testWidgets('a cancelled picker adds nothing', (tester) async {
      await pumpPage(tester, _loaded);
      await addGames(tester, 'Files…');
      await addGames(tester, 'A folder…');

      expect(picker.calls, hasLength(2));
      verifyNever(() => bloc.add(any(that: isA<SwitchAddFilesEvent>())));
      verifyNever(() => bloc.add(any(that: isA<SwitchAddFolderEvent>())));
    });

    testWidgets("the empty state's action adds as the header's does", (
      tester,
    ) async {
      await pumpPage(tester, _loaded.copyWith(games: const []));
      picker.answer = ['/g'];
      await addGames(
        tester,
        'A folder…',
        at: find.descendant(
          of: find.byType(EmptyState),
          matching: find.text('Add games'),
        ),
      );

      verify(() => bloc.add(const SwitchEvent.addFolder('/g'))).called(1);
    });

    for (final (name, state) in [
      ('while an add runs', _loaded.copyWith(isAdding: true)),
      ('with no status', _loaded.copyWith(status: null)),
      (
        'in the empty state, while an add runs',
        const SwitchState(isLoading: false, isAdding: true, status: _found),
      ),
    ]) {
      testWidgets('Add games is disabled $name', (tester) async {
        await pumpPage(tester, state);
        final buttons = find.byType(GradientButton);
        expect(buttons, findsWidgets);
        for (final button in tester.widgetList<GradientButton>(buttons)) {
          expect(button.onPressed, isNull);
        }

        await tester.tap(find.text('Add games').first);
        await tester.pumpAndSettle();
        expect(find.text('Files…'), findsNothing);
      });
    }

    testWidgets('Add games is enabled once the status is read', (tester) async {
      await pumpPage(tester, _loaded.copyWith(games: const []));
      final buttons = tester.widgetList<GradientButton>(
        find.byType(GradientButton),
      );
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        expect(button.onPressed, isNotNull);
      }
    });
  });

  group('game cards (SA15)', () {
    Finder card(String path) => find.byKey(ValueKey(path));
    Finder inCard(String path, Finder finder) =>
        find.descendant(of: card(path), matching: finder);

    testWidgets("a card per game, its cover by the game's id or path, and "
        'its initial', (tester) async {
      await pumpPage(tester, _loaded);

      expect(find.byType(AppCard), findsNWidgets(2));
      for (final (path, id, initial) in [
        (_gamePath, '0100F00DBA5E0000', 'B'),
        ('/g/Homebrew Demo.nro', '/g/Homebrew Demo.nro', 'H'),
      ]) {
        final shown = tester.widget<AppCard>(card(path));
        expect(shown.id, id);
        expect(shown.iconPath, isNull);
        expect(inCard(path, find.text(initial)), findsOneWidget);
        expect(inCard(path, find.text('Native')), findsNothing);
      }
    });

    testWidgets('Play opens a game whatever the panel says', (tester) async {
      // No emulator, no keys, no firmware: the engine tells what is missing.
      await pumpPage(tester, _loaded.copyWith(status: _missing));
      await tester.tap(inCard(_gamePath, find.byTooltip('Play')));
      await tester.pump();

      verify(() => bloc.add(const SwitchEvent.open(_gamePath))).called(1);
    });

    testWidgets('a native game: its path picks its cover, it shows Native, '
        'and it plays with no emulator', (tester) async {
      await pumpPage(
        tester,
        _loaded.copyWith(status: _missing, games: [_native]),
      );

      expect(tester.widget<AppCard>(card(_nativePath)).id, _nativePath);
      final chip = tester.widget<StatusChip>(
        inCard(_nativePath, find.byType(StatusChip)),
      );
      expect(chip.label, 'Native');
      expect(chip.color, AppColor.statusReported);

      await tester.tap(inCard(_nativePath, find.byTooltip('Play')));
      await tester.pump();
      verify(() => bloc.add(const SwitchEvent.open(_nativePath))).called(1);
    });

    testWidgets("a double click and the menu's Open play it too", (
      tester,
    ) async {
      await pumpPage(tester, _loaded);
      final title = inCard(_gamePath, find.text('Bodega Test'));
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(title);
      await tester.pumpAndSettle();
      verify(() => bloc.add(const SwitchEvent.open(_gamePath))).called(1);

      await tester.tap(
        inCard(_gamePath, find.byTooltip('Bodega Test options')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const SwitchEvent.open(_gamePath))).called(1);
    });

    testWidgets('Stop asks first: its Stop stops the game, Cancel does not', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _loaded.copyWith(running: const {_gamePath: '/l/a.log'}),
      );
      expect(inCard(_gamePath, find.text('Running')), findsOneWidget);

      Future<void> askToStop() async {
        await tester.tap(inCard(_gamePath, find.byTooltip('Stop')));
        await tester.pumpAndSettle();
        expect(find.text('Stop Bodega Test'), findsOneWidget);
        expect(
          find.text(
            "Bodega Test will close. Anything you haven't saved will be lost.",
          ),
          findsOneWidget,
        );
      }

      await askToStop();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any(that: isA<SwitchStopEvent>())));

      await askToStop();
      await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const SwitchEvent.stop(_gamePath))).called(1);
    });

    testWidgets('Remove is disabled while the game runs, and removes it once '
        'it ended', (tester) async {
      final states = StreamController<SwitchState>();
      addTearDown(states.close);
      final running = _loaded.copyWith(running: const {_gamePath: '/l/a.log'});
      await pumpPage(tester, running, stream: states.stream);

      final remove = find.widgetWithText(
        PopupMenuItem<SwitchGameAction>,
        'Remove from list',
      );
      Future<void> openMenu() async {
        await tester.tap(
          inCard(_gamePath, find.byTooltip('Bodega Test options')),
        );
        await tester.pumpAndSettle();
      }

      await openMenu();
      expect(
        tester.widget<PopupMenuItem<SwitchGameAction>>(remove).enabled,
        isFalse,
      );
      await tester.tap(remove);
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any(that: isA<SwitchRemoveEvent>())));
      // A disabled item leaves the menu open.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      states.add(_loaded);
      await tester.pumpAndSettle();
      expect(inCard(_gamePath, find.text('Running')), findsNothing);
      await openMenu();
      expect(
        tester.widget<PopupMenuItem<SwitchGameAction>>(remove).enabled,
        isTrue,
      );
      await tester.tap(remove);
      await tester.pumpAndSettle();
      verify(() => bloc.add(const SwitchEvent.remove(_gamePath))).called(1);
    });
  });
}
