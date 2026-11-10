import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/preferences/preferences_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/storage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements StorageRepository {}

void main() {
  late _MockStorage repository;

  setUp(() {
    repository = _MockStorage();
    when(() => repository.dataFolder).thenReturn('/home/x/.bodega');
    when(() => repository.downloadsSize()).thenAnswer((_) async => right(2048));
    when(() => repository.clearDownloads())
        .thenAnswer((_) async => right(unit));
  });

  blocTest<PreferencesBloc, PreferencesState>(
    'load gives the folder and the cache size',
    build: () => PreferencesBloc(repository),
    act: (bloc) => bloc.add(const PreferencesEvent.load()),
    expect: () => const [
      PreferencesState(dataFolder: '/home/x/.bodega'),
      PreferencesState(dataFolder: '/home/x/.bodega', cacheBytes: 2048),
    ],
  );

  blocTest<PreferencesBloc, PreferencesState>(
    'clear empties the cache and leaves the size at 0',
    build: () => PreferencesBloc(repository),
    seed: () => const PreferencesState(cacheBytes: 2048),
    act: (bloc) => bloc.add(const PreferencesEvent.clear()),
    expect: () => const [
      PreferencesState(cacheBytes: 2048, isClearing: true),
      PreferencesState(cacheBytes: 0),
    ],
    verify: (_) => verify(() => repository.clearDownloads()).called(1),
  );

  blocTest<PreferencesBloc, PreferencesState>(
    'a failed clear keeps the size and shows the error',
    build: () {
      when(() => repository.clearDownloads())
          .thenAnswer((_) async => left(const AppError.engine('busy')));
      return PreferencesBloc(repository);
    },
    seed: () => const PreferencesState(cacheBytes: 2048),
    act: (bloc) => bloc.add(const PreferencesEvent.clear()),
    expect: () => const [
      PreferencesState(cacheBytes: 2048, isClearing: true),
      PreferencesState(cacheBytes: 2048, error: AppError.engine('busy')),
    ],
  );

  blocTest<PreferencesBloc, PreferencesState>(
    'a failed size shows the error',
    build: () {
      when(() => repository.downloadsSize())
          .thenAnswer((_) async => left(const AppError.engine('denied')));
      return PreferencesBloc(repository);
    },
    act: (bloc) => bloc.add(const PreferencesEvent.load()),
    skip: 1,
    expect: () => const [
      PreferencesState(
        dataFolder: '/home/x/.bodega',
        error: AppError.engine('denied'),
      ),
    ],
  );
}
