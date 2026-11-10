import 'dart:io';

import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/progress_mapper.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/progress_step.dart';
import 'package:bodega/domain/repository/install_repository.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: InstallRepository)
class InstallRepositoryImpl implements InstallRepository {
  final EngineHome _home;
  final Downloader _downloader;
  CancelToken? _cancel;

  InstallRepositoryImpl(this._home, this._downloader);

  @override
  Future<Either<AppError, String?>> download(
    String id,
    void Function(int received, int? total) onProgress, {
    bool intoExisting = false,
  }) => repositoryCall(() {
    final entry = engine.catalogEntry(id);
    if (!intoExisting && bottleExists(id)) {
      throw AppError.bottleExists(id);
    }
    final extension = entry.msi ? 'msi' : 'exe';
    return _downloader.fetch(
      entry.url,
      '${_home.path}/downloads/$id-setup.$extension',
      cancel: _cancel = CancelToken(),
      onProgress: onProgress,
    );
  });

  @override
  void cancelDownload() => _cancel?.cancel();

  @override
  Future<Either<AppError, Unit>> install(
    String id,
    String setup,
    void Function(ProgressStep step) onStep, {
    String? bottle,
  }) => repositoryCall(() async {
    await engine.installEntry(
      _home.path,
      engine.catalogEntry(id),
      bottle: bottle,
      intoExisting: bottle != null,
      setup: setup,
      onStep: (step) => onStep(progressStep(step)),
    );
    return unit;
  });

  @override
  bool bottleExists(String name) =>
      Directory(engine.bottleDir(_home.path, name)).existsSync();

  @override
  Future<Either<AppError, Unit>> removeBottle(String name) =>
      repositoryCall(() async {
        await engine.removeBottle(_home.path, name);
        return unit;
      });
}
