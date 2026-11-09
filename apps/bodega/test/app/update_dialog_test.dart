import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/widgets/update_dialog.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

void main() {
  late _MockUpdate bloc;
  const mac = AppUpdate(
    version: '1.4.0',
    current: '1.3.0',
    notes: 'Arreglos de Blur',
    page: 'https://x/page',
    installer: 'https://x/Bodega.dmg',
    sums: 'https://x/SHA256SUMS-macos',
  );

  setUpAll(() => registerFallbackValue(const UpdateEvent.check()));
  setUp(() => bloc = _MockUpdate());

  Future<void> show(WidgetTester tester, UpdateState state) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<UpdateBloc>.value(
          value: bloc,
          child: const Scaffold(body: UpdateDialog()),
        ),
      ),
    );
  }

  testWidgets('an update this Mac can install (A3)', (tester) async {
    await show(tester, const UpdateState(update: mac));
    expect(find.text('Hay una versión nueva'), findsOneWidget);
    expect(find.text('Bodega 1.4.0 (tienes 1.3.0)'), findsOneWidget);
    expect(find.text('Arreglos de Blur'), findsOneWidget);
    expect(
      find.text('Tus botellas, juegos y ajustes se quedan como están.'),
      findsOneWidget,
    );
    expect(find.text('Ahora no'), findsOneWidget);
    await tester.tap(find.text('Actualizar'));
    verify(() => bloc.add(const UpdateEvent.install())).called(1);
  });

  testWidgets('a Linux package gets the command and the page (A2)', (
    tester,
  ) async {
    await show(
      tester,
      const UpdateState(
        update: AppUpdate(
          version: '1.4.0',
          current: '1.3.0',
          page: 'https://x/page',
          command: 'sudo apt install ./Bodega-1.4.0-linux-amd64.deb',
        ),
      ),
    );
    expect(find.text('Actualizar'), findsNothing);
    expect(find.text('Ver la versión'), findsOneWidget);
    expect(
      find.text('sudo apt install ./Bodega-1.4.0-linux-amd64.deb'),
      findsOneWidget,
    );
  });

  testWidgets('the download shows its progress and can be cancelled', (
    tester,
  ) async {
    await show(
      tester,
      const UpdateState(
        update: mac,
        phase: UpdatePhase.downloading,
        received: 5 << 20,
        total: 10 << 20,
      ),
    );
    expect(find.text('Descargando: 5 de 10 MB'), findsOneWidget);
    expect(find.text('Ahora no'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    verify(() => bloc.add(const UpdateEvent.cancel())).called(1);
  });

  testWidgets('a failure says why, and the update stays available', (
    tester,
  ) async {
    await show(
      tester,
      const UpdateState(
        update: mac,
        error: AppError.engine(
          'la descarga de Bodega.dmg no coincide con su SHA256',
        ),
      ),
    );
    expect(find.textContaining('no coincide con su SHA256'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
  });
}
