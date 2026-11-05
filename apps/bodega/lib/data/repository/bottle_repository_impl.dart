import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bodega/data/service/app_mapper.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BottleRepository)
class BottleRepositoryImpl implements BottleRepository {
  static const _maxLogLines = 2000;

  final EngineHome _home;

  BottleRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<Bottle>>> list() => repositoryCall(
    () => [
      for (final bottle in engine.listBottles(_home.path))
        Bottle(name: bottle.name, ready: bottle.ready),
    ],
  );

  @override
  Future<Either<AppError, BottleDetail>> detail(String name) {
    final home = _home.path;
    return repositoryCall(() => Isolate.run(() => _detail(home, name)));
  }

  @override
  Future<Either<AppError, Unit>> setBackend(
    String name,
    String backend, {
    String? exe,
  }) => repositoryCall(() {
    engine.setBackend(_home.path, name, backend, exe: exe);
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> setSync(String name, String sync) =>
      repositoryCall(() async {
        await engine.setSync(_home.path, name, sync);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> setHighRes(String name, bool value) =>
      repositoryCall(() async {
        await engine.setHighRes(_home.path, name, value);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> setWindowsVersion(
    String name,
    String version,
  ) => repositoryCall(() async {
    await engine.setWindowsVersion(_home.path, name, version);
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> setOptions(
    String name, {
    bool? dlss,
    bool? avx,
  }) => repositoryCall(() {
    engine.setBottleOptions(_home.path, name, dlss: dlss, avx: avx);
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> delete(String name) =>
      repositoryCall(() async {
        await engine.removeBottle(_home.path, name);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> hideApp(String name, String key) =>
      repositoryCall(() {
        engine.hideApp(_home.path, name, key);
        return unit;
      });

  @override
  Future<Either<AppError, List<String>>> logLines(String path) =>
      repositoryCall(() async {
        final lines = ListQueue<String>();
        final stream = File(path)
            .openRead()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter());
        await for (final line in stream) {
          lines.add(line);
          if (lines.length > _maxLogLines) lines.removeFirst();
        }
        return lines.toList();
      });
}

BottleDetail _detail(String home, String name) {
  final settings = engine.bottleSettings(home, name);
  return BottleDetail(
    name: name,
    ready: engine.listBottles(home).any((b) => b.name == name && b.ready),
    backend: settings.backend,
    sync: settings.sync,
    highRes: settings.highRes,
    dlss: settings.dlss,
    avx: settings.avx,
    windows: settings.windows,
    driveC: '${engine.bottleDir(home, name)}/prefix/drive_c',
    apps: libraryApps(home, engine.bottleApps(home, name)),
    exceptions: [
      for (final MapEntry(:key, :value) in settings.programs.entries)
        if (value.backend case final backend?)
          ProgramBackend(exe: key, backend: backend),
    ],
    logs: [
      for (final log in engine.bottleLogs(home, name))
        BottleLogEntry(
          path: log.path,
          name: log.name,
          modified: log.modified,
          exitCode: log.exitCode,
        ),
    ],
    installedBackends: [
      for (final MapEntry(:key, :value) in engine.listBackends(home).entries)
        if (value) key,
    ],
  );
}
