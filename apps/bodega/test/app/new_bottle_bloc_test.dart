import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
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

    for (final name in ['-juegos', 'mis juegos', 'a' * 65]) {
      bloc.add(NewBottleEvent.nameChanged(name));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.canSubmit, isFalse, reason: name);
    }
    await bloc.close();
  });

  blocTest<NewBottleBloc, NewBottleState>(
    'submitting creates the bottle with the chosen Windows and backend',
    build: () {
      when(() => repository.create('juegos', windows: 'win10', backend: 'dxmt'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const NewBottleEvent.nameChanged('juegos'))
        ..add(const NewBottleEvent.windowsChanged('win10'))
        ..add(const NewBottleEvent.backendChanged('dxmt'))
        ..add(const NewBottleEvent.submit());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(
        () => repository.create('juegos', windows: 'win10', backend: 'dxmt'),
      ).called(1);
      expect(bloc.state.createdName, 'juegos');
      expect(bloc.state.isCreating, isFalse);
    },
  );

  blocTest<NewBottleBloc, NewBottleState>(
    'a failed creation keeps the error and creates nothing',
    build: () {
      when(
        () => repository.create('juegos', windows: 'win11', backend: 'auto'),
      ).thenAnswer((_) async => left(const AppError.engine('wineboot failed')));
      return build();
    },
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const NewBottleEvent.nameChanged('juegos'))
        ..add(const NewBottleEvent.submit());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('wineboot failed'));
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

  test('importing a file names the bottle it made', () async {
    when(() => repository.importBottle('/tmp/steam.tar.gz'))
        .thenAnswer((_) async => right('steam-2'));
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    bloc.add(const NewBottleEvent.import('/tmp/steam.tar.gz'));
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.importBottle('/tmp/steam.tar.gz')).called(1);
    expect(bloc.state.createdName, 'steam-2');
    expect(bloc.state.isImporting, isFalse);
    await bloc.close();
  });

  test('a failed import says why and makes nothing', () async {
    when(() => repository.importBottle('/tmp/bad.tar.gz'))
        .thenAnswer((_) async => left(const AppError.engine('not a bottle')));
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    bloc.add(const NewBottleEvent.import('/tmp/bad.tar.gz'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.error, const AppError.engine('not a bottle'));
    expect(bloc.state.createdName, isNull);
    expect(bloc.state.isImporting, isFalse);
    verifyNever(() => repository.create(any()));
    await bloc.close();
  });
}
