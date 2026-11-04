import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LibraryRepository)
class LibraryRepositoryImpl implements LibraryRepository {
  final EngineHome _home;

  LibraryRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<LibraryApp>>> apps() => repositoryCall(
    () => [
      for (final app in engine.installedApps(_home.path))
        LibraryApp(bottle: app.bottle, id: app.id, title: app.title),
    ],
  );

  @override
  Future<Either<AppError, String>> open(String bottle) =>
      repositoryCall(() => engine.openApp(_home.path, bottle));

  @override
  Future<Either<AppError, Unit>> stop(String bottle) =>
      repositoryCall(() async {
        await engine.stopBottle(_home.path, bottle);
        return unit;
      });

  // A failure in these two only means there is nothing left to wait for.
  @override
  Future<void> firstExit(String log) =>
      repositoryCall(() => engine.exitOf(log));

  @override
  Future<void> waitBottle(String bottle) =>
      repositoryCall(() => engine.waitBottle(_home.path, bottle));

  @override
  List<String> antiCheatHints(String bottle, DateTime since) {
    try {
      return engine.antiCheatHints(_home.path, bottle, since: since);
    } on Object {
      return const [];
    }
  }

  @override
  Future<List<String>> hintsIn(String log) async {
    try {
      return await engine.hintsIn(log);
    } on Object {
      return const [];
    }
  }
}
