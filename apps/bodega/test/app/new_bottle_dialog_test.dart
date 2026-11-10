import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
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

  testWidgets('an error from the engine is selectable text', (tester) async {
    await _pump(
      tester,
      state: const NewBottleState(
        name: 'games',
        error: AppError.engine('the bottle could not be created'),
      ),
    );

    expect(
      find.widgetWithText(SelectableText, 'the bottle could not be created'),
      findsOneWidget,
    );
  });
}
