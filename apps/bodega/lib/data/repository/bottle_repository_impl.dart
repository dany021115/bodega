import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/library_app.dart';
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
        Bottle(
          name: bottle.name,
          ready: bottle.ready,
          app: switch (bottle.app) {
            final app? => LibraryApp(
              bottle: app.bottle,
              id: app.id,
              title: app.title,
            ),
            null => null,
          },
        ),
    ],
  );

  @override
  Future<Either<AppError, BottleDetail>> detail(String name) =>
      repositoryCall(() {
        final settings = engine.bottleSettings(_home.path, name);
        return BottleDetail(
          name: name,
          backend: settings.backend,
          sync: settings.sync,
          exceptions: [
            for (final MapEntry(:key, :value) in settings.programs.entries)
              if (value.backend case final backend?)
                ProgramBackend(exe: key, backend: backend),
          ],
          logs: [
            for (final log in engine.bottleLogs(_home.path, name))
              BottleLogEntry(
                path: log.path,
                name: log.name,
                modified: log.modified,
                exitCode: log.exitCode,
              ),
          ],
          installedBackends: [
            for (final MapEntry(:key, :value)
                in engine.listBackends(_home.path).entries)
              if (value) key,
          ],
        );
      });

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
  Future<Either<AppError, Unit>> delete(String name) =>
      repositoryCall(() async {
        await engine.removeBottle(_home.path, name);
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
