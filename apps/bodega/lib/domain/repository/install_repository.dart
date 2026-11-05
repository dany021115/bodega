import 'package:bodega/domain/entities/app_error.dart';
import 'package:fpdart/fpdart.dart';

abstract class InstallRepository {
  /// Downloads the installer of [id] and returns its path, or null if it was
  /// cancelled with [cancelDownload]. Fails if its bottle already exists.
  Future<Either<AppError, String?>> download(
    String id,
    void Function(int received, int? total) onProgress, {
    bool intoExisting = false,
  });

  void cancelDownload();

  /// In a bottle of its own, or in [bottle] if given, which must be ready.
  Future<Either<AppError, Unit>> install(
    String id,
    String setup,
    void Function(String step) onStep, {
    String? bottle,
  });

  bool bottleExists(String name);

  Future<Either<AppError, Unit>> removeBottle(String name);
}
