import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:fpdart/fpdart.dart';

abstract class UpdateRepository {
  /// A1: a newer release, or null: none, asked less than a day ago, skipped,
  /// or no answer. No answer is null too: an update is not worth an error.
  Future<Either<AppError, AppUpdate?>> check();

  /// "Not now": no more notices of [version].
  Future<Either<AppError, Unit>> skip(String version);

  /// A4: the installer, checked against its SHA-256. Null if it was cancelled
  /// with [cancel].
  Future<Either<AppError, String?>> download(
    AppUpdate update,
    void Function(int received, int? total) onProgress,
  );

  void cancel();

  /// A4: puts [file] in place of the running app, once it closes, and opens it.
  /// Only the program changes: the data folder and preferences stay (A5).
  Future<Either<AppError, Unit>> install(String file);

  /// Closes the app, so the new version can take its place.
  void quit();
}
