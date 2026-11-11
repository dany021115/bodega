import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/presentation/add_app/add_app_dialog.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

class _MockAddApp extends MockBloc<AddAppEvent, AddAppState>
    implements AddAppBloc {}

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

/// The card shows the status note of [id] from the ARBs: Steam's is long
/// enough to be cut short, even in the narrowest window there is.
CatalogApp _app(String id, String title, CatalogStatus status) => CatalogApp(
  id: id,
  title: '$title, with a title that is rather long for the card',
  status: status,
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
    wrapApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<AddAppBloc>.value(value: addBloc),
          BlocProvider<CatalogBloc>.value(value: catalogBloc),
        ],
        child: const Scaffold(body: AddAppDialog()),
      ),
      theme: AppTheme.getDarkTheme(),
    ),
  );
}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  const longBottle =
      'A bottle with a name that is far too long for the dialog header';

  testWidgets('the Others tab fits at 720 px, blocked apps cannot install', (
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

    await tester.tap(find.text('Others'));
    await tester.pump();

    expect(find.textContaining('Steam'), findsOneWidget);
    expect(find.text(en.catalogSteamStatusNote), findsOneWidget);
    expect(find.text('Not supported'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Install'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the .exe tab fits at 720 px with long names', (tester) async {
    await _pump(
      tester,
      add: AddAppState(
        bottle: longBottle,
        exe: '/g/${'a_very_long_setup_' * 8}.exe',
        title: 'A title longer than long ' * 6,
      ),
    );

    expect(find.text('Add an app to $longBottle'), findsOneWidget);
    expect(find.text("It's an installer"), findsOneWidget);
    expect(find.text("It's already a program"), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Add to library'), findsOneWidget);
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
        error: AppError.badPath(
          PathProblem.missing(
            '/Users/me/Downloads/a/very/long/path/to/an/installer/setup.exe',
          ),
        ),
      ),
    );

    expect(find.text('The installer has finished'), findsOneWidget);
    expect(find.text(en.commonCancel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
