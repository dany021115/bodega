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

  const gptk = GptkRelease(version: '3.0', tested: true, url: 'https://x');

  setUpAll(() {
    registerFallbackValue((int _, int? _) {});
    registerFallbackValue((String _) {});
    registerFallbackValue(() => false);
  });

  setUp(() {
    repository = _MockBackends();
    when(() => repository.gptkReleases).thenReturn(const []);
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
    'installs D3DMetal from the dmg in Downloads, then checks it (I2, I3)',
    build: () {
      when(() => repository.findGptkDmg('3.0'))
          .thenAnswer((_) async => right('/d/G.dmg'));
      when(
        () => repository.installD3DMetalDmg(
          '/d/G.dmg',
          onStep: any(named: 'onStep'),
          cancelled: any(named: 'cancelled'),
        ),
      ).thenAnswer((call) async {
        (call.namedArguments[#onStep] as void Function(String))('Importando');
        return right('3.0');
      });
      when(() => repository.check('prueba', 'd3dmetal'))
          .thenAnswer((_) async => right(const []));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.installGptk(gptk)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.busy, isNull);
      expect(bloc.state.gptkStep, isNull);
      expect(bloc.state.gptkInstalled, '3.0');
      expect(bloc.state.error, isNull);
      verify(() => repository.check('prueba', 'd3dmetal')).called(1);
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'without the dmg it waits for it in Downloads, until cancelled (I2)',
    build: () {
      when(() => repository.findGptkDmg('3.0'))
          .thenAnswer((_) async => right(null));
      return BackendsBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const BackendsEvent.installGptk(gptk));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.gptkWaiting, '3.0');
      bloc.add(const BackendsEvent.cancelGptk());
    },
    verify: (bloc) {
      expect(bloc.state.gptkWaiting, isNull);
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
