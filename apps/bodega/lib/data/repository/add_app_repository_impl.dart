import 'dart:io';

import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/add_app_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AddAppRepository)
class AddAppRepositoryImpl implements AddAppRepository {
  final EngineHome _home;

  AddAppRepositoryImpl(this._home);

  @override
  String? pathProblem(String path) {
    if (!File(path).existsSync()) return 'No existe $path';
    return engine.winPathProblem(path);
  }

  @override
  Future<Either<AppError, String>> addApp(
    String bottle,
    String title,
    String exe,
  ) => repositoryCall(() {
    // Inside the bottle it goes as C:\…, which survives moving the bottle.
    final drive = '${driveC(bottle)}/';
    final path = exe.startsWith(drive) ? exe.substring(drive.length) : exe;
    engine.addApp(_home.path, bottle, title, path);
    // The key the engine stores the app under, for the library.
    return engine.appKey(path);
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
