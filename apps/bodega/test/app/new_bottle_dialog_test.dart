import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
    MaterialApp(
      theme: AppTheme.getDarkTheme(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<NewBottleBloc>.value(value: bottle),
          BlocProvider<BackendsBloc>.value(value: backendBloc),
        ],
        child: const Scaffold(body: NewBottleDialog()),
      ),
    ),
  );
}

void main() {
  testWidgets('fits at 720 px with long names and backends', (tester) async {
    await _pump(
      tester,
      state: NewBottleState(
        name: 'un-nombre-de-botella-que-no-cabe-en-el-campo-' * 3,
        taken: const ['gaming'],
      ),
      backends: BackendsState(
        isLoading: false,
        backends: [
          for (var i = 0; i < 3; i++)
            BackendInfo(
              name: 'backend-con-nombre-largo-$i',
              installed: true,
              downloadable: false,
            ),
        ],
      ),
    );

    expect(find.text('Nueva botella'), findsOneWidget);
    expect(find.text('Crear botella'), findsOneWidget);
    expect(find.text('Automático'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a name taken or invalid says why, and cannot submit', (
    tester,
  ) async {
    await _pump(
      tester,
      state: const NewBottleState(name: 'gaming', taken: ['Gaming']),
    );

    expect(find.text('Ya tienes una botella con ese nombre.'), findsOneWidget);
    final button = tester.widget<GradientButton>(find.byType(GradientButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('while it is made the dialog says so and shows no form', (
    tester,
  ) async {
    await _pump(
      tester,
      state: const NewBottleState(name: 'juegos', isCreating: true),
    );

    expect(find.text('Creando la botella…'), findsOneWidget);
    expect(find.text('Crear botella'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error from the engine is selectable text', (tester) async {
    await _pump(
      tester,
      state: const NewBottleState(
        name: 'juegos',
        error: AppError.engine('no se pudo crear la botella'),
      ),
    );

    expect(
      find.widgetWithText(SelectableText, 'no se pudo crear la botella'),
      findsOneWidget,
    );
  });
}
