import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/widgets/needs_dialog.dart';
import 'package:bodega/app/shared/widgets/shell_body.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockSwitch extends MockBloc<SwitchEvent, SwitchState>
    implements SwitchBloc {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

class _MockDependencies extends MockBloc<DependenciesEvent, DependenciesState>
    implements DependenciesBloc {}

const _steam = CatalogApp(
  id: 'steam',
  title: 'Steam',
  status: CatalogStatus.tested,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: true,
);

const _blur = AppNeeds(
  key: 'blur.exe',
  title: 'Blur',
  dependencies: [
    DependencyNeed(
      dependency: Dependency(
        id: 'vcrun2008',
        name: 'Visual C++ 2008',
        arch: Arch.x86,
        bytes: 4483040,
        status: DependencyStatus.notInstalled,
      ),
      need: Need.recommended,
      reason: NeedReason.knownFix,
      fix: 'blur',
    ),
  ],
);

void main() {
  late _MockDependencies dependencies;
  late _MockInstall install;
  late StreamController<DependenciesState> dependencyStates;
  late StreamController<InstallState> installStates;

  setUpAll(() => registerFallbackValue(const DependenciesEvent.offerShown()));

  setUp(() {
    dependencies = _MockDependencies();
    install = _MockInstall();
    dependencyStates = StreamController<DependenciesState>.broadcast();
    installStates = StreamController<InstallState>.broadcast();
    whenListen(
      dependencies,
      dependencyStates.stream,
      initialState: const DependenciesState(),
    );
    whenListen(
      install,
      installStates.stream,
      initialState: const InstallState(),
    );
  });

  tearDown(() async {
    await dependencyStates.close();
    await installStates.close();
  });

  Future<void> pump(WidgetTester tester) async {
    T quiet<T extends Bloc<Object?, S>, S>(T bloc, S state) {
      whenListen(bloc, Stream<S>.empty(), initialState: state);
      return bloc;
    }

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LibraryBloc>.value(
            value: quiet(_MockLibrary(), const LibraryState()),
          ),
          BlocProvider<UpdateBloc>.value(
            value: quiet(_MockUpdate(), const UpdateState()),
          ),
          BlocProvider<SwitchBloc>.value(
            value: quiet(_MockSwitch(), const SwitchState()),
          ),
          BlocProvider<BottlesBloc>.value(
            value: quiet(_MockBottles(), const BottlesState()),
          ),
          BlocProvider<CatalogBloc>.value(
            value: quiet(_MockCatalog(), const CatalogState()),
          ),
          BlocProvider<InstallBloc>.value(value: install),
          BlocProvider<DependenciesBloc>.value(value: dependencies),
        ],
        child: wrapApp(const ShellBody(child: SizedBox.expand())),
      ),
    );
  }

  testWidgets('a proposal opens its dialog over the page, once', (
    tester,
  ) async {
    await pump(tester);
    dependencyStates.add(
      const DependenciesState(offer: _blur, offerBottle: 'games'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NeedsDialog), findsOneWidget);
    verify(() => dependencies.add(const DependenciesEvent.offerShown()))
        .called(1);
  });

  testWidgets('a catalog install that ends proposes for its app', (
    tester,
  ) async {
    await pump(tester);
    installStates.add(
      const InstallState(
        phase: InstallPhase.done,
        app: _steam,
        bottle: 'games',
      ),
    );
    await tester.pumpAndSettle();
    verify(
      () => dependencies.add(
        const DependenciesEvent.offerCatalogApp('games', 'steam'),
      ),
    ).called(1);
  });
}
