// The app's words in both languages, one group per section of the UI: the
// forms of the ARB messages (plurals, selects, placeholders), the tables of
// lib/app/shared/text/, and the widgets that show them. English is read as
// written; Spanish only through lookupAppL10n, with the same arguments as
// English (design §9, L19).

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/bloc/graphics/graphics_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/backends/widgets/backend_card.dart';
import 'package:bodega/app/presentation/backends/widgets/gptk_section.dart';
import 'package:bodega/app/presentation/backends/widgets/probe_dialog.dart';
import 'package:bodega/app/presentation/bottles/bottle_detail_page.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/presentation/bottles/widgets/gamepads_section.dart';
import 'package:bodega/app/presentation/bottles/widgets/library_toggle.dart';
import 'package:bodega/app/presentation/bottles/widgets/rename_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockBackends extends MockBloc<BackendsEvent, BackendsState>
    implements BackendsBloc {}

class _MockBottleDetail extends MockBloc<BottleDetailEvent, BottleDetailState>
    implements BottleDetailBloc {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockGamepads extends MockBloc<GamepadsEvent, GamepadsState>
    implements GamepadsBloc {}

class _MockGraphics extends MockBloc<GraphicsEvent, GraphicsState>
    implements GraphicsBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockNewBottle extends MockBloc<NewBottleEvent, NewBottleState>
    implements NewBottleBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

const _es = Locale('es');
const _locales = [Locale('en'), _es];

/// The bottle of the bottle screens' cases.
const _bottle = 'steam';

// The Backends page.
const _dxvk = BackendInfo(name: 'dxvk', installed: true, downloadable: true);
const _dxmt = BackendInfo(name: 'dxmt', installed: false, downloadable: true);

// A bottle's panel.

/// DX9 in 32 bits: d3dmetal does not suit it (G3).
const _blur = LibraryApp(
  bottle: _bottle,
  key: 'blur.exe',
  id: 'blur',
  title: 'Blur',
  exe: r'C:\Blur\Blur.exe',
);

/// Suits every backend.
const _muck = LibraryApp(
  bottle: _bottle,
  key: 'muck.exe',
  id: 'muck',
  title: 'Muck',
  exe: r'C:\Muck\Muck.exe',
);

BottleDetail _detail({String backend = 'd3dmetal', bool ready = true}) =>
    BottleDetail(
      name: _bottle,
      ready: ready,
      backend: backend,
      sync: 'msync',
      apps: const [_blur, _muck],
      installedBackends: const ['d3dmetal', 'dxvk'],
    );

// The other bottle screens.

/// Names the engine refuses for a bottle's folder (`engine.dart:55-60`).
final _badNames = ['-steam', '_steam', 'my games', 'x' * 65];

/// A text without its digits: what is left to change when only a count does.
String _words(String text) => text.replaceAll(RegExp(r'\d'), '');

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(_es);

  // T6: the library's count, one message with two plurals (L10), and the
  // placeholders that carry a version or a path.
  group('the shell, the library and the setup page', () {
    final number = RegExp(r'\d+');

    /// [text] with each number replaced by #: what is left are its words.
    String words(String text) => text.replaceAll(number, '#');

    group('libraryCount (L10)', () {
      test('in English, each noun agrees with its own number', () {
        expect(en.libraryCount(1, 1), '1 app in 1 bottle');
        expect(en.libraryCount(2, 3), '2 apps in 3 bottles');
        expect(en.libraryCount(3, 2), '3 apps in 2 bottles');
        expect(en.libraryCount(12, 3), '12 apps in 3 bottles');
      });

      for (final (language, l10n) in [('en', en), ('es', es)]) {
        test('in $language, either count going from 2 to 1 changes more than '
            'its digit', () {
          final both = words(l10n.libraryCount(2, 2));
          final oneApp = words(l10n.libraryCount(1, 2));
          final oneBottle = words(l10n.libraryCount(2, 1));
          expect(oneApp, isNot(both));
          expect(oneBottle, isNot(both));
          // Each plural is its own: the apps' does not follow the bottles'.
          expect(oneApp, isNot(oneBottle));
        });

        test('in $language, it carries both numbers, apps first', () {
          final text = l10n.libraryCount(12, 3);
          expect(
            [for (final match in number.allMatches(text)) match[0]],
            ['12', '3'],
          );
        });
      }
    });

    group('placeholders', () {
      for (final (language, l10n) in [('en', en), ('es', es)]) {
        test('in $language, the version and the path show as given', () {
          expect(l10n.appVersionLabel('1.5.0'), contains('1.5.0'));
          expect(l10n.routeNotFoundMessage('/nope'), contains('/nope'));
        });
      }
    });
  });

  // T7: lib/app/shared/widgets, and the progress text of every download
  // (L13, L15).
  group('the shared widgets', () {
    group('downloadProgressText', () {
      test('formats percent and MB for the locale (L13)', () {
        final text = downloadProgressText(
          en,
          received: 1234000000,
          total: 2468000000,
        );
        expect(text, contains('50%'));
        expect(text, contains('1,234 MB'));
        expect(text, contains('2,468 MB'));

        final spanish = downloadProgressText(
          es,
          received: 1234000000,
          total: 2468000000,
        );
        expect(spanish, contains('50 %'));
        expect(spanish, contains('1.234 MB'));
        expect(spanish, contains('2.468 MB'));
      });

      test('counts MB of 10^6 bytes (L13)', () {
        final text = downloadProgressText(en, received: 150 * (1 << 20));
        expect(text, contains('157 MB'));
        expect(text, isNot(contains('150 MB')));
      });

      test('without a total, only what arrived (L15)', () {
        expect(
          downloadProgressText(en, received: 5000000, total: null),
          en.downloadProgressNoTotal(5),
        );
      });
    });

    // What BottleRow passes as `state`; `closed` is the messages' `other`.
    const states = ['incomplete', 'open', 'closed'];

    group('a bottle row says its state in one message (L12)', () {
      test('in English', () {
        expect(
          [for (final state in states) en.bottleRowLabel('steam', state)],
          [
            'Bottle steam, incomplete',
            'Bottle steam, open',
            'Bottle steam, closed',
          ],
        );
        expect(
          [for (final state in states) en.bottleRowTooltip('steam', state)],
          ['steam (incomplete)', 'steam (open)', 'steam (closed)'],
        );
      });

      test('with a different text per state, in both languages', () {
        for (final l10n in [en, es]) {
          for (final message in [l10n.bottleRowLabel, l10n.bottleRowTooltip]) {
            final texts = [for (final state in states) message('steam', state)];
            expect(texts.toSet(), hasLength(states.length), reason: '$texts');
            for (final text in texts) {
              expect(text, contains('steam'));
            }
          }
        }
      });

      test('and Spanish words each state its own way', () {
        for (final state in states) {
          expect(
            es.bottleRowLabel('steam', state),
            isNot(en.bottleRowLabel('steam', state)),
          );
          expect(
            es.bottleRowTooltip('steam', state),
            isNot(en.bottleRowTooltip('steam', state)),
          );
        }
      });
    });

    test('the menu button of an app names it (L12)', () {
      expect(en.appOptions('Steam'), 'Steam options');
      expect(es.appOptions('Steam'), contains('Steam'));
      expect(es.appOptions('Steam'), isNot(en.appOptions('Steam')));
    });

    test('a bottle row counts its apps with a plural (L10)', () {
      expect(en.bottleAppCount(1), '1 app');
      expect(en.bottleAppCount(2), '2 apps');
      // From 2 to 1, more than the digit changes, in both languages.
      for (final l10n in [en, es]) {
        String words(int count) =>
            l10n.bottleAppCount(count).replaceAll(RegExp(r'\d'), '');
        expect(words(1), isNot(words(2)), reason: l10n.localeName);
      }
    });
  });

  // T8: lib/app/shared/text/catalog_text.dart, and the catalog and add-app
  // messages with placeholders (L11, L12, L15).
  group('the catalog and the add-app dialog', () {
    group('catalogStatusText', () {
      test('words each status in English', () {
        expect(
          {
            for (final status in CatalogStatus.values)
              status: catalogStatusText(en, status),
          },
          {
            CatalogStatus.tested: 'Tested',
            CatalogStatus.reported: 'Reported',
            CatalogStatus.untested: 'Untested',
            CatalogStatus.blocked: 'Not supported',
          },
        );
      });

      test('gives each status a text of its own, in both languages', () {
        for (final l10n in [en, es]) {
          final texts = [
            for (final status in CatalogStatus.values)
              catalogStatusText(l10n, status),
          ];
          expect(texts, everyElement(isNotEmpty), reason: l10n.localeName);
          expect(
            texts.toSet(),
            hasLength(CatalogStatus.values.length),
            reason: l10n.localeName,
          );
        }
      });

      test('translates each status', () {
        for (final status in CatalogStatus.values) {
          expect(
            catalogStatusText(es, status),
            isNot(catalogStatusText(en, status)),
            reason: status.name,
          );
        }
      });

      test('reads blocked from its one key, in both languages (L15)', () {
        expect(
          catalogStatusText(en, CatalogStatus.blocked),
          en.catalogStatusBlocked,
        );
        expect(
          catalogStatusText(es, CatalogStatus.blocked),
          es.catalogStatusBlocked,
        );
      });
    });

    group('catalogSourceText', () {
      const known = ['repo', 'commit', 'path', 'license', 'verified'];

      test('words each field of the catalog data in English', () {
        expect(
          [for (final key in known) catalogSourceText(en, key)],
          ['Repository', 'Commit', 'Recipe', 'License', 'Verified'],
        );
      });

      test('gives each known field a label of its own, in both languages', () {
        for (final l10n in [en, es]) {
          final labels = [
            for (final key in known) catalogSourceText(l10n, key),
          ];
          expect(
            labels.toSet(),
            hasLength(known.length),
            reason: l10n.localeName,
          );
          for (final (index, key) in known.indexed) {
            expect(
              labels[index],
              isNot(key),
              reason: '${l10n.localeName} $key',
            );
          }
        }
      });

      test('shows a field it does not know as it is', () {
        expect(catalogSourceText(en, 'mirror'), 'mirror');
        expect(catalogSourceText(es, 'mirror'), 'mirror');
      });

      test('puts the label and its value in one line', () {
        expect(en.catalogSourceLine('Repository', 'a/b'), 'Repository: a/b');
        final label = catalogSourceText(es, 'repo');
        expect(
          es.catalogSourceLine(label, 'a/b'),
          allOf(contains(label), contains('a/b')),
        );
      });
    });

    test('"Installed" on a catalog app is a key of its own (L11)', () {
      expect(en.catalogAppInstalled, 'Installed');
      expect(es.catalogAppInstalled, isNot(en.catalogAppInstalled));
    });

    test('the anti-cheat note quotes the chip of its own language (L12)', () {
      expect(
        en.catalogAntiCheatNote(en.catalogAntiCheatMayFail),
        contains('"May fail"'),
      );
      final spanish = es.catalogAntiCheatNote(es.catalogAntiCheatMayFail);
      expect(spanish, contains('"${es.catalogAntiCheatMayFail}"'));
      expect(spanish, isNot(contains(en.catalogAntiCheatMayFail)));
    });

    test('each sentence names what it carries, in both languages (L12)', () {
      for (final l10n in [en, es]) {
        for (final (value, message) in [
          ('games', l10n.addAppTitle('games')),
          ('Blur', l10n.addAppAddedToLibrary('Blur')),
          ('Blur', l10n.addAppAddedToBottle('Blur')),
          ('dxmt', l10n.catalogInstallBackend('dxmt')),
          ('dxmt', l10n.catalogBackend('dxmt')),
          ('msync', l10n.catalogSync('msync')),
          ('SteamSetup.exe', l10n.catalogInstallerFile('SteamSetup.exe')),
          ('Steam', l10n.catalogInstallRunning('Steam')),
        ]) {
          expect(
            message,
            contains(value),
            reason: '${l10n.localeName}: $message',
          );
        }
      }
      expect(en.addAppTitle('games'), 'Add an app to games');
      expect(en.catalogInstallBackend('dxmt'), 'Install dxmt');
    });
  });

  // T9: the backend descriptions, the card's chips and progress, the D3DMetal
  // section and its toast, and the dialog that picks the bottle of a check.
  group('the Backends page', () {
    group('backendDescriptionText', () {
      test('says what each backend is', () {
        expect(
          backendDescriptionText(en, 'wine'),
          'wined3d and vkd3d. It comes with the engine.',
        );
        expect(
          backendDescriptionText(en, 'dxmt'),
          'D3D10 and D3D11 on Metal. The one launchers use.',
        );
        expect(
          backendDescriptionText(en, 'dxvk'),
          'D3D10 and D3D11 on Vulkan, through MoltenVK.',
        );
        expect(
          backendDescriptionText(en, 'd3dmetal'),
          'D3D11 and D3D12 on Metal, by Apple. You import it yourself.',
        );
      });

      test('in Spanish, from the same key for each backend, translated', () {
        final keys = {
          'wine': es.backendDescriptionWine,
          'dxmt': es.backendDescriptionDxmt,
          'dxvk': es.backendDescriptionDxvk,
          'd3dmetal': es.backendDescriptionD3dMetal,
        };
        for (final MapEntry(key: backend, value: text) in keys.entries) {
          expect(backendDescriptionText(es, backend), text, reason: backend);
          expect(text, isNot(backendDescriptionText(en, backend)));
        }
      });

      test('gives none for a backend it does not know', () {
        expect(backendDescriptionText(en, 'vkd3d-proton'), isNull);
        expect(backendDescriptionText(es, 'vkd3d-proton'), isNull);
      });
    });

    group('the backend card', () {
      late _MockBackends bloc;

      setUp(() => bloc = _MockBackends());

      Future<void> pumpCard(
        WidgetTester tester,
        BackendInfo backend,
        BackendsState state, {
        Locale locale = const Locale('en'),
      }) async {
        whenListen(
          bloc,
          const Stream<BackendsState>.empty(),
          initialState: state,
        );
        await tester.pumpWidget(
          BlocProvider<BackendsBloc>.value(
            value: bloc,
            child: wrapApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: BackendCard(backend: backend, state: state),
                ),
              ),
              locale: locale,
            ),
          ),
        );
      }

      const idle = BackendsState(isLoading: false);

      testWidgets('says whether the backend is installed, in its own words '
          '(L11)', (tester) async {
        await pumpCard(tester, _dxvk, idle);
        expect(find.text('Installed'), findsOneWidget);
        await pumpCard(tester, _dxmt, idle);
        expect(find.text('Not installed'), findsOneWidget);

        await pumpCard(tester, _dxvk, idle, locale: _es);
        expect(find.text(es.backendInstalled), findsOneWidget);
        await pumpCard(tester, _dxmt, idle, locale: _es);
        expect(find.text(es.backendNotInstalled), findsOneWidget);
        // A backend's word of its own, translated: not an app's or a bottle's.
        expect(es.backendInstalled, isNot(en.backendInstalled));
      });

      testWidgets('says what the backend is and what it is for', (
        tester,
      ) async {
        const role = 'DirectX 10 and 11, 32 and 64 bits';
        await pumpCard(tester, _dxmt.copyWith(use: role), idle);
        expect(
          find.text('D3D10 and D3D11 on Metal. The one launchers use.'),
          findsOneWidget,
        );
        expect(find.text('Used for: $role'), findsOneWidget);

        await pumpCard(tester, _dxmt.copyWith(use: role), idle, locale: _es);
        expect(find.text(es.backendDescriptionDxmt), findsOneWidget);
        expect(find.text(es.backendUsedFor(role)), findsOneWidget);
      });

      testWidgets('a backend it does not know shows no description', (
        tester,
      ) async {
        const other = BackendInfo(
          name: 'vkd3d-proton',
          installed: true,
          downloadable: false,
        );
        await pumpCard(tester, other, idle);
        expect(find.text('vkd3d-proton'), findsOneWidget);
        expect(find.text(''), findsNothing);
      });

      testWidgets('words the download as the other panels do (L15)', (
        tester,
      ) async {
        final downloading = idle.copyWith(
          busy: 'dxmt',
          isDownloading: true,
          received: 1234000000,
          total: 2468000000,
        );
        await pumpCard(tester, _dxmt, downloading);
        expect(
          find.text('Downloading · 50% · 1,234 MB of 2,468 MB'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);

        await pumpCard(tester, _dxmt, downloading, locale: _es);
        expect(
          find.text(
            downloadProgressText(es, received: 1234000000, total: 2468000000),
          ),
          findsOneWidget,
        );
        expect(find.text(es.commonCancel), findsOneWidget);

        await pumpCard(tester, _dxmt, downloading.copyWith(total: null));
        expect(find.text('Downloading · 1,234 MB'), findsOneWidget);
      });

      testWidgets('then the install, and a check, in their own words', (
        tester,
      ) async {
        final installing = idle.copyWith(busy: 'dxmt');
        await pumpCard(tester, _dxmt, installing);
        expect(find.text('Installing'), findsOneWidget);
        await pumpCard(tester, _dxmt, installing, locale: _es);
        expect(find.text(es.commonInstalling), findsOneWidget);

        final checking = idle.copyWith(checking: 'dxvk');
        await pumpCard(tester, _dxvk, checking);
        expect(
          find.text('Checking; each case can take up to 90 s'),
          findsOneWidget,
        );
        await pumpCard(tester, _dxvk, checking, locale: _es);
        expect(find.text(es.backendChecking), findsOneWidget);
      });

      testWidgets('offers what fits the backend', (tester) async {
        await pumpCard(tester, _dxmt, idle);
        expect(find.widgetWithText(FilledButton, 'Install'), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'Choose file…'),
          findsOneWidget,
        );
        await pumpCard(tester, _dxvk, idle);
        expect(find.widgetWithText(OutlinedButton, 'Check'), findsOneWidget);

        await pumpCard(tester, _dxmt, idle, locale: _es);
        expect(
          find.widgetWithText(FilledButton, es.commonInstall),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, es.commonChooseFile),
          findsOneWidget,
        );
        await pumpCard(tester, _dxvk, idle, locale: _es);
        expect(
          find.widgetWithText(OutlinedButton, es.backendCheck),
          findsOneWidget,
        );
      });

      testWidgets('shows each case of its check', (tester) async {
        final checked = idle.copyWith(
          results: {
            'dxvk': const [
              ProbeResult(bits: 64, d3d: '11', ok: true, log: '/l/a.log'),
              ProbeResult(bits: 32, d3d: '10', ok: false, log: '/l/b.log'),
            ],
          },
        );
        await pumpCard(tester, _dxvk, checked);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('64-bit, D3D11'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
        expect(find.text('32-bit, D3D10'), findsOneWidget);

        await pumpCard(tester, _dxvk, checked, locale: _es);
        expect(find.text(es.backendCheckPassed), findsOneWidget);
        expect(find.text(es.backendCheckCase(64, '11')), findsOneWidget);
        expect(find.text(es.backendCheckFailed), findsOneWidget);
        expect(find.text(es.backendCheckCase(32, '10')), findsOneWidget);
      });
    });

    group('the D3DMetal section', () {
      late _MockBackends bloc;

      setUp(() => bloc = _MockBackends());

      final offered = const BackendsState(isLoading: false).copyWith(
        releases: const [
          GptkRelease(version: '3.0', tested: true, url: 'https://x'),
          GptkRelease(version: '4.0', tested: false, url: 'https://y'),
        ],
      );

      Future<void> pumpSection(
        WidgetTester tester,
        BackendsState state, {
        String? installed,
        Stream<BackendsState> changes = const Stream.empty(),
        Locale locale = const Locale('en'),
      }) async {
        whenListen(bloc, changes, initialState: state);
        await tester.pumpWidget(
          BlocProvider<BackendsBloc>.value(
            value: bloc,
            child: wrapApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: GptkSection(state: state, installed: installed),
                ),
              ),
              locale: locale,
            ),
          ),
        );
      }

      testWidgets('offers the versions, and says which one is there', (
        tester,
      ) async {
        await pumpSection(tester, offered);
        expect(
          find.text("Choose a version of Apple's Game Porting Toolkit."),
          findsOneWidget,
        );
        expect(find.text('Tested'), findsOneWidget);
        expect(find.text('Beta, untested'), findsOneWidget);
        expect(find.text('Install'), findsNWidgets(2));
        expect(find.text('I already have it: choose the dmg…'), findsOneWidget);
        expect(
          find.text(
            "Bodega doesn't download D3DMetal: your browser does, with your "
            'Apple account, and you accept its license.',
          ),
          findsOneWidget,
        );

        await pumpSection(tester, offered, installed: '3.0');
        expect(find.text('You have D3DMetal 3.0.'), findsOneWidget);
        expect(find.text('Reinstall'), findsOneWidget);
        expect(find.text('Install'), findsOneWidget);
      });

      testWidgets('in Spanish, from the same keys', (tester) async {
        await pumpSection(tester, offered, installed: '3.0', locale: _es);
        expect(find.text(es.gptkInstalledVersion('3.0')), findsOneWidget);
        expect(find.text(es.gptkTested), findsOneWidget);
        expect(find.text(es.gptkUntested), findsOneWidget);
        expect(find.text(es.gptkReinstall), findsOneWidget);
        expect(find.text(es.commonInstall), findsOneWidget);
        expect(find.text(es.gptkPickDmg), findsOneWidget);
        expect(find.text(es.gptkLicenseNote), findsOneWidget);

        await pumpSection(tester, offered, locale: _es);
        expect(find.text(es.gptkChooseVersion), findsOneWidget);
      });

      testWidgets('while it waits for the download, names the version', (
        tester,
      ) async {
        final waiting = offered.copyWith(gptkWaiting: '4.0');
        await pumpSection(tester, waiting);
        expect(
          find.text(
            'Sign in to Apple in your browser and download Game Porting '
            'Toolkit 4.0. Bodega installs it as soon as it shows up in '
            'Downloads.',
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);

        await pumpSection(tester, waiting, locale: _es);
        expect(find.text(es.gptkWaiting('4.0')), findsOneWidget);
        expect(find.text(es.commonCancel), findsOneWidget);
      });

      group('once it installs, toasts', () {
        // The install ends: the version arrives, with the bottles there are.
        // A fresh tree, so the listener subscribes to this install's stream.
        Future<void> install(
          WidgetTester tester, {
          required List<String> bottles,
          Locale locale = const Locale('en'),
        }) async {
          final before = offered.copyWith(bottles: bottles);
          await tester.pumpWidget(const SizedBox());
          await pumpSection(
            tester,
            before,
            changes: Stream.value(before.copyWith(gptkInstalled: '3.0')),
            locale: locale,
          );
          // The state arrives and asks for the toast; the next frame adds it to
          // the toasts' list, and it slides in.
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }

        // The toast closes by itself after 5 s: no timer outlives the test.
        Future<void> letItClose(WidgetTester tester) async {
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        }

        testWidgets('the version and the check that follows', (tester) async {
          await install(tester, bottles: const ['steam']);
          expect(
            find.text('D3DMetal 3.0 is installed. Checking…'),
            findsOneWidget,
          );
          await letItClose(tester);
        });

        testWidgets('the version, and asks for a bottle when there is none', (
          tester,
        ) async {
          await install(tester, bottles: const []);
          expect(
            find.text(
              'D3DMetal 3.0 is installed. Create a bottle to check it.',
            ),
            findsOneWidget,
          );
          await letItClose(tester);
        });

        testWidgets('in Spanish, each sentence from its key', (tester) async {
          await install(tester, bottles: const ['steam'], locale: _es);
          expect(
            find.text(
              '${es.gptkInstalledToast('3.0')} ${es.gptkToastChecking}',
            ),
            findsOneWidget,
          );
          await letItClose(tester);

          await install(tester, bottles: const [], locale: _es);
          expect(
            find.text(
              '${es.gptkInstalledToast('3.0')} ${es.gptkToastNeedsBottle}',
            ),
            findsOneWidget,
          );
          await letItClose(tester);
        });
      });
    });

    group('the probe dialog', () {
      // Opens the dialog as the card does, and keeps what it returns.
      Future<String? Function()> open(
        WidgetTester tester,
        List<String> bottles, {
        Locale locale = const Locale('en'),
      }) async {
        String? chosen;
        await tester.pumpWidget(
          wrapApp(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await chooseProbeBottle(context, 'dxvk', bottles);
                },
                child: const Text('open'),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        return () => chosen;
      }

      testWidgets('warns that the chosen bottle closes, and follows the '
          'choice', (tester) async {
        final chosen = await open(tester, const ['steam', 'blur']);
        expect(find.text('Check dxvk'), findsOneWidget);
        expect(find.text('Bottle'), findsOneWidget);
        expect(
          find.text(
            'Everything open in the bottle steam will close. Anything you '
            "haven't saved will be lost.",
          ),
          findsOneWidget,
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('blur').last);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Everything open in the bottle blur will close. Anything you '
            "haven't saved will be lost.",
          ),
          findsOneWidget,
        );
        expect(find.text(en.bottleStopConfirm('steam')), findsNothing);

        await tester.tap(find.widgetWithText(FilledButton, 'Check'));
        await tester.pumpAndSettle();
        expect(chosen(), 'blur');
      });

      testWidgets('without a bottle, says how to get one', (tester) async {
        await open(tester, const []);
        expect(
          find.text(
            'You need a bottle. Install something from the catalog and come '
            'back.',
          ),
          findsOneWidget,
        );
        final check = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Check'),
        );
        expect(check.onPressed, isNull);
        expect(find.text(en.commonBottle), findsNothing);
      });

      testWidgets('in Spanish, from the same keys', (tester) async {
        await open(tester, const ['steam', 'blur'], locale: _es);
        expect(find.text(es.probeTitle('dxvk')), findsOneWidget);
        expect(find.text(es.bottleStopConfirm('steam')), findsOneWidget);
        expect(find.text(es.commonBottle), findsOneWidget);
        expect(find.text(es.commonCancel), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, es.backendCheck),
          findsOneWidget,
        );

        await tester.tap(find.text(es.commonCancel));
        await tester.pumpAndSettle();
        await open(tester, const [], locale: _es);
        expect(find.text(es.probeNoBottle), findsOneWidget);
      });
    });
  });

  // T10: the forms of its messages in both languages, and the panel showing
  // them (L11, L12, L15).
  group("a bottle's panel", () {
    late _MockBottleDetail bottle;
    late _MockLibrary library;
    late _MockSetup setup;
    late _MockSections sections;
    late _MockGraphics graphics;
    late _MockGamepads gamepads;

    setUp(() {
      bottle = _MockBottleDetail();
      library = _MockLibrary();
      setup = _MockSetup();
      sections = _MockSections();
      graphics = _MockGraphics();
      gamepads = _MockGamepads();
      when(() => library.state)
          .thenReturn(const LibraryState(isLoading: false));
      // Every setting of the panel, the GPU and GameMode included.
      when(() => setup.state).thenReturn(
        const SetupState(
          isChecking: false,
          capabilities: HostCapabilities(gpu: true, gameMode: true),
        ),
      );
      when(() => sections.state).thenReturn(const SectionsState());
      when(() => gamepads.state)
          .thenReturn(const GamepadsState(isLoading: false));
      when(() => graphics.state).thenReturn(
        GraphicsState(
          byKey: {
            GraphicsState.keyOf(_bottle, _blur.exe): const ExeGraphics(
              bits: 32,
              directx: 'DX9',
              misfits: ['d3dmetal'],
            ),
            GraphicsState.keyOf(_bottle, _muck.exe): const ExeGraphics(
              bits: 64,
              directx: 'DX11',
            ),
          },
        ),
      );
    });

    Future<void> pumpColumn(
      WidgetTester tester,
      Locale locale, {
      BottleDetail? detail,
      bool isOpen = false,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 3000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapApp(
          MultiBlocProvider(
            providers: [
              BlocProvider<BottleDetailBloc>.value(value: bottle),
              BlocProvider<LibraryBloc>.value(value: library),
              BlocProvider<SetupBloc>.value(value: setup),
              BlocProvider<SectionsBloc>.value(value: sections),
              BlocProvider<GraphicsBloc>.value(value: graphics),
              BlocProvider<GamepadsBloc>.value(value: gamepads),
            ],
            child: Scaffold(
              body: SingleChildScrollView(
                child: BottleColumn(
                  detail: detail ?? _detail(),
                  isBusy: false,
                  isOpen: isOpen,
                  hints: const [],
                ),
              ),
            ),
          ),
          locale: locale,
        ),
      );
    }

    group('Automatic (L11)', () {
      test('is two keys, equal in English, each agreeing with its noun in '
          'Spanish', () {
        expect(en.bottleGraphicsAuto, 'Automatic');
        expect(en.bottleGpuAuto, en.bottleGraphicsAuto);
        // Spanish agrees with the noun: the backend is masculine, the GPU not.
        expect(es.bottleGpuAuto, isNot(es.bottleGraphicsAuto));
        expect(es.bottleGraphicsAuto, isNot(en.bottleGraphicsAuto));
        expect(es.bottleGpuAuto, isNot(en.bottleGpuAuto));
      });

      for (final locale in _locales) {
        testWidgets('the backend and the GPU each show their own '
            '(${locale.languageCode})', (tester) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale, detail: _detail(backend: 'auto'));

          Finder shows(String key, String text) => find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text(text),
          );
          expect(
            shows('backend auto', l10n.bottleGraphicsAuto),
            findsOneWidget,
          );
          expect(shows('gpu auto', l10n.bottleGpuAuto), findsOneWidget);
          // The fact beside Windows says it too.
          expect(find.text(l10n.bottleGraphicsAuto), findsAtLeast(2));
        });
      }
    });

    group('the misfit warning (L12)', () {
      test('is one sentence that quotes the Automatic option of its '
          'language', () {
        expect(
          en.bottleMisfitWarning(
            'd3dmetal',
            'Blur (DX9 · 32 bits)',
            en.bottleGraphicsAuto,
          ),
          "d3dmetal won't work for Blur (DX9 · 32 bits). Use Automatic.",
        );
        final spanish = es.bottleMisfitWarning(
          'd3dmetal',
          'Blur (DX9 · 32 bits)',
          es.bottleGraphicsAuto,
        );
        expect(spanish, contains('d3dmetal'));
        expect(spanish, contains('Blur (DX9 · 32 bits)'));
        expect(spanish, contains(es.bottleGraphicsAuto));
        expect(spanish, isNot(contains(en.bottleGraphicsAuto)));
      });

      for (final locale in _locales) {
        testWidgets('on the panel, names the misfits and the Automatic of the '
            'active language (${locale.languageCode})', (tester) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale);

          // Only Blur: the backend suits Muck.
          expect(
            find.text(
              l10n.bottleMisfitWarning(
                'd3dmetal',
                'Blur (DX9 · 32 bits)',
                l10n.bottleGraphicsAuto,
              ),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('Muck'), findsNothing);
        });
      }
    });

    group('the state of the bottle', () {
      const states = ['incomplete', 'open', 'closed'];

      test('is a select with a word for each state, in both languages', () {
        expect(
          [for (final state in states) en.bottleStatus(state)],
          ['Incomplete', 'Open', 'Closed'],
        );
        for (final l10n in [en, es]) {
          final words = {for (final state in states) l10n.bottleStatus(state)};
          expect(words, hasLength(states.length));
          // Its other branch: any other state reads as closed.
          expect(l10n.bottleStatus('stopping'), l10n.bottleStatus('closed'));
        }
        for (final state in states) {
          expect(es.bottleStatus(state), isNot(en.bottleStatus(state)));
        }
      });

      for (final locale in _locales) {
        testWidgets('shows on the chip (${locale.languageCode})', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale, detail: _detail(ready: false));
          expect(find.text(l10n.bottleStatus('incomplete')), findsOneWidget);

          await pumpColumn(tester, locale, isOpen: true);
          expect(find.text(l10n.bottleStatus('open')), findsOneWidget);

          await pumpColumn(tester, locale);
          expect(find.text(l10n.bottleStatus('closed')), findsOneWidget);
        });
      }
    });

    test('the apps fact agrees with the count (plural)', () {
      expect(en.bottleFactApps(1), 'App');
      expect(en.bottleFactApps(0), 'Apps');
      expect(en.bottleFactApps(2), 'Apps');
      expect(es.bottleFactApps(1), isNot(es.bottleFactApps(2)));
      expect(es.bottleFactApps(0), es.bottleFactApps(2));
    });

    test('a log says its program still runs, or the code it exited with', () {
      expect(en.bottleLogRunning, 'Running');
      expect(en.bottleLogExited(42), 'Exited with code 42');
      expect(es.bottleLogRunning, isNot(en.bottleLogRunning));
      for (final l10n in [en, es]) {
        // A code is no amount: no digit grouping, and its sign stays.
        expect(l10n.bottleLogExited(3221225477), contains('3221225477'));
        expect(l10n.bottleLogExited(-1), contains('-1'));
      }
    });

    test('each Wine tool has its own name, in both languages', () {
      final english = [
        for (final (label, _, _) in BottleColumn.panels(en)) label,
      ];
      final spanish = [
        for (final (label, _, _) in BottleColumn.panels(es)) label,
      ];
      expect(english, contains('Game controllers'));
      expect(english.toSet(), hasLength(english.length));
      expect(spanish.toSet(), hasLength(spanish.length));
      for (var i = 0; i < english.length; i++) {
        expect(spanish[i], isNot(english[i]));
      }
    });

    test('placeholders carry their value in both languages', () {
      for (final l10n in [en, es]) {
        expect(l10n.bottleDeleteTitle(_bottle), contains(_bottle));
        expect(l10n.bottleWindowsUserDefault('maria'), contains('maria'));
        expect(l10n.bottleExceptionRemove('Blur.exe'), contains('Blur.exe'));
      }
    });

    group('what closes the bottle says so (L15)', () {
      for (final locale in _locales) {
        final lang = '(${locale.languageCode})';

        testWidgets('stopping it asks with the shared confirmation $lang', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale, isOpen: true);
          await tester.tap(find.text(l10n.commonStop));
          await tester.pumpAndSettle();

          expect(find.text(l10n.bottleStopTitle(_bottle)), findsOneWidget);
          expect(find.text(l10n.bottleStopConfirm(_bottle)), findsOneWidget);
          await tester.tap(find.widgetWithText(FilledButton, l10n.commonStop));
          await tester.pumpAndSettle();
          verify(() => library.add(const LibraryEvent.stop(_bottle))).called(1);
        });

        testWidgets('a setting that stops it asks the same, to change $lang', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale);
          expect(find.text(l10n.bottleChangeCloses), findsOneWidget);
          // Its own note first, then the shared sentence.
          expect(
            find.text('${l10n.bottleHighResNote} ${l10n.bottleChangeCloses}'),
            findsOneWidget,
          );

          // msync is on: the switch turns it off.
          await tester.tap(find.widgetWithText(SwitchListTile, 'msync'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.bottleMsyncOff), findsOneWidget);
          expect(find.text(l10n.bottleStopConfirm(_bottle)), findsOneWidget);
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.commonChange),
          );
          await tester.pumpAndSettle();
          verify(() => bottle.add(const BottleDetailEvent.setSync('none')))
              .called(1);
        });

        testWidgets('deleting it asks with its own confirmation $lang', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          await pumpColumn(tester, locale);
          await tester.tap(find.text(l10n.bottleDelete));
          await tester.pumpAndSettle();

          expect(find.text(l10n.bottleDeleteTitle(_bottle)), findsOneWidget);
          expect(find.text(l10n.bottleDeleteConfirm), findsOneWidget);
          expect(
            find.widgetWithText(FilledButton, l10n.commonDelete),
            findsOneWidget,
          );
        });
      }
    });
  });

  // T11: the page header's counts, the bottle name rule both dialogs share,
  // the state of a controller, and what a Windows user change closes.
  group('the other bottle screens', () {
    /// The bottle page with [apps] apps, the first one in the library.
    Future<void> pumpBottle(
      WidgetTester tester, {
      required int apps,
      required Locale locale,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);

      final detail = _MockBottleDetail();
      whenListen(
        detail,
        const Stream<BottleDetailState>.empty(),
        initialState: BottleDetailState(
          isLoading: false,
          detail: BottleDetail(
            name: _bottle,
            ready: true,
            backend: 'auto',
            sync: 'msync',
            apps: [
              for (var i = 0; i < apps; i++)
                LibraryApp(
                  bottle: _bottle,
                  key: 'app$i.exe',
                  id: 'custom-$i',
                  title: 'App $i',
                  inLibrary: i == 0,
                ),
            ],
            installedBackends: const [],
          ),
        ),
      );
      final library = _MockLibrary();
      when(() => library.state)
          .thenReturn(const LibraryState(isLoading: false));
      final bottles = _MockBottles();
      when(() => bottles.state).thenReturn(const BottlesState());
      final gamepads = _MockGamepads();
      when(() => gamepads.state)
          .thenReturn(const GamepadsState(isLoading: false));
      final sections = _MockSections();
      when(() => sections.state).thenReturn(const SectionsState());
      final setup = _MockSetup();
      when(() => setup.state).thenReturn(const SetupState(isChecking: false));
      final graphics = _MockGraphics();
      when(() => graphics.state).thenReturn(const GraphicsState());
      final viewMode = _MockViewMode();
      when(() => viewMode.state).thenReturn(const ViewModeState());

      // A fresh tree: each count is its own page.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrapApp(
          MultiBlocProvider(
            providers: [
              BlocProvider<BottleDetailBloc>.value(value: detail),
              BlocProvider<LibraryBloc>.value(value: library),
              BlocProvider<BottlesBloc>.value(value: bottles),
              BlocProvider<GamepadsBloc>.value(value: gamepads),
              BlocProvider<SectionsBloc>.value(value: sections),
              BlocProvider<SetupBloc>.value(value: setup),
              BlocProvider<ViewModeBloc>.value(value: viewMode),
              BlocProvider<GraphicsBloc>.value(value: graphics),
            ],
            child: const BottleDetailView(name: _bottle),
          ),
          locale: locale,
        ),
      );
      await tester.pump();
    }

    Future<void> pumpNewBottle(
      WidgetTester tester,
      String name,
      Locale locale,
    ) async {
      final bottle = _MockNewBottle();
      whenListen(
        bottle,
        const Stream<NewBottleState>.empty(),
        initialState: NewBottleState(name: name),
      );
      final backends = _MockBackends();
      when(() => backends.state)
          .thenReturn(const BackendsState(isLoading: false));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrapApp(
          MultiBlocProvider(
            providers: [
              BlocProvider<NewBottleBloc>.value(value: bottle),
              BlocProvider<BackendsBloc>.value(value: backends),
            ],
            child: const Scaffold(body: NewBottleDialog()),
          ),
          locale: locale,
        ),
      );
    }

    group("a bottle's app count (L10)", () {
      test('in es, it changes in more than its digit from 2 to 1', () {
        expect(
          _words(es.bottleAppCount(1)),
          isNot(_words(es.bottleAppCount(2))),
        );
        expect(
          _words(en.bottleAppCount(1)),
          isNot(_words(en.bottleAppCount(2))),
        );
      });

      testWidgets('the bottle page words it in the active language', (
        tester,
      ) async {
        for (final locale in _locales) {
          final l10n = lookupAppL10n(locale);
          final headers = <String>[];
          for (final apps in [2, 1]) {
            await pumpBottle(tester, apps: apps, locale: locale);
            final header = l10n.bottleDetailSummary(
              l10n.bottleAppCount(apps),
              _bottle,
              1,
            );
            expect(find.text(header), findsOneWidget, reason: '$locale');
            headers.add(header);
          }
          expect(
            _words(headers.last),
            isNot(_words(headers.first)),
            reason: '$locale: from 2 apps to 1, more than the digit changes',
          );
        }
      });
    });

    group('the bottle page header', () {
      test('is one sentence: the count, the name and the library count', () {
        expect(
          en.bottleDetailSummary(en.bottleAppCount(3), _bottle, 2),
          '3 apps in steam · 2 in your library',
        );
        expect(
          en.bottleDetailSummary(en.bottleAppCount(1), _bottle, 1),
          '1 app in steam · 1 in your library',
        );
        expect(
          en.bottleDetailSummary(en.bottleAppCount(0), _bottle, 0),
          '0 apps in steam · 0 in your library',
        );

        final spanish = es.bottleDetailSummary(
          es.bottleAppCount(3),
          _bottle,
          2,
        );
        expect(spanish, allOf(contains(_bottle), contains('3'), contains('2')));
        expect(spanish, contains(es.bottleAppCount(3)));
        expect(
          spanish,
          isNot(en.bottleDetailSummary(en.bottleAppCount(3), _bottle, 2)),
        );
      });
    });

    group('bottleNameRule (L15)', () {
      test("says the engine's rule", () {
        expect(
          en.bottleNameRule,
          allOf(contains('64'), contains('-'), contains('_')),
        );
        expect(
          es.bottleNameRule,
          allOf(contains('64'), isNot(en.bottleNameRule)),
        );
      });

      for (final locale in _locales) {
        final lang = '(${locale.languageCode})';

        testWidgets('the new-bottle dialog shows it for a bad name $lang', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          for (final name in _badNames) {
            await pumpNewBottle(tester, name, locale);
            expect(
              find.text(l10n.bottleNameRule),
              findsOneWidget,
              reason: name,
            );
          }

          await pumpNewBottle(tester, 'steam-2', locale);
          expect(find.text(l10n.bottleNameRule), findsNothing);
        });

        testWidgets('the rename dialog shows the same text $lang', (
          tester,
        ) async {
          final l10n = lookupAppL10n(locale);
          await tester.pumpWidget(
            wrapApp(
              const Scaffold(body: RenameBottleDialog(current: _bottle)),
              locale: locale,
            ),
          );
          expect(find.text(l10n.renameBottleTitle), findsOneWidget);

          for (final name in _badNames) {
            await tester.enterText(find.byType(TextField), name);
            await tester.pump();
            expect(
              find.text(l10n.bottleNameRule),
              findsOneWidget,
              reason: name,
            );
          }

          await tester.enterText(find.byType(TextField), 'steam-2');
          await tester.pump();
          expect(find.text(l10n.bottleNameRule), findsNothing);
        });
      }
    });

    group("a controller's state (select)", () {
      test('each branch, in both languages', () {
        expect(en.gamepadsPadState('ready'), 'Ready');
        expect(en.gamepadsPadState('noAccess'), 'No access');
        for (final state in ['ready', 'noAccess']) {
          expect(es.gamepadsPadState(state), isNot(en.gamepadsPadState(state)));
        }
        expect(
          es.gamepadsPadState('ready'),
          isNot(es.gamepadsPadState('noAccess')),
        );
      });

      testWidgets('the section words each pad in the active language', (
        tester,
      ) async {
        final gamepads = _MockGamepads();
        when(() => gamepads.state).thenReturn(
          const GamepadsState(
            isLoading: false,
            report: GamepadReport(
              pads: [
                Gamepad(
                  name: 'Pad A',
                  vid: '2dc8',
                  pid: '310b',
                  readable: true,
                ),
                Gamepad(
                  name: 'Pad B',
                  vid: '045e',
                  pid: '028e',
                  readable: false,
                ),
              ],
              sdl: true,
              issues: [],
            ),
          ),
        );
        final sections = _MockSections();
        when(() => sections.state).thenReturn(const SectionsState());

        for (final locale in _locales) {
          final l10n = lookupAppL10n(locale);
          await tester.pumpWidget(
            wrapApp(
              MultiBlocProvider(
                providers: [
                  BlocProvider<GamepadsBloc>.value(value: gamepads),
                  BlocProvider<SectionsBloc>.value(value: sections),
                ],
                child: const Scaffold(
                  body: SingleChildScrollView(child: GamepadsSection()),
                ),
              ),
              locale: locale,
            ),
          );
          expect(find.text(l10n.gamepadsTitle), findsOneWidget);
          expect(find.text(l10n.gamepadsPadState('ready')), findsOneWidget);
          expect(find.text(l10n.gamepadsPadState('noAccess')), findsOneWidget);
          expect(find.text(l10n.commonCheckAgain), findsOneWidget);
        }
      });
    });

    group('the Windows user dialog', () {
      test('says a change closes what is open, as other settings do', () {
        for (final l10n in [en, es]) {
          expect(
            l10n.windowsUserHelp(l10n.bottleChangeCloses),
            contains(l10n.bottleChangeCloses),
          );
        }
      });

      testWidgets('reads in the active language', (tester) async {
        for (final locale in _locales) {
          final l10n = lookupAppL10n(locale);
          await tester.pumpWidget(
            wrapApp(
              Scaffold(
                body: WindowsUserDialog(
                  current: 'Dany',
                  macUser: 'quasar',
                  problem: (_) => null,
                ),
              ),
              locale: locale,
            ),
          );
          expect(find.text(l10n.bottleWindowsUser), findsOneWidget);
          expect(
            find.text(l10n.windowsUserHelp(l10n.bottleChangeCloses)),
            findsOneWidget,
          );
          expect(find.text(l10n.windowsUserUseHost('quasar')), findsOneWidget);
        }
      });
    });

    group('the library toggle', () {
      test('settled copy (L15)', () {
        expect(en.libraryAdd, 'Add to library');
        expect(en.libraryToggleIn, isNot(en.libraryAdd));
        expect(es.libraryToggleIn, isNot(es.libraryAdd));
      });

      testWidgets('offers libraryAdd, the app menu\'s text, until it is in', (
        tester,
      ) async {
        for (final locale in _locales) {
          final l10n = lookupAppL10n(locale);
          for (final inLibrary in [false, true]) {
            await tester.pumpWidget(
              wrapApp(
                Scaffold(
                  body: LibraryToggle(inLibrary: inLibrary, onPressed: () {}),
                ),
                locale: locale,
              ),
            );
            expect(
              find.text(inLibrary ? l10n.libraryToggleIn : l10n.libraryAdd),
              findsOneWidget,
              reason: '$locale, in library: $inLibrary',
            );
          }
        }
      });
    });
  });

  // L11 across sections: the catalog's key (T8) and the backend's (T9).
  test('"Installed" is two keys, an app and a backend, alike in English and '
      'each agreeing with its noun in Spanish (L11)', () {
    expect(en.catalogAppInstalled, 'Installed');
    expect(en.backendInstalled, en.catalogAppInstalled);
    expect(es.backendInstalled, isNot(es.catalogAppInstalled));
  });
}
