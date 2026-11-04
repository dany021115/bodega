import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/runtime_status.dart';
import 'package:fpdart/fpdart.dart';

abstract class RuntimeRepository {
  Future<Either<AppError, RuntimeStatus>> status();

  /// Installs the runtime from local tarballs, each with its `.sha256` beside.
  Future<Either<AppError, Unit>> install({
    required String engine,
    required String hostlibs,
  });
}
