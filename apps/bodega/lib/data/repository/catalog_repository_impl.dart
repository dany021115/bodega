import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/repository/catalog_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CatalogRepository)
class CatalogRepositoryImpl implements CatalogRepository {
  final EngineHome _home;

  CatalogRepositoryImpl(this._home);

  /// The catalog's entries as data: their prose stays in the engine, in
  /// English, and the app words it from its ARBs by id (design §7).
  @override
  Future<Either<AppError, List<CatalogApp>>> apps() => repositoryCall(() {
    final installed = {
      for (final app in engine.installedApps(_home.path)) app.id: app,
    };
    final backends = engine.listBackends(_home.path);
    return [
      for (final entry in engine.catalogEntries())
        CatalogApp(
          id: entry.id,
          title: entry.title,
          status: CatalogStatus.values.byName(entry.status),
          flaky: entry.flaky != null,
          backend: entry.backend,
          backendInstalled: backends[entry.backend] ?? false,
          sync: entry.sync,
          host: Uri.parse(entry.url).host,
          hasChecksum: entry.sha256 != null,
          source: entry.source,
          bottle: installed[entry.id]?.bottle,
          appKey: installed[entry.id]?.key,
          installKey: engine.appKey(entry.exe),
        ),
    ];
  });
}
