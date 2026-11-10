import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/repository/gamepad_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockGamepads extends Mock implements GamepadRepository {}

const _report = GamepadReport(
  pads: [Gamepad(name: 'Pad', vid: '045e', pid: '028e', readable: true)],
  sdl: true,
  issues: [],
);

void main() {
  late _MockGamepads repository;

  setUp(() => repository = _MockGamepads());

  blocTest<GamepadsBloc, GamepadsState>(
    'looking shows the report',
    build: () {
      when(() => repository.report()).thenAnswer((_) async => right(_report));
      return GamepadsBloc(repository);
    },
    act: (bloc) => bloc.add(const GamepadsEvent.load()),
    expect: () => [
      const GamepadsState(isLoading: true),
      const GamepadsState(isLoading: false, report: _report),
    ],
  );

  blocTest<GamepadsBloc, GamepadsState>(
    'where there is nothing to check the report stays empty',
    build: () {
      when(() => repository.report()).thenAnswer((_) async => right(null));
      return GamepadsBloc(repository);
    },
    act: (bloc) => bloc.add(const GamepadsEvent.load()),
    verify: (bloc) {
      expect(bloc.state.report, isNull);
      expect(bloc.state.isLoading, isFalse);
    },
  );

  blocTest<GamepadsBloc, GamepadsState>(
    'an error is kept, and the last report with it',
    build: () {
      when(() => repository.report())
          .thenAnswer((_) async => left(const AppError.engine('it failed')));
      return GamepadsBloc(repository);
    },
    seed: () => const GamepadsState(isLoading: false, report: _report),
    act: (bloc) => bloc.add(const GamepadsEvent.load()),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('it failed'));
      expect(bloc.state.report, _report);
    },
  );
}
