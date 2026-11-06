import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/entities/runtime_status.dart';
import 'package:bodega/domain/repository/runtime_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockRuntime extends Mock implements RuntimeRepository {}

void main() {
  late _MockRuntime runtime;

  void statusIs({List<HostIssue> issues = const [], required bool installed}) {
    when(() => runtime.status()).thenAnswer(
      (_) async => right(
        RuntimeStatus(
          issues: issues,
          runtime: installed,
          capabilities: const HostCapabilities(),
        ),
      ),
    );
  }

  setUp(() => runtime = _MockRuntime());

  blocTest<SetupBloc, SetupState>(
    'with a host issue it is not ready',
    build: () {
      statusIs(
        issues: const [
          HostIssue(title: 'Falta Rosetta', detail: 'x', command: 'cmd'),
        ],
        installed: true,
      );
      return SetupBloc(runtime);
    },
    act: (bloc) => bloc.add(const SetupEvent.check()),
    verify: (bloc) {
      expect(bloc.state.isChecking, isFalse);
      expect(bloc.state.issues.single.title, 'Falta Rosetta');
      expect(bloc.state.isReady, isFalse);
    },
  );

  blocTest<SetupBloc, SetupState>(
    'without issues and with the runtime it is ready',
    build: () {
      statusIs(installed: true);
      return SetupBloc(runtime);
    },
    act: (bloc) => bloc.add(const SetupEvent.check()),
    verify: (bloc) {
      expect(bloc.state.issues, isEmpty);
      expect(bloc.state.isReady, isTrue);
    },
  );

  blocTest<SetupBloc, SetupState>(
    'without the runtime it is not ready',
    build: () {
      statusIs(installed: false);
      return SetupBloc(runtime);
    },
    act: (bloc) => bloc.add(const SetupEvent.check()),
    verify: (bloc) {
      expect(bloc.state.runtime, isFalse);
      expect(bloc.state.isReady, isFalse);
    },
  );

  blocTest<SetupBloc, SetupState>(
    'installing correctly makes it ready',
    build: () {
      statusIs(installed: true);
      when(() => runtime.install(engine: 'e.tar.xz', hostlibs: 'h.tar.xz'))
          .thenAnswer((_) async => right(unit));
      return SetupBloc(runtime);
    },
    act: (bloc) => bloc
      ..add(const SetupEvent.engineChosen('e.tar.xz'))
      ..add(const SetupEvent.hostlibsChosen('h.tar.xz'))
      ..add(const SetupEvent.install()),
    verify: (bloc) {
      expect(bloc.state.isInstalling, isFalse);
      expect(bloc.state.isReady, isTrue);
    },
  );

  blocTest<SetupBloc, SetupState>(
    'an engine error stays in the state, and it can retry',
    build: () {
      when(() => runtime.install(engine: 'e.tar.xz', hostlibs: 'h.tar.xz'))
          .thenAnswer(
            (_) async => left(const AppError.engine('falta el .sha256')),
          );
      return SetupBloc(runtime);
    },
    act: (bloc) => bloc
      ..add(const SetupEvent.engineChosen('e.tar.xz'))
      ..add(const SetupEvent.hostlibsChosen('h.tar.xz'))
      ..add(const SetupEvent.install()),
    verify: (bloc) {
      expect(bloc.state.isInstalling, isFalse);
      expect(bloc.state.error, const AppError.engine('falta el .sha256'));
      expect(bloc.state.engine, 'e.tar.xz');
    },
  );
}
