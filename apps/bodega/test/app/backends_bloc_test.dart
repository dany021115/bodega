import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockBackends extends Mock implements BackendRepository {}

void main() {
  late _MockBackends repository;
  const missing = BackendInfo(
    name: 'dxvk',
    installed: false,
    downloadable: true,
  );
  const installed = BackendInfo(
    name: 'dxvk',
    installed: true,
    downloadable: true,
  );

  setUpAll(() => registerFallbackValue((int _, int? _) {}));

  setUp(() {
    repository = _MockBackends();
    when(() => repository.list())
        .thenAnswer((_) async => right(const [missing]));
    when(() => repository.readyBottles())
        .thenAnswer((_) async => right(const ['prueba']));
  });

  blocTest<BackendsBloc, BackendsState>(
    'loads the backends and the bottles',
    build: () => BackendsBloc(repository),
    act: (bloc) => bloc.add(const BackendsEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.backends, const [missing]);
      expect(bloc.state.bottles, ['prueba']);
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'shows the progress, one state per percent, and ends installed',
    build: () {
      when(() => repository.download('dxvk', any())).thenAnswer((call) async {
        final onProgress =
            call.positionalArguments[1] as void Function(int, int?);
        onProgress(50, 100);
        onProgress(50, 100);
        when(() => repository.list())
            .thenAnswer((_) async => right(const [installed]));
        return right(true);
      });
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.download('dxvk')),
    expect: () => [
      const BackendsState(busy: 'dxvk', isDownloading: true),
      const BackendsState(
        busy: 'dxvk',
        isDownloading: true,
        received: 50,
        total: 100,
      ),
      const BackendsState(received: 50, total: 100),
      const BackendsState(
        isLoading: false,
        backends: [installed],
        bottles: ['prueba'],
        received: 50,
        total: 100,
      ),
    ],
  );

  blocTest<BackendsBloc, BackendsState>(
    'a wrong SHA is shown, and the backend stays not installed',
    build: () {
      when(() => repository.download('dxvk', any())).thenAnswer(
        (_) async => left(const AppError.engine('checksum incorrecto')),
      );
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.download('dxvk')),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('checksum incorrecto'));
      expect(bloc.state.busy, isNull);
      expect(bloc.state.backends, const [missing]);
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'importing with an error says why',
    build: () {
      when(
        () => repository.importD3DMetal('/x'),
      ).thenAnswer((_) async => left(const AppError.engine('falta external')));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.importD3DMetal('/x')),
    verify: (bloc) {
      expect(bloc.state.error, const AppError.engine('falta external'));
      expect(bloc.state.busy, isNull);
    },
  );

  const result = ProbeResult(bits: 64, d3d: '11', ok: false, log: '/l/p.log');

  blocTest<BackendsBloc, BackendsState>(
    'keeps the results of a check, case by case',
    build: () {
      when(() => repository.check('prueba', 'dxvk'))
          .thenAnswer((_) async => right(const [result]));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.check('prueba', 'dxvk')),
    expect: () => const [
      BackendsState(checking: 'dxvk'),
      BackendsState(
        results: {
          'dxvk': [result],
        },
      ),
    ],
  );
}
