import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/domain/repository/dependency_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements DependencyRepository {}

const _vc2008 = NeedItem.runtime('vcrun2008', Arch.x86);
const _vc2022 = NeedItem.runtime('vcrun2022', Arch.x64);
const _nfs = NeedItem.settings('need-for-speed-most-wanted-2012');
const _data = BottleDependencies();

AppNeeds _needs({required bool recommended}) => AppNeeds(
  key: 'k',
  title: 'Blur',
  dependencies: [
    DependencyNeed(
      dependency: const Dependency(
        id: 'vcrun2008',
        name: 'Visual C++ 2008',
        arch: Arch.x86,
        bytes: 4483040,
        installed: false,
      ),
      need: recommended ? Need.recommended : Need.optional,
      reason: recommended ? NeedReason.knownFix : NeedReason.imported,
    ),
  ],
);

void main() {
  late _MockRepository repository;

  setUpAll(() {
    registerFallbackValue((int _, int? _) {});
    registerFallbackValue(Arch.x86);
  });

  setUp(() {
    repository = _MockRepository();
    when(() => repository.bottle(any())).thenAnswer((_) async => right(_data));
    when(() => repository.download(any(), any(), any()))
        .thenAnswer((call) async {
          final onProgress =
              call.positionalArguments[2] as void Function(int, int?);
          onProgress(50, 100);
          onProgress(50, 100);
          onProgress(100, 100);
          return right('/h/downloads/${call.positionalArguments[0]}.exe');
        });
    when(() => repository.install(any(), any(), any(), any()))
        .thenAnswer((_) async => right(unit));
    when(() => repository.applySettings(any(), any()))
        .thenAnswer((_) async => right(unit));
  });

  DependenciesBloc build() => DependenciesBloc(repository);

  blocTest<DependenciesBloc, DependenciesState>(
    'does the queue one at a time, runtimes before settings, then reloads',
    build: build,
    act: (bloc) => bloc.add(
      const DependenciesEvent.install('b', [_nfs, _vc2008, _vc2022]),
    ),
    expect: () => [
      const DependenciesState(bottle: 'b'),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2008,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2008,
        received: 50,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2008,
        received: 100,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.installing,
        item: _vc2008,
        received: 100,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2022,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2022,
        received: 50,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2022,
        received: 100,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.installing,
        item: _vc2022,
        received: 100,
        total: 100,
      ),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.applying,
        item: _nfs,
        received: 100,
        total: 100,
      ),
      const DependenciesState(bottle: 'b'),
      const DependenciesState(bottle: 'b', bottles: {'b': _data}),
    ],
    verify: (_) {
      verifyInOrder([
        () => repository.install(
          'b',
          'vcrun2008',
          Arch.x86,
          '/h/downloads/vcrun2008.exe',
        ),
        () => repository.install(
          'b',
          'vcrun2022',
          Arch.x64,
          '/h/downloads/vcrun2022.exe',
        ),
        () => repository.applySettings('b', 'need-for-speed-most-wanted-2012'),
      ]);
    },
  );

  blocTest<DependenciesBloc, DependenciesState>(
    'a failure stops the queue and keeps its item for a file of the user',
    build: build,
    setUp: () =>
        when(() => repository.install(any(), 'vcrun2008', any(), any()))
            .thenAnswer((_) async => left(const AppError.network())),
    act: (bloc) =>
        bloc.add(const DependenciesEvent.install('b', [_vc2008, _vc2022])),
    skip: 5,
    expect: () => [
      const DependenciesState(
        bottle: 'b',
        received: 100,
        total: 100,
        error: AppError.network(),
        failed: _vc2008,
        failedBottle: 'b',
      ),
      const DependenciesState(
        bottle: 'b',
        received: 100,
        total: 100,
        error: AppError.network(),
        failed: _vc2008,
        failedBottle: 'b',
        bottles: {'b': _data},
      ),
    ],
    verify: (_) =>
        verifyNever(() => repository.install(any(), 'vcrun2022', any(), any())),
  );

  blocTest<DependenciesBloc, DependenciesState>(
    "a file of the user's skips the download",
    build: build,
    act: (bloc) => bloc.add(
      const DependenciesEvent.installFile(
        'b',
        RuntimeItem('vcrun2008', Arch.x86),
        '/Users/me/vcredist_x86.exe',
      ),
    ),
    expect: () => [
      const DependenciesState(bottle: 'b'),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.installing,
        item: _vc2008,
      ),
      const DependenciesState(bottle: 'b'),
      const DependenciesState(bottle: 'b', bottles: {'b': _data}),
    ],
    verify: (_) {
      verifyNever(() => repository.download(any(), any(), any()));
      verify(
        () => repository.install(
          'b',
          'vcrun2008',
          Arch.x86,
          '/Users/me/vcredist_x86.exe',
        ),
      ).called(1);
    },
  );

  test('a second job waits for none: it is refused while one runs', () async {
    final gate = Completer<Either<AppError, Unit>>();
    when(() => repository.install(any(), any(), any(), any()))
        .thenAnswer((_) => gate.future);
    final bloc = build()..add(const DependenciesEvent.install('b', [_vc2008]));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.phase, DependencyPhase.installing);
    bloc.add(const DependenciesEvent.install('b', [_vc2022]));
    await Future<void>.delayed(Duration.zero);
    gate.complete(right(unit));
    await bloc.close();
    verifyNever(() => repository.install(any(), 'vcrun2022', any(), any()));
  });

  blocTest<DependenciesBloc, DependenciesState>(
    'a cancelled download ends the job with no error',
    build: build,
    setUp: () =>
        when(() => repository.download(any(), any(), any()))
            .thenAnswer((_) async => right(null)),
    act: (bloc) => bloc.add(const DependenciesEvent.install('b', [_vc2008])),
    expect: () => [
      const DependenciesState(bottle: 'b'),
      const DependenciesState(
        bottle: 'b',
        phase: DependencyPhase.downloading,
        item: _vc2008,
      ),
      const DependenciesState(bottle: 'b'),
      const DependenciesState(bottle: 'b', bottles: {'b': _data}),
    ],
    verify: (_) =>
        verifyNever(() => repository.install(any(), any(), any(), any())),
  );

  blocTest<DependenciesBloc, DependenciesState>(
    'cancel reaches the download only while one runs',
    build: build,
    seed: () => const DependenciesState(phase: DependencyPhase.downloading),
    act: (bloc) => bloc.add(const DependenciesEvent.cancel()),
    verify: (_) => verify(() => repository.cancelDownload()).called(1),
  );

  blocTest<DependenciesBloc, DependenciesState>(
    'an app with something recommended gets its dialog; one without, none',
    build: build,
    setUp: () {
      when(() => repository.needs('b', 'yes'))
          .thenAnswer((_) async => right(_needs(recommended: true)));
      when(() => repository.needs('b', 'no'))
          .thenAnswer((_) async => right(_needs(recommended: false)));
    },
    act: (bloc) => bloc
      ..add(const DependenciesEvent.offer('b', 'no'))
      ..add(const DependenciesEvent.offer('b', 'yes'))
      ..add(const DependenciesEvent.offerShown()),
    expect: () => [
      DependenciesState(offer: _needs(recommended: true), offerBottle: 'b'),
      const DependenciesState(),
    ],
  );

  blocTest<DependenciesBloc, DependenciesState>(
    'a catalog install proposes for the key of its app',
    build: build,
    setUp: () {
      when(
        () => repository.catalogKey('steam'),
      ).thenAnswer((_) async => right('program files (x86)/steam/steam.exe'));
      when(() => repository.needs('b', 'program files (x86)/steam/steam.exe'))
          .thenAnswer((_) async => right(_needs(recommended: true)));
    },
    act: (bloc) =>
        bloc.add(const DependenciesEvent.offerCatalogApp('b', 'steam')),
    expect: () => [
      DependenciesState(offer: _needs(recommended: true), offerBottle: 'b'),
    ],
  );
}
