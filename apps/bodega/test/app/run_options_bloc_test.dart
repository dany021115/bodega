import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/run_options/run_options_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibrary extends Mock implements LibraryRepository {}

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
        hud: any(named: 'hud'),
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
    hud: true,
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
          hud: true,
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
    'a variable that is not NOMBRE=valor does not launch',
    build: () => RunOptionsBloc(repository),
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form(env: 'BIEN=1\nmal')))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.error?.message, contains('línea 2'));
      expect(bloc.state.log, isNull);
      verifyNever(
        () => repository.launch(
          any(),
          any(),
          args: any(named: 'args'),
          env: any(named: 'env'),
          backend: any(named: 'backend'),
          hud: any(named: 'hud'),
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
          hud: any(named: 'hud'),
          avx: any(named: 'avx'),
        ),
      ).thenAnswer(
        (_) async => left(const AppError.engine('"raro:" en /g/raro:/a.exe')),
      );
      return RunOptionsBloc(repository);
    },
    act: (bloc) => bloc
      ..add(RunOptionsEvent.changed(form(program: '/g/raro:/a.exe')))
      ..add(const RunOptionsEvent.submit()),
    verify: (bloc) {
      expect(bloc.state.error?.message, contains('raro:'));
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
  });
}
