// SwitchBloc over a mocked repository (switch-support SA9 to SA12): the load,
// the runs it follows and the notices their ends give, the list and the
// settings, and its errors.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:bodega/domain/repository/switch_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwitch extends Mock implements SwitchRepository {}

/// A call of the repository that adds games.
typedef _Adding = Future<Either<AppError, ({int added, int known})>> Function();

/// A game file, with its title and id from its name.
const _gamePath = '/g/Bodega Test [0100F00DBA5E0000][v0] (EU).nsp';
const _game = SwitchGame(
  path: _gamePath,
  title: 'Bodega Test',
  titleId: '0100F00DBA5E0000',
);

/// A game file with no id.
const _homebrew = SwitchGame(
  path: '/g/Homebrew Demo.nro',
  title: 'Homebrew Demo',
);

/// A native game: a Mac app made of a game, which plays without the emulator.
const _nativePath = '/g/Bodega Test.app';
const _native = SwitchGame(
  path: _nativePath,
  title: 'Bodega Test',
  native: true,
);

const _games = [_game, _homebrew, _native];

/// Ryubing's official download page, as the engine's table gives it.
const _page = 'https://ryujinx.app/download';

const _status = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  install: EmulatorInstall(app: '/Applications/Ryujinx.app', version: '1.3.3'),
  keys: true,
  firmware: true,
  extensions: ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'],
);

/// No emulator in the Applications folders, and none picked.
const _missing = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  keys: false,
  firmware: false,
  extensions: ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'],
);

/// The emulator picked on the page, elsewhere.
const _picked = SwitchStatus(
  emulator: 'Ryubing',
  appName: 'Ryujinx.app',
  page: _page,
  install: EmulatorInstall(
    app: '/x/Ryujinx.app',
    version: '1.3.3',
    picked: true,
  ),
  keys: false,
  firmware: false,
  extensions: ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'],
);

const _notAnEmulator = AppError.notAnEmulator(
  '/x/Other.app',
  'Ryubing',
  detail: 'DETAIL',
);

/// The log of the run each open gives.
const _log = '/l/a.log';

/// The log of a later run of the same game.
const _laterLog = '/l/b.log';

const _notFound = AppError.switchGameNotFound(_gamePath, detail: 'DETAIL');

