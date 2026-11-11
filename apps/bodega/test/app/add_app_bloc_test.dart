import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/repository/add_app_repository.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddApp extends Mock implements AddAppRepository {}

class _MockBottles extends Mock implements BottleRepository {}

void main() {
  late _MockAddApp repository;
  late _MockBottles bottles;
  const exe = '/g/Blur/Blur.exe';

  setUp(() {
    repository = _MockAddApp();
    bottles = _MockBottles();
    when(() => repository.pathProblem(any())).thenReturn(null);
    when(() => repository.addApp(any(), any(), any()))
        .thenAnswer((_) async => right('blur/blur.exe'));
    when(() => bottles.setInLibrary(any(), any(), any()))
        .thenAnswer((_) async => right(unit));
  });

  AddAppBloc build() => AddAppBloc(repository, bottles);

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
    'a loose program goes into the bottle it was opened from, in the library',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.load('sample'))
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(() => repository.addApp('sample', 'Blur', exe)).called(1);
      verifyNever(() => bottles.setInLibrary(any(), any(), any()));
      verifyNever(() => repository.runInstaller(any(), any()));
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'an app added out of the library is hidden there, and stays in the bottle',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.load('sample'))
      ..add(const AddAppEvent.addToLibraryToggled(false))
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(() => bottles.setInLibrary('sample', 'blur/blur.exe', false))
          .called(1);
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'a failure hiding the app shows the error and does not finish',
    build: () {
      when(
        () => bottles.setInLibrary(any(), any(), any()),
      ).thenAnswer((_) async => left(const AppError.bottleNotFound('sample')));
      return build();
    },
    act: (bloc) => bloc
      ..add(const AddAppEvent.load('sample'))
      ..add(const AddAppEvent.addToLibraryToggled(false))
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.form);
      expect(bloc.state.error, const AppError.bottleNotFound('sample'));
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
        ..add(const AddAppEvent.load('blur'))
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
        ..add(const AddAppEvent.load('blur'))
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
      ..add(const AddAppEvent.load('blur'))
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.installerToggled(true))
      ..add(const AddAppEvent.submit());
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.installing);
    bloc.add(const AddAppEvent.installerDone());
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.pickInstalled);
    bloc.add(const AddAppEvent.installedChosen('/b/x.exe'));
    await bloc.stream.firstWhere((s) => s.step == AddAppStep.done);

    installer.complete(left(const AppError.unknown()));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.step, AddAppStep.done);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  blocTest<AddAppBloc, AddAppState>(
    'an invalid path registers nothing',
    build: () {
      when(() => repository.pathProblem(exe))
          .thenReturn(const PathProblem.missing(exe));
      return build();
    },
    act: (bloc) => bloc
      ..add(const AddAppEvent.load('blur'))
      ..add(const AddAppEvent.exeChosen(exe))
      ..add(const AddAppEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.form);
      expect(
        bloc.state.error,
        const AppError.badPath(PathProblem.missing(exe)),
      );
      verifyNever(() => repository.addApp(any(), any(), any()));
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'a retry after a failure goes to the same bottle',
    build: () {
      var attempt = 0;
      when(() => repository.addApp('blur', 'Blur', exe)).thenAnswer(
        (_) async => attempt++ == 0
            ? left(const AppError.appAlreadyAdded('blur'))
            : right('k'),
      );
      return build();
    },
    act: (bloc) async {
      bloc
        ..add(const AddAppEvent.load('blur'))
        ..add(const AddAppEvent.exeChosen(exe))
        ..add(const AddAppEvent.submit());
      await bloc.stream.firstWhere((s) => s.error != null);
      expect(bloc.state.step, AddAppStep.form);
      expect(bloc.state.bottle, 'blur');
      bloc.add(const AddAppEvent.submit());
    },
    verify: (bloc) {
      expect(bloc.state.step, AddAppStep.done);
      verify(() => repository.addApp('blur', 'Blur', exe)).called(2);
    },
  );

  blocTest<AddAppBloc, AddAppState>(
    'without a program or a title it does not submit',
    build: build,
    act: (bloc) => bloc
      ..add(const AddAppEvent.load('blur'))
      ..add(const AddAppEvent.submit()),
    verify: (_) => verifyNever(() => repository.addApp(any(), any(), any())),
  );
}
