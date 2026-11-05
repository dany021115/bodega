import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:fpdart/fpdart.dart';

abstract class BottleRepository {
  Future<Either<AppError, List<Bottle>>> list();

  Future<Either<AppError, BottleDetail>> detail(String name);

  /// The bottle's backend or, with [exe], that program's exception. `auto` on
  /// a program removes its exception.
  Future<Either<AppError, Unit>> setBackend(
    String name,
    String backend, {
    String? exe,
  });

  /// Closes what is open in the bottle.
  Future<Either<AppError, Unit>> setSync(String name, String sync);

  /// Closes what is open in the bottle.
  Future<Either<AppError, Unit>> setHighRes(String name, bool value);

  Future<Either<AppError, Unit>> setWindowsVersion(String name, String version);

  Future<Either<AppError, Unit>> setOptions(
    String name, {
    bool? dlss,
    bool? avx,
  });

  Future<Either<AppError, Unit>> delete(String name);

  /// Takes the application out of the bottle's list.
  Future<Either<AppError, Unit>> hideApp(String name, String key);

  /// The last 2,000 lines of a log.
  Future<Either<AppError, List<String>>> logLines(String path);
}
