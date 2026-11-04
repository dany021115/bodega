import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/add_app_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddApp extends Mock implements AddAppRepository {}

void main() {
  late _MockAddApp repository;
  const exe = '/g/Blur/Blur.exe';

  setUp(() {
    repository = _MockAddApp();
    when(() => repository.pathProblem(any())).thenReturn(null);
    when(() => repository.createBottle('Blur'))
        .thenAnswer((_) async => right('blur'));
    when(() => repository.addApp(any(), any(), any()))
        .thenAnswer((_) async => right(unit));
  });

  AddAppBloc build() => AddAppBloc(repository);

  blocTest<AddAppBloc, AddAppState>(
    'the title comes from the file, and can be changed',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.titleChanged('Blur 2010')),
    verify: (bloc) => expect(bloc.state.title, 'Blur 2010'),
    expect: () => const [
      AddAppState(exe: exe, title: 'Blur'),
      AddAppState(exe: exe, title: 'Blur 2010'),
    ],
  );

  blocTest<AddAppBloc, AddAppState>(
    'a loose program goes into a new bottle',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(() => repository.createBottle('Blur')).called(1);
      verify(() => repository.addApp('blur', 'Blur', exe)).called(1);
      verifyNever(() => repository.runInstaller(any(), any()));
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'into an existing bottle it creates none',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.bottleChosen('prueba'))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verifyNever(() => repository.createBottle(any()));
      verify(() => repository.addApp('prueba', 'Blur', exe)).called(1);
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'an installer runs, then asks for the installed program',
    build: () {
      when(() => repository.runInstaller('blur', exe))
          .thenAnswer((_) async => right(unit));
      when(() => repository.driveC('blur')).thenReturn('/b/blur/drive_c');
      return build();
    },
    act: (bloc) async {
      bloc
        ..add(const AddAppEvent.exeChosen(exe))
        ..add(const AddAppEvent.installerToggled(true))
        ..add(const AddAppEvent.submit());
      await bloc.stream.firstWhere((s) => s.step == AddAppStep.pickInstalled);
      expect(bloc.state.driveC, '/b/blur/drive_c');
      verifyNever(() => repository.addApp(any(), any(), any()));
      bloc.add(
        const AddAppEvent.installedChosen('/b/blur/drive_c/Blur/Blur.exe'),
      );
    },
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(
        () =>
            repository.addApp('blur', 'Blur', '/b/blur/drive_c/Blur/Blur.exe'),
      ).called(1);
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'an installer that leaves a service does not hold the user back',
    build: () {
      // The bottle never empties.
      when(() => repository.runInstaller('blur', exe))
          .thenAnswer((_) => Completer<Either<AppError, Unit>>().future);
      when(() => repository.driveC('blur')).thenReturn('/b/blur/drive_c');
      return build();
    },
    act: (bloc) async {
      bloc
        ..add(const AddAppEvent.exeChosen(exe))
        ..add(const AddAppEvent.installerToggled(true))
        ..add(const AddAppEvent.submit());
      await bloc.stream.firstWhere((s) => s.step == AddAppStep.installing);
      bloc.add(const AddAppEvent.installerDone());
      await bloc.stream.firstWhere((s) => s.step == AddAppStep.pickInstalled);
      expect(bloc.state.driveC, '/b/blur/drive_c');
      bloc.add(
        const AddAppEvent.installedChosen('/b/blur/drive_c/Blur/Blur.exe'),
      );
    },
    verify: (bloc) => expect(bloc.state.step, AddAppStep.done),
  );

  test('an installer ending after the user went on changes nothing', () async {
    final installer = Completer<Either<AppError, Unit>>();
    when(() => repository.runInstaller('blur', exe))
        .thenAnswer((_) => installer.future);
    when(() => repository.driveC('blur')).thenReturn('/b/blur/drive_c');
    final bloc = build()
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.installerToggled(true))
      ..add(const AddAppEvent.submit());
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.installing);
    bloc.add(const AddAppEvent.installerDone());
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.pickInstalled);
    bloc.add(const AddAppEvent.installedChosen('/b/x.exe'));
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.done);

    installer.complete(left(const AppError.engine('tarde')));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.step, AddAppStep.done);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  blocTest<AddAppBloc, AddAppState>(
    'an invalid path creates no bottle',
    build: () {
      when(() => repository.pathProblem(exe)).thenReturn('nombre no válido');
      return build();
    },
    act: (bloc) => bloc
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.form);
      expect(bloc.state.error, const AppError.engine('nombre no válido'));
      verifyNever(() => repository.createBottle(any()));
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'a retry after a failure reuses the bottle it just created',
    build: () {
      var attempt = 0;
      when(() => repository.addApp('blur', 'Blur', exe)).thenAnswer(
        (_) async =>
            attempt++ == 0 ? left(const AppError.engine('falló')) : right(unit),
      );
      return build();
    },
    act: (bloc) async {
      bloc
        ..add(const AddAppEvent.exeChosen(exe))
        ..add(const AddAppEvent.submit());
      await bloc.stream.firstWhere((s) => s.error != null);
      expect(bloc.state.step, AddAppStep.form);
      expect(bloc.state.bottle, 'blur');
      bloc.add(const AddAppEvent.submit());
    },
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(() => repository.createBottle('Blur')).called(1);
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'without a program or a title it does not submit',
    build: build,
    act: (bloc) => bloc.add(const AddAppEvent.submit()),
    verify: (_) => verifyNever(() => repository.createBottle(any())),
  );
}
