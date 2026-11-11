import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/run_options/run_options_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibrary extends Mock implements LibraryRepository {}

/// A folder name Windows refuses (trap 11).
const _odd = PathProblem.windowsName(part: 'odd:', path: '/g/odd:/a.exe');

void main() {
  late _MockLibrary repository;

  setUp(() {
    repository = _MockLibrary();
    when(
      () => repository.launch(
        any(),
        any(),
        args: any(named: 'args'),
        env: any(named: 'env'),
        backend: any(named: 'backend'),
        avx: any(named: 'avx'),
      ),
    ).thenAnswer((_) async => right('/l/a.log'));
    when(
      () => repository.saveLauncher(
        any(),
        any(),
        any(),
        args: any(named: 'args'),
        env: any(named: 'env'),
      ),
    ).thenAnswer((_) async => right(unit));
  });

  RunOptionsState form({
    String program = r'C:\Juego\a.exe',
    String args = '-uno "dos tres"',
    String env = 'DXVK_HUD=fps\n\nWINEDEBUG=+d3d',
    bool save = false,
  }) => RunOptionsState(
    bottle: 'steam',
    program: program,
    args: args,
    env: env,
    backend: 'dxvk',
    avx: false,
    save: save,
    title: 'Mi juego',
  );

  blocTest<RunOptionsBloc, RunOptionsState>(
    'launches with what was written',
    build: () => RunOptionsBloc(repository),
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form()))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.log, '/l/a.log');
      verify(
        () => repository.launch(
          'steam',
          r'C:\Juego\a.exe',
          args: ['-uno', 'dos tres'],
          env: {'DXVK_HUD': 'fps', 'WINEDEBUG': '+d3d'},
          backend: 'dxvk',
          avx: false,
        ),
      ).called(1);
      verifyNever(
        () => repository.saveLauncher(
          any(),
          any(),
          any(),
          args: any(named: 'args'),
          env: any(named: 'env'),
        ),
      );
    },
  );

  blocTest<RunOptionsBloc, RunOptionsState>(
    'saving creates the application, and then launches',
    build: () => RunOptionsBloc(repository),
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form(save: true)))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      verify(
        () => repository.saveLauncher(
          'steam',
          'Mi juego',
          r'C:\Juego\a.exe',
          args: ['-uno', 'dos tres'],
          env: {'DXVK_HUD': 'fps', 'WINEDEBUG': '+d3d'},
        ),
      ).called(1);
      expect(bloc.state.log, '/l/a.log');
    },
  );

  blocTest<RunOptionsBloc, RunOptionsState>(
    'a variable that is not NAME=value does not launch (E9)',
    build: () => RunOptionsBloc(repository),
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form(env: 'GOOD=1\nbad')))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.badEnvLine(2, 'bad'));
      expect(bloc.state.log, isNull);
      verifyNever(
        () => repository.launch(
          any(),
          any(),
          args: any(named: 'args'),
          env: any(named: 'env'),
          backend: any(named: 'backend'),
          avx: any(named: 'avx'),
        ),
      );
    },
  );

  blocTest<RunOptionsBloc, RunOptionsState>(
    'a path Wine does not take is said',
    build: () {
      when(
        () => repository.launch(
          any(),
          any(),
          args: any(named: 'args'),
          env: any(named: 'env'),
          backend: any(named: 'backend'),
          avx: any(named: 'avx'),
        ),
      ).thenAnswer((_) async => left(const AppError.badPath(_odd)));
      return RunOptionsBloc(repository);
    },
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form(program: '/g/odd:/a.exe')))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.badPath(_odd));
      expect(bloc.state.isRunning, isFalse);
    },
  );

  test('splitArgs and parseEnv', () {
    expect(splitArgs(' -a  "b c" d '), ['-a', 'b c', 'd']);
    expect(splitArgs(''), isEmpty);
    expect(parseEnv('A=1\nB_2= x=y \n').getOrElse((_) => {}), {
      'A': '1',
      'B_2': ' x=y',
    });
    expect(parseEnv('=1').isLeft(), isTrue);
    expect(parseEnv('1A=1').isLeft(), isTrue);
    // Blank lines count, as the user sees them; the line is given trimmed.
    expect(
      parseEnv('A=1\n\n  1A=2 ').getLeft().toNullable(),
      const AppError.badEnvLine(3, '1A=2'),
    );
  });
}
