import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:fpdart/fpdart.dart';

abstract class BackendRepository {
  Future<Either<AppError, List<BackendInfo>>> list();

  /// The bottles that can run a check.
  Future<Either<AppError, List<String>>> readyBottles();

  /// Downloads and installs [name], checking its pinned SHA-256. False if it
  /// was cancelled with [cancelDownload].
  Future<Either<AppError, bool>> download(
    String name,
    void Function(int received, int? total) onProgress,
  );

  void cancelDownload();

  Future<Either<AppError, Unit>> installFile(String name, String tarball);

  Future<Either<AppError, Unit>> importD3DMetal(String folder);

  /// Closes what is open in [bottle], and runs the probe with [backend].
  Future<Either<AppError, List<ProbeResult>>> check(
    String bottle,
    String backend,
  );
}
