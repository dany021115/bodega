import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/dependencies_section.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockDependencies extends MockBloc<DependenciesEvent, DependenciesState>
    implements DependenciesBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

const _vc2008 = Dependency(
  id: 'vcrun2008',
  name: 'Visual C++ 2008',
  arch: Arch.x86,
  bytes: 4483040,
  installed: false,
);

/// The Games bottle as the user had it: Blur without its runtime, and NFS13
/// with its reverb still on.
const _games = BottleDependencies(
  all: [_vc2008],
  apps: [
    AppNeeds(
      key: 'blur.exe',
      title: 'Blur',
      dependencies: [
        DependencyNeed(
          dependency: _vc2008,
          need: Need.recommended,
          reason: NeedReason.knownFix,
          fix: 'blur',
        ),
      ],
    ),
    AppNeeds(
      key: 'nfs13.exe',
      title: 'NFS13',
      settings: [
        SettingNeed(
          fix: 'need-for-speed-most-wanted-2012',
          game: 'Need for Speed: Most Wanted (2012)',
          section: 'Sound',
          name: 'Reverb',
          value: '0',
          state: SettingState.notApplied,
        ),
      ],
    ),
  ],
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockDependencies bloc;
  late _MockSections sections;

  setUpAll(() => registerFallbackValue(const DependenciesEvent.offerShown()));

  setUp(() {
    bloc = _MockDependencies();
    sections = _MockSections();
    when(() => sections.state).thenReturn(const SectionsState());
  });

  Future<void> pump(
    WidgetTester tester,
    DependenciesState state, {
    bool isOpen = false,
  }) async {
    whenListen(
      bloc,
      const Stream<DependenciesState>.empty(),
      initialState: state,
    );
    // The width of the bottle's panel, the narrowest place it goes.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<DependenciesBloc>.value(value: bloc),
            BlocProvider<SectionsBloc>.value(value: sections),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: DependenciesSection(bottle: 'games', isOpen: isOpen),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('reads the bottle, and says so until it has', (tester) async {
    await pump(tester, const DependenciesState());
    verify(() => bloc.add(const DependenciesEvent.load('games'))).called(1);
    expect(find.text(en.depsLoading), findsOneWidget);
  });

  testWidgets('each app with its items, and a button for each', (tester) async {
    await pump(tester, const DependenciesState(bottles: {'games': _games}));
    expect(find.text('Blur'), findsOneWidget);
    expect(find.text('Visual C++ 2008 · 32-bit · 4.5 MB'), findsOneWidget);
    expect(find.text(en.depsFixBlur), findsOneWidget);
    expect(find.text('Game setting: [Sound] Reverb = 0'), findsOneWidget);
    await tester.tap(find.text(en.commonInstall));
    await tester.tap(find.text(en.depsApply));
    verify(
      () => bloc.add(
        const DependenciesEvent.install('games', [
          NeedItem.runtime('vcrun2008', Arch.x86),
        ]),
      ),
    ).called(1);
    verify(
      () => bloc.add(
        const DependenciesEvent.install('games', [
          NeedItem.settings('need-for-speed-most-wanted-2012'),
        ]),
      ),
    ).called(1);
  });

  testWidgets('while the bottle is open nothing starts', (tester) async {
    await pump(
      tester,
      const DependenciesState(bottles: {'games': _games}),
      isOpen: true,
    );
    expect(find.text(en.depsStopFirst), findsOneWidget);
    for (final label in [en.commonInstall, en.depsApply]) {
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, label))
            .onPressed,
        isNull,
        reason: label,
      );
    }
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, en.depsInstallOther),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a download in progress shows how far, for screen readers too', (
    tester,
  ) async {
    await pump(
      tester,
      const DependenciesState(
        bottles: {'games': _games},
        phase: DependencyPhase.downloading,
        bottle: 'games',
        item: NeedItem.runtime('vcrun2008', Arch.x86),
        received: 2000000,
        total: 4000000,
      ),
    );
    expect(find.text(en.downloadProgress(0.5, 2, 4)), findsOneWidget);
    await tester.tap(find.text(en.commonCancel));
    verify(() => bloc.add(const DependenciesEvent.cancel())).called(1);
  });

  testWidgets('a failed runtime offers a file of the user', (tester) async {
    await pump(
      tester,
      const DependenciesState(
        bottles: {'games': _games},
        error: AppError.network(detail: 'Connection reset by peer'),
        failed: NeedItem.runtime('vcrun2008', Arch.x86),
        failedBottle: 'games',
      ),
    );
    expect(find.text(en.depsChooseFile), findsOneWidget);
    expect(find.text(en.commonCopyDetails), findsOneWidget);
  });

  testWidgets('nothing needed, and what is installed', (tester) async {
    await pump(
      tester,
      DependenciesState(
        bottles: {
          'games': BottleDependencies(all: [_vc2008.copyWith(installed: true)]),
        },
      ),
    );
    expect(find.text(en.depsNothing), findsOneWidget);
    expect(find.text(en.depsInstalledHeader), findsOneWidget);
    expect(find.text('Visual C++ 2008 (32-bit)'), findsOneWidget);
  });
}
