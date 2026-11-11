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
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/bloc/run_options/run_options_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
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
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/app/presentation/library/widgets/bottle_tag.dart';
import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/hint_text.dart';
import 'package:bodega/app/shared/text/issue_text.dart';
import 'package:bodega/app/shared/text/problem_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/app/shared/text/step_text.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/app/shared/widgets/install_panel.dart';
import 'package:bodega/app/shared/widgets/shell_body.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/backend_role.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/entities/install_step.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockNewBottle extends MockBloc<NewBottleEvent, NewBottleState>
    implements NewBottleBloc {}

class _MockRunOptions extends MockBloc<RunOptionsEvent, RunOptionsState>
    implements RunOptionsBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

const _es = Locale('es');
const _locales = [Locale('en'), _es];

/// What the CLI says to run, where the app says what to do in it (L8).
final _command = RegExp(r'\bbodega [a-z]|rm -rf|gh release|sudo ');

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

// Run hints.

/// One of each hint, and what its text has to name (L8).
const _hintCases = <(RunHint, List<String>)>[
  (RunHint.log(LogHint.freeType), ['FreeType']),
  (RunHint.log(LogHint.gnuTls), ['GnuTLS']),
  (RunHint.log(LogHint.otherServer), []),
  (RunHint.log(LogHint.cannotOpen), ['<>:"|?*']),
  (RunHint.log(LogHint.fixNotApplied), ['Steam', 'Bodega']),
  (RunHint.antiCheat(game: 'POLYGON'), ['POLYGON', 'Easy Anti-Cheat', '206']),
  (RunHint.antiCheat(), ['Easy Anti-Cheat', '206']),
];

/// What a bottle shows after a run that missed its fix and failed Easy
/// Anti-Cheat.
const _shownHints = [
  RunHint.log(LogHint.fixNotApplied),
  RunHint.antiCheat(game: 'POLYGON'),
];

// Install and D3DMetal steps.

/// The app being installed: it asks for msync.
const _steamApp = CatalogApp(
  id: 'steam',
  title: 'Steam',
  status: CatalogStatus.tested,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'msync',
  host: 'cdn.akamai.steamstatic.com',
  hasChecksum: true,
);

/// D3DMetal before its import: Bodega never downloads it.
const _d3dmetal = BackendInfo(
  name: 'd3dmetal',
  installed: false,
  downloadable: false,
);

// Host issues, backend roles and graphics.

const _pad = 'Microsoft X-Box 360 pad';
const _installCommand = 'sudo apt install steam-devices';

/// One issue of each kind, as the engine gives them: only a pad issue names
/// something.
final _issues = [
  for (final kind in HostIssueKind.values)
    HostIssue(
      kind: kind,
      subject: kind == HostIssueKind.padNoAccess ? _pad : null,
      command: kind == HostIssueKind.unsupportedCpu ? null : _installCommand,
    ),
];

