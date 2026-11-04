import 'dart:io';
import 'dart:math';

import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/add_app_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// A valid, free bottle name for [title]: `Mi Juego!` is `mi-juego`, and
/// `mi-juego-2` if that one is taken.
String bottleNameFor(String title, Iterable<String> taken) {
  final used = {for (final name in taken) name.toLowerCase()};
  final base = title
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final name = base.isEmpty ? 'app' : base.substring(0, min(base.length, 58));
  if (!used.contains(name)) return name;
  for (var suffix = 2; ; suffix++) {
    if (!used.contains('$name-$suffix')) return '$name-$suffix';
  }
}

@LazySingleton(as: AddAppRepository)
class AddAppRepositoryImpl implements AddAppRepository {
  final EngineHome _home;

  AddAppRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<String>>> readyBottles() => repositoryCall(
    () => [
      for (final bottle in engine.listBottles(_home.path))
        if (bottle.ready) bottle.name,
    ],
  );

  @override
  String? pathProblem(String path) {
    if (!File(path).existsSync()) return 'No existe $path';
    return engine.winPathProblem(path);
  }

  @override
  Future<Either<AppError, String>> createBottle(String title) =>
      repositoryCall(() async {
        final name = bottleNameFor(title, [
          for (final bottle in engine.listBottles(_home.path)) bottle.name,
        ]);
        await engine.createBottle(_home.path, name);
        return name;
      });

  @override
  Future<Either<AppError, Unit>> addApp(
    String bottle,
    String title,
    String exe,
  ) => repositoryCall(() {
    // Inside the bottle it goes as C:\…, which survives moving the bottle.
    final drive = '${driveC(bottle)}/';
    engine.addApp(
      _home.path,
      bottle,
      title,
      exe.startsWith(drive) ? exe.substring(drive.length) : exe,
    );
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> runInstaller(String bottle, String exe) =>
      repositoryCall(() async {
        // Like the catalog's installers: their own windows need no layer.
        final log = await engine.runInBottle(
          _home.path,
          bottle,
          exe,
          const [],
          backend: 'wine',
        );
        await engine.exitOf(log);
        await engine.waitBottle(_home.path, bottle);
        return unit;
      });

  @override
  String driveC(String bottle) =>
      '${engine.bottleDir(_home.path, bottle)}/prefix/drive_c';
}
