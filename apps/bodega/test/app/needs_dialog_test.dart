import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/shared/widgets/needs_dialog.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockDependencies extends MockBloc<DependenciesEvent, DependenciesState>
    implements DependenciesBloc {}

const _vc2008 = Dependency(
  id: 'vcrun2008',
  name: 'Visual C++ 2008',
  arch: Arch.x86,
  bytes: 4483040,
  installed: false,
);
const _vc2010 = Dependency(
  id: 'vcrun2010',
  name: 'Visual C++ 2010',
  arch: Arch.x86,
  bytes: 5076456,
  installed: false,
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockDependencies bloc;

  setUpAll(() => registerFallbackValue(const DependenciesEvent.offerShown()));

  setUp(() {
    bloc = _MockDependencies();
    whenListen(
      bloc,
      const Stream<DependenciesState>.empty(),
      initialState: const DependenciesState(),
    );
  });

  /// Opens the dialog from a button, as the app does.
  Future<void> open(
    WidgetTester tester, {
    AppNeeds? needs,
    List<Dependency>? all,
  }) async {
    await tester.pumpWidget(
      wrapApp(
        BlocProvider<DependenciesBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showNeedsDialog(
                  context,
                  bottle: 'games',
                  needs: needs,
                  all: all,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets("Blur's needs: its runtime checked, with its reason", (
    tester,
  ) async {
    await open(
      tester,
      needs: const AppNeeds(
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
    );
    expect(find.text(en.depsDialogFor('Blur')), findsOneWidget);
    expect(find.text('Visual C++ 2008 · 32-bit · 4.5 MB'), findsOneWidget);
    expect(find.text(en.depsNeedRecommended), findsOneWidget);
    expect(find.text(en.depsFixBlur), findsOneWidget);
    expect(find.text(en.depsWholeBottle), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.text(en.commonInstall));
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(
        const DependenciesEvent.install('games', [
          NeedItem.runtime('vcrun2008', Arch.x86),
        ]),
      ),
    ).called(1);
    expect(find.byType(NeedsDialog), findsNothing);
  });

  testWidgets('optional needs start unchecked, and Install waits for one', (
    tester,
  ) async {
    await open(
      tester,
      needs: const AppNeeds(
        key: 'tool.exe',
        title: 'Tool',
        dependencies: [
          DependencyNeed(
            dependency: _vc2010,
            need: Need.optional,
            reason: NeedReason.imported,
            dll: 'msvcr100.dll',
          ),
        ],
      ),
    );
    FilledButton install() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, en.commonInstall),
    );
    expect(install().onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(install().onPressed, isNotNull);
    await tester.tap(find.text(en.depsNotNow));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('a game setting is checked and says what changes', (
    tester,
  ) async {
    await open(
      tester,
      needs: const AppNeeds(
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
    );
    expect(find.text('Game setting: [Sound] Reverb = 0'), findsOneWidget);
    expect(find.text(en.depsFixNfsMostWanted2012), findsOneWidget);
    expect(find.text(en.depsWholeBottle), findsNothing);
    await tester.tap(find.text(en.commonInstall));
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(
        const DependenciesEvent.install('games', [
          NeedItem.settings('need-for-speed-most-wanted-2012'),
        ]),
      ),
    ).called(1);
  });

  testWidgets('by hand: every runtime not installed, none checked', (
    tester,
  ) async {
    await open(tester, all: [_vc2008.copyWith(installed: true), _vc2010]);
    expect(find.text(en.depsDialogAll), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Visual C++ 2010 · 32-bit · 5.1 MB'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('by hand, with everything installed, it says so', (tester) async {
    await open(tester, all: [_vc2008.copyWith(installed: true)]);
    expect(find.text(en.depsDialogNone), findsOneWidget);
  });
}
