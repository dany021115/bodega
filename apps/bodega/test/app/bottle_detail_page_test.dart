import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/bottles/bottle_detail_page.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_empty_apps.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBottleDetail extends MockBloc<BottleDetailEvent, BottleDetailState>
    implements BottleDetailBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockGamepads extends MockBloc<GamepadsEvent, GamepadsState>
    implements GamepadsBloc {}

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

const _longName = 'Una-botella-con-un-nombre-muy-largo-para-probar-los-limites';

LibraryApp _app(int index, {bool inLibrary = true}) => LibraryApp(
  bottle: _longName,
  key: 'app$index.exe',
  id: 'custom-$index',
  title: 'Una aplicación con un título bastante largo número $index',
  inLibrary: inLibrary,
);

BottleDetail _detail({bool ready = true, int apps = 8}) => BottleDetail(
  name: _longName,
  ready: ready,
  backend: 'dxvk',
  sync: 'msync',
  apps: [for (var i = 0; i < apps; i++) _app(i, inLibrary: i.isEven)],
  installedBackends: const ['dxvk', 'vkd3d'],
);

void main() {
  late _MockBottleDetail bottle;
  late _MockLibrary library;
  late _MockBottles bottles;
  late _MockGamepads gamepads;
  late _MockSections sections;
  late _MockSetup setup;
  late _MockViewMode viewMode;

  void showBottle(BottleDetail detail, {bool isBusy = false}) {
    whenListen(
      bottle,
      const Stream<BottleDetailState>.empty(),
      initialState: BottleDetailState(
        isLoading: false,
        isBusy: isBusy,
        detail: detail,
      ),
    );
  }

  setUp(() {
    bottle = _MockBottleDetail();
    library = _MockLibrary();
    bottles = _MockBottles();
    sections = _MockSections();
    setup = _MockSetup();
    gamepads = _MockGamepads();
    viewMode = _MockViewMode();

    when(() => bottles.state).thenReturn(const BottlesState());
    when(() => sections.state).thenReturn(const SectionsState());
    when(() => setup.state).thenReturn(const SetupState(isChecking: false));
    when(() => gamepads.state)
        .thenReturn(const GamepadsState(isLoading: false));
    when(() => library.state).thenReturn(const LibraryState(isLoading: false));
    when(() => viewMode.state).thenReturn(const ViewModeState());
    showBottle(_detail());
  });

  Future<void> pump(
    WidgetTester tester,
    double width, {
    bool grid = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    when(() => viewMode.state).thenReturn(ViewModeState(isGrid: grid));

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BottleDetailBloc>.value(value: bottle),
            BlocProvider<LibraryBloc>.value(value: library),
            BlocProvider<BottlesBloc>.value(value: bottles),
            BlocProvider<GamepadsBloc>.value(value: gamepads),
            BlocProvider<SectionsBloc>.value(value: sections),
            BlocProvider<SetupBloc>.value(value: setup),
            BlocProvider<ViewModeBloc>.value(value: viewMode),
          ],
          child: const BottleDetailView(name: _longName),
        ),
      ),
    );
    await tester.pump();
  }

  for (final width in [720.0, 900.0, 1200.0]) {
    testWidgets('8 apps with long names fit in grid at $width px', (
      tester,
    ) async {
      await pump(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppCard), findsNWidgets(8));
    });

    testWidgets('8 apps with long names fit in list at $width px', (
      tester,
    ) async {
      await pump(tester, width, grid: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppRow), findsNWidgets(8));
    });

    testWidgets('an empty bottle fits at $width px', (tester) async {
      showBottle(_detail(apps: 0));
      await pump(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('Esta botella está vacía'), findsOneWidget);
      expect(find.byType(BottleEmptyApps), findsOneWidget);
    });
  }

  testWidgets('the panel goes below the apps when the window is narrow', (
    tester,
  ) async {
    await pump(tester, 720);
    // Below the apps the list builds its children lazily: scroll there first.
    await tester.scrollUntilVisible(
      find.text('Configuración'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final title = tester.getTopLeft(find.text('Configuración')).dx;
    expect(title, lessThan(720 / 2));
  });

  testWidgets('the panel sits at the right of the apps when there is room', (
    tester,
  ) async {
    await pump(tester, 1200);
    final left = tester.getTopLeft(find.text('Configuración')).dx;
    expect(left, greaterThan(1200 - BottleDetailView.panelWidth));
  });

  testWidgets('the library toggle sets the app and reloads the library', (
    tester,
  ) async {
    await pump(tester, 1200);
    // The first app is in the library: its chip offers to take it out.
    await tester.tap(find.text('En biblioteca').first);
    await tester.pump();

    verify(
      () => bottle.add(const BottleDetailEvent.setInLibrary('app0.exe', false)),
    ).called(1);
    verify(() => library.add(const LibraryEvent.load())).called(1);
  });

  testWidgets('the menu of an app hides it from the bottle', (tester) async {
    await pump(tester, 1200);
    await tester.tap(
      find
          .byTooltip(
            'Opciones de Una aplicación con un título bastante largo número 1',
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la botella'));
    await tester.pumpAndSettle();

    verify(() => bottle.add(const BottleDetailEvent.hideApp('app1.exe')))
        .called(1);
    verify(() => library.add(const LibraryEvent.load())).called(1);
  });
}
