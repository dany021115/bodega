import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_block.dart';
import 'package:bodega/domain/entities/runtime_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
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
    registerFallbackValue((Mach9Step _) {});
    registerFallbackValue(RuntimeKind.mach9);
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
    when(() => repository.readyBottles(runtime: RuntimeKind.mach9))
        .thenAnswer((_) async => right(const ['native']));
    when(() => repository.runtimes()).thenAnswer((_) async => right(const []));
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
        nativeBottles: ['native'],
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

  blocTest<BackendsBloc, BackendsState>(
    'PA4 the engine check probes mtld3d, dxmt and wine in turn',
    build: () {
      for (final name in mach9Checks) {
        when(() => repository.check('native', name))
            .thenAnswer((_) async => right(const [result]));
      }
      return BackendsBloc(repository);
    },
    act: (bloc) => bloc.add(const BackendsEvent.checkEngine('native')),
    verify: (bloc) {
      expect(bloc.state.checking, isNull);
      expect(bloc.state.results.keys, [
        'mach9:mtld3d',
        'mach9:dxmt',
        'mach9:wine',
      ]);
      for (final name in mach9Checks) {
        verify(() => repository.check('native', name)).called(1);
      }
    },
  );

  blocTest<BackendsBloc, BackendsState>(
    'PA4 the ready Native engine bottles load apart',
    build: () => BackendsBloc(repository),
    act: (bloc) => bloc.add(const BackendsEvent.load()),
    verify: (bloc) {
      expect(bloc.state.bottles, ['sample']);
      expect(bloc.state.nativeBottles, ['native']);
    },
  );

  group('the native engine (MA5)', () {
    const bodega = RuntimeInfo(kind: RuntimeKind.bodega, installed: true);
    const notInstalled = RuntimeInfo(
      kind: RuntimeKind.mach9,
      installed: false,
      latestVersion: '0.4.0',
    );
    const installedMach9 = RuntimeInfo(
      kind: RuntimeKind.mach9,
      installed: true,
      version: '0.4.0',
      latestVersion: '0.4.0',
    );

    test('MA1 and MA2 a newer Mach9 is told once per version', () async {
      const outdated = RuntimeInfo(
        kind: RuntimeKind.mach9,
        installed: true,
        version: '0.4.0',
        latestVersion: '0.5.0',
      );
      when(() => repository.checkMach9()).thenAnswer((_) async => right(unit));
      when(() => repository.runtimes())
          .thenAnswer((_) async => right(const [bodega, outdated]));
      final bloc = BackendsBloc(repository)
        ..add(const BackendsEvent.checkMach9())
        ..add(const BackendsEvent.checkMach9());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.mach9Notice, '0.5.0');
      expect(bloc.state.noticeId, 1);
      expect(bloc.state.runtimes.last.updateAvailable, isTrue);
      verify(() => repository.checkMach9()).called(2);
      await bloc.close();
    });

    test('MA1 offline says nothing', () async {
      when(() => repository.checkMach9()).thenAnswer(
        (_) async => left(const AppError.network(detail: 'offline')),
      );
      final bloc = BackendsBloc(repository)
        ..add(const BackendsEvent.checkMach9());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.mach9Notice, isNull);
      expect(bloc.state.noticeId, 0);
      expect(bloc.state.error, isNull);
      await bloc.close();
    });

    /// Installing reports [steps] and progress, then ends with [result]; on
    /// success the runtime lists as installed.
    void installs(
      List<Mach9Step> steps,
      Either<AppError, bool> result, {
      String? file,
    }) {
      when(() => repository.runtimes())
          .thenAnswer((_) async => right(const [bodega, notInstalled]));
      when(
        () => repository.installRuntime(
          RuntimeKind.mach9,
          file: file,
          deleteFile: any(named: 'deleteFile'),
          onProgress: any(named: 'onProgress'),
          onStep: any(named: 'onStep'),
        ),
      ).thenAnswer((call) async {
        final onStep = call.namedArguments[#onStep] as void Function(Mach9Step);
        final onProgress =
            call.namedArguments[#onProgress] as void Function(int, int?);
        for (final step in steps) {
          onStep(step);
          if (step == Mach9Step.downloading) onProgress(50, 100);
        }
        if (result case Right(value: true)) {
          when(() => repository.runtimes())
              .thenAnswer((_) async => right(const [bodega, installedMach9]));
        }
        return result;
      });
    }

    Matcher runtimeState({Mach9Step? step, String? busy}) =>
        isA<BackendsState>()
            .having((s) => s.runtimeStep, 'runtimeStep', step)
            .having((s) => s.busy, 'busy', busy);

    blocTest<BackendsBloc, BackendsState>(
      'loads the runtimes with the backends',
      build: () {
        when(() => repository.runtimes())
            .thenAnswer((_) async => right(const [bodega, notInstalled]));
        return BackendsBloc(repository);
      },
      act: (bloc) => bloc.add(const BackendsEvent.load()),
      verify: (bloc) {
        expect(bloc.state.runtimes, const [bodega, notInstalled]);
        expect(bloc.state.mach9, notInstalled);
        expect(bloc.state.nativeUsable, isFalse);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'downloaded: marks mach9 busy, shows each step and the download, and '
      'ends installed',
      build: () {
        installs(const [
          Mach9Step.downloadingMono,
          Mach9Step.downloading,
          Mach9Step.mounting,
          Mach9Step.checkingSignature,
          Mach9Step.copying,
          Mach9Step.checking,
          Mach9Step.switching,
        ], right(true));
        return BackendsBloc(repository);
      },
      act: (bloc) =>
          bloc.add(const BackendsEvent.installRuntime(RuntimeKind.mach9)),
      expect: () => containsAllInOrder([
        runtimeState(busy: 'mach9'),
        runtimeState(step: Mach9Step.downloadingMono, busy: 'mach9'),
        isA<BackendsState>()
            .having((s) => s.runtimeStep, 'step', Mach9Step.downloading)
            .having((s) => s.isDownloading, 'isDownloading', true),
        isA<BackendsState>().having((s) => s.fraction, 'fraction', 0.5),
        runtimeState(step: Mach9Step.copying, busy: 'mach9'),
        runtimeState(step: Mach9Step.switching, busy: 'mach9'),
      ]),
      verify: (bloc) {
        expect(bloc.state.busy, isNull);
        expect(bloc.state.runtimeStep, isNull);
        expect(bloc.state.error, isNull);
        expect(bloc.state.nativeUsable, isTrue);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'from the Mach9 app found: copies it, with no download',
      build: () {
        installs(const [
          Mach9Step.checkingSignature,
          Mach9Step.copying,
          Mach9Step.checking,
          Mach9Step.switching,
        ], right(true));
        return BackendsBloc(repository);
      },
      act: (bloc) =>
          bloc.add(const BackendsEvent.installRuntime(RuntimeKind.mach9)),
      verify: (bloc) {
        expect(bloc.state.nativeUsable, isTrue);
        expect(bloc.state.received, 0);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'from a file with the box unticked: kept',
      build: () {
        installs(
          const [Mach9Step.mounting, Mach9Step.copying],
          right(true),
          file: '/d/Mach9.dmg',
        );
        return BackendsBloc(repository);
      },
      act: (bloc) => bloc
        ..add(const BackendsEvent.setDeleteDmg(false))
        ..add(
          const BackendsEvent.installRuntime(
            RuntimeKind.mach9,
            file: '/d/Mach9.dmg',
          ),
        ),
      verify: (bloc) {
        expect(bloc.state.deleteDmg, isFalse);
        verify(
          () => repository.installRuntime(
            RuntimeKind.mach9,
            file: '/d/Mach9.dmg',
            onProgress: any(named: 'onProgress'),
            onStep: any(named: 'onStep'),
          ),
        ).called(1);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'from a file: passes it on, to delete once installed (by default)',
      build: () {
        installs(
          const [Mach9Step.mounting, Mach9Step.copying],
          right(true),
          file: '/d/Mach9.dmg',
        );
        return BackendsBloc(repository);
      },
      act: (bloc) => bloc.add(
        const BackendsEvent.installRuntime(
          RuntimeKind.mach9,
          file: '/d/Mach9.dmg',
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.installRuntime(
            RuntimeKind.mach9,
            file: '/d/Mach9.dmg',
            deleteFile: true,
            onProgress: any(named: 'onProgress'),
            onStep: any(named: 'onStep'),
          ),
        ).called(1);
        expect(bloc.state.nativeUsable, isTrue);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'cancel stops the download, and nothing is installed',
      build: () {
        when(() => repository.runtimes())
            .thenAnswer((_) async => right(const [bodega, notInstalled]));
        when(
          () => repository.installRuntime(
            RuntimeKind.mach9,
            onProgress: any(named: 'onProgress'),
            onStep: any(named: 'onStep'),
          ),
        ).thenAnswer((call) async {
          (call.namedArguments[#onStep] as void Function(Mach9Step))(
            Mach9Step.downloading,
          );
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return right(false);
        });
        return BackendsBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const BackendsEvent.installRuntime(RuntimeKind.mach9));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const BackendsEvent.cancel());
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        verify(() => repository.cancelDownload()).called(1);
        expect(bloc.state.busy, isNull);
        expect(bloc.state.error, isNull);
        expect(bloc.state.nativeUsable, isFalse);
      },
    );

    blocTest<BackendsBloc, BackendsState>(
      'a failure is shown, and the engine stays not installed',
      build: () {
        installs(const [
          Mach9Step.checkingSignature,
        ], left(const AppError.runtimeNotTrusted('/Applications/Mach9.app')));
        return BackendsBloc(repository);
      },
      act: (bloc) =>
          bloc.add(const BackendsEvent.installRuntime(RuntimeKind.mach9)),
      verify: (bloc) {
        expect(
          bloc.state.error,
          const AppError.runtimeNotTrusted('/Applications/Mach9.app'),
        );
        expect(bloc.state.busy, isNull);
        expect(bloc.state.runtimeStep, isNull);
        expect(bloc.state.nativeUsable, isFalse);
      },
    );

    test('a Mac that cannot run it at all shows no card; a too-old macOS '
        'does', () {
      for (final block in RuntimeBlock.values) {
        final state = BackendsState(
          runtimes: [
            bodega,
            RuntimeInfo(
              kind: RuntimeKind.mach9,
              installed: false,
              blocked: block,
            ),
          ],
        );
        expect(
          state.mach9 != null,
          block == RuntimeBlock.macosTooOld,
          reason: '$block',
        );
        expect(state.nativeUsable, isFalse);
      }
    });
  });
}