void main() {
  late _MockSwitch repository;

  /// The end of the run in [_log], which a test gives when it wants it.
  late Completer<int?> runEnd;

  setUp(() {
    repository = _MockSwitch();
    runEnd = Completer();
    when(() => repository.status()).thenAnswer((_) async => right(_status));
    when(() => repository.games()).thenAnswer((_) async => right(_games));
    when(() => repository.running()).thenAnswer((_) async => const []);
    when(() => repository.open(any())).thenAnswer((_) async => right(_log));
    when(() => repository.waitRun(_log)).thenAnswer((_) => runEnd.future);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// A bloc that has loaded [_games], as the page leaves it.
  Future<SwitchBloc> loaded() async {
    final bloc = SwitchBloc(repository)..add(const SwitchEvent.load());
    await settle();
    return bloc;
  }

  group('the load (SA9)', () {
    test('reads the status, the games and the runs, and follows each run '
        'once', () async {
      when(() => repository.games())
          .thenAnswer((_) async => right(const [_game, _homebrew]));
      when(
        () => repository.running(),
      ).thenAnswer((_) async => const [SwitchRun(game: _gamePath, log: _log)]);
      final bloc = SwitchBloc(repository);
      expect(bloc.state.isLoading, isTrue);

      bloc.add(const SwitchEvent.load());
      await settle();
      expect(
        bloc.state,
        const SwitchState(
          isLoading: false,
          status: _status,
          games: [_game, _homebrew],
          running: {_gamePath: _log},
        ),
      );
      verify(() => repository.waitRun(_log)).called(1);

      // The run is still there: it is followed already.
      bloc.add(const SwitchEvent.load());
      await settle();
      verifyNever(() => repository.waitRun(any()));
      expect(bloc.state.running, {_gamePath: _log});
      await bloc.close();
    });

    test('keeps the runs it follows when the runs come back empty, as they '
        'do when they cannot be read', () async {
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.open(_gamePath));
      await settle();
      bloc.add(const SwitchEvent.load());
      await settle();
      expect(bloc.state.running, {_gamePath: _log});
      verify(() => repository.waitRun(_log)).called(1);
      await bloc.close();
    });

    blocTest<SwitchBloc, SwitchState>(
      'a status it cannot read stays null and says why, and the games show',
      build: () {
        when(() => repository.status()).thenAnswer(
          (_) async => left(const AppError.unknown(detail: 'DETAIL')),
        );
        when(() => repository.games())
            .thenAnswer((_) async => right(const [_game, _homebrew]));
        return SwitchBloc(repository);
      },
      act: (bloc) => bloc.add(const SwitchEvent.load()),
      expect: () => [
        const SwitchState(
          isLoading: false,
          games: [_game, _homebrew],
          error: AppError.unknown(detail: 'DETAIL'),
        ),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'a read that fails keeps what the last one gave, and says why',
      build: () {
        when(() => repository.status()).thenAnswer(
          (_) async => left(const AppError.unknown(detail: 'DETAIL')),
        );
        when(() => repository.games()).thenAnswer(
          (_) async => left(const AppError.corruptData('/h/switch/games.json')),
        );
        return SwitchBloc(repository);
      },
      seed: () =>
          const SwitchState(isLoading: false, status: _status, games: _games),
      act: (bloc) => bloc.add(const SwitchEvent.load()),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _status,
          games: _games,
          error: AppError.unknown(detail: 'DETAIL'),
        ),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'games it cannot read say why, beside the status',
      build: () {
        when(() => repository.games()).thenAnswer(
          (_) async => left(const AppError.corruptData('/h/switch/games.json')),
        );
        return SwitchBloc(repository);
      },
      act: (bloc) => bloc.add(const SwitchEvent.load()),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _status,
          error: AppError.corruptData('/h/switch/games.json'),
        ),
      ],
    );
  });

  group('running games (SA11)', () {
    test('open puts the run in running and follows it', () async {
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.open(_gamePath));
      await settle();
      expect(bloc.state.running, {_gamePath: _log});
      verify(() => repository.open(_gamePath)).called(1);
      verify(() => repository.waitRun(_log)).called(1);
      await bloc.close();
    });

    blocTest<SwitchBloc, SwitchState>(
      'two opens of a game in a row open it once, and another game opens '
      'between them',
      build: () {
        when(() => repository.open('/g/b.xci'))
            .thenAnswer((_) async => right(_laterLog));
        when(() => repository.waitRun(_laterLog))
            .thenAnswer((_) => Completer<int?>().future);
        return SwitchBloc(repository);
      },
      act: (bloc) => bloc
        ..add(const SwitchEvent.open(_gamePath))
        ..add(const SwitchEvent.open('/g/b.xci'))
        ..add(const SwitchEvent.open(_gamePath)),
      verify: (bloc) {
        verify(() => repository.open(_gamePath)).called(1);
        verify(() => repository.open('/g/b.xci')).called(1);
        expect(bloc.state.running, {_gamePath: _log, '/g/b.xci': _laterLog});
      },
    );

    // Fake time: the pause is two seconds.
    testWidgets('once the pause is over, the game opens again', (tester) async {
      when(() => repository.waitRun(_log)).thenAnswer((_) async => 0);
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.open(_gamePath));
      await tester.pump();
      bloc.add(const SwitchEvent.open(_gamePath));
      await tester.pump(const Duration(milliseconds: 1900));
      verify(() => repository.open(_gamePath)).called(1);

      await tester.pump(const Duration(milliseconds: 200));
      bloc.add(const SwitchEvent.open(_gamePath));
      await tester.pump();
      verify(() => repository.open(_gamePath)).called(1);
      // The last open's pause, so that no timer is left.
      await tester.pump(const Duration(seconds: 2));
      // Closed at once, but its future never completes under fake time:
      // awaiting it would hang the test.
      unawaited(bloc.close());
      await tester.pump();
      expect(bloc.isClosed, isTrue);
    });

    blocTest<SwitchBloc, SwitchState>(
      'a run that ends with 1 leaves running, and the notice names the game',
      build: () {
        when(() => repository.waitRun(_log)).thenAnswer((_) async => 1);
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, games: _games),
      act: (bloc) => bloc.add(const SwitchEvent.open(_gamePath)),
      expect: () => [
        const SwitchState(
          isLoading: false,
          games: _games,
          running: {_gamePath: _log},
        ),
        const SwitchState(
          isLoading: false,
          games: _games,
          notice: SwitchNotice.exited('Bodega Test', 1),
          noticeId: 1,
        ),
      ],
    );

    for (final code in [0, null]) {
      blocTest<SwitchBloc, SwitchState>(
        'a run that ends with $code leaves running, with no notice',
        build: () {
          when(() => repository.waitRun(_log)).thenAnswer((_) async => code);
          return SwitchBloc(repository);
        },
        seed: () => const SwitchState(isLoading: false, games: _games),
        act: (bloc) => bloc.add(const SwitchEvent.open(_gamePath)),
        expect: () => [
          const SwitchState(
            isLoading: false,
            games: _games,
            running: {_gamePath: _log},
          ),
          const SwitchState(isLoading: false, games: _games),
        ],
      );
    }

    blocTest<SwitchBloc, SwitchState>(
      'a game the list no longer holds is named by its file',
      build: () {
        when(() => repository.waitRun(_log)).thenAnswer((_) async => 1);
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, games: _games),
      act: (bloc) => bloc.add(const SwitchEvent.open('/g/x.nsp')),
      verify: (bloc) {
        expect(bloc.state.running, isEmpty);
        expect(bloc.state.notice, const SwitchNotice.exited('x.nsp', 1));
        expect(bloc.state.noticeId, 1);
      },
    );

    // nxnative's launcher gives 0 for a quit, 70 when macOS stopped the
    // game's GPU work, and 134 for an abort (design §4).
    for (final (code, notice) in [
      (134, const SwitchNotice.exited('Bodega Test', 134)),
      (70, const SwitchNotice.exited('Bodega Test', 70)),
      (0, null),
    ]) {
      blocTest<SwitchBloc, SwitchState>(
        "a native game's run that ends with $code gives "
        "${notice ?? 'no notice'}",
        build: () {
          when(() => repository.waitRun(_log)).thenAnswer((_) async => code);
          return SwitchBloc(repository);
        },
        seed: () => const SwitchState(isLoading: false, games: _games),
        act: (bloc) => bloc.add(const SwitchEvent.open(_nativePath)),
        verify: (bloc) {
          verify(() => repository.open(_nativePath)).called(1);
          expect(bloc.state.running, isEmpty);
          expect(bloc.state.notice, notice);
          expect(bloc.state.noticeId, notice == null ? 0 : 1);
        },
      );
    }

    test('a Stop from Bodega gives no notice for the code it causes, and '
        "the game's next run is told again", () async {
      when(() => repository.stop(_gamePath))
          .thenAnswer((_) async => right(unit));
      final bloc = await loaded();
      bloc.add(const SwitchEvent.open(_gamePath));
      await settle();
      bloc.add(const SwitchEvent.stop(_gamePath));
      await settle();
      verify(() => repository.stop(_gamePath)).called(1);
      expect(bloc.state.running, {_gamePath: _log});

      runEnd.complete(143);
      await settle();
      expect(bloc.state.running, isEmpty);
      expect(bloc.state.notice, isNull);
      expect(bloc.state.noticeId, 0);

      // Run again, as from the CLI, and found by a load: it fails.
      when(() => repository.running()).thenAnswer(
        (_) async => const [SwitchRun(game: _gamePath, log: _laterLog)],
      );
      when(() => repository.waitRun(_laterLog)).thenAnswer((_) async => 1);
      bloc.add(const SwitchEvent.load());
      await settle();
      expect(bloc.state.running, isEmpty);
      expect(bloc.state.notice, const SwitchNotice.exited('Bodega Test', 1));
      expect(bloc.state.noticeId, 1);
      await bloc.close();
    });

    test('a run that ends while its Stop is still going gives no notice, '
        'and the next one is told again', () async {
      // The engine waits for the run's end before the Stop returns.
      final stopped = Completer<Either<AppError, Unit>>();
      when(() => repository.stop(_gamePath)).thenAnswer((_) => stopped.future);
      final bloc = await loaded();
      bloc
        ..add(const SwitchEvent.open(_gamePath))
        ..add(const SwitchEvent.stop(_gamePath));
      await settle();

      runEnd.complete(143);
      await settle();
      expect(bloc.state.running, isEmpty);
      expect(bloc.state.notice, isNull);
      stopped.complete(right(unit));
      await settle();

      when(() => repository.running()).thenAnswer(
        (_) async => const [SwitchRun(game: _gamePath, log: _laterLog)],
      );
      when(() => repository.waitRun(_laterLog)).thenAnswer((_) async => 1);
      bloc.add(const SwitchEvent.load());
      await settle();
      expect(bloc.state.notice, const SwitchNotice.exited('Bodega Test', 1));
      await bloc.close();
    });

    test(
      'a Stop of a game that does not run here leaves its next run told',
      () async {
        when(() => repository.stop(_gamePath))
            .thenAnswer((_) async => right(unit));
        final bloc = await loaded();
        bloc.add(const SwitchEvent.stop(_gamePath));
        await settle();

        bloc.add(const SwitchEvent.open(_gamePath));
        await settle();
        runEnd.complete(1);
        await settle();
        expect(bloc.state.notice, const SwitchNotice.exited('Bodega Test', 1));
        await bloc.close();
      },
    );

    test('after a Stop that fails, a later 1 still gives the notice', () async {
      when(() => repository.stop(_gamePath))
          .thenAnswer((_) async => left(_notFound));
      final bloc = await loaded();
      bloc.add(const SwitchEvent.open(_gamePath));
      await settle();
      bloc.add(const SwitchEvent.stop(_gamePath));
      await settle();
      expect(bloc.state.error, _notFound);

      runEnd.complete(1);
      await settle();
      expect(bloc.state.running, isEmpty);
      expect(bloc.state.notice, const SwitchNotice.exited('Bodega Test', 1));
      await bloc.close();
    });

    test('closed before its run ends, it adds no event', () async {
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.open(_gamePath));
      await settle();
      await bloc.close();

      // An event added now would throw a StateError in this test's zone.
      runEnd.complete(1);
      await settle();
      expect(bloc.state.running, {_gamePath: _log});
      expect(bloc.state.notice, isNull);
    });
  });

  group('the list and the settings (SA10)', () {
    const picked = ['/g/a.nsp', '/g/b.xci'];
    final adds = <(String, SwitchEvent, _Adding)>[
      (
        'files',
        const SwitchEvent.addFiles(picked),
        () => repository.addFiles(picked),
      ),
      (
        'a folder',
        const SwitchEvent.addFolder('/g'),
        () => repository.addFolder('/g'),
      ),
    ];

    for (final (what, event, call) in adds) {
      blocTest<SwitchBloc, SwitchState>(
        'adding $what reads the games again, and the notice tells what it '
        'found',
        build: () {
          when(call).thenAnswer((_) async => right((added: 1, known: 1)));
          when(() => repository.games())
              .thenAnswer((_) async => right(const [_game, _homebrew]));
          return SwitchBloc(repository);
        },
        seed: () => const SwitchState(
          isLoading: false,
          status: _status,
          games: [_game],
        ),
        act: (bloc) => bloc.add(event),
        expect: () => [
          const SwitchState(
            isLoading: false,
            isAdding: true,
            status: _status,
            games: [_game],
          ),
          const SwitchState(
            isLoading: false,
            status: _status,
            games: [_game, _homebrew],
            notice: SwitchNotice.added(1, 1),
            noticeId: 1,
          ),
        ],
        verify: (_) {
          verify(call).called(1);
          verify(() => repository.games()).called(1);
        },
      );

      blocTest<SwitchBloc, SwitchState>(
        'adding $what that fails says why, with no notice',
        build: () {
          when(call).thenAnswer(
            (_) async => left(const AppError.notASwitchGame('/g/notes.txt')),
          );
          return SwitchBloc(repository);
        },
        seed: () => const SwitchState(
          isLoading: false,
          status: _status,
          games: [_game],
        ),
        act: (bloc) => bloc.add(event),
        expect: () => [
          const SwitchState(
            isLoading: false,
            isAdding: true,
            status: _status,
            games: [_game],
          ),
          const SwitchState(
            isLoading: false,
            status: _status,
            games: [_game],
            error: AppError.notASwitchGame('/g/notes.txt'),
          ),
        ],
        verify: (_) => verifyNever(() => repository.games()),
      );
    }

    test('one add at a time: another one meanwhile adds nothing', () async {
      final adding = Completer<Either<AppError, ({int added, int known})>>();
      when(() => repository.addFiles(picked)).thenAnswer((_) => adding.future);
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.addFiles(picked))
        ..add(const SwitchEvent.addFolder('/g'));
      await settle();
      expect(bloc.state.isAdding, isTrue);
      verifyNever(() => repository.addFolder(any()));

      adding.complete(right((added: 2, known: 0)));
      await settle();
      expect(bloc.state.isAdding, isFalse);
      expect(bloc.state.notice, const SwitchNotice.added(2, 0));
      await bloc.close();
    });

    test('each add gives a new notice, even one equal to the last', () async {
      when(() => repository.addFolder('/g'))
          .thenAnswer((_) async => right((added: 0, known: 2)));
      final bloc = SwitchBloc(repository)
        ..add(const SwitchEvent.addFolder('/g'));
      await settle();
      expect(bloc.state.notice, const SwitchNotice.added(0, 2));
      expect(bloc.state.noticeId, 1);

      bloc.add(const SwitchEvent.addFolder('/g'));
      await settle();
      expect(bloc.state.notice, const SwitchNotice.added(0, 2));
      expect(bloc.state.noticeId, 2);
      await bloc.close();
    });

    blocTest<SwitchBloc, SwitchState>(
      'a pick that is not the emulator says why, and the status stays',
      build: () {
        when(() => repository.chooseEmulator('/x/Ryujinx.app')).thenAnswer(
          (_) async =>
              left(const AppError.notAnEmulator('/x/Ryujinx.app', 'Ryubing')),
        );
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _missing),
      act: (bloc) =>
          bloc.add(const SwitchEvent.chooseEmulator('/x/Ryujinx.app')),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _missing,
          error: AppError.notAnEmulator('/x/Ryujinx.app', 'Ryubing'),
        ),
      ],
      verify: (_) => verifyNever(() => repository.status()),
    );

    blocTest<SwitchBloc, SwitchState>(
      'a pick reads the status again',
      build: () {
        when(() => repository.chooseEmulator('/x/Ryujinx.app'))
            .thenAnswer((_) async => right(unit));
        when(() => repository.status()).thenAnswer((_) async => right(_picked));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _missing),
      act: (bloc) =>
          bloc.add(const SwitchEvent.chooseEmulator('/x/Ryujinx.app')),
      expect: () => [const SwitchState(isLoading: false, status: _picked)],
      verify: (_) => verify(() => repository.status()).called(1),
    );

    blocTest<SwitchBloc, SwitchState>(
      'keys the user picked are copied, the status is read again, and a '
      'notice counts them',
      build: () {
        when(() => repository.installKeys(['/k/prod.keys', '/k/title.keys']))
            .thenAnswer((_) async => right(['prod.keys', 'title.keys']));
        when(() => repository.status()).thenAnswer((_) async => right(_status));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _missing),
      act: (bloc) => bloc.add(
        const SwitchEvent.installKeys(['/k/prod.keys', '/k/title.keys']),
      ),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _status,
          notice: SwitchNotice.keysAdded('Ryubing', 2),
          noticeId: 1,
        ),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'keys with no .keys file say why, and the status stays',
      build: () {
        when(() => repository.installKeys(['/k/notes.txt'])).thenAnswer(
          (_) async => left(const AppError.noSwitchKeys('/k/notes.txt')),
        );
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _missing),
      act: (bloc) => bloc.add(const SwitchEvent.installKeys(['/k/notes.txt'])),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _missing,
          error: AppError.noSwitchKeys('/k/notes.txt'),
        ),
      ],
      verify: (_) => verifyNever(() => repository.status()),
    );

    blocTest<SwitchBloc, SwitchState>(
      "the firmware opens the emulator's installer and a notice says so; the "
      'status is read when Bodega comes back',
      build: () {
        when(() => repository.installFirmware('/f/fw.zip'))
            .thenAnswer((_) async => right(unit));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _picked),
      act: (bloc) => bloc.add(const SwitchEvent.installFirmware('/f/fw.zip')),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _picked,
          notice: SwitchNotice.firmwareOpened('Ryubing'),
          noticeId: 1,
        ),
      ],
      verify: (_) => verifyNever(() => repository.status()),
    );

    blocTest<SwitchBloc, SwitchState>(
      'a firmware with no emulator says why',
      build: () {
        when(() => repository.installFirmware('/f/fw.zip')).thenAnswer(
          (_) async =>
              left(const AppError.noEmulator('Ryubing', 'Ryujinx.app')),
        );
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _missing),
      act: (bloc) => bloc.add(const SwitchEvent.installFirmware('/f/fw.zip')),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _missing,
          error: AppError.noEmulator('Ryubing', 'Ryujinx.app'),
        ),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'full screen off is saved, and the status shows it',
      build: () {
        when(() => repository.setFullscreen(false))
            .thenAnswer((_) async => right(unit));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _status),
      act: (bloc) => bloc.add(const SwitchEvent.setFullscreen(false)),
      expect: () => [
        SwitchState(
          isLoading: false,
          status: _status.copyWith(fullscreen: false),
        ),
      ],
      verify: (_) {
        verify(() => repository.setFullscreen(false)).called(1);
        verifyNever(() => repository.status());
      },
    );

    blocTest<SwitchBloc, SwitchState>(
      'full screen that cannot be saved says why, and the status stays',
      build: () {
        when(() => repository.setFullscreen(false)).thenAnswer(
          (_) async =>
              left(const AppError.corruptData('/h/switch/settings.json')),
        );
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, status: _status),
      act: (bloc) => bloc.add(const SwitchEvent.setFullscreen(false)),
      expect: () => [
        const SwitchState(
          isLoading: false,
          status: _status,
          error: AppError.corruptData('/h/switch/settings.json'),
        ),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'removing reads the games again, and a run of the game goes on',
      build: () {
        when(() => repository.remove(_gamePath))
            .thenAnswer((_) async => right(unit));
        when(() => repository.games())
            .thenAnswer((_) async => right(const [_homebrew, _native]));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(
        isLoading: false,
        games: _games,
        running: {_gamePath: _log},
      ),
      act: (bloc) => bloc.add(const SwitchEvent.remove(_gamePath)),
      expect: () => [
        const SwitchState(
          isLoading: false,
          games: [_homebrew, _native],
          running: {_gamePath: _log},
        ),
      ],
      verify: (_) {
        verify(() => repository.remove(_gamePath)).called(1);
        verify(() => repository.games()).called(1);
      },
    );

    blocTest<SwitchBloc, SwitchState>(
      'a removal that fails says why, and the list stays',
      build: () {
        when(() => repository.remove(_gamePath))
            .thenAnswer((_) async => left(_notFound));
        return SwitchBloc(repository);
      },
      seed: () => const SwitchState(isLoading: false, games: _games),
      act: (bloc) => bloc.add(const SwitchEvent.remove(_gamePath)),
      expect: () => [
        const SwitchState(isLoading: false, games: _games, error: _notFound),
      ],
      verify: (_) => verifyNever(() => repository.games()),
    );
  });

  group('failures (SA12)', () {
    blocTest<SwitchBloc, SwitchState>(
      'a pick refused twice is the error, none, and the error again',
      build: () {
        when(() => repository.chooseEmulator('/x/Other.app'))
            .thenAnswer((_) async => left(_notAnEmulator));
        return SwitchBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const SwitchEvent.chooseEmulator('/x/Other.app'));
        await settle();
        bloc.add(const SwitchEvent.chooseEmulator('/x/Other.app'));
      },
      expect: () => [
        const SwitchState(error: _notAnEmulator),
        const SwitchState(),
        const SwitchState(error: _notAnEmulator),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'a launch that fails says why, and nothing runs',
      build: () {
        when(() => repository.open(_gamePath)).thenAnswer(
          (_) async => left(const AppError.switchGameRunning(_gamePath)),
        );
        return SwitchBloc(repository);
      },
      act: (bloc) => bloc.add(const SwitchEvent.open(_gamePath)),
      expect: () => [
        const SwitchState(error: AppError.switchGameRunning(_gamePath)),
      ],
      verify: (_) => verifyNever(() => repository.waitRun(any())),
    );

    blocTest<SwitchBloc, SwitchState>(
      'the same failure twice is two errors: each call clears the last',
      build: () {
        when(() => repository.stop(_gamePath))
            .thenAnswer((_) async => left(_notFound));
        return SwitchBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const SwitchEvent.stop(_gamePath));
        await settle();
        bloc.add(const SwitchEvent.stop(_gamePath));
      },
      expect: () => [
        const SwitchState(error: _notFound),
        const SwitchState(),
        const SwitchState(error: _notFound),
      ],
    );

    blocTest<SwitchBloc, SwitchState>(
      'a load clears the last error first',
      build: () => SwitchBloc(repository),
      seed: () => const SwitchState(error: _notFound),
      act: (bloc) => bloc.add(const SwitchEvent.load()),
      expect: () => [
        const SwitchState(),
        const SwitchState(isLoading: false, status: _status, games: _games),
      ],
    );
  });
}
