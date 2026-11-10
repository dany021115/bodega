import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockBottles extends Mock implements BottleRepository {}

const _detail = BottleDetail(
  name: 'steam',
  ready: true,
  backend: 'auto',
  sync: 'msync',
);

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
    'hiding an application reloads the bottle',
    build: () {
      when(() => repository.hideApp('steam', 'steam:9'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.hideApp('steam:9'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(() => repository.hideApp('steam', 'steam:9')).called(1);
      verify(() => repository.detail('steam')).called(2);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'each setting goes to the repository and reloads',
    build: () {
      when(() => repository.setHighRes('steam', true))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setWindowsVersion('steam', 'win7'))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setOptions('steam', dlss: true))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setOptions('steam', avx: false))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setUser('steam', 'Dany'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc
        ..add(const BottleDetailEvent.setHighRes(true))
        ..add(const BottleDetailEvent.setWindows('win7'))
        ..add(const BottleDetailEvent.setDlss(true))
        ..add(const BottleDetailEvent.setAvx(false))
        ..add(const BottleDetailEvent.setUser('Dany'));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      verify(() => repository.setHighRes('steam', true)).called(1);
      verify(() => repository.setWindowsVersion('steam', 'win7')).called(1);
      verify(() => repository.setOptions('steam', dlss: true)).called(1);
      verify(() => repository.setOptions('steam', avx: false)).called(1);
      verify(() => repository.setUser('steam', 'Dany')).called(1);
      verify(() => repository.detail('steam')).called(6);
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'gpu and gamemode go to the repository and reload',
    build: () {
      when(() => repository.setOptions('steam', gpu: 'discrete'))
          .thenAnswer((_) async => right(unit));
      when(() => repository.setOptions('steam', gamemode: true))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc
        ..add(const BottleDetailEvent.setGpu('discrete'))
        ..add(const BottleDetailEvent.setGamemode(true));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      verify(() => repository.setOptions('steam', gpu: 'discrete')).called(1);
      verify(() => repository.setOptions('steam', gamemode: true)).called(1);
      verify(() => repository.detail('steam')).called(3);
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'a failed setting is shown and the bottle stays',
    build: () {
      when(() => repository.setWindowsVersion('steam', 'win7')).thenAnswer(
        (_) async => left(const AppError.engine('winecfg exited with 1')),
      );
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.setWindows('win7'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('winecfg exited with 1'));
      expect(bloc.state.detail, _detail);
    },
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
          .thenAnswer((_) async => left(const AppError.engine('it failed')));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.delete());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('it failed'));
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

  blocTest<BottleDetailBloc, BottleDetailState>(
    'renaming reloads the bottle under its new name',
    build: () {
      when(() => repository.renameBottle('steam', 'juegos'))
          .thenAnswer((_) async => right(unit));
      when(() => repository.detail('juegos'))
          .thenAnswer((_) async => right(_detail.copyWith(name: 'juegos')));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.rename('juegos'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(() => repository.renameBottle('steam', 'juegos')).called(1);
      expect(bloc.state.detail?.name, 'juegos');
      expect(bloc.state.renamedTo, 'juegos');
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'a failed rename keeps the name and says why',
    build: () {
      when(() => repository.renameBottle('steam', 'juegos'))
          .thenAnswer((_) async => left(const AppError.engine('it exists')));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.rename('juegos'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('it exists'));
      expect(bloc.state.renamedTo, isNull);
      expect(bloc.state.detail, _detail);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'the HUD of an application is saved and the detail reloads',
    build: () {
      when(() => repository.setHud('steam', 'a/a.exe', true))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.setHud('a/a.exe', true));
    },
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(() => repository.setHud('steam', 'a/a.exe', true)).called(1);
      verify(() => repository.detail('steam')).called(2);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'hiding an application from the library saves it and reloads',
    build: () {
      when(() => repository.setInLibrary('steam', 'a/a.exe', false))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.setInLibrary('a/a.exe', false));
    },
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(() => repository.setInLibrary('steam', 'a/a.exe', false))
          .called(1);
      verify(() => repository.detail('steam')).called(2);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'duplicating makes the copy and points to it',
    build: () {
      when(() => repository.duplicate('steam', 'steam-2'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.duplicate('steam-2'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(() => repository.duplicate('steam', 'steam-2')).called(1);
      verify(() => repository.detail('steam')).called(2);
      expect(bloc.state.duplicatedTo, 'steam-2');
      expect(bloc.state.working, isNull);
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'exporting writes the file and names it',
    build: () {
      when(() => repository.export('steam', '/tmp/steam.tar.gz'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.export('/tmp/steam.tar.gz'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      verify(() => repository.export('steam', '/tmp/steam.tar.gz')).called(1);
      expect(bloc.state.exportedTo, '/tmp/steam.tar.gz');
      expect(bloc.state.working, isNull);
      expect(bloc.state.isBusy, isFalse);
    },
  );

  blocTest<BottleDetailBloc, BottleDetailState>(
    'shows the job while it runs',
    build: () {
      when(() => repository.export('steam', '/tmp/steam.tar.gz'))
          .thenAnswer((_) async => right(unit));
      return build();
    },
    act: (bloc) async {
      bloc.add(load);
      await bloc.stream.first;
      bloc.add(const BottleDetailEvent.export('/tmp/steam.tar.gz'));
    },
    skip: 1,
    wait: const Duration(milliseconds: 10),
    expect: () => [
      const BottleDetailState(
        isLoading: false,
        detail: _detail,
        isBusy: true,
        working: BottleWork.exporting,
      ),
      const BottleDetailState(
        isLoading: false,
        detail: _detail,
        exportedTo: '/tmp/steam.tar.gz',
      ),
    ],
  );

  for (final (label, event) in [
    ('duplicate', const BottleDetailEvent.duplicate('steam-2')),
    ('export', const BottleDetailEvent.export('/tmp/steam.tar.gz')),
  ]) {
    blocTest<BottleDetailBloc, BottleDetailState>(
      'a failed $label leaves the bottle as it was and says why',
      build: () {
        when(() => repository.duplicate(any(), any()))
            .thenAnswer((_) async => left(const AppError.engine('no room')));
        when(() => repository.export(any(), any()))
            .thenAnswer((_) async => left(const AppError.engine('no room')));
        return build();
      },
      act: (bloc) async {
        bloc.add(load);
        await bloc.stream.first;
        bloc.add(event);
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.error, const AppError.engine('no room'));
        expect(bloc.state.duplicatedTo, isNull);
        expect(bloc.state.exportedTo, isNull);
        expect(bloc.state.working, isNull);
        expect(bloc.state.isBusy, isFalse);
        expect(bloc.state.detail, _detail);
      },
    );
  }
}
