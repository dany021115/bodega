import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
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
}) async {
  // The smallest window the app goes down to.
  tester.view.physicalSize = const Size(720, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final bottle = _MockNewBottle();
  whenListen(bottle, const Stream<NewBottleState>.empty(), initialState: state);
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
}
