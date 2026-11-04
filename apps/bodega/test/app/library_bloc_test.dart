import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibrary extends Mock implements LibraryRepository {}

const _blur = LibraryApp(
  bottle: 'blur',
  key: 'blur.exe',
  id: 'custom',
  title: 'Blur',
);

void main() {
  late _MockLibrary repository;
  late Completer<void> firstExit;
  late Completer<void> bottleEmpty;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repository = _MockLibrary();
    firstExit = Completer();
    bottleEmpty = Completer();
    when(() => repository.open('steam'))
        .thenAnswer((_) async => right('/l/a.log'));
    when(() => repository.firstExit('/l/a.log'))
        .thenAnswer((_) => firstExit.future);
    when(() => repository.waitBottle('steam'))
        .thenAnswer((_) => bottleEmpty.future);
    when(() => repository.bottleNames()).thenAnswer((_) async => const []);
    when(() => repository.antiCheatHints(any(), any())).thenReturn(const []);
    when(() => repository.hintsIn(any())).thenAnswer((_) async => const []);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  blocTest<LibraryBloc, LibraryState>(
    'lists the apps',
    build: () {
      when(() => repository.apps())
          .thenAnswer((_) async => right(const [_blur]));
      return LibraryBloc(repository);
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
      return LibraryBloc(repository);
    },
    act: (bloc) => bloc.add(const LibraryEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.apps, isEmpty);
    },
  );

  test('open until the last process, not the first', () async {
    final bloc = LibraryBloc(repository)..add(const LibraryEvent.open('steam'));
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
    final bloc = LibraryBloc(repository)
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
    final bloc = LibraryBloc(repository)
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
        .thenReturn(const ['EAC falló']);
    final bloc = LibraryBloc(repository)..add(const LibraryEvent.open('steam'));
    await settle();
    bloc.add(const LibraryEvent.checkHints());
    await settle();
    bloc.add(const LibraryEvent.open('steam', 'b'));
    await settle();

    expect(bloc.state.hints['steam'], ['EAC falló']);
    await bloc.close();
  });

  blocTest<LibraryBloc, LibraryState>(
    'a double click launches it once',
    build: () => LibraryBloc(repository),
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
      return LibraryBloc(repository);
    },
    act: (bloc) => bloc.add(const LibraryEvent.load()),
    wait: const Duration(milliseconds: 1100),
    verify: (bloc) => expect(bloc.state.open, {'steam'}),
  );

  blocTest<LibraryBloc, LibraryState>(
    'a hint comes out once, and stays on the card',
    build: () {
      when(() => repository.antiCheatHints('steam', any()))
          .thenReturn(const ['EAC falló']);
      return LibraryBloc(repository);
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
      expect(bloc.state.toast, 'EAC falló');
      expect(bloc.state.hints['steam'], ['EAC falló']);
    },
  );

  test('closing also reads the hints of the log', () async {
    when(() => repository.hintsIn('/l/a.log'))
        .thenAnswer((_) async => const ['falta FreeType']);
    firstExit.complete();
    bottleEmpty.complete();

    final bloc = LibraryBloc(repository)..add(const LibraryEvent.open('steam'));
    await bloc.stream.firstWhere((state) => state.toastId == 1);

    expect(bloc.state.open, isEmpty);
    expect(bloc.state.hints['steam'], ['falta FreeType']);
    await bloc.close();
  });
}
