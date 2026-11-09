import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/presentation/add_app/add_app_dialog.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAddApp extends MockBloc<AddAppEvent, AddAppState>
    implements AddAppBloc {}

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

const _longNote =
    'Una nota muy larga para comprobar que el texto de la tarjeta se corta '
    'sin desbordar, aunque la ventana sea la más angosta posible.';

CatalogApp _app(String id, String title, CatalogStatus status) => CatalogApp(
  id: id,
  title: '$title, con un título bastante largo para la tarjeta',
  status: status,
  statusNote: _longNote,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: true,
);

Future<void> _pump(
  WidgetTester tester, {
  required AddAppState add,
  CatalogState catalog = const CatalogState(isLoading: false),
}) async {
  // The smallest window the app goes down to.
  tester.view.physicalSize = const Size(720, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final addBloc = _MockAddApp();
  whenListen(addBloc, const Stream<AddAppState>.empty(), initialState: add);
  final catalogBloc = _MockCatalog();
  whenListen(
    catalogBloc,
    const Stream<CatalogState>.empty(),
    initialState: catalog,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.getDarkTheme(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AddAppBloc>.value(value: addBloc),
          BlocProvider<CatalogBloc>.value(value: catalogBloc),
        ],
        child: const Scaffold(body: AddAppDialog()),
      ),
    ),
  );
}

void main() {
  const longBottle =
      'Una botella con un nombre excesivamente largo para la cabecera';

  testWidgets('the Otros tab fits at 720 px, blocked apps cannot install', (
    tester,
  ) async {
    await _pump(
      tester,
      add: const AddAppState(bottle: longBottle),
      catalog: CatalogState(
        isLoading: false,
        apps: [
          _app('steam', 'Steam', CatalogStatus.tested),
          _app('riot', 'Riot Client', CatalogStatus.blocked),
          _app('gog', 'GOG Galaxy', CatalogStatus.reported),
        ],
      ),
    );

    await tester.tap(find.text('Otros'));
    await tester.pump();

    expect(find.textContaining('Steam'), findsOneWidget);
    expect(find.text('Sin soporte'), findsOneWidget);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('Instalar'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the .exe tab fits at 720 px with long names', (tester) async {
    await _pump(
      tester,
      add: AddAppState(
        bottle: longBottle,
        exe: '/g/${'setup_muy_largo_' * 8}.exe',
        title: 'Un título larguísimo ' * 6,
      ),
    );

    expect(find.text('Es un instalador'), findsOneWidget);
    expect(find.text('Ya es un programa'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Agregar a la biblioteca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an installer in progress shows its own step and the error', (
    tester,
  ) async {
    await _pump(
      tester,
      add: const AddAppState(
        bottle: longBottle,
        step: AddAppStep.installing,
        error: AppError.engine('un error muy largo que se puede copiar'),
      ),
    );

    expect(find.text('El instalador ya terminó'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
