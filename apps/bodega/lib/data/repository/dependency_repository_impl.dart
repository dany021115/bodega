import 'dart:io';

import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/domain/repository/dependency_repository.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DependencyRepository)
class DependencyRepositoryImpl implements DependencyRepository {
  final EngineHome _home;
  final Downloader _downloader;
  CancelToken? _cancel;

  DependencyRepositoryImpl(this._home, this._downloader);

  static String _arch(Arch arch) => switch (arch) {
    Arch.x86 => 'x86',
    Arch.x64 => 'x64',
  };

  static Dependency _dependency(String id, String arch, bool installed) {
    final row = engine.dependencyTable.firstWhere((row) => row.id == id);
    return Dependency(
      id: id,
      name: row.name,
      arch: arch == 'x64' ? Arch.x64 : Arch.x86,
      bytes: (arch == 'x64' ? row.x64 : row.x86).bytes,
      installed: installed,
    );
  }

  static AppNeeds _needs(String title, engine.AppNeeds needs) => AppNeeds(
    key: needs.key,
    title: title,
    dependencies: [
      for (final need in needs.dependencies)
        DependencyNeed(
          dependency: _dependency(need.id, need.arch, need.installed),
          need: switch (need.need) {
            engine.Need.recommended => Need.recommended,
            engine.Need.optional => Need.optional,
          },
          reason: switch (need.reason) {
            engine.NeedReason.knownFix => NeedReason.knownFix,
            engine.NeedReason.notInWine => NeedReason.notInWine,
            engine.NeedReason.imported => NeedReason.imported,
          },
          dll: need.dll,
          fix: need.fix,
        ),
    ],
    settings: [
      for (final setting in needs.settings)
        SettingNeed(
          fix: setting.fix,
          game: engine.gameFix(setting.fix).title,
          section: setting.section,
          name: setting.name,
          value: setting.value,
          state: switch (setting.state) {
            engine.SettingState.applied => SettingState.applied,
            engine.SettingState.notApplied => SettingState.notApplied,
            engine.SettingState.noFile => SettingState.noFile,
          },
        ),
    ],
  );

  // ponytail: every app is worked out again, each reading the bottle's list;
  // fine for tens of apps, a shared read if a bottle ever holds hundreds.
  @override
  Future<Either<AppError, BottleDependencies>> bottle(String bottle) =>
      repositoryCall(() async {
        final home = _home.path;
        final apps = <AppNeeds>[];
        for (final app in engine.bottleApps(home, bottle)) {
          final needs = _needs(
            app.title,
            await engine.appNeeds(home, bottle, app.key),
          );
          if (!needs.isEmpty) apps.add(needs);
        }
        return BottleDependencies(
          all: [
            for (final line in engine.bottleDependencies(home, bottle))
              _dependency(line.id, line.arch, line.installed),
          ],
          apps: apps,
        );
      });

  @override
  Future<Either<AppError, AppNeeds>> needs(String bottle, String key) =>
      repositoryCall(() async {
        final home = _home.path;
        final app = engine
            .bottleApps(home, bottle)
            .where((app) => app.key == key)
            .firstOrNull;
        return _needs(
          app?.title ?? key,
          await engine.appNeeds(home, bottle, key),
        );
      });

  @override
  Future<Either<AppError, String>> catalogKey(String catalogId) =>
      repositoryCall(() => engine.appKey(engine.catalogEntry(catalogId).exe));

  @override
  Future<Either<AppError, String?>> download(
    String id,
    Arch arch,
    void Function(int received, int? total) onProgress,
  ) => repositoryCall(() async {
    final pin = engine.dependencyDownload(_home.path, id, _arch(arch));
    if (File(pin.path).existsSync() &&
        await engine.sha256Of(pin.path) == pin.sha256) {
      return pin.path;
    }
    return _downloader.fetch(
      pin.url,
      pin.path,
      cancel: _cancel = CancelToken(),
      onProgress: onProgress,
    );
  });

  @override
  void cancelDownload() => _cancel?.cancel();

  @override
  Future<Either<AppError, Unit>> install(
    String bottle,
    String id,
    Arch arch,
    String file,
  ) => repositoryCall(() async {
    try {
      await engine.installDependency(
        _home.path,
        bottle,
        id,
        _arch(arch),
        file: file,
      );
    } on engine.ChecksumMismatch {
      // A bad download must not be reused by the next attempt; a file the
      // user picked stays where it was.
      final cached = engine.dependencyDownload(_home.path, id, _arch(arch));
      if (file == cached.path && File(file).existsSync()) {
        File(file).deleteSync();
      }
      rethrow;
    }
    return unit;
  });

  @override
  Future<Either<AppError, Unit>> applySettings(String bottle, String fix) =>
      repositoryCall(() async {
        await engine.applyFixSettings(_home.path, bottle, fix);
        return unit;
      });
}
