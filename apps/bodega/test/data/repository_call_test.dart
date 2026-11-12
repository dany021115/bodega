import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('repositoryCall (E10)', () {
    Future<Either<AppError, Object?>> throwing(Object error) =>
        repositoryCall<Object?>(() => throw error);

    test('gives what the call returns', () async {
      expect(await repositoryCall(() => 42), right<AppError, int>(42));
      expect(
        await repositoryCall(() async => 'done'),
        right<AppError, String>('done'),
      );
    });

    test('maps an engine failure to its code, with its English message as '
        'detail', () async {
      expect(
        await throwing(const engine.BottleOpen('steam')),
        left<AppError, Object?>(
          const AppError.bottleOpen(
            'steam',
            detail: 'the bottle steam is open: bodega stop steam',
          ),
        ),
      );
    });

    test('a Switch failure gives the code of its name, with its message as '
        'detail (SA1)', () async {
      const other = '/Applications/Other.app';
      const game = '/g/a.nsp';
      const extensions = ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'];
      final cases = <(engine.EngineFailure, AppError)>[
        (
          const engine.NoEmulator('Ryubing', 'Ryujinx.app'),
          const AppError.noEmulator('Ryubing', 'Ryujinx.app'),
        ),
        (
          const engine.NotAnEmulator(other, 'Ryubing'),
          const AppError.notAnEmulator(other, 'Ryubing'),
        ),
        (
          const engine.SwitchGameNotFound(game),
          const AppError.switchGameNotFound(game),
        ),
        (
          const engine.SwitchGameRunning(game),
          const AppError.switchGameRunning(game),
        ),
        // Any app bundle can be picked, so one that is not a native app gets
        // here; the extensions stay in the message.
        (
          const engine.NotASwitchGame(other, extensions),
          const AppError.notASwitchGame(other),
        ),
      ];
      for (final (failure, code) in cases) {
        expect(
          await throwing(failure),
          left<AppError, Object?>(code.copyWith(detail: failure.message)),
          reason: '$failure',
        );
      }
      expect(
        (await throwing(const engine.NotASwitchGame(other, extensions)))
            .getLeft()
            .toNullable()
            ?.detail,
        contains('.xci .nsp .pfs0 .nca .nro .nso'),
      );
    });

    test('a game that is gone and Switch where it is not available keep the '
        'codes Wine has (SA1)', () async {
      const gone = '/g/gone.nsp';
      const missing = engine.MissingFile(gone);
      expect(
        await throwing(missing),
        left<AppError, Object?>(
          AppError.badPath(
            const PathProblem.missing(gone),
            detail: missing.message,
          ),
        ),
      );
      const linux = engine.NotAvailable('switch', 'Linux');
      expect(
        await throwing(linux),
        left<AppError, Object?>(AppError.unknown(detail: linux.message)),
      );
    });

    test('a failure the app never triggers is unknown, with its message as '
        'detail', () async {
      const url = 'http://example.com/setup.exe';
      expect(
        await throwing(const engine.NotHttps(url)),
        left<AppError, Object?>(
          const AppError.unknown(detail: 'the URL is not https: $url'),
        ),
      );
    });

    test('passes an AppError as it is', () async {
      expect(
        await throwing(const AppError.downloadCut(10, 20)),
        left<AppError, Object?>(const AppError.downloadCut(10, 20)),
      );
    });

    test('a DioException is network, with its text as detail', () async {
      final dio = DioException(
        requestOptions: RequestOptions(path: 'https://example.com'),
        type: DioExceptionType.connectionError,
        message: 'connection refused',
      );
      expect(
        await throwing(dio),
        left<AppError, Object?>(AppError.network(detail: '$dio')),
      );
      expect('$dio', contains('connection refused'));
    });

    test('anything else is unknown, with its text as detail', () async {
      expect(
        await throwing(StateError('x')),
        left<AppError, Object?>(const AppError.unknown(detail: 'Bad state: x')),
      );
    });
  });

  group('appErrorOf', () {
    const log = '/l/a.log';

    /// One of each engine failure, and the code it maps to before its detail.
    final cases = <(engine.EngineFailure, AppError)>[
      (
        const engine.BottleNotFound('nope'),
        const AppError.bottleNotFound('nope'),
      ),
      (
        const engine.BottleExists('steam'),
        const AppError.bottleExists('steam'),
      ),
      (
        const engine.BottleNotReady('steam'),
        const AppError.bottleNotReady('steam'),
      ),
      (const engine.BottleOpen('steam'), const AppError.bottleOpen('steam')),
      for (final timedOut in [true, false])
        (
          engine.BottleSetupFailed(log, timedOut),
          AppError.bottleSetupFailed(log, timedOut),
        ),
      (const engine.BadBottleName('-x'), const AppError.badBottleName('-x')),
      (
        const engine.BadWindowsPath((part: 'odd:', path: '/g/odd:/a.exe')),
        const AppError.badPath(
          PathProblem.windowsName(part: 'odd:', path: '/g/odd:/a.exe'),
        ),
      ),
      // Each problem maps to the domain's of the same name.
      for (final problem in engine.UserNameProblem.values)
        (
          engine.BadUserName('Dany', problem),
          AppError.badUserName(
            'Dany',
            UserNameProblem.values.byName(problem.name),
          ),
        ),
      (
        const engine.AppNotFound('steam'),
        const AppError.appNotFound('steam', null),
      ),
      (
        const engine.AppNotFound('steam', 'blur.exe'),
        const AppError.appNotFound('steam', 'blur.exe'),
      ),
      (
        const engine.AppAlreadyAdded('steam'),
        const AppError.appAlreadyAdded('steam'),
      ),
      (
        const engine.MissingFile('/g/a.exe'),
        const AppError.badPath(PathProblem.missing('/g/a.exe')),
      ),
      (
        const engine.ChecksumMissing('/d/engine-11.0.tar.gz.sha256'),
        const AppError.badPath(
          PathProblem.missing('/d/engine-11.0.tar.gz.sha256'),
        ),
      ),
      (
        const engine.ChecksumMismatch('/d/dxvk.tar.gz'),
        const AppError.checksumMismatch('/d/dxvk.tar.gz'),
      ),
      (
        const engine.IncompleteArchive('engine-11.0', 'engine/bin/wine'),
        const AppError.incompleteArchive('engine-11.0', 'engine/bin/wine'),
      ),
      (
        const engine.CorruptData('/b/steam/apps.json', 'FormatException: x'),
        const AppError.corruptData('/b/steam/apps.json'),
      ),
      (const engine.NoRuntime(), const AppError.noRuntime()),
      (
        const engine.AlreadyInstalled('/h/backends/dxvk'),
        const AppError.alreadyInstalled('/h/backends/dxvk'),
      ),
      (
        const engine.BackendNotInstalled('dxvk'),
        const AppError.backendNotInstalled('dxvk'),
      ),
      (
        const engine.NoD3DMetal('/v/GPTK', 'redist/lib'),
        const AppError.noD3DMetal('/v/GPTK', 'redist/lib'),
      ),
      (const engine.CrossOverCopy(), const AppError.crossOverCopy()),
      (
        const engine.MountFailed('/d/GPTK.dmg', 'hdiutil: attach failed'),
        const AppError.mountFailed('/d/GPTK.dmg'),
      ),
      (const engine.Cancelled(), const AppError.cancelled()),
      (const engine.LicenseNotAccepted(), const AppError.licenseNotAccepted()),
      // Each tool maps to the domain's of the same name.
      for (final tool in engine.WineTool.values)
        (
          engine.WineToolFailed(tool, 53, log),
          AppError.wineToolFailed(WineTool.values.byName(tool.name), 53, log),
        ),
      (
        const engine.InstallerNoExe('Steam/steam.exe', log),
        const AppError.installerNoExe('Steam/steam.exe', log),
      ),
      (
        const engine.ProcessFailed('/usr/bin/tar -xzf a.tar.gz', 2, 'bad'),
        const AppError.processFailed('/usr/bin/tar -xzf a.tar.gz', 2),
      ),
      (
        const engine.ProcessFailed('wine --version', null, ''),
        const AppError.processFailed('wine --version', null),
      ),
      // Switch games (switch-support SA1).
      (
        const engine.NoEmulator('Ryubing', 'Ryujinx.app'),
        const AppError.noEmulator('Ryubing', 'Ryujinx.app'),
      ),
      (
        const engine.NotAnEmulator('/Applications/Other.app', 'Ryubing'),
        const AppError.notAnEmulator('/Applications/Other.app', 'Ryubing'),
      ),
      (
        const engine.NotASwitchGame('/g/notes.txt', ['xci', 'nsp']),
        const AppError.notASwitchGame('/g/notes.txt'),
      ),
      (
        const engine.SwitchGameNotFound('/g/a.nsp'),
        const AppError.switchGameNotFound('/g/a.nsp'),
      ),
      (
        const engine.SwitchGameRunning('/g/a.nsp'),
        const AppError.switchGameRunning('/g/a.nsp'),
      ),
      // What the app never triggers (design §5).
      (const engine.NotAvailable('SDL', 'Linux'), const AppError.unknown()),
      (const engine.NotDownloadable('d3dmetal'), const AppError.unknown()),
      (
        const engine.BadChoice(engine.ChoiceKind.gpu, 'fast'),
        const AppError.unknown(),
      ),
      (const engine.CatalogBlocked('origin'), const AppError.unknown()),
      (
        const engine.NotHttps('http://example.com/setup.exe'),
        const AppError.unknown(),
      ),
    ];

    test('maps each failure to its code, with its message as detail', () {
      for (final (failure, code) in cases) {
        expect(
          appErrorOf(failure),
          code.copyWith(detail: failure.message),
          reason: '$failure',
        );
      }
    });

    test('the cases hold every failure of the engine', () {
      expect({
        for (final (failure, _) in cases) failure.runtimeType,
      }, hasLength(36));
    });
  });

  test('two codes with the same fields are equal, and detail reads on AppError '
      '(E9)', () {
    const error = AppError.bottleOpen('steam', detail: 'x');
    expect(error, const AppError.bottleOpen('steam', detail: 'x'));
    expect(
      error.hashCode,
      const AppError.bottleOpen('steam', detail: 'x').hashCode,
    );
    expect(error, isNot(const AppError.bottleOpen('steam', detail: 'y')));
    expect(error.detail, 'x');
  });
}
