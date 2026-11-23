import 'dart:io';
import 'dart:isolate';

import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:bodega/domain/repository/switch_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// Switch games through the engine (switch-support design §9). What stats a
/// game, which may sit on a slow or missing disk, runs in an isolate, given
/// the host's emulators read before it: the isolate's globals start fresh.
@LazySingleton(as: SwitchRepository)
class SwitchRepositoryImpl implements SwitchRepository {
  final EngineHome _home;

  SwitchRepositoryImpl(this._home);

  /// The environment whose HOME holds the emulator's data folders and is the
  /// folder a game starts in: this process's, or a test's.
  @visibleForTesting
  Map<String, String> environment = Platform.environment;

  @override
  Future<Either<AppError, SwitchStatus>> status() => repositoryCall(() async {
    final home = _home.path;
    final (:emulator, :install, :keys, :firmware) = await engine.checkSwitch(
      home,
      environment,
    );
    return SwitchStatus(
      emulator: emulator.name,
      appName: emulator.mac?.app ?? emulator.name,
      page: emulator.page,
      install: install == null
          ? null
          : EmulatorInstall(
              app: install.app,
              version: install.version,
              picked: install.picked,
              quarantined: install.quarantined,
            ),
      keys: keys,
      firmware: firmware,
      fullscreen: engine.switchSettings(home).fullscreen,
      extensions: emulator.extensions,
    );
  });

  @override
  Future<Either<AppError, List<SwitchGame>>> games() {
    final home = _home.path;
    final emulators = engine.hostPlatform.emulators;
    return repositoryCall(() => Isolate.run(() => _gamesIn(home, emulators)));
  }

  @override
  Future<Either<AppError, ({int added, int known})>> addFiles(
    List<String> paths,
  ) {
    final home = _home.path;
    final emulators = engine.hostPlatform.emulators;
    return repositoryCall(
      () => Isolate.run(
        () => engine.addSwitchGames(home, paths, emulators: emulators),
      ),
    );
  }

  @override
  Future<Either<AppError, ({int added, int known})>> addFolder(String folder) {
    final home = _home.path;
    final emulators = engine.hostPlatform.emulators;
    return repositoryCall(
      () => Isolate.run(
        () => engine.addSwitchFolder(home, folder, emulators: emulators),
      ),
    );
  }

  @override
  Future<Either<AppError, Unit>> remove(String path) => repositoryCall(() {
    engine.removeSwitchGame(_home.path, path);
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> chooseEmulator(String app) =>
      repositoryCall(() async {
        await engine.chooseEmulator(_home.path, app);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> setFullscreen(bool value) =>
      repositoryCall(() {
        engine.setSwitchOptions(_home.path, fullscreen: value);
        return unit;
      });

  @override
  Future<Either<AppError, String>> open(String path) => repositoryCall(
    () => engine.openSwitchGame(_home.path, path, environment),
  );

  @override
  Future<Either<AppError, List<String>>> installKeys(List<String> sources) =>
      repositoryCall(
        () => engine.installSwitchKeys(_home.path, sources, environment),
      );

  @override
  Future<Either<AppError, Unit>> installFirmware(String source) =>
      repositoryCall(() async {
        await engine.installSwitchFirmware(_home.path, source, environment);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> stop(String path) => repositoryCall(() async {
    await engine.stopSwitchGame(_home.path, path);
    return unit;
  });

  // A failure in these two only means there is nothing to follow.
  @override
  Future<List<SwitchRun>> running() async => (await repositoryCall(
    () async => [
      for (final run in await engine.switchRuns(_home.path))
        SwitchRun(game: run.game, log: run.log),
    ],
  )).getOrElse((_) => const []);

  @override
  Future<int?> waitRun(String log) async =>
      (await repositoryCall(() => engine.exitOf(log))).toNullable();
}

/// The list in [home], in the engine's order: by title without case, then by
/// path. A native game is told by its path, the engine's one rule, and
/// [emulators] say whether macOS keeps its app in quarantine, where they are
/// supported.
Future<List<SwitchGame>> _gamesIn(
  String home,
  engine.EmulatorHost emulators,
) async => [
  for (final game in engine.switchGames(home))
    if (engine.isNativeApp(game.path))
      SwitchGame(
        path: game.path,
        title: game.title,
        titleId: game.titleId,
        native: true,
        quarantined:
            emulators.supported &&
            ((await emulators.nativeApp(game.path))?.quarantined ?? false),
      )
    else
      SwitchGame(path: game.path, title: game.title, titleId: game.titleId),
];
