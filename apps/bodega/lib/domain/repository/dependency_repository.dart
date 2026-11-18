import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:fpdart/fpdart.dart';

abstract class DependencyRepository {
  /// Every runtime with its status in [bottle], and what its apps need.
  Future<Either<AppError, BottleDependencies>> bottle(String bottle);

  /// What the app with [key] needs in [bottle].
  Future<Either<AppError, AppNeeds>> needs(String bottle, String key);

  /// The key the catalog app [catalogId] gets in a bottle once installed.
  Future<Either<AppError, String>> catalogKey(String catalogId);

  /// The installer of [id] for [arch]: the one already downloaded when it
  /// matches its SHA-256, or else a download, with progress. Null if it was
  /// cancelled with [cancelDownload].
  Future<Either<AppError, String?>> download(
    String id,
    Arch arch,
    void Function(int received, int? total) onProgress,
  );

  void cancelDownload();

  /// Installs [id] for [arch] in [bottle] from [file], checked against its
  /// pinned SHA-256.
  Future<Either<AppError, Unit>> install(
    String bottle,
    String id,
    Arch arch,
    String file,
  );

  /// Applies fix [fix]'s changes to its game's settings file in [bottle].
  Future<Either<AppError, Unit>> applySettings(String bottle, String fix);
}
