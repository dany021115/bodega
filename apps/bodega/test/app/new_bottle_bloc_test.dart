import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockBottles extends Mock implements BottleRepository {}

void main() {
  late _MockBottles repository;

  setUp(() {
    repository = _MockBottles();
    when(() => repository.list()).thenAnswer(
      (_) async => right(const [Bottle(name: 'steam', ready: true)]),
    );
  });

  NewBottleBloc build() => NewBottleBloc(repository);

  test('starts with win11 and auto, and refuses an empty name', () async {
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.windows, 'win11');
    expect(bloc.state.backend, 'auto');
    expect(bloc.state.canSubmit, isFalse);
    await bloc.close();
  });

  test('a name taken by a bottle, in any case, cannot be submitted', () async {
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    bloc.add(const NewBottleEvent.nameChanged('STEAM'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.taken, ['steam']);
    expect(bloc.state.canSubmit, isFalse);
    await bloc.close();
  });

  test('a name the engine would reject cannot be submitted', () async {
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    for (final name in ['-games', 'my games', 'a' * 65]) {
      bloc.add(NewBottleEvent.nameChanged(name));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.canSubmit, isFalse, reason: name);
    }
    await bloc.close();
  });

  blocTest<NewBottleBloc, NewBottleState>(
    'submitting creates the bottle with the chosen Windows and backend',
    build: () {
      when(() => repository.create('games', windows: 'win10', backend: 'dxmt'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const NewBottleEvent.nameChanged('games'))
        ..add(const NewBottleEvent.windowsChanged('win10'))
        ..add(const NewBottleEvent.backendChanged('dxmt'))
        ..add(const NewBottleEvent.submit());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(
        () => repository.create('games', windows: 'win10', backend: 'dxmt'),
      ).called(1);
      expect(bloc.state.createdName, 'games');
      expect(bloc.state.isCreating, isFalse);
    },
  );

  blocTest<NewBottleBloc, NewBottleState>(
    'a failed creation keeps the error and creates nothing',
    build: () {
      when(() => repository.create('games', windows: 'win11', backend: 'auto'))
          .thenAnswer(
            (_) async => left(
              const AppError.wineToolFailed(
                WineTool.wineboot,
                1,
                '/l/wineboot.log',
              ),
            ),
          );
      return build();
    },
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const NewBottleEvent.nameChanged('games'))
        ..add(const NewBottleEvent.submit());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(
        bloc.state.error,
        const AppError.wineToolFailed(WineTool.wineboot, 1, '/l/wineboot.log'),
      );
      expect(bloc.state.createdName, isNull);
      expect(bloc.state.isCreating, isFalse);
    },
  );

  blocTest<NewBottleBloc, NewBottleState>(
    'submitting a taken name does not call the repository',
    build: build,
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const NewBottleEvent.nameChanged('steam'))
        ..add(const NewBottleEvent.submit());
    },
    wait: const Duration(milliseconds: 10),
    verify: (_) => verifyNever(
      () => repository.create(
        any(),
        windows: any(named: 'windows'),
        backend: any(named: 'backend'),
      ),
    ),
  );

  group('the engine (MA6)', () {
    setUpAll(() => registerFallbackValue((BottleStep _) {}));

    /// Native creation reports [steps], then ends with [result].
    void createsNative(List<BottleStep> steps, Either<AppError, Unit> result) {
      when(
        () => repository.create(
          'games',
          windows: 'win11',
          backend: 'auto',
          runtime: RuntimeKind.mach9,
          onStep: any(named: 'onStep'),
        ),
      ).thenAnswer((call) async {
        steps.forEach(
          call.namedArguments[#onStep] as void Function(BottleStep),
        );
        return result;
      });
    }

    test('starts on Rosetta; Native when the engine is available, until '
        'the user picks one (D26)', () async {
      final bloc = build();
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.runtime, RuntimeKind.bodega);

      bloc.add(const NewBottleEvent.nativeAvailable(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.runtime, RuntimeKind.mach9);

      bloc
        ..add(const NewBottleEvent.runtimeChanged(RuntimeKind.bodega))
        ..add(const NewBottleEvent.nativeAvailable(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.runtime, RuntimeKind.bodega);
      await bloc.close();
    });

    blocTest<NewBottleBloc, NewBottleState>(
      'changing the engine resets Graphics to Automatic',
      build: build,
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const NewBottleEvent.backendChanged('dxvk'))
          ..add(const NewBottleEvent.runtimeChanged(RuntimeKind.mach9));
      },
      verify: (bloc) {
        expect(bloc.state.runtime, RuntimeKind.mach9);
        expect(bloc.state.backend, 'auto');
      },
    );

    blocTest<NewBottleBloc, NewBottleState>(
      'submitting passes the engine, and shows each step',
      build: () {
        createsNative(const [BottleStep.prefix, BottleStep.mono], right(unit));
        return build();
      },
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const NewBottleEvent.nameChanged('games'))
          ..add(const NewBottleEvent.runtimeChanged(RuntimeKind.mach9))
          ..add(const NewBottleEvent.submit());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => containsAllInOrder([
        isA<NewBottleState>().having((s) => s.step, 'step', BottleStep.prefix),
        isA<NewBottleState>().having((s) => s.step, 'step', BottleStep.mono),
      ]),
      verify: (bloc) {
        expect(bloc.state.createdName, 'games');
        expect(bloc.state.monoFailed, isFalse);
        expect(bloc.state.error, isNull);
      },
    );

    blocTest<NewBottleBloc, NewBottleState>(
      'a Wine Mono failure leaves the bottle made, with the error',
      build: () {
        createsNative(
          const [BottleStep.prefix, BottleStep.mono],
          left(const AppError.wineToolFailed(WineTool.mono, 1603, '/l/m.log')),
        );
        return build();
      },
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const NewBottleEvent.nameChanged('games'))
          ..add(const NewBottleEvent.runtimeChanged(RuntimeKind.mach9))
          ..add(const NewBottleEvent.submit());
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.createdName, 'games');
        expect(bloc.state.monoFailed, isTrue);
        expect(
          bloc.state.error,
          const AppError.wineToolFailed(WineTool.mono, 1603, '/l/m.log'),
        );
        expect(bloc.state.isCreating, isFalse);
      },
    );

    blocTest<NewBottleBloc, NewBottleState>(
      'a failure before Mono creates nothing',
      build: () {
        createsNative(const [
          BottleStep.prefix,
        ], left(const AppError.runtimeNotInstalled(RuntimeKind.mach9)));
        return build();
      },
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const NewBottleEvent.nameChanged('games'))
          ..add(const NewBottleEvent.runtimeChanged(RuntimeKind.mach9))
          ..add(const NewBottleEvent.submit());
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.createdName, isNull);
        expect(bloc.state.monoFailed, isFalse);
        expect(
          bloc.state.error,
          const AppError.runtimeNotInstalled(RuntimeKind.mach9),
        );
      },
    );
  });
}
