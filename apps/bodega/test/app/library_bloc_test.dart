import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibrary extends Mock implements LibraryRepository {}

class _MockBottles extends Mock implements BottleRepository {}

const _blur = LibraryApp(
  bottle: 'blur',
  key: 'blur.exe',
  id: 'custom',
  title: 'Blur',
);

/// Easy Anti-Cheat failing for POLYGON, as its log names it.
const _polygon = RunHint.antiCheat(game: 'POLYGON');

// Hints as the repository makes them: a new object on each call, equal to any
// other with the same code, so that only value equality finds it known (E14).
RunHint _antiCheat(String? game) => RunHint.antiCheat(game: game);
RunHint _log(LogHint hint) => RunHint.log(hint);

void main() {
  late _MockLibrary repository;
  late _MockBottles bottles;
  late Completer<void> firstExit;
  late Completer<void> bottleEmpty;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repository = _MockLibrary();
    bottles = _MockBottles();
    firstExit = Completer();
    bottleEmpty = Completer();
    when(() => repository.open('steam'))
        .thenAnswer((_) async => right('/l/a.log'));
    when(() => repository.firstExit('/l/a.log'))
        .thenAnswer((_) => firstExit.future);
    when(() => repository.waitBottle('steam'))
        .thenAnswer((_) => bottleEmpty.future);
    when(() => repository.bottleNames()).thenAnswer((_) async => const []);
    // Closing a bottle reloads the apps: what ran may have added some.
    when(() => repository.apps()).thenAnswer((_) async => right(const []));
    when(() => repository.antiCheatHints(any(), any())).thenReturn(const []);
    when(() => repository.hintsIn(any())).thenAnswer((_) async => const []);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  blocTest<LibraryBloc, LibraryState>(
    'lists the apps',
    build: () {
      when(() => repository.apps())
          .thenAnswer((_) async => right(const [_blur]));
      return LibraryBloc(repository, bottles);
    },
    act: (bloc) => bloc.add(const LibraryEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.apps, const [_blur]);
    },
  );

  blocTest<LibraryBloc, LibraryState>(
    'an empty library is not loading',
    build: () {
      when(() => repository.apps()).thenAnswer((_) async => right(const []));
      return LibraryBloc(repository, bottles);
    },
    act: (bloc) => bloc.add(const LibraryEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.apps, isEmpty);
    },
  );

  blocTest<LibraryBloc, LibraryState>(
    'the HUD of an application is saved and the library reloads',
    build: () {
      when(() => repository.apps()).thenAnswer((_) async => right(const []));
      when(() => bottles.setHud('steam', 'a/a.exe', true))
          .thenAnswer((_) async => right(unit));
      return LibraryBloc(repository, bottles);
    },
    act: (bloc) =>
        bloc.add(const LibraryEvent.setHud('steam', 'a/a.exe', true)),
    wait: const Duration(milliseconds: 10),
    verify: (_) {
      verify(() => bottles.setHud('steam', 'a/a.exe', true)).called(1);
      verify(() => repository.apps()).called(1);
    },
  );

  test('open until the last process, not the first', () async {
    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.open('steam'));
    await settle();
    expect(bloc.state.open, {'steam'});

    // Steam restarting itself: the first process goes, the bottle stays.
    firstExit.complete();
    await settle();
    expect(bloc.state.open, {'steam'});

    bottleEmpty.complete();
    await settle();
    await settle();
    expect(bloc.state.open, isEmpty);
    await bloc.close();
  });

  test('a program run in a bottle keeps it open until it empties', () async {
    when(() => repository.run('steam', '/g/tool.exe'))
        .thenAnswer((_) async => right('/l/a.log'));
    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.run('steam', '/g/tool.exe'));
    await settle();
    expect(bloc.state.open, {'steam'});

    firstExit.complete();
    bottleEmpty.complete();
    await settle();
    await settle();
    expect(bloc.state.open, isEmpty);
    await bloc.close();
  });

  test('two applications of a bottle open one after the other', () async {
    when(() => repository.open('steam', key: 'a'))
        .thenAnswer((_) async => right('/l/a.log'));
    when(() => repository.open('steam', key: 'b'))
        .thenAnswer((_) async => right('/l/a.log'));
    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.open('steam', 'a'));
    await settle();
    bloc.add(const LibraryEvent.open('steam', 'b'));
    await settle();

    verify(() => repository.open('steam', key: 'a')).called(1);
    verify(() => repository.open('steam', key: 'b')).called(1);
    expect(bloc.state.open, {'steam'});

    firstExit.complete();
    bottleEmpty.complete();
    await settle();
    await settle();
    expect(bloc.state.open, isEmpty);
    await bloc.close();
  });

  test('opening a second one keeps the hints of the first', () async {
    when(() => repository.open('steam', key: 'b'))
        .thenAnswer((_) async => right('/l/a.log'));
    when(() => repository.antiCheatHints('steam', any()))
        .thenReturn(const [_polygon]);
    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.open('steam'));
    await settle();
    bloc.add(const LibraryEvent.checkHints());
    await settle();
    bloc.add(const LibraryEvent.open('steam', 'b'));
    await settle();

    expect(bloc.state.hints['steam'], [_polygon]);
    await bloc.close();
  });

  test('a panel runs with its arguments', () async {
    when(() => repository.run('steam', 'control', args: ['joy.cpl']))
        .thenAnswer((_) async => right('/l/a.log'));
    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.run('steam', 'control', ['joy.cpl']));
    await settle();
    expect(bloc.state.open, {'steam'});
    await bloc.close();
  });

  test(
    'a launch made elsewhere is followed until the bottle empties',
    () async {
      final bloc = LibraryBloc(repository, bottles)
        ..add(const LibraryEvent.track('steam', '/l/a.log'));
      await settle();
      expect(bloc.state.open, {'steam'});
      firstExit.complete();
      bottleEmpty.complete();
      await settle();
      await settle();
      expect(bloc.state.open, isEmpty);
      await bloc.close();
    },
  );

  blocTest<LibraryBloc, LibraryState>(
    'a double click launches it once',
    build: () => LibraryBloc(repository, bottles),
    act: (bloc) => bloc
      ..add(const LibraryEvent.open('steam'))
      ..add(const LibraryEvent.open('steam')),
    verify: (_) => verify(() => repository.open('steam')).called(1),
  );

  blocTest<LibraryBloc, LibraryState>(
    'rebuilds what is running when it starts',
    build: () {
      when(() => repository.apps())
          .thenAnswer((_) async => right(const [_blur]));
      // steam has no app here: a running bottle counts just the same.
      when(() => repository.bottleNames())
          .thenAnswer((_) async => const ['steam', 'blur']);
      when(() => repository.waitBottle('blur')).thenAnswer((_) async {});
      return LibraryBloc(repository, bottles);
    },
    act: (bloc) => bloc.add(const LibraryEvent.load()),
    wait: const Duration(milliseconds: 1100),
    verify: (bloc) => expect(bloc.state.open, {'steam'}),
  );

  // Two checks find equal hints: one value, on the card and in one toast.
  blocTest<LibraryBloc, LibraryState>(
    'a hint comes out once, and stays on the card (E14)',
    build: () {
      when(() => repository.antiCheatHints('steam', any()))
          .thenAnswer((_) => [_antiCheat('POLYGON')]);
      return LibraryBloc(repository, bottles);
    },
    act: (bloc) async {
      bloc.add(const LibraryEvent.open('steam'));
      await settle();
      bloc
        ..add(const LibraryEvent.checkHints())
        ..add(const LibraryEvent.checkHints());
    },
    verify: (bloc) {
      expect(bloc.state.toastId, 1);
      expect(bloc.state.toast, _polygon);
      expect(bloc.state.hints['steam'], [_polygon]);
    },
  );

  test('closing also reads the hints of the log', () async {
    when(() => repository.hintsIn('/l/a.log'))
        .thenAnswer((_) async => const [RunHint.log(LogHint.freeType)]);
    firstExit.complete();
    bottleEmpty.complete();

    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.open('steam'));
    await bloc.stream.firstWhere((state) => state.toastId == 1);

    expect(bloc.state.open, isEmpty);
    expect(bloc.state.hints['steam'], [const RunHint.log(LogHint.freeType)]);
    await bloc.close();
  });

  test('a closing run adds each of its hints once, in order (E14)', () async {
    when(() => repository.antiCheatHints('steam', any()))
        .thenAnswer((_) => [_antiCheat('A'), _antiCheat('B')]);
    when(
      () => repository.hintsIn('/l/a.log'),
    ).thenAnswer((_) async => [_log(LogHint.freeType), _log(LogHint.freeType)]);
    firstExit.complete();
    bottleEmpty.complete();

    final bloc = LibraryBloc(repository, bottles)
      ..add(const LibraryEvent.open('steam'));
    await bloc.stream.firstWhere((state) => state.toastId == 3);
    await settle();

    expect(bloc.state.hints['steam'], const [
      RunHint.antiCheat(game: 'A'),
      RunHint.antiCheat(game: 'B'),
      RunHint.log(LogHint.freeType),
    ]);
    expect(bloc.state.toastId, 3);
    expect(bloc.state.toast, const RunHint.log(LogHint.freeType));
    await bloc.close();
  });

  test('two hints with the same code are equal, never the same object', () {
    expect(_antiCheat('A'), _antiCheat('A'));
    expect(identical(_antiCheat('A'), _antiCheat('A')), isFalse);
    expect(_antiCheat('A'), isNot(_antiCheat('B')));
    expect(_antiCheat(null), isNot(_antiCheat('A')));
    expect(_log(LogHint.freeType), isNot(_log(LogHint.gnuTls)));
  });
}
