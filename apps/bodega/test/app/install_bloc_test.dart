import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/repository/install_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockInstall extends Mock implements InstallRepository {}

const _app = CatalogApp(
  id: 'rockstar',
  title: 'Rockstar',
  status: CatalogStatus.reported,
  statusNote: '',
  backend: 'dxvk',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: false,
);

void main() {
  late _MockInstall repository;

  setUpAll(() {
    registerFallbackValue((int _, int? _) {});
    registerFallbackValue((String _) {});
  });

  void downloads(Either<AppError, String?> result) {
    when(() => repository.download(any(), any())).thenAnswer((call) async {
      final onProgress =
          call.positionalArguments[1] as void Function(int, int?);
      onProgress(50, 100);
      onProgress(50, 100);
      onProgress(100, 100);
      return result;
    });
  }

  setUp(() => repository = _MockInstall());

  blocTest<InstallBloc, InstallState>(
    'shows the progress, one state per percent, and finishes',
    build: () {
      downloads(right('/d/setup.exe'));
      when(() => repository.install(any(), any(), any()))
          .thenAnswer((call) async {
            (call.positionalArguments[2] as void Function(String))('Creando');
            return right(unit);
          });
      return InstallBloc(repository);
    },
    act: (bloc) => bloc.add(const InstallEvent.start(_app)),
    expect: () => const [
      InstallState(phase: InstallPhase.downloading, app: _app),
      InstallState(
        phase: InstallPhase.downloading,
        app: _app,
        received: 50,
        total: 100,
      ),
      InstallState(
        phase: InstallPhase.downloading,
        app: _app,
        received: 100,
        total: 100,
      ),
      InstallState(
        phase: InstallPhase.installing,
        app: _app,
        received: 100,
        total: 100,
      ),
      InstallState(
        phase: InstallPhase.installing,
        app: _app,
        received: 100,
        total: 100,
        step: 'Creando',
      ),
      InstallState(
        phase: InstallPhase.done,
        app: _app,
        received: 100,
        total: 100,
        step: 'Creando',
      ),
    ],
  );

  blocTest<InstallBloc, InstallState>(
    'cancelling goes back to idle, without installing',
    build: () {
      final cancelled = Completer<Either<AppError, String?>>();
      when(() => repository.download(any(), any()))
          .thenAnswer((_) => cancelled.future);
      when(() => repository.cancelDownload()).thenAnswer((_) {
        cancelled.complete(right(null));
      });
      return InstallBloc(repository);
    },
    act: (bloc) => bloc
      ..add(const InstallEvent.start(_app))
      ..add(const InstallEvent.cancel()),
    verify: (bloc) {
      expect(bloc.state, const InstallState());
      verify(() => repository.cancelDownload()).called(1);
      verifyNever(() => repository.install(any(), any(), any()));
    },
  );

  blocTest<InstallBloc, InstallState>(
    'a network error fails with no bottle to delete',
    build: () {
      downloads(left(const AppError.network('sin red')));
      return InstallBloc(repository);
    },
    act: (bloc) => bloc.add(const InstallEvent.start(_app)),
    verify: (bloc) {
      expect(bloc.state.phase, InstallPhase.failed);
      expect(bloc.state.error, const AppError.network('sin red'));
      expect(bloc.state.bottleLeft, isFalse);
      verifyNever(() => repository.install(any(), any(), any()));
    },
  );

  blocTest<InstallBloc, InstallState>(
    'an installer error keeps the log in its message and offers deleting',
    build: () {
      downloads(right('/d/setup.exe'));
      when(() => repository.install(any(), any(), any())).thenAnswer(
        (_) async => left(
          const AppError.engine('el instalador salió con 1; log: /l/a.log'),
        ),
      );
      when(() => repository.bottleExists('rockstar')).thenReturn(true);
      when(() => repository.removeBottle('rockstar'))
          .thenAnswer((_) async => right(unit));
      return InstallBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const InstallEvent.start(_app));
      await bloc.stream.firstWhere((s) => s.phase == InstallPhase.failed);
      expect(bloc.state.error?.message, contains('/l/a.log'));
      expect(bloc.state.bottleLeft, isTrue);
      bloc.add(const InstallEvent.removeBottle());
    },
    verify: (bloc) {
      expect(bloc.state, const InstallState());
      verify(() => repository.removeBottle('rockstar')).called(1);
    },
  );

  blocTest<InstallBloc, InstallState>(
    'a second installation is refused while one is running',
    build: () {
      when(() => repository.download(any(), any()))
          .thenAnswer((_) => Completer<Either<AppError, String?>>().future);
      return InstallBloc(repository);
    },
    act: (bloc) => bloc
      ..add(const InstallEvent.start(_app))
      ..add(InstallEvent.start(_app.copyWith(id: 'ea-app'))),
    verify: (bloc) {
      expect(bloc.state.app?.id, 'rockstar');
      verify(() => repository.download('rockstar', any())).called(1);
      verifyNever(() => repository.download('ea-app', any()));
    },
  );
}
