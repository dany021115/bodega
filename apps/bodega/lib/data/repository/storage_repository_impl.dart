import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/storage_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: StorageRepository)
class StorageRepositoryImpl implements StorageRepository {
  final EngineHome _home;

  StorageRepositoryImpl(this._home);

  @override
  String get dataFolder => _home.path;

  @override
  Future<Either<AppError, int>> downloadsSize() =>
      repositoryCall(() => engine.downloadsSize(_home.path));

  @override
  Future<Either<AppError, Unit>> clearDownloads() => repositoryCall(() {
    engine.clearDownloads(_home.path);
    return unit;
  });
}
