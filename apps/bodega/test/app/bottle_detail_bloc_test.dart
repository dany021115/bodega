import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockBottles extends Mock implements BottleRepository {}

const _detail = BottleDetail(name: 'steam', backend: 'auto', sync: 'msync');

void main() {
  late _MockBottles repository;

  setUp(() {
    repository = _MockBottles();
    when(() => repository.detail('steam'))
        .thenAnswer((_) async => right(_detail));
  });

  BottleDetailBloc build() => BottleDetailBloc(repository);
  const load = BottleDetailEvent.load('steam');

  blocTest<BottleDetailBloc, BottleDetailState>(
    'loads',
    build: build,
    act: (bloc) => bloc.add(load),
    expect: () => const [BottleDetailState(isLoading: false, detail: _detail)],
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'changing backend and msync saves them and reloads',
    build: () {
      when(() => repository.setBackend('steam', 'dxmt'))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setSync('steam', 'none'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc
        ..add(const BottleDetailEvent.setBackend('dxmt'))
        ..add(const BottleDetailEvent.setSync('none'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(() => repository.setBackend('steam', 'dxmt')).called(1);
      verify(() => repository.setSync('steam', 'none')).called(1);
      verify(() => repository.detail('steam')).called(3);
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'removing an exception sets that program to auto',
    build: () {
      when(() => repository.setBackend('steam', 'auto', exe: 'steam.exe'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.removeException('steam.exe'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (_) =>
        verify(() => repository.setBackend('steam', 'auto', exe: 'steam.exe'))
            .called(1),
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'deleting tells the page to go back to the list',
    build: () {
      when(() => repository.delete('steam'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.delete());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) => expect(bloc.state.deleted, isTrue),
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'an engine error stays in the state, with the bottle still shown',
    build: () {
      when(() => repository.delete('steam'))
          .thenAnswer((_) async => left(const AppError.engine('no se pudo')));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.delete());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('no se pudo'));
      expect(bloc.state.deleted, isFalse);
      expect(bloc.state.isBusy, isFalse);
      expect(bloc.state.detail, _detail);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'opens a log',
    build: () {
      when(() => repository.logLines('/l/a.log'))
          .thenAnswer((_) async => right(const ['uno', 'dos']));
      return build();
    },
    act: (bloc) => bloc.add(const BottleDetailEvent.openLog('/l/a.log')),
    verify: (bloc) {
      expect(bloc.state.logPath, '/l/a.log');
      expect(bloc.state.logLines, ['uno', 'dos']);
    },
  );
}
