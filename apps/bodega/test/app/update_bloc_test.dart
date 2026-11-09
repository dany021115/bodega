import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:bodega/domain/repository/update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockUpdates extends Mock implements UpdateRepository {}

void main() {
  late _MockUpdates repository;
  const update = AppUpdate(
    version: '1.4.0',
    current: '1.3.0',
    page: 'https://x/page',
    installer: 'https://x/Bodega.dmg',
    sums: 'https://x/SHA256SUMS-macos',
  );

  setUpAll(() {
    registerFallbackValue(update);
    registerFallbackValue((int _, int? _) {});
  });

  setUp(() {
    repository = _MockUpdates();
    when(() => repository.check()).thenAnswer((_) async => right(update));
    when(() => repository.skip(any())).thenAnswer((_) async => right(unit));
  });

  blocTest<UpdateBloc, UpdateState>(
    'a newer version is announced; no news, nothing (A1)',
    build: () => UpdateBloc(repository),
    act: (bloc) => bloc.add(const UpdateEvent.check()),
    expect: () => const [UpdateState(update: update)],
  );

  blocTest<UpdateBloc, UpdateState>(
    '"Ahora no" remembers the version and hides it',
    build: () => UpdateBloc(repository),
    seed: () => const UpdateState(update: update),
    act: (bloc) => bloc.add(const UpdateEvent.skip()),
    expect: () => const [UpdateState()],
    verify: (_) => verify(() => repository.skip('1.4.0')).called(1),
  );

  blocTest<UpdateBloc, UpdateState>(
    'install downloads, installs and closes the app (A4)',
    build: () {
      when(() => repository.download(any(), any())).thenAnswer((call) async {
        (call.positionalArguments[1] as void Function(int, int?))(
          5 << 20,
          10 << 20,
        );
        return right('/tmp/Bodega.dmg');
      });
      when(() => repository.install('/tmp/Bodega.dmg'))
          .thenAnswer((_) async => right(unit));
      return UpdateBloc(repository);
    },
    seed: () => const UpdateState(update: update),
    act: (bloc) => bloc.add(const UpdateEvent.install()),
    expect: () => const [
      UpdateState(update: update, phase: UpdatePhase.downloading),
      UpdateState(
        update: update,
        phase: UpdatePhase.downloading,
        received: 5 << 20,
        total: 10 << 20,
      ),
      UpdateState(
        update: update,
        phase: UpdatePhase.installing,
        received: 5 << 20,
        total: 10 << 20,
      ),
    ],
    verify: (_) => verify(() => repository.quit()).called(1),
  );

  blocTest<UpdateBloc, UpdateState>(
    'a failed or cancelled download leaves it as it was (A3)',
    build: () {
      var calls = 0;
      when(() => repository.download(any(), any())).thenAnswer(
        (_) async => calls++ == 0
            ? left(const AppError.engine('no coincide con su SHA256'))
            : right(null),
      );
      return UpdateBloc(repository);
    },
    seed: () => const UpdateState(update: update),
    act: (bloc) async {
      bloc.add(const UpdateEvent.install());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateEvent.install());
    },
    verify: (bloc) {
      expect(bloc.state.phase, UpdatePhase.available);
      expect(bloc.state.error, isNull);
      verifyNever(() => repository.install(any()));
      verifyNever(() => repository.quit());
    },
  );
}
