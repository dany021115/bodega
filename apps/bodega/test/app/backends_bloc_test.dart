import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
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
    registerFallbackValue((GptkStep _) {});
    registerFallbackValue(() => false);
  });

  /// The dmg is in Downloads, and installing it reports [steps], then ends
  /// with [result].
  void importsDmg(List<GptkStep> steps, Either<AppError, String?> result) {
    when(() => repository.findGptkDmg('3.0'))
        .thenAnswer((_) async => right('/d/G.dmg'));
    when(
      () => repository.installD3DMetalDmg(
        '/d/G.dmg',
        onStep: any(named: 'onStep'),
        cancelled: any(named: 'cancelled'),
      ),
    ).thenAnswer((call) async {
      steps.forEach(call.namedArguments[#onStep] as void Function(GptkStep));
      return result;
    });
    when(() => repository.check('sample', 'd3dmetal'))
        .thenAnswer((_) async => right(const []));
  }

  setUp(() {
    repository = _MockBackends();
    when(() => repository.gptkReleases).thenReturn(const []);
    when(() => repository.list())
        .thenAnswer((_) async => right(const [missing]));
    when(() => repository.readyBottles())
        .thenAnswer((_) async => right(const ['sample']));
  });

  blocTest<BackendsBloc, BackendsState>(
    'loads the backends and the bottles',
    build: () => BackendsBloc(repository),
    act: (bloc) => bloc.add(const BackendsEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.backends, const [missing]);
      expect(bloc.state.bottles, ['sample']);
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
        bottles: ['sample'],
        received: 50,
        total: 100,
      ),
    ],
  );

  blocTest<BackendsBloc, BackendsState>(
    'a wrong SHA is shown, and the backend stays not installed',
    build: () {
      when(() => repository.download('dxvk', any())).thenAnswer(
        (_) async =>
            left(const AppError.checksumMismatch('/h/downloads/dxvk.tar.gz')),
      );
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.download('dxvk')),
    verify: (bloc) {
      expect(
        bloc.state.error,
        const AppError.checksumMismatch('/h/downloads/dxvk.tar.gz'),
      );
      expect(bloc.state.busy, isNull);
      expect(bloc.state.backends, const [missing]);
    },
  );

  /// What a state says of the D3DMetal install: its step and its result.
  Matcher gptkState({GptkStep? step, ({String? version})? installed}) =>
      isA<BackendsState>()
          .having((s) => s.gptkStep, 'gptkStep', step)
          .having((s) => s.gptkInstalled, 'gptkInstalled', installed);

  blocTest<BackendsBloc, BackendsState>(
    'installs D3DMetal from the dmg in Downloads, then checks it (I2, I3)',
    build: () {
      importsDmg(const [GptkStep.opening, GptkStep.importing], right('3.0'));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.installGptk(gptk)),
    wait: const Duration(milliseconds: 50),
    // Each step as a code, which the card words (L6).
    expect: () => containsAllInOrder([
      gptkState(step: GptkStep.opening),
      gptkState(step: GptkStep.importing),
      gptkState(installed: (version: '3.0')),
    ]),
    verify: (bloc) {
      expect(bloc.state.busy, isNull);
      expect(bloc.state.gptkStep, isNull);
      expect(bloc.state.gptkInstalled, (version: '3.0'));
      expect(bloc.state.error, isNull);
      verify(() => repository.check('sample', 'd3dmetal')).called(1);
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'a version it cannot read still counts as installed (E3)',
    build: () {
      importsDmg(const [GptkStep.importing], right(null));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.installGptk(gptk)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.gptkInstalled, (version: null));
      expect(bloc.state.error, isNull);
      verify(() => repository.check('sample', 'd3dmetal')).called(1);
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'a failed install says nothing was installed, and checks nothing',
    build: () {
      importsDmg(const [
        GptkStep.acceptLicense,
      ], left(const AppError.licenseNotAccepted()));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.installGptk(gptk)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.gptkStep, isNull);
      expect(bloc.state.gptkInstalled, isNull);
      expect(bloc.state.error, const AppError.licenseNotAccepted());
      verifyNever(() => repository.check(any(), any()));
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
      when(() => repository.check('sample', 'dxvk'))
          .thenAnswer((_) async => right(const [result]));
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.check('sample', 'dxvk')),
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