/// What Blur draws with: DX9 in 32 bits, which d3dmetal does not suit (G3).
const _blurGraphics = ExeGraphics(
  bits: 32,
  directx: 'DX9',
  misfits: ['d3dmetal'],
);

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
        final dxmt = _dxmt.copyWith(role: BackendRole.dx10to11);
        await pumpCard(tester, dxmt, idle);
        expect(
          find.text('D3D10 and D3D11 on Metal. The one launchers use.'),
          findsOneWidget,
        );
        expect(find.text('Used for: $role'), findsOneWidget);

        await pumpCard(tester, dxmt, idle, locale: _es);
        expect(find.text(es.backendDescriptionDxmt), findsOneWidget);
        expect(
          find.text(es.backendUsedFor(es.backendRoleDx10to11)),
          findsOneWidget,
        );
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
            changes: Stream.value(
              before.copyWith(gptkInstalled: (version: '3.0')),
            ),
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

  // T16: lib/app/shared/text/error_text.dart and problem_text.dart, for every
  // AppError code, user-name and path problem (L6, L8, E13).
  group('errors and problems', () {
    /// The raw text behind a code, which no text may show (E13).
    const detail = 'DETAIL-7f3';
    const log = '/l/steam/logs/a.log';

    /// One of each code, and what its text has to name: the bottle, path,
    /// log or value it carries (L8).
    final codes = <(AppError, List<String>)>[
      (const AppError.bottleNotFound('steam', detail: detail), ['steam']),
      (const AppError.bottleExists('steam', detail: detail), ['steam']),
      (const AppError.bottleNotReady('steam', detail: detail), ['steam']),
      (const AppError.bottleOpen('steam', detail: detail), ['steam']),
      for (final timedOut in [true, false])
        (AppError.bottleSetupFailed(log, timedOut, detail: detail), [log]),
      (const AppError.badBottleName('my games', detail: detail), ['my games']),
      for (final problem in UserNameProblem.values)
        (AppError.badUserName('Dany', problem, detail: detail), ['Dany']),
      (
        const AppError.badPath(PathProblem.missing('/g/a.exe'), detail: detail),
        ['/g/a.exe'],
      ),
      (
        const AppError.badPath(
          PathProblem.windowsName(part: 'odd:', path: '/g/odd:/a.exe'),
          detail: detail,
        ),
        ['"odd:"', '/g/odd:/a.exe'],
      ),
      (
        const AppError.appNotFound('steam', 'blur.exe', detail: detail),
        ['steam', 'blur.exe'],
      ),
      (const AppError.appNotFound('steam', null, detail: detail), ['steam']),
      (const AppError.appAlreadyAdded('steam', detail: detail), ['steam']),
      (const AppError.badEnvLine(2, 'bad', detail: detail), ['2', 'bad']),
      (const AppError.noRuntime(detail: detail), []),
      (
        const AppError.alreadyInstalled('/h/backends/dxvk', detail: detail),
        ['/h/backends/dxvk'],
      ),
      (
        const AppError.checksumMismatch('/d/dxvk.tar.gz', detail: detail),
        ['/d/dxvk.tar.gz'],
      ),
      (
        const AppError.incompleteArchive(
          'engine-11.0',
          'engine/bin/wine',
          detail: detail,
        ),
        ['engine-11.0', 'engine/bin/wine'],
      ),
      (
        const AppError.corruptData('/b/steam/apps.json', detail: detail),
        ['/b/steam/apps.json'],
      ),
      (const AppError.backendNotInstalled('dxvk', detail: detail), ['dxvk']),
      (
        const AppError.noD3DMetal('/v/GPTK', 'redist/lib', detail: detail),
        ['/v/GPTK', 'redist/lib'],
      ),
      (const AppError.crossOverCopy(detail: detail), []),
      (
        const AppError.mountFailed('/d/GPTK.dmg', detail: detail),
        ['/d/GPTK.dmg'],
      ),
      (const AppError.licenseNotAccepted(detail: detail), []),
      (const AppError.cancelled(detail: detail), []),
      for (final tool in WineTool.values)
        (AppError.wineToolFailed(tool, 53, log, detail: detail), ['53', log]),
      (
        const AppError.installerNoExe('Steam/steam.exe', log, detail: detail),
        ['Steam/steam.exe', log],
      ),
      (
        const AppError.processFailed(
          '/usr/bin/hdiutil attach',
          2,
          detail: detail,
        ),
        ['/usr/bin/hdiutil attach', '2'],
      ),
      (
        const AppError.processFailed('wine --version', null, detail: detail),
        ['wine --version'],
      ),
      (
        const AppError.downloadCut(1234000000, 2468000000, detail: detail),
        ['234', '468'],
      ),
      (const AppError.updateNotInstallable(detail: detail), []),
      (
        const AppError.updateNoChecksum(
          'Bodega-1.5.0-macos-arm64.dmg',
          detail: detail,
        ),
        ['Bodega-1.5.0-macos-arm64.dmg'],
      ),
      (
        const AppError.updateNotWritable('/Applications', detail: detail),
        ['/Applications'],
      ),
      (const AppError.network(detail: detail), []),
      (const AppError.unknown(detail: detail), []),
    ];

    test('the cases hold every code', () {
      expect({
        for (final (error, _) in codes) error.runtimeType,
      }, hasLength(31));
    });

    for (final (language, l10n) in [('en', en), ('es', es)]) {
      test('in $language, each code is worded, names what it carries, gives no '
          'command and leaves its detail out (L8, E13)', () {
        for (final (error, names) in codes) {
          final text = error.localized(l10n);
          final reason = '$language: $error';
          expect(text.trim(), isNotEmpty, reason: reason);
          for (final name in names) {
            expect(text, contains(name), reason: reason);
          }
          expect(text, isNot(contains(_command)), reason: reason);
          expect(text, isNot(contains(detail)), reason: reason);
        }
      });
    }

    test('each code has words of its own, and Spanish ones', () {
      for (final l10n in [en, es]) {
        final texts = [for (final (error, _) in codes) error.localized(l10n)];
        expect(texts.toSet(), hasLength(texts.length), reason: l10n.localeName);
      }
      for (final (error, _) in codes) {
        expect(
          error.localized(es),
          isNot(error.localized(en)),
          reason: '$error',
        );
      }
    });

    test('an open bottle says to stop it, where the engine says bodega stop '
        '(L8)', () {
      const open = AppError.bottleOpen(
        'steam',
        detail: 'the bottle steam is open: bodega stop steam',
      );
      expect(
        open.localized(en),
        'The bottle steam is open. Stop it, then try again.',
      );
      expect(open.localized(es), es.errBottleOpen('steam'));
    });

    test('a label or a sentence inside an error comes from its own key, in the '
        'same language (L12)', () {
      for (final l10n in [en, es]) {
        expect(
          const AppError.backendNotInstalled('dxvk').localized(l10n),
          contains(l10n.navBackends),
        );
        expect(
          const AppError.badBottleName('my games').localized(l10n),
          contains(l10n.bottleNameRule),
        );
        expect(
          const AppError.badUserName(
            'Dany',
            UserNameProblem.tooLong,
          ).localized(l10n),
          contains(l10n.problemUserNameTooLong),
        );
      }
    });

    test('a cut download counts MB of 10^6 bytes, for the locale (L13)', () {
      const cut = AppError.downloadCut(1234000000, 2468000000);
      expect(cut.localized(en), contains('1,234 MB of 2,468 MB'));
      expect(
        cut.localized(es),
        allOf(contains('1.234 MB'), contains('2.468 MB')),
      );
    });

    group('problem texts', () {
      test('each user-name problem has words of its own, and Spanish ones', () {
        for (final l10n in [en, es]) {
          final texts = [
            for (final problem in UserNameProblem.values)
              userNameProblemText(l10n, problem),
          ];
          expect(texts, everyElement(isNotEmpty), reason: l10n.localeName);
          expect(
            texts.toSet(),
            hasLength(UserNameProblem.values.length),
            reason: l10n.localeName,
          );
        }
        for (final problem in UserNameProblem.values) {
          expect(
            userNameProblemText(es, problem),
            isNot(userNameProblemText(en, problem)),
            reason: problem.name,
          );
        }
      });

      test('a path problem names the path, and the name Windows refuses', () {
        const missing = PathProblem.missing('/g/a.exe');
        const odd = PathProblem.windowsName(
          part: 'odd:',
          path: '/g/odd:/a.exe',
        );
        expect(pathProblemText(en, missing), "/g/a.exe doesn't exist.");
        for (final l10n in [en, es]) {
          expect(pathProblemText(l10n, missing), contains('/g/a.exe'));
          expect(
            pathProblemText(l10n, odd),
            allOf(contains('"odd:"'), contains('/g/odd:/a.exe')),
          );
          expect(
            pathProblemText(l10n, odd),
            isNot(pathProblemText(l10n, missing)),
          );
        }
      });
    });

    testWidgets('an error panel rewords when the language changes (L6)', (
      tester,
    ) async {
      const error = AppError.bottleExists('games');
      final bottle = _MockNewBottle();
      whenListen(
        bottle,
        const Stream<NewBottleState>.empty(),
        initialState: const NewBottleState(name: 'games', error: error),
      );
      final backends = _MockBackends();
      when(() => backends.state)
          .thenReturn(const BackendsState(isLoading: false));

      // The same state, under one language and then the other.
      for (final (shown, other) in [(en, es), (es, en)]) {
        await tester.pumpWidget(
          wrapApp(
            MultiBlocProvider(
              providers: [
                BlocProvider<NewBottleBloc>.value(value: bottle),
                BlocProvider<BackendsBloc>.value(value: backends),
              ],
              child: const Scaffold(body: NewBottleDialog()),
            ),
            locale: Locale(shown.localeName),
          ),
        );
        expect(find.text(error.localized(shown)), findsOneWidget);
        expect(find.text(error.localized(other)), findsNothing);
      }
    });

    testWidgets('the Windows user dialog words the problem in the active '
        'language', (tester) async {
      for (final locale in _locales) {
        final l10n = lookupAppL10n(locale);
        await tester.pumpWidget(
          wrapApp(
            Scaffold(
              body: WindowsUserDialog(
                current: '',
                macUser: 'quasar',
                problem: (_) => UserNameProblem.tooLong,
              ),
            ),
            locale: locale,
          ),
        );
        expect(
          find.text(userNameProblemText(l10n, UserNameProblem.tooLong)),
          findsOneWidget,
          reason: '$locale',
        );
      }
    });
  });

  // T18: Copy details under an error panel, and the toast that follows a
  // copy (L9).
  group('copy details (L9)', () {
    /// The raw text behind an error: a tool's stderr (E13).
    const detail = 'stderr: boom';

    test('the button and its toast, in English', () {
      expect(en.commonCopyDetails, 'Copy details');
      expect(en.commonCopied, 'Copied');
    });

    test('each has Spanish words of its own', () {
      for (final text in <String Function(AppL10n)>[
        (l10n) => l10n.commonCopyDetails,
        (l10n) => l10n.commonCopied,
      ]) {
        expect(text(es).trim(), isNotEmpty);
        expect(text(es), isNot(text(en)));
      }
      expect(es.commonCopied, isNot(es.commonCopyDetails));
    });

    for (final locale in _locales) {
      final l10n = lookupAppL10n(locale);

      testWidgets('the button and its toast read in the active language, and '
          'the detail only reaches the clipboard (${locale.languageCode})', (
        tester,
      ) async {
        final copied = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text']);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await tester.pumpWidget(
          wrapApp(
            const Scaffold(
              body: CopyDetailsButton(error: AppError.unknown(detail: detail)),
            ),
            locale: locale,
          ),
        );
        expect(find.text(l10n.commonCopyDetails), findsOneWidget);
        expect(find.textContaining('boom', findRichText: true), findsNothing);

        await tester.tap(find.text(l10n.commonCopyDetails));
        // The copy, then the toast, which slides in.
        await tester.pumpAndSettle();
        expect(copied, [detail]);
        expect(find.text(l10n.commonCopied), findsOneWidget);
        expect(find.textContaining('boom', findRichText: true), findsNothing);
        // The toast closes by itself.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('an error without a detail gets no button', (tester) async {
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(body: CopyDetailsButton(error: AppError.unknown())),
        ),
      );
      expect(find.text(en.commonCopyDetails), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  // T19: lib/app/shared/text/hint_text.dart for every run hint (L8), and
  // the three places that show them, which reword when the language changes
  // (L6).
  group('run hints (L8)', () {
    test('the cases hold every hint', () {
      expect({
        for (final (hint, _) in _hintCases)
          if (hint case LogRunHint(hint: final log)) log,
      }, LogHint.values.toSet());
      expect(
        {
          for (final (hint, _) in _hintCases)
            if (hint case AntiCheatRunHint(:final game)) game,
        },
        {'POLYGON', null},
      );
    });

    for (final (language, l10n) in [('en', en), ('es', es)]) {
      test('in $language, each hint is worded, names what it carries and '
          'gives no command', () {
        for (final (hint, names) in _hintCases) {
          final text = hint.localized(l10n);
          final reason = '$language: $hint';
          expect(text.trim(), isNotEmpty, reason: reason);
          for (final name in names) {
            expect(text, contains(name), reason: reason);
          }
          expect(text, isNot(contains(_command)), reason: reason);
        }
      });
    }

    test('each hint has words of its own, and Spanish ones', () {
      for (final l10n in [en, es]) {
        final texts = [
          for (final (hint, _) in _hintCases) hint.localized(l10n),
        ];
        expect(texts.toSet(), hasLength(texts.length), reason: l10n.localeName);
      }
      for (final (hint, _) in _hintCases) {
        expect(hint.localized(es), isNot(hint.localized(en)), reason: '$hint');
      }
    });

    test('a hint from a log reads as its own key, in both languages', () {
      for (final l10n in [en, es]) {
        for (final log in LogHint.values) {
          expect(
            RunHint.log(log).localized(l10n),
            logHintText(l10n, log),
            reason: '${l10n.localeName}: $log',
          );
        }
        expect(
          const RunHint.log(LogHint.gnuTls).localized(l10n),
          l10n.hintGnuTls,
        );
      }
    });

    test('another Wine server says to stop the bottle, where the engine says '
        'bodega stop', () {
      const server = RunHint.log(LogHint.otherServer);
      expect(
        server.localized(en),
        'A Wine server from another engine is still running in this bottle. '
        'Stop the bottle, then open the app again.',
      );
      expect(server.localized(es), es.hintOtherServer);
    });

    test('Easy Anti-Cheat names the game its log names, or says this game', () {
      expect(
        const RunHint.antiCheat(game: 'POLYGON').localized(en),
        "POLYGON uses Easy Anti-Cheat, which couldn't load under Wine "
        "(error 206). This isn't a problem with your installation: it depends "
        "on the game's developers and on Epic.",
      );
      expect(
        const RunHint.antiCheat().localized(en),
        startsWith('This game uses Easy Anti-Cheat'),
      );
      expect(
        const RunHint.antiCheat(game: 'POLYGON').localized(es),
        es.hintAntiCheat('POLYGON'),
      );
      expect(const RunHint.antiCheat().localized(es), es.hintAntiCheatUnnamed);
    });

    // The state holds codes, so what is on screen rewords on a switch (L6).
    group('the places that show hints word them in the active language (L6)', () {
      /// The same state, under one language and then the other.
      final switches = [(en, es), (es, en)];

      String tooltip(AppL10n l10n) =>
          [for (final hint in _shownHints) hint.localized(l10n)].join('\n');

      testWidgets("a bottle tag's warning, one line per hint", (tester) async {
        for (final (shown, other) in switches) {
          await tester.pumpWidget(
            wrapApp(
              const Scaffold(
                body: BottleTag(bottle: 'steam', hints: _shownHints),
              ),
              locale: Locale(shown.localeName),
            ),
          );
          expect(find.byTooltip(tooltip(shown)), findsOneWidget);
          expect(find.byTooltip(tooltip(other)), findsNothing);
        }

        // No hint, no warning.
        await tester.pumpWidget(
          wrapApp(
            const Scaffold(
              body: BottleTag(bottle: 'steam', hints: []),
            ),
          ),
        );
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });

      testWidgets("a bottle's page, one paragraph per hint", (tester) async {
        final bottle = _MockBottleDetail();
        final library = _MockLibrary();
        final setup = _MockSetup();
        final sections = _MockSections();
        final graphics = _MockGraphics();
        final gamepads = _MockGamepads();
        when(() => library.state)
            .thenReturn(const LibraryState(isLoading: false));
        when(() => setup.state).thenReturn(const SetupState(isChecking: false));
        when(() => sections.state).thenReturn(const SectionsState());
        when(() => graphics.state).thenReturn(const GraphicsState());
        when(() => gamepads.state)
            .thenReturn(const GamepadsState(isLoading: false));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(600, 3000);
        addTearDown(tester.view.reset);

        for (final (shown, other) in switches) {
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
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: BottleColumn(
                      detail: BottleDetail(
                        name: 'steam',
                        ready: true,
                        backend: 'auto',
                        sync: 'msync',
                      ),
                      isBusy: false,
                      isOpen: false,
                      hints: _shownHints,
                    ),
                  ),
                ),
              ),
              locale: Locale(shown.localeName),
            ),
          );
          for (final hint in _shownHints) {
            expect(find.text(hint.localized(shown)), findsOneWidget);
            expect(find.text(hint.localized(other)), findsNothing);
          }
        }
      });

      testWidgets('the toast of a new hint', (tester) async {
        const hint = RunHint.log(LogHint.otherServer);
        for (final (shown, other) in switches) {
          final library = _MockLibrary();
          final updates = _MockUpdate();
          final install = _MockInstall();
          whenListen(
            library,
            Stream.value(const LibraryState(toast: hint, toastId: 1)),
            initialState: const LibraryState(),
          );
          whenListen(
            updates,
            const Stream<UpdateState>.empty(),
            initialState: const UpdateState(),
          );
          whenListen(
            install,
            const Stream<InstallState>.empty(),
            initialState: const InstallState(),
          );
          // A fresh tree, so the listener subscribes to this stream.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider<LibraryBloc>.value(value: library),
                BlocProvider<UpdateBloc>.value(value: updates),
                BlocProvider<InstallBloc>.value(value: install),
              ],
              child: wrapApp(
                const ShellBody(child: SizedBox.expand()),
                locale: Locale(shown.localeName),
              ),
            ),
          );
          // The state arrives and asks for the toast; the next frame adds it to
          // the toasts' list, and it slides in.
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(hint.localized(shown)), findsOneWidget);
          expect(find.text(hint.localized(other)), findsNothing);

          // It closes by itself after 5 s: no timer outlives the test.
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        }
      });
    });
  });

  // T20: lib/app/shared/text/step_text.dart for every install and D3DMetal
  // step, the widgets that show them, and the D3DMetal toast when its
  // version is unknown (L6, L8, E3).
  group('install and D3DMetal steps', () {
    group('installStepText', () {
      /// One of each step, its English text and what its text has to name.
      const steps = <(InstallStep, String, List<String>)>[
        (
          InstallStep.unpinnedDownload('example.com'),
          'This installer has no fixed checksum: it relies on HTTPS and '
              'example.com.',
          ['example.com'],
        ),
        (InstallStep.downloading(), 'Downloading the installer', []),
        (
          InstallStep.syncMismatch('none'),
          "This bottle keeps its sync (none), not Steam's (msync). If Steam "
              "fails, change it in the bottle's settings.",
          ['none', 'Steam', 'msync'],
        ),
        (
          InstallStep.creatingBottle('steam'),
          'Creating the bottle steam',
          ['steam'],
        ),
        (
          InstallStep.registry('ServicesPipeTimeout'),
          'Writing ServicesPipeTimeout to the Windows registry',
          ['ServicesPipeTimeout'],
        ),
        (InstallStep.runningInstaller(), 'Running the installer', []),
        (InstallStep.waiting(), 'Waiting for the installation to finish', []),
      ];

      test('the cases hold every step', () {
        expect({
          for (final (step, _, _) in steps) step.runtimeType,
        }, hasLength(7));
      });

      test('in English, each step reads as written', () {
        for (final (step, english, _) in steps) {
          expect(
            installStepText(en, step, _steamApp),
            english,
            reason: '$step',
          );
        }
      });

      for (final (language, l10n) in [('en', en), ('es', es)]) {
        test('in $language, each step names what it carries and gives no '
            'command (L8)', () {
          for (final (step, _, names) in steps) {
            final text = installStepText(l10n, step, _steamApp);
            final reason = '$language: $step';
            expect(text.trim(), isNotEmpty, reason: reason);
            for (final name in names) {
              expect(text, contains(name), reason: reason);
            }
            expect(text, isNot(contains(_command)), reason: reason);
          }
        });
      }

      test('each step has words of its own, and Spanish ones', () {
        for (final l10n in [en, es]) {
          final texts = [
            for (final (step, _, _) in steps)
              installStepText(l10n, step, _steamApp),
          ];
          expect(
            texts.toSet(),
            hasLength(steps.length),
            reason: l10n.localeName,
          );
        }
        for (final (step, _, _) in steps) {
          expect(
            installStepText(es, step, _steamApp),
            isNot(installStepText(en, step, _steamApp)),
            reason: '$step',
          );
        }
      });

      test('a download with no pinned checksum reads as the download note: one '
          'meaning, one text (L15)', () {
        for (final l10n in [en, es]) {
          expect(
            installStepText(
              l10n,
              const InstallStep.unpinnedDownload('example.com'),
              _steamApp,
            ),
            l10n.installNoChecksum('example.com'),
          );
        }
      });

      test('a sync mismatch names the app and the sync it asks for, in Spanish '
          'too', () {
        expect(
          installStepText(
            es,
            const InstallStep.syncMismatch('none'),
            _steamApp,
          ),
          es.stepSyncMismatch('none', 'Steam', 'msync'),
        );
      });
    });

    group('gptkStepText', () {
      const english = {
        GptkStep.opening: 'Opening the disk image',
        GptkStep.acceptLicense:
            "Accept Apple's license in the window that opened",
        GptkStep.importing: 'Importing D3DMetal',
      };

      test('in English, each step reads as written', () {
        expect(english.keys, containsAll(GptkStep.values));
        for (final MapEntry(key: step, value: text) in english.entries) {
          expect(gptkStepText(en, step), text, reason: '$step');
        }
      });

      test('each step has words of its own, and Spanish ones', () {
        for (final l10n in [en, es]) {
          final texts = [
            for (final step in GptkStep.values) gptkStepText(l10n, step),
          ];
          expect(texts, everyElement(isNotEmpty), reason: l10n.localeName);
          expect(texts, everyElement(isNot(contains(_command))));
          expect(
            texts.toSet(),
            hasLength(GptkStep.values.length),
            reason: l10n.localeName,
          );
        }
        for (final step in GptkStep.values) {
          expect(
            gptkStepText(es, step),
            isNot(gptkStepText(en, step)),
            reason: '$step',
          );
        }
      });
    });

    group('the install panel', () {
      Future<void> pumpPanel(
        WidgetTester tester,
        InstallState state, {
        Locale locale = const Locale('en'),
      }) async {
        final bloc = _MockInstall();
        whenListen(
          bloc,
          const Stream<InstallState>.empty(),
          initialState: state,
        );
        await tester.pumpWidget(
          BlocProvider<InstallBloc>.value(
            value: bloc,
            child: wrapApp(
              const Scaffold(body: InstallPanel()),
              locale: locale,
            ),
          ),
        );
      }

      testWidgets('says the step in the active language (L6)', (tester) async {
        const state = InstallState(
          phase: InstallPhase.installing,
          app: _steamApp,
          step: InstallStep.registry('ServicesPipeTimeout'),
        );
        await pumpPanel(tester, state);
        expect(
          find.text('Writing ServicesPipeTimeout to the Windows registry'),
          findsOneWidget,
        );

        await pumpPanel(tester, state, locale: _es);
        expect(
          find.text(es.stepRegistry('ServicesPipeTimeout')),
          findsOneWidget,
        );
        expect(find.text(en.stepRegistry('ServicesPipeTimeout')), findsNothing);
      });

      testWidgets('before its first step, says it is installing', (
        tester,
      ) async {
        const state = InstallState(
          phase: InstallPhase.installing,
          app: _steamApp,
        );
        await pumpPanel(tester, state);
        expect(find.text('Installing'), findsOneWidget);
        await pumpPanel(tester, state, locale: _es);
        expect(find.text(es.commonInstalling), findsOneWidget);
      });
    });

    group("D3DMetal's card and section", () {
      late _MockBackends bloc;

      setUp(() => bloc = _MockBackends());

      const idle = BackendsState(isLoading: false);

      Future<void> pumpCard(
        WidgetTester tester,
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
                  child: BackendCard(backend: _d3dmetal, state: state),
                ),
              ),
              locale: locale,
            ),
          ),
        );
      }

      testWidgets("the card says the import's step in the active language "
          '(L6)', (tester) async {
        for (final step in GptkStep.values) {
          final importing = idle.copyWith(busy: 'd3dmetal', gptkStep: step);
          await pumpCard(tester, importing);
          expect(find.text(gptkStepText(en, step)), findsOneWidget);
          // The import can be cancelled at any step.
          expect(find.text('Cancel'), findsOneWidget);

          await pumpCard(tester, importing, locale: _es);
          expect(find.text(gptkStepText(es, step)), findsOneWidget);
          expect(find.text(gptkStepText(en, step)), findsNothing);
        }
      });

      group('a version it cannot read still toasts (E3)', () {
        // The install ends: an unknown version arrives, with the bottles there
        // are. A fresh tree, so the listener subscribes to this install's
        // stream.
        Future<void> install(
          WidgetTester tester, {
          required List<String> bottles,
          Locale locale = const Locale('en'),
        }) async {
          final before = idle.copyWith(bottles: bottles);
          whenListen(
            bloc,
            Stream.value(before.copyWith(gptkInstalled: (version: null))),
            initialState: before,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            BlocProvider<BackendsBloc>.value(
              value: bloc,
              child: wrapApp(
                Scaffold(
                  body: SingleChildScrollView(
                    child: GptkSection(state: before),
                  ),
                ),
                locale: locale,
              ),
            ),
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

        testWidgets('without the version, and the check that follows', (
          tester,
        ) async {
          await install(tester, bottles: const ['steam']);
          expect(find.text('D3DMetal is installed. Checking…'), findsOneWidget);
          await letItClose(tester);

          await install(tester, bottles: const []);
          expect(
            find.text('D3DMetal is installed. Create a bottle to check it.'),
            findsOneWidget,
          );
          await letItClose(tester);
        });

        testWidgets('in Spanish, each sentence from its key', (tester) async {
          await install(tester, bottles: const ['steam'], locale: _es);
          expect(
            find.text(
              '${es.gptkInstalledToastNoVersion} ${es.gptkToastChecking}',
            ),
            findsOneWidget,
          );
          expect(
            es.gptkInstalledToastNoVersion,
            isNot(en.gptkInstalledToastNoVersion),
          );
          await letItClose(tester);
        });
      });
    });
  });

  // T21: lib/app/shared/text/issue_text.dart for host issues, and
  // backend_text.dart for backend roles and what an exe draws with, with the
  // widgets that show them (L8).
  group('host issues, backend roles and graphics', () {
    group('host issues', () {
      test('words each kind in English', () {
        String words(HostIssueKind kind) {
          final text = hostIssueText(en, _issues[kind.index]);
          return '${text.title} | ${text.detail}';
        }

        expect(
          words(HostIssueKind.noRosetta),
          'Rosetta is missing | Windows games run on Rosetta 2.',
        );
        expect(
          words(HostIssueKind.unsupportedCpu),
          'Unsupported processor | Bodega needs an x86_64 processor.',
        );
        expect(
          words(HostIssueKind.noVulkan),
          'Vulkan is missing | Games draw with Vulkan (DXVK).',
        );
        expect(
          words(HostIssueKind.noAudio),
          'Audio is missing | Wine needs PulseAudio, or PipeWire with Pulse '
          'support.',
        );
        expect(
          words(HostIssueKind.padNoAccess),
          'No access to the controller $_pad | '
          "Bodega can't open the controller, so Wine won't see it. Install the "
          'controller udev rules (on Arch, the package is in multilib), then '
          'unplug the controller and plug it in again.',
        );
        expect(
          words(HostIssueKind.noSdl),
          'SDL2 is missing | Wine uses SDL2 to understand controllers. Without '
          'it, Wine uses udev, which knows fewer controllers.',
        );
      });

      for (final (language, l10n) in [('en', en), ('es', es)]) {
        test('in $language, each kind has words of its own, and no command '
            '(L8)', () {
          final texts = [
            for (final issue in _issues) ...[
              hostIssueText(l10n, issue).title,
              hostIssueText(l10n, issue).detail,
            ],
          ];
          expect(texts.toSet(), hasLength(texts.length));
          for (final text in texts) {
            expect(text.trim(), isNotEmpty);
            // The card shows the install command apart, to copy.
            expect(text, isNot(contains(_installCommand)));
            expect(text, isNot(contains('bodega ')));
          }
        });

        test('in $language, a pad issue names the pad (E3)', () {
          final pad = _issues[HostIssueKind.padNoAccess.index];
          expect(hostIssueText(l10n, pad).title, contains(_pad));
        });
      }

      test('each text is translated', () {
        for (final issue in _issues) {
          final english = hostIssueText(en, issue);
          final spanish = hostIssueText(es, issue);
          expect(spanish.title, isNot(english.title), reason: '${issue.kind}');
          expect(
            spanish.detail,
            isNot(english.detail),
            reason: '${issue.kind}',
          );
        }
      });

      Future<void> pumpCard(
        WidgetTester tester,
        HostIssue issue,
        Locale locale,
      ) => tester.pumpWidget(
        wrapApp(
          Scaffold(body: RequirementCard(issue: issue)),
          locale: locale,
        ),
      );

      for (final locale in _locales) {
        testWidgets(
          'a card names the pad in the active language, and keeps its '
          'install command (${locale.languageCode})',
          (tester) async {
            final l10n = lookupAppL10n(locale);
            await pumpCard(
              tester,
              _issues[HostIssueKind.padNoAccess.index],
              locale,
            );

            expect(find.text(l10n.issuePadNoAccessTitle(_pad)), findsOneWidget);
            expect(find.text(l10n.issuePadNoAccessDetail), findsOneWidget);
            expect(find.text(_installCommand), findsOneWidget);
            expect(find.text(l10n.setupCopyCommand), findsOneWidget);
          },
        );
      }

      testWidgets('a card rewords when the language changes (L6)', (
        tester,
      ) async {
        final issue = _issues[HostIssueKind.noRosetta.index];
        await pumpCard(tester, issue, const Locale('en'));
        expect(find.text(en.issueNoRosettaTitle), findsOneWidget);

        await pumpCard(tester, issue, _es);
        expect(find.text(es.issueNoRosettaTitle), findsOneWidget);
        expect(find.text(es.issueNoRosettaDetail), findsOneWidget);
        expect(find.text(en.issueNoRosettaTitle), findsNothing);
        expect(find.text(en.issueNoRosettaDetail), findsNothing);
      });
    });

    group('backend roles', () {
      test('words each role in English', () {
        expect(
          {
            for (final role in BackendRole.values)
              role: backendRoleText(en, role),
          },
          {
            BackendRole.dx11to12x64: 'DirectX 11 and 12, 64 bits only',
            BackendRole.dx10to11: 'DirectX 10 and 11, 32 and 64 bits',
            BackendRole.everythingElse: "Everything: DirectX 9 and older, and what the others can't run",
            BackendRole.dx8to12: 'DirectX 8 to 12 (DXVK and vkd3d-proton)',
            BackendRole.everythingSlower: 'Everything, slower than dxvk',
          },
        );
      });

      test('in Spanish, each role has words of its own, translated', () {
        final spanish = [
          for (final role in BackendRole.values) backendRoleText(es, role),
        ];
        expect(spanish.toSet(), hasLength(BackendRole.values.length));
        for (final role in BackendRole.values) {
          expect(
            backendRoleText(es, role),
            isNot(backendRoleText(en, role)),
            reason: '$role',
          );
        }
      });

      group('on the card', () {
        late _MockBackends bloc;

        setUp(() => bloc = _MockBackends());

        Future<void> pumpCard(
          WidgetTester tester,
          BackendInfo backend,
          Locale locale,
        ) async {
          const state = BackendsState(isLoading: false);
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

        const dxvk = BackendInfo(
          name: 'dxvk',
          installed: true,
          downloadable: false,
          role: BackendRole.dx8to12,
        );

        for (final locale in _locales) {
          testWidgets('says what the backend is for, in the active language '
              '(${locale.languageCode})', (tester) async {
            final l10n = lookupAppL10n(locale);
            await pumpCard(tester, dxvk, locale);
            expect(
              find.text(l10n.backendUsedFor(l10n.backendRoleDx8to12)),
              findsOneWidget,
            );
          });
        }

        testWidgets('says nothing of it without a role', (tester) async {
          await pumpCard(tester, dxvk.copyWith(role: null), const Locale('en'));
          expect(find.textContaining('Used for'), findsNothing);
        });
      });
    });

    group('what an exe draws with', () {
      test(
        'the label names the DirectX and the bits, or only the bits (G2)',
        () {
          const noDirectX = ExeGraphics(bits: 64, directx: '');
          expect(graphicsLabelText(en, _blurGraphics), 'DX9 · 32 bits');
          expect(graphicsLabelText(en, noDirectX), '64 bits');
          expect(
            graphicsLabelText(es, _blurGraphics),
            es.graphicsLabel('DX9', 32),
          );
          expect(graphicsLabelText(es, noDirectX), es.graphicsBits(64));
          expect(
            graphicsLabelText(es, _blurGraphics),
            allOf(contains('DX9'), contains('32')),
          );
        },
      );

      test('a backend that does not suit the exe is named, with the Automatic '
          'option of each language (G4, L12)', () {
        expect(
          graphicsMisfitText(
            en,
            _blurGraphics,
            program: 'Blur',
            backend: 'd3dmetal',
          ),
          "Blur is 32-bit, with DirectX 9: d3dmetal won't work for it. "
          'Use Automatic.',
        );
        final spanish = graphicsMisfitText(
          es,
          _blurGraphics,
          program: 'Blur',
          backend: 'd3dmetal',
        );
        expect(
          spanish,
          es.graphicsMisfitWarning(
            'Blur',
            32,
            '9',
            'd3dmetal',
            es.bottleGraphicsAuto,
          ),
        );
        expect(spanish, contains(es.bottleGraphicsAuto));
        expect(spanish, isNot(contains(en.bottleGraphicsAuto)));
      });

      test('a backend that suits the exe gives no warning', () {
        for (final l10n in [en, es]) {
          expect(
            graphicsMisfitText(
              l10n,
              _blurGraphics,
              program: 'Blur',
              backend: 'wine',
            ),
            isNull,
          );
        }
      });

      group('in the run-with-options dialog', () {
        const exe = r'C:\Blur\Blur.exe';
        late _MockRunOptions options;
        late _MockGraphics graphics;
        late _MockSetup setup;
        late _MockLibrary library;

        setUp(() {
          options = _MockRunOptions();
          graphics = _MockGraphics();
          setup = _MockSetup();
          library = _MockLibrary();
          when(() => setup.state)
              .thenReturn(const SetupState(isChecking: false));
          when(() => graphics.state).thenReturn(
            GraphicsState(
              byKey: {GraphicsState.keyOf('steam', exe): _blurGraphics},
            ),
          );
        });

        Future<void> pumpDialog(
          WidgetTester tester,
          String? backend,
          Locale locale,
        ) async {
          whenListen(
            options,
            const Stream<RunOptionsState>.empty(),
            initialState: RunOptionsState(
              bottle: 'steam',
              program: exe,
              title: 'Blur',
              backend: backend,
            ),
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1150, 1200);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            wrapApp(
              MultiBlocProvider(
                providers: [
                  BlocProvider<RunOptionsBloc>.value(value: options),
                  BlocProvider<GraphicsBloc>.value(value: graphics),
                  BlocProvider<SetupBloc>.value(value: setup),
                  BlocProvider<LibraryBloc>.value(value: library),
                ],
                child: const RunOptionsDialog(backends: ['wine', 'd3dmetal']),
              ),
              locale: locale,
            ),
          );
        }

        for (final locale in _locales) {
          testWidgets('warns of a backend that does not suit the program, in '
              'the active language (${locale.languageCode})', (tester) async {
            final l10n = lookupAppL10n(locale);
            await pumpDialog(tester, 'd3dmetal', locale);
            expect(
              find.text(
                l10n.graphicsMisfitWarning(
                  'Blur',
                  32,
                  '9',
                  'd3dmetal',
                  l10n.bottleGraphicsAuto,
                ),
              ),
              findsOneWidget,
            );
          });
        }

        testWidgets('says nothing for one that suits it', (tester) async {
          await pumpDialog(tester, 'wine', const Locale('en'));
          expect(find.textContaining("won't work"), findsNothing);
        });
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
