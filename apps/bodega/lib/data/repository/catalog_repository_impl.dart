import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/repository/catalog_repository.dart';
import 'package:engine/engine.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CatalogRepository)
class CatalogRepositoryImpl implements CatalogRepository {
  final EngineHome _home;

  CatalogRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<CatalogApp>>> apps() => repositoryCall(() {
    final installed = {
      for (final app in installedApps(_home.path)) app.id: app,
    };
    final backends = listBackends(_home.path);
    return [
      for (final entry in catalogEntries())
        CatalogApp(
          id: entry.id,
          title: entry.title,
          status: CatalogStatus.values.byName(entry.status),
          statusNote: entry.statusNote,
          flaky: entry.flaky,
          backend: entry.backend,
          backendInstalled: backends[entry.backend] ?? false,
          sync: entry.sync,
          host: Uri.parse(entry.url).host,
          hasChecksum: entry.sha256 != null,
          notes: entry.notes,
          knownIssues: [
            for (final issue in entry.knownIssues)
              KnownIssue(symptom: issue.symptom, fix: issue.fix),
          ],
          source: entry.source,
          bottle: installed[entry.id]?.bottle,
          appKey: installed[entry.id]?.key,
        ),
    ];
  });
}
