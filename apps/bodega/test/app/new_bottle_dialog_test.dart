import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/runtime_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

class _MockNewBottle extends MockBloc<NewBottleEvent, NewBottleState>
    implements NewBottleBloc {}

class _MockBackends extends MockBloc<BackendsEvent, BackendsState>
    implements BackendsBloc {}

Future<void> _pump(
  WidgetTester tester, {
  required NewBottleState state,
  BackendsState backends = const BackendsState(isLoading: false),
  Locale locale = const Locale('en'),
  Stream<NewBottleState> states = const Stream<NewBottleState>.empty(),
}) async {
  // The smallest window the app goes down to.
  tester.view.physicalSize = const Size(720, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final bottle = _MockNewBottle();
  whenListen(bottle, states, initialState: state);
  final backendBloc = _MockBackends();
  whenListen(
    backendBloc,
    const Stream<BackendsState>.empty(),
    initialState: backends,
  );

  await tester.pumpWidget(
    wrapApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewBottleBloc>.value(value: bottle),
          BlocProvider<BackendsBloc>.value(value: backendBloc),
        ],
        child: const Scaffold(body: NewBottleDialog()),
      ),
      locale: locale,
      theme: AppTheme.getDarkTheme(),
    ),
  );
}

void main() {
  final en = lookupAppL10n(const Locale('en'));

  testWidgets('fits at 720 px with long names and backends', (tester) async {
    await _pump(
      tester,
      state: NewBottleState(
        name: 'a-bottle-name-that-does-not-fit-in-the-field-' * 3,
        taken: const ['gaming'],
      ),
      backends: BackendsState(
        isLoading: false,
        backends: [
          for (var i = 0; i < 3; i++)
            BackendInfo(
              name: 'backend-with-a-long-name-$i',
              installed: true,
              downloadable: false,
            ),
        ],
      ),
    );

    expect(find.text('New bottle'), findsOneWidget);
    expect(find.text('Create bottle'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a name taken or invalid says why, and cannot submit', (
    tester,
  ) async {
    await _pump(
      tester,
      state: const NewBottleState(name: 'gaming', taken: ['Gaming']),
    );

    expect(
      find.text('You already have a bottle with that name.'),
      findsOneWidget,
    );
    final button = tester.widget<GradientButton>(find.byType(GradientButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('while it is made the dialog says so and shows no form', (
    tester,
  ) async {
    await _pump(
      tester,
      state: const NewBottleState(name: 'games', isCreating: true),
    );

    expect(find.text('Creating the bottle…'), findsOneWidget);
    expect(find.text(en.newBottleCreate), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error from the engine is selectable text, and a long one '
      'fits at 720 px with its Copy details button', (tester) async {
    const log =
        '/Users/someone/Library/Application Support/Bodega/bottles/games/'
        'logs/wineboot-2026-11-10-14-52-07.log';
    for (final locale in AppL10n.supportedLocales) {
      await _pump(
        tester,
        state: const NewBottleState(
          name: 'games',
          // With a detail, as data/ sets it: Copy details shows too (L9).
          error: AppError.wineToolFailed(
            WineTool.wineboot,
            1,
            log,
            detail: 'stderr: boom',
          ),
        ),
        locale: locale,
      );

      expect(
        find.widgetWithText(
          SelectableText,
          lookupAppL10n(locale).errWinebootFailed(1, log),
        ),
        findsOneWidget,
        reason: '$locale',
      );
      // The button scrolls with the text, under it: outside the scroll it
      // would take the little room the text has here.
      final scroll = find.ancestor(
        of: find.byType(SelectableText),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget, reason: '$locale');
      expect(
        find.descendant(
          of: scroll,
          matching: find.text(lookupAppL10n(locale).commonCopyDetails),
        ),
        findsOneWidget,
        reason: '$locale',
      );
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  group('the engine (MA6)', () {
    /// A Mac with the native engine installed, and Rosetta backends.
    final native = BackendsState(
      isLoading: false,
      backends: [
        for (final name in ['dxmt', 'dxvk', 'backend-with-a-long-name'])
          BackendInfo(name: name, installed: true, downloadable: false),
      ],
      runtimes: const [
        RuntimeInfo(kind: RuntimeKind.bodega, installed: true),
        RuntimeInfo(
          kind: RuntimeKind.mach9,
          installed: true,
          version: '0.4.0',
          backends: ['wine', 'dxmt', 'mtld3d'],
        ),
      ],
    );

    testWidgets('without the native engine there is no Engine field', (
      tester,
    ) async {
      await _pump(tester, state: const NewBottleState(name: 'games'));
      expect(find.text(en.bottleEngine), findsNothing);
      expect(find.text(en.newBottleNote), findsOneWidget);
    });

    for (final locale in AppL10n.supportedLocales) {
      testWidgets('three dropdowns fit at 720×480, with one Automatic '
          '($locale)', (tester) async {
        final l10n = lookupAppL10n(locale);
        await _pump(
          tester,
          state: NewBottleState(
            name: 'a-bottle-name-that-does-not-fit-in-the-field-' * 3,
            runtime: RuntimeKind.mach9,
            error: const AppError.runtimeNotInstalled(
              RuntimeKind.mach9,
              detail: 'boom',
            ),
          ),
          backends: native,
          locale: locale,
        );
        expect(find.text(l10n.bottleEngine), findsOneWidget);
        expect(find.text(l10n.engineNative), findsOneWidget);
        expect(find.text(l10n.bottleGraphicsAuto), findsOneWidget);
        expect(find.text(l10n.newBottleNoteNative), findsOneWidget);
        expect(find.text(l10n.newBottleCreate), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the native graphics are its own: no dxvk', (tester) async {
      await _pump(
        tester,
        state: const NewBottleState(name: 'games', runtime: RuntimeKind.mach9),
        backends: native,
      );
      await tester.tap(find.text(en.bottleGraphicsAuto));
      await tester.pumpAndSettle();
      expect(find.text('mtld3d'), findsWidgets);
      expect(find.text('dxvk'), findsNothing);
    });

    testWidgets('switching the engine raises no assertion', (tester) async {
      final controller = StreamController<NewBottleState>();
      addTearDown(controller.close);
      const rosetta = NewBottleState(name: 'games', backend: 'dxvk');
      await _pump(
        tester,
        state: rosetta,
        backends: native,
        states: controller.stream,
      );
      expect(find.text('dxvk'), findsOneWidget);
      // What runtimeChanged emits: the new engine, with Graphics reset.
      controller.add(
        rosetta.copyWith(runtime: RuntimeKind.mach9, backend: 'auto'),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.engineNative), findsOneWidget);
      expect(find.text(en.bottleGraphicsAuto), findsOneWidget);
      controller.add(rosetta.copyWith(backend: 'auto'));
      await tester.pumpAndSettle();
      expect(find.text(en.engineRosetta), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while Wine Mono installs the dialog says so', (tester) async {
      await _pump(
        tester,
        state: const NewBottleState(
          name: 'games',
          runtime: RuntimeKind.mach9,
          isCreating: true,
          step: BottleStep.mono,
        ),
        backends: native,
      );
      expect(find.text(en.newBottleInstallingMono), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
