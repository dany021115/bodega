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

  Future<Either<AppError, Unit>> delete(String name);

  /// The last 2,000 lines of a log.
  Future<Either<AppError, List<String>>> logLines(String path);
}
